<p align="center">
  <img src="assets/readme-banner.svg" alt="Lenovo Tab Plus TB351FU device tree banner" />
</p>

# Android Device Tree for Lenovo Tab Plus TB351FU

This repository contains the public AOSP / LineageOS device tree currently being used for Lenovo Tab Plus `TB351FU` bring-up work.

The tree is focused on making the device boot and behave correctly on a modern aftermarket Android stack, with current work aimed at Android 16/17 and LineageOS-based development. It is a bring-up tree, so some parts are still evolving alongside the kernel, vendor, and recovery work.

## Status

- Device codename: `TB351FU`
- Product target: `lineage_TB351FU`
- ROM direction: Android 16/17 / LineageOS bring-up
- Board platform: `mt6789`
- Bootloader board name: `t808aa`
- Current dependencies: matching kernel tree, and the vendor tree (proprietary blobs bundled)

> [!NOTE]
> This repository is shared for development and educational use. It combines original Lenovo device information from the stock software base with LineageOS-style bring-up structure and community work needed to make the tree usable in an aftermarket build environment.

## Device Reference

| Item | Value |
| --- | --- |
| Device | Lenovo Tab Plus `TB351FU` |
| Brand / manufacturer | Lenovo |
| Platform | MediaTek `MT6789` |
| Board name | `t808aa` |
| Architecture | `arm64` with `arm` secondary support |
| Kernel | Stock Google-derived GKI 6.12 prebuilt |
| Vendor module KMI | `6.12-android16-5` (4 KiB pages) |
| Boot image format | Header v4 |
| Partition details | Virtual A/B, vendor boot, metadata partition, super partition |
| Filesystems in-tree | `erofs` for system images, `f2fs` for userdata |
| Security layout | AVB enabled, `vbmeta` flags configured in-tree |
| Device features referenced here | Dolby hooks, Lenovo pen support, tablet-specific hardware configs |

## What This Tree Covers

- product definition and lunch target wiring
- board configuration for the TB351FU platform
- `device.mk` product package and copy rules
- DTBO / prebuilt kernel-side assets used by bring-up
- recovery fstab and rootdir init configuration
- VINTF manifests and compatibility declarations
- extraction scaffolding for proprietary blobs (reference only — blobs are bundled in the vendor tree)

## Important Files

- [BoardConfig.mk](BoardConfig.mk): platform, partition, kernel, filesystem, and AVB settings
- [device.mk](device.mk): product packages, copy rules, and vendor tree inclusion
- [lineage_TB351FU.mk](lineage_TB351FU.mk): LineageOS product target definition
- [recovery.fstab](recovery.fstab): recovery mount and partition mapping
- [dts/](dts): DTBO-related source used by the current bring-up
- [rootdir/](rootdir): init and fstab content copied into the build
- [vintf/](vintf): manifest and framework compatibility declarations
- [proprietary-files.txt](proprietary-files.txt): blob manifest used with extract-utils

## Build Notes

The tree is set up like a standard LineageOS device tree. Once the matching vendor tree is present in your source checkout, the usual product target is:

```bash
lunch lineage_TB351FU-userdebug
```

Current in-tree expectations include:

- `TARGET_PREBUILT_KERNEL := device/lenovo/tb351fu/prebuilt/kernel`
- the stock DTB and DTBO from the same firmware family
- proprietary modules with KMI `6.12-android16-5`
- `vendor/lenovo/tb351fu/tb351fu-vendor.mk`

The Lenovo open-source release in `kernel/lenovo/tb351fu` is Linux 5.10 and
does not correspond to the 6.12 GKI used by current stock firmware. It is not
used to build the Android 16/17 boot image. Porting its drivers into Google
6.12 is also unnecessary for normal boot: hardware-specific MediaTek and
Lenovo support is delivered by the stock `vendor_dlkm` modules and stock DTB.

Do not replace the kernel with an arbitrary newer 6.12 image. In particular,
`6.12-android16-6` is a different KMI generation from the stock modules. Run
the compatibility check before building or testing another GKI:

```bash
device/lenovo/tb351fu/tools/verify-kmi.sh
```

## Blob Notes

Proprietary blobs are bundled directly in the matching vendor tree at `vendor/lenovo/tb351fu/proprietary/` — **no extraction step is required** to build this device. The vendor tree's `tb351fu-vendor-blobs.mk` and `Android.bp` reference the bundled payload directly.

### Re-generating the blobs from a stock dump or a running device

The bundled payload was produced from a stock firmware dump. If you want to re-extract the vendor blobs yourself, the LineageOS extract-utils flow is included:

```bash
# From a running device (stock or custom ROM, adb root required):
./extract-files.sh

# From a local stock system dump:
./extract-files.sh /path/to/system_dump
```

`extract-files.sh` pulls every file listed in `proprietary-files.txt` (either over `adb pull` from the connected device, or straight from the dump directory), copies it into `vendor/lenovo/tb351fu/proprietary/`, and then runs `setup-makefiles.sh` to regenerate the vendor-side `Android.bp` and `Android.mk` modules. It requires the standard `tools/extract-utils` repository in the same Android source checkout.

The vendor tree also ships helper scripts to work with the extracted payload:

- `generate_advanced_blobs.py` — regenerates `tb351fu-vendor-blobs.mk` (the `PRODUCT_COPY_FILES` wiring) from whatever is currently inside `proprietary/`
- `purge_missing_blobs.py` — strips entries from `tb351fu-vendor.mk` whose source files no longer exist in `proprietary/`

Proprietary blob redistribution should be handled carefully and with respect to applicable licensing and redistribution limits.

## Current Bring-Up Focus

- stabilizing Android 16/17 device configuration
- matching kernel and vendor expectations
- improving recovery compatibility
- validating partition, AVB, and boot flow behavior
- cleaning up device-specific packaging and feature declarations

## Credits

- Lenovo, for the stock software base and the original device-side platform content this work builds from
- The LineageOS project, for the extract-utils flow and standard device tree structure used here
- Community developers and testers helping with TB351FU bring-up

## Related Repositories

- Kernel tree: <https://github.com/helllopratik/android_kernel_lenovo_tb351fu>
- Vendor tree: <https://github.com/helllopratik/android_vendor_lenovo_tb351fu>
- Recovery tree: <https://github.com/helllopratik/twrp_device_lenovo_TB351FU>
- TB351FU dev page: <https://helllopratik.github.io/tb351fu/>
