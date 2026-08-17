#!/bin/bash
# Apply all TB351FU-specific patches after `repo sync`
# Usage: cd <lineage_root> && bash device/lenovo/tb351fu/patches/apply_patches.sh

set -e

LINEAGE_ROOT="$(pwd)"
PATCHES_DIR="device/lenovo/tb351fu/patches"

echo "=== Applying TB351FU patches ==="
echo ""

apply_patch() {
    local pattern="$1"
    shift
    for f in "${LINEAGE_ROOT}/${PATCHES_DIR}/${pattern}"*.patch; do
        [ -f "$f" ] || continue
        echo -n "  $(basename "$f") ... "
        if patch -p1 -N --dry-run --silent < "$f" 2>/dev/null; then
            patch -p1 -N --silent < "$f"
            echo "OK"
        else
            echo "SKIP (already applied or context mismatch)"
        fi
    done
}

# ── Frameworks patches ──────────────────────────────────────────────
echo "--- frameworks/base ---"
for n in 0001 0002; do apply_patch "$n"; done

# ── Device tree patches ─────────────────────────────────────────────
echo "--- device/lenovo/tb351fu ---"
apply_patch 0003

# ── Vendor patches ──────────────────────────────────────────────────
echo "--- vendor/lenovo/tb351fu ---"

apply_patch 0004 || true

# Fallback: sed-based patch for vendor.mk if the .patch file failed
if grep -q '^    DebugLoggerUI \\' vendor/lenovo/tb351fu/tb351fu-vendor.mk 2>/dev/null; then
    echo -n "  tb351fu-vendor.mk (sed fallback) ... "
    sed -i 's/^    DebugLoggerUI \\/    # DebugLoggerUI \\/' \
        vendor/lenovo/tb351fu/tb351fu-vendor.mk && echo "OK" || echo "FAIL"
fi

# Comment out DebugLoggerUI in tb351fu-vendor-blobs.mk (untracked file)
if [ -f vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk ]; then
    echo -n "  tb351fu-vendor-blobs.mk (DebugLoggerUI) ... "
    if grep -q '^    DebugLoggerUI \\' vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk; then
        sed -i 's/^    DebugLoggerUI \\/    # DebugLoggerUI \\/' \
            vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk && echo "OK" || echo "FAIL"
    else
        echo "already commented or not found"
    fi
fi

echo ""
echo "=== All patches applied ==="
echo "Verify with:"
echo "  git -C frameworks/base diff --stat"
echo "  git -C device/lenovo/tb351fu diff --stat"
echo "  git -C vendor/lenovo/tb351fu diff --stat"
echo ""
echo "Then rebuild: ./build.sh"
