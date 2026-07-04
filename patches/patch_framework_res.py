#!/usr/bin/env python3
"""Post-build patcher for framework-res.apk.

Removes the android:featureFlag attribute from permission definitions
in the binary AndroidManifest.xml, fixing first-boot crashes when
aconfig flags are not available at runtime.

Usage:
  patch_framework_res.py [--out PATH]

  By default, patches framework-res.apk in the build output directory
  (auto-detects OUT_DIR from env or uses default path).
"""

import argparse
import os
import struct
import sys
import zipfile

# String indices — these are stable across AAPT2 runs
IDX_ATTR_NAME = 3
IDX_FEATURE_FLAG = 49
# IDX_PERMISSION_TAG and IDX_PERMISSION_VALUE are resolved from
# the string pool at runtime (they can shift between builds)


def find_build_output():
    """Find the framework-res.apk in the build output."""
    out_dir = os.environ.get('OUT_DIR') or os.environ.get('OUT')
    if out_dir:
        apk = os.path.join(out_dir, 'target', 'product', 'tb351fu',
                           'system', 'framework', 'framework-res.apk')
        if os.path.exists(apk):
            return apk
    # Fallback: check cwd
    candidates = [
        '/run/media/hellopratik/Nvme/new_update/lineage/out/target/product'
        '/tb351fu/system/framework/framework-res.apk',
        'out/target/product/tb351fu/system/framework/framework-res.apk',
        'out/target/product/tb351fu/system/framework/framework-res.apk',
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def read_strings(data, sp_off=8):
    """Read all strings from the string pool."""
    sp_str_count = struct.unpack_from('<I', data, sp_off + 8)[0]
    sp_strings_start = struct.unpack_from('<I', data, sp_off + 20)[0]
    mStrings = sp_off + sp_strings_start

    strings = []
    for i in range(sp_str_count):
        entry = struct.unpack_from('<I', data, sp_off + 28 + i * 4)[0]
        byte_pos = mStrings + entry
        length = struct.unpack_from('<H', data, byte_pos)[0]
        raw = data[byte_pos + 2 : byte_pos + 2 + length * 2]
        s = raw.decode('utf-16-le', errors='replace')
        strings.append(''.join(c for c in s if c != '\x00'))
    return strings


def _detect_permission_tag_idx(data, strings):
    """Walk the XML chunks to find the string index used for <permission> tag name."""
    sp_off = 8
    sp_size = struct.unpack_from('<I', data, sp_off + 4)[0]
    pos = sp_off + sp_size
    TYPE_START_TAG = 0x0102
    while pos < len(data):
        typ = struct.unpack_from('<H', data, pos)[0]
        cs = struct.unpack_from('<I', data, pos + 4)[0]
        if cs <= 0:
            break
        if typ == TYPE_START_TAG:
            name_idx = struct.unpack_from('<I', data, pos + 20)[0]
            name = strings[name_idx] if name_idx < len(strings) else ''
            if name == 'permission':
                return name_idx
        pos += cs
    return None


def remove_feature_flag(data, strings):
    """Remove featureFlag attributes from permission tags.

    For permissions with duplicate declarations (featureFlag="X" and
    featureFlag="!X"), only the negated variant is kept active — the
    non-negated one retains its featureFlag so it stays inactive at
    boot (when aconfig flags default to FALSE).  This prevents the
    "Found duplicate permission with a different attribute value"
    crash in PackageManagerService.

    Returns (patched_data, count_removed) or raises on error.
    """
    perm_tag_idx = _detect_permission_tag_idx(data, strings)
    if perm_tag_idx is None:
        print("ERROR: Could not find <permission> tag in manifest!", file=sys.stderr)
        sys.exit(1)

    sp_off = 8
    sp_size = struct.unpack_from('<I', data, sp_off + 4)[0]
    pos = sp_off + sp_size
    TYPE_START_TAG = 0x0102

    # ── First pass: collect every <permission> tag ──────────────────
    # by_name: {name -> [(pos, attrCount, attrStart, ff_attrs)]}
    # ff_attrs is a list of attribute indices that are featureFlag
    by_name = {}

    while pos < len(data):
        typ = struct.unpack_from('<H', data, pos)[0]
        cs = struct.unpack_from('<I', data, pos + 4)[0]
        if cs <= 0:
            break
        if typ == TYPE_START_TAG:
            name_idx = struct.unpack_from('<I', data, pos + 20)[0]
            if name_idx == perm_tag_idx:
                attrStart = struct.unpack_from('<H', data, pos + 24)[0]
                attrCount = struct.unpack_from('<H', data, pos + 28)[0]
                attr_base = pos + 16 + attrStart
                perm_name = None
                ff_indices = []
                for ai in range(attrCount):
                    aoff = attr_base + ai * 20
                    aname_idx = struct.unpack_from('<I', data, aoff + 4)[0]
                    rawVal = struct.unpack_from('<I', data, aoff + 8)[0]
                    if aname_idx == IDX_ATTR_NAME:
                        perm_name = strings[rawVal] if 0 <= rawVal < len(strings) else '?'
                    if aname_idx == IDX_FEATURE_FLAG:
                        # Read the raw value to see if it is negated (!X)
                        ff_raw = strings[rawVal] if 0 <= rawVal < len(strings) else ''
                        ff_indices.append((ai, ff_raw))
                if perm_name:
                    by_name.setdefault(perm_name, []).append(
                        (pos, attrCount, attrStart, ff_indices))
        pos += cs

    if not by_name:
        return None, 0

    # ── Second pass: decide which tags to patch ─────────────────────
    # For names with single declaration: patch as normal.
    # For names with *multiple* declarations and featureFlags:
    #   patch only the one with !X (negated flag) so it becomes the
    #   permanent declaration; skip the non-negated variant(s).
    # For names with *multiple* declarations where only one has
    #   featureFlag: patch that one.
    to_patch = set()  # {(pos, ai)} tuples to remove

    for pname, decls in by_name.items():
        # Filter to those that have featureFlag
        with_ff = [(pos, ac, as_, ff_items) for pos, ac, as_, ff_items in decls if ff_items]
        if not with_ff:
            continue

        if len(decls) == 1:
            # Single declaration: remove all featureFlag attrs
            for pos, ac, as_, ff_items in with_ff:
                for ai, ff_raw in ff_items:
                    to_patch.add((pos, ai))
        else:
            # Multiple declarations.  Keep only the negated variant active.
            negated = [(pos, ac, as_, ff_items) for pos, ac, as_, ff_items in with_ff
                       if any(fr.startswith('!') for _, fr in ff_items)]
            if negated:
                # Patch only the negated one(s)
                for pos, ac, as_, ff_items in negated:
                    for ai, ff_raw in ff_items:
                        to_patch.add((pos, ai))
                print(f"  {pname}: {len(decls)} declarations; patching negated variant(s) only",
                      file=sys.stderr)
            else:
                # No negated variant — patch the last one (avoid duplication)
                pos, ac, as_, ff_items = with_ff[-1]
                for ai, ff_raw in ff_items:
                    to_patch.add((pos, ai))
                print(f"  {pname}: {len(decls)} declarations (no negated); patching last variant only",
                      file=sys.stderr)

    # ── Third pass: apply removals ──────────────────────────────────
    data = bytearray(data)

    # Sort by offset descending so deletions don't shift positions
    to_patch_list = []
    # Build full removal entries: for each (pos, ai), compute remove_offset
    for pname, decls in by_name.items():
        for pos, attrCount, attrStart, ff_items in decls:
            for ai, ff_raw in ff_items:
                if (pos, ai) in to_patch:
                    attr_base = pos + 16 + attrStart
                    remove_offset = attr_base + ai * 20
                    to_patch_list.append((pos, remove_offset, attrCount))

    to_patch_list.sort(key=lambda x: x[1], reverse=True)

    for pos, remove_offset, attrCount in to_patch_list:
        del data[remove_offset : remove_offset + 20]
        new_count = struct.unpack_from('<H', data, pos + 28)[0] - 1
        struct.pack_into('<H', data, pos + 28, new_count)
        new_cs = struct.unpack_from('<I', data, pos + 4)[0] - 20
        struct.pack_into('<I', data, pos + 4, new_cs)

    # Update RES_XML wrapper size
    struct.pack_into('<I', data, 4, len(data))

    print(f"Patched {len(to_patch_list)} featureFlag attribute(s) across {len(by_name)} permission(s)",
          file=sys.stderr)
    return data, len(to_patch_list)


def verify_manifest(data):
    """Quick integrity check on the patched manifest."""
    sp_off = 8
    sp_size = struct.unpack_from('<I', data, sp_off + 4)[0]
    pos = sp_off + sp_size
    errors = 0
    while pos < len(data):
        cs = struct.unpack_from('<I', data, pos + 4)[0]
        if cs <= 0 or pos + cs > len(data):
            errors += 1
            break
        pos += cs
    return errors == 0


def main():
    parser = argparse.ArgumentParser(
        description='Patch framework-res.apk: remove featureFlag from permissions')
    parser.add_argument('--apk', help='Path to framework-res.apk')
    parser.add_argument('--out', help='Output APK path')
    args = parser.parse_args()

    apk_path = args.apk or find_build_output()
    if not apk_path or not os.path.exists(apk_path):
        print("ERROR: framework-res.apk not found. Specify --apk or run from build dir.",
              file=sys.stderr)
        sys.exit(1)

    print(f"Reading: {apk_path}", file=sys.stderr)

    with zipfile.ZipFile(apk_path, 'r') as z:
        manifest = bytearray(z.read('AndroidManifest.xml'))

    strings = read_strings(manifest)
    print(f"String pool: {len(strings)} strings", file=sys.stderr)

    patched, count = remove_feature_flag(manifest, strings)
    if patched is None:
        print("No featureFlag attributes found on permission tags!", file=sys.stderr)
        patched = bytes(manifest)
        count = 0

    if not verify_manifest(patched):
        print("ERROR: Manifest integrity check failed!", file=sys.stderr)
        sys.exit(1)

    out_path = args.out or apk_path
    # Read all entries into memory first to avoid truncation when
    # reading and writing the same file (in-place patching).
    with zipfile.ZipFile(apk_path, 'r') as zin:
        entries = [(item, zin.read(item.filename)) for item in zin.infolist()]
    with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item, content in entries:
            if item.filename == 'AndroidManifest.xml':
                zout.writestr(item, bytes(patched))
            else:
                zout.writestr(item, content)

    print(f"Written: {out_path}", file=sys.stderr)
    print(f"Patched {count} permission tag(s)", file=sys.stderr)


if __name__ == '__main__':
    main()
