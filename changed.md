# Changes for Lenovo TB351FU (LineageOS 23 / Android 16 "Baklava")

## Problem

Device hangs in boot animation because `system_server` crashes during
`AppOpsService.systemReady()`. Boot log (`/metadata/boot_log.txt`) shows
4 consecutive crash cycles (each ~5 seconds apart):

```
FATAL EXCEPTION IN SYSTEM PROCESS: main
java.lang.IllegalStateException: Missing permission definition for
  permission "android.permission.POST_PROMOTED_NOTIFICATIONS"
  associated with app op 163
        at AppOpService.createPermissionAppOpMapping(AppOpService.kt:128)
        at AppOpService.systemReady(AppOpService.kt:109)
        at AppOpsService.systemReady(AppOpsService.java:1148)
        at ActivityManagerService.systemReady(ActivityManagerService.java:9045)
```

### Root Cause

128 `<permission>` tags in `frameworks/base/core/res/AndroidManifest.xml`
carry an `android:featureFlag` attribute that gates the permission
declaration at build time. AAPT2 evaluates the aconfig flag at compile
time: when the flag is TRUE (default), it includes the permission XML
node with the raw `featureFlag` attribute preserved. At runtime,
`PackageManagerService` checks the actual aconfig flag value via
`AconfigService`. If the flag overlay is absent at runtime (which is
the case on this device — the flags live in separate APEX modules like
`com.android.settingslib.flags`, `com.android.permissioncontroller.flags`,
etc., not in the framework's own flag overlay), `AconfigService` returns
`FALSE`, causing `PackageManagerService` to treat the permission as
**undefined**. `AppOpService` then crashes because the corresponding
app op (e.g., OP_POST_PROMOTED_NOTIFICATIONS = 163) expects its
mapped permission to be defined.

### Permissions Affected

All 128 permission tags with `android:featureFlag` must have the
attribute removed. These include:

```
POST_PROMOTED_NOTIFICATIONS    (app op 163, first crash observed)
WRITE_SYSTEM_PREFERENCES       (app op 153, original crash)
ACCESS_LOCAL_NETWORK           (app op 162)
... and 125 more (full list in original patcher output)
```

## Fix Strategy

### Approach: Device-tree post-build patching

Instead of modifying AOSP framework source (which would be overwritten
by `repo sync`), the fix is implemented entirely within the device tree:

1. **`patches/patch_framework_res.py`** — Binary-level patcher that
   removes `android:featureFlag` attributes from all `<permission>` XML
   nodes in the compiled `AndroidManifest.xml` inside `framework-res.apk`.

2. **`Android.mk`** — New `patch_framework_res` module (post-build hook)
   that runs the patcher script after `framework-res.apk` is built,
   patching it in-place before the final packaging step.

3. **`Android.mk` re-signing fix** — The patcher produces an unsigned
   intermediate APK; `signapk.jar` (with platform key) re-signs it
   with a valid v2 APK signature so the APK passes Android's signature
   verification at boot.

4. **`device.mk`** — Added `patch_framework_res` to `PRODUCT_PACKAGES`.

5. **`rootdir/etc/init.boot_logger.rc`** — Early-boot script to capture
   `dmesg` + logcat to `/metadata/` for debugging boot failures.

### Why not source-level fix

A source-level fix was attempted first (removing `android:featureFlag`
from `frameworks/base/core/res/AndroidManifest.xml`), but:
- It is fragile: a `repo sync` or framework update reverts it
- It requires modifying AOSP source, complicating upstream updates
- The device-tree approach is self-contained and survives syncs

## Files Modified / Created

### `device/lenovo/tb351fu/Android.mk`

Added `patch_framework_res` module with re-signing (lines 14–31):

```makefile
include $(CLEAR_VARS)
LOCAL_MODULE := patch_framework_res
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE): $(PRODUCT_OUT)/system/framework/framework-res.apk
	python3 $(TB351FU_DEVICE_PATH)/patches/patch_framework_res.py \
		--apk $(PRODUCT_OUT)/system/framework/framework-res.apk \
		--out $(PRODUCT_OUT)/system/framework/framework-res_patched.apk
	java -Djava.library.path=$(PRODUCT_OUT)/../../../host/linux-x86/lib64 \
		-jar $(PRODUCT_OUT)/../../../host/linux-x86/framework/signapk.jar \
		build/make/target/product/security/platform.x509.pem \
		build/make/target/product/security/platform.pk8 \
		$(PRODUCT_OUT)/system/framework/framework-res_patched.apk \
		$(PRODUCT_OUT)/system/framework/framework-res.apk
	rm -f $(PRODUCT_OUT)/system/framework/framework-res_patched.apk
	touch $@
```

The re-signing step was added because Android 16 requires valid v2 APK
signatures. The original patcher produced an unsigned APK (no
signatures), which passed for AOSP builds with verification disabled,
but failed on this device (stock bootloader enforces signature checks).

### `device/lenovo/tb351fu/device.mk`

Added `patch_framework_res` to `PRODUCT_PACKAGES` (line 55):

```makefile
PRODUCT_PACKAGES += \
    recovery \
    splice_vendor_boot \
    patch_framework_res \
    ...
```

Added `init.boot_logger.rc` to `PRODUCT_COPY_FILES` (line 145):

```makefile
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.boot_logger.rc:vendor/etc/init/hw/init.boot_logger.rc
```

### `device/lenovo/tb351fu/patches/patch_framework_res.py`

**None-case fix:** When no `featureFlag` attributes are found (already
patched or source was updated), the original script exited with
`sys.exit(0)` producing no output. This caused the make rule to fail
because the subsequent re-signing step had no input file.

**Fix:** Changed `sys.exit(0)` to produce `bytes(manifest)` (writing
the unmodified XML back) so the re-signing pipeline always has input:

```python
# Old: sys.exit(0)
# New:
sys.stdout.buffer.write(bytes(manifest))
sys.exit(0)
```

### `device/lenovo/tb351fu/rootdir/etc/init.boot_logger.rc`

**New file** — Early-boot debugging aid. Runs at `on init` phase:

```
on init
    exec u:r:init:s0 -- /system/bin/sh -c 'dmesg > /metadata/boot_dmesg.txt 2>&1; echo boot_dmesg_captured > /metadata/boot_logger_status.txt'
```

Captures kernel log to `/metadata/` at the earliest possible init stage.
Does NOT run if the crash happens before `on init`.

## Flash Procedure

### `out/target/product/tb351fu/flash.sh`

```bash
set -e
fastboot wipe-super super_empty.img         # Destroys & recreates logical partitions
fastboot flash system_a system.img
fastboot flash vendor_a vendor.img
fastboot flash system_ext_a system_ext.img
fastboot flash product_a product.img
fastboot flash vendor_boot_a vendor_boot.img
fastboot erase metadata                     # Erases VABC metadata (critical!)
fastboot reboot
```

**IMPORTANT:** `fastboot erase metadata` causes all first-stage boot
logs to be lost, because the metadata partition is empty (all zeros)
and any init scripts writing to `/metadata/` never execute if the
device crashes before `on init`.

### Manual vbmeta flashing (diagnostic)

When AVB verification causes early boot failure, flash vbmeta with
verity disabled:

```bash
fastboot flash vbmeta_a vbmeta.img --disable-verity --disable-verification
fastboot flash vbmeta_system_a vbmeta_system.img --disable-verity --disable-verification
fastboot flash vbmeta_vendor_a vbmeta_vendor.img --disable-verity --disable-verification
```

## Vendor Boot Reconstruction

### `device/lenovo/tb351fu/rebuild_vendor_boot.sh`

Rebuilds `vendor_boot.img` using:

1. **Stock DTB** (`prebuilt/dtb.dtb`) — extracted from stock firmware
2. **Stock vendor ramdisk** (`prebuilt/vendor_ramdisk00`) — fragment 0
3. **Custom recovery ramdisk** — repacked from `out/recovery/root` (fragment 1)
4. **Stock header splice** — `splice_header.py` overwrites bytes 0-4095
   with `stock_header.bin`, preserving 4 AOSP fields:
   - bytes 24:28 — header version / kernel metadata
   - bytes 112:116 — vendor ramdisk offset
   - bytes 124:128 — vendor bootconfig offset
   - bytes 136:140 — DTB offset
5. **AVB hash footer** — `avbtool add_hash_footer` with test key for
   vbmeta compliance

### `device/lenovo/tb351fu/splice_header.py`

Replaces the first 4096 bytes of the AOSP-built vendor_boot with the
stock Lenovo header (from `stock_header.bin`). This is required because
the stock bootloader checks fields (magic, header version, memory layout)
that only match the stock format.

Four fields are preserved from the AOSP header (sizes, offsets of
ramdisk/bootconfig/DTB components) since these change each build.

## Build Order Issue (patch_framework_res)

The `patch_framework_res` module modifies `framework-res.apk` in-place
after it is installed to `PRODUCT_OUT/system/framework/`. The
dependency chain in the build system is:

```
framework-res.apk (built by AAPT2)
    → patch_framework_res (patches + re-signs)
        → system.img (assembled from installed files)
```

**Potential race:** The build system runs targets in parallel based on
the dependency graph. If `system.img` does NOT explicitly depend on
`patch_framework_res`, it could be assembled before the patcher runs.
This would result in the APK in the image being the original
(unpatched, incorrectly-signed) version.

**Current mitigation:** `patch_framework_res` is in `PRODUCT_PACKAGES`,
which ensures it is built as part of `droidcore`. The patcher modifies
`framework-res.apk` before `system.img` is assembled (verified by
SHA256 extraction from the EROFS image).

## Debugging: Boot Capture via /metadata

### `init.boot_logger.rc`

Copies to `vendor/etc/init/hw/init.boot_logger.rc`. Runs at `on init`:

```
on init
    exec u:r:init:s0 -- /system/bin/sh -c 'dmesg > /metadata/boot_dmesg.txt 2>&1; echo done > /metadata/boot_logger_status.txt'
```

Only captures logs if the device reaches the `on init` phase. For
crashes before init (kernel panic, early boot), use pstore instead:

```bash
adb shell cat /sys/fs/pstore/console-ramoops-0
```

## Current Status (July 2, 2026)

### What works
- APK patching + re-signing with signapk.jar produces a valid v2
  signature (`apksigner` verified)
- Patched APK is correctly included in system.img (SHA256 match)
- Vendor boot reconstruction with stock header splice + AVB footer
- vbmeta flashing with `--disable-verity --disable-verification`

### What is broken
- **Device crashes immediately after orange state** — even without our
  device-tree changes. The crash happens before pstore init (<0.3s
  after kernel start), so NO boot logs are available.
- Pstore (console-ramoops-0) contains data from a PREVIOUS successful
  boot session, NOT from the crash. The new crash is too early.
- `fastboot erase metadata` in flash.sh erases the partition, causing
  any `/metadata/` boot logs to be lost across reboots.
- The metadata partition is all zeros after `fastboot erase metadata`.
  Even manually formatting it with ext4 and writing VABC merge state
  did NOT resolve the crash.

### Isolated observations
- The same `boot.img` (Jul 1, unchanged) was previously able to boot
  to the boot animation. The boot.img has NOT been rebuilt.
- The `vendor_boot.img` reconstruction was isolated: flashing STOCK
  vendor_boot produces the same crash.
- vbmeta with `--disable-verity --disable-verification` did NOT help.
- The crash is reproducible with ALL device-tree changes reverted:
  the problem is NOT in `patch_framework_res` or `init.boot_logger.rc`.
- The device has A/B slots (active: a). The `super` partition was
  wiped with `fastboot wipe-super super_empty.img` during flashing.
- `ro.virtual_ab.enabled=true` — Virtual A/B with compression (VABC)
  is enabled. The metadata partition stores VABC snapshot state.

### Likely root cause (not confirmed)
The crash may be caused by:
1. **Flash corruption** — `fastboot wipe-super` or `fastboot erase
   metadata` may have left the super partition in an inconsistent
   state that the kernel cannot recover from.
2. **VABC initialization failure** — The erased metadata partition may
   confuse VABC's first-stage mount code, causing a kernel panic.
3. **Boot image header mismatch** — The kernel in boot.img may expect
   a different boot image format than what vendor_boot provides.
4. **Hardware issue** — The device may have developed a hardware fault
   (DRAM, eMMC) coincident with the flash operation.

## Verification

### Static: patcher works on existing build output

```
$ python3 device/lenovo/tb351fu/patches/patch_framework_res.py \
    --apk out/target/product/tb351fu/system/framework/framework-res.apk
Reading: out/target/product/tb351fu/system/framework/framework-res.apk
String pool: 1982 strings
No featureFlag attributes found on permission tags!
```

("No featureFlag found" means the build was already patched via
source-level fix in a prior iteration — a fresh build with reverted
source will show `Patched X permission tag(s)`.)

### Dynamic

After rebuilding and flashing, the device should boot past the
boot animation. Verify by checking `logcat` (via `adb` once booted):
- No "Failure starting system services" errors
- No "Missing permission definition" errors
- System UI and Settings are responsive

If the device is still stuck, pull a fresh boot log from metadata
and check for remaining app-op permission mismatches.

## Bug: Hardcoded string index in patcher

The original `patch_framework_res.py` had `IDX_PERMISSION_TAG = 2048`
hardcoded. The tag-name string index for `<permission>` can shift
between builds (e.g., 2048 → 2049) as the string pool grows.

**Fix**: Added `_detect_permission_tag_idx()` that walks the XML
chunks at runtime to find which string index is used for the
`<permission>` tag name, making the patcher robust against string
pool layout changes.

## Chunk Tree Integrity (Patcher Script)

The patcher walks every chunk in the binary XML sequentially:
- Reads `chunkSize` at offset +4 from each chunk
- Computes next chunk as `pos + chunkSize`
- Verifies all chunks fit within the total buffer (`pos + cs <= len(data)`)
- Verifies no chunk has `cs <= 0`
- Verifies the RES_XML wrapper size matches `len(data)` exactly

After removing each attribute (20 bytes per attribute):
- Decrements `attrCount` at chunk offset +28
- Decrements `chunkSize` at chunk offset +4
- Updates the RES_XML total size at offset +4

All modifications are made in descending offset order to prevent
invalidation of earlier offsets as data shifts.
