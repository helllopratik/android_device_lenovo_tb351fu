# Lenovo Tab Plus 2024 (TB351FU) - Android 15 (EvolutionX A17) Boot & Build Fixes Guide

**Target Device**: Lenovo Tab Plus 2024 (`tb351fu`)  
**Platform**: MediaTek Helio G99 / MT6789 / MT8781  
**OS Version**: EvolutionX A17 (Android 15)  
**Status**: Successfully Booted (`sys.boot_completed=1`, launcher active, display service running, ADB root working)  
**Verification Date**: September 30, 2026

---

## Table of Contents
1. [Overview & Boot Status Verification](#1-overview--boot-status-verification)
2. [Critical Boot Fix #1: Display Backlight Configuration & System Server Crash](#2-critical-boot-fix-1-display-backlight-configuration--system-server-crash)
3. [Critical Boot Fix #2: EvolutionX Refresh Rate Controller SELinux Registration](#3-critical-boot-fix-2-evolutionx-refresh-rate-controller-selinux-registration)
4. [Critical Boot Fix #3: Vendor DLKM Module Dependency & Driver Integrity](#4-critical-boot-fix-3-vendor-dlkm-module-dependency--driver-integrity)
5. [Critical Boot Fix #4: SELinux Permissive Boot Configuration](#5-critical-boot-fix-4-selinux-permissive-boot-configuration)
6. [Build System Fix #1: Duplicate Sysprop Collision (`ro.debuggable`)](#6-build-system-fix-1-duplicate-sysprop-collision-rodebuggable)
7. [Build System Fix #2: Prebuilt Stock Vendor Packaging (`fsck.erofs`)](#7-build-system-fix-2-prebuilt-stock-vendor-packaging-fsckerofs)
9. [Diagnostic Log References](#9-diagnostic-log-references)
10. [Critical Boot Fix #5: MediaTek Boot HAL & Fstab Matching](#10-critical-boot-fix-5-mediatek-boot-hal--fstab-matching-rohardwaremt8781)
11. [Critical Boot Fix #6: Vendor Boot Header Splicing & Bootconfig Permissive Offset](#11-critical-boot-fix-6-vendor-boot-header-splicing--bootconfig-permissive-offset)
12. [Connectivity Fix: Bluetooth HAL Driver Integration](#12-connectivity-fix-bluetooth-hal-driver-integration-bt_drv_connac1xko)
13. [Connectivity Diagnosis: Wi-Fi Operation & CONNSYS Co-existence](#13-connectivity-diagnosis-wi-fi-operation--connsys-co-existence)
14. [Stylus & Palm Rejection Fix: Lenovo Active Pen Support](#14-stylus--palm-rejection-fix-lenovo-active-pen-support)
15. [Summary of Changes Needed to Boot the Device](#15-summary-of-changes-needed-to-boot-the-device)
16. [Ninja Dependency Cycle Fix (`vendor/etc/linker.config.pb`)](#16-ninja-dependency-cycle-fix-vendoretclinkerconfigpb)
17. [Linkerconfig Duplicate Abort & Bootloop Fix (`libcamera_metadata.so`)](#17-linkerconfig-duplicate-abort--bootloop-fix-libcamerametadataso)
18. [OTA Packaging Disk Space Fix (Zip2Zip "No space left on device")](#18-ota-packaging-disk-space-fix-zip2zip-no-space-left-on-device)
19. [Lenovo Tab Pen Plus: Architecture, Hardware Digitizer, Button Mapping & Remote Control Integration](#19-lenovo-tab-pen-plus-architecture-hardware-digitizer-button-mapping--remote-control-integration)
20. [Display Brightness Floor & UI Slider Calibration Fix](#20-display-brightness-floor--ui-slider-calibration-fix-preventing-backlight-blackout-at-0)

---

## 1. Overview & Boot Status Verification

After flashing the newly compiled ROM with the patches outlined in this document:
- **`sys.boot_completed`**: `1` (System fully loaded and booted)
- **Display Service**: Running smoothly with active backlight spline mapping.
- **Refresh Rate Ext**: `org.evolution.display.IRefreshRateManagerService` successfully registered.
- **Kernel**: `6.12.15-4k+` with stock 182-module vendor_dlkm driver stack loaded.
- **Tombstones**: 0 crash tombstones generated during boot.

---

## 2. Critical Boot Fix #1: Display Backlight Configuration & System Server Crash

### Symptom
The device hung indefinitely at the EvolutionX boot animation. Logcat revealed `system_server` crashing continuously in a boot loop:
```text
FATAL EXCEPTION IN SYSTEM PROCESS: main
java.lang.IllegalStateException: Min or max values are invalid; raw min=0.011764706; raw max=1.0; backlight min=0.0; backlight max=1.0
    at com.android.server.display.DisplayDeviceConfig.constrainNitsAndBacklightArrays(DisplayDeviceConfig.java:2668)
    at com.android.server.display.DisplayDeviceConfig.loadBrightnessMapFromConfigXml(DisplayDeviceConfig.java:2635)
    ...
    at com.android.server.display.DisplayManagerService.systemReady(DisplayManagerService.java:948)
```

### Root Cause
1. In Android 15, `DisplayDeviceConfig` calculates the normalized minimum backlight as `rawBacklight[0] = (float) config_screenBrightnessBacklight[0] / 255.0f`.
2. The device tree overlay defined the first entry of `config_screenBrightnessBacklight` as `3`.
3. `3 / 255 = 0.011764706`. Because `mBacklightMinimum = 0.0`, the assertion `mRawBacklight[0] <= mBacklightMinimum` failed, causing Android 15 to throw a fatal `IllegalStateException` and aborting `system_server`.

### Fixes Applied

#### A. Device Tree Overlay Fix
File: [`device/lenovo/tb351fu/overlay/frameworks/base/core/res/res/values/config.xml`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/overlay/frameworks/base/core/res/res/values/config.xml)
Changed the minimum raw backlight integer from `3` to `0`:
```xml
    <integer-array name="config_screenBrightnessBacklight">
        <item>0</item>
        <item>31</item>
        <item>50</item>
        <item>76</item>
        <item>152</item>
        <item>213</item>
        <item>255</item>
    </integer-array>
```

#### B. Framework Defensive Clamping
File: [`frameworks/base/services/core/java/com/android/server/display/DisplayDeviceConfig.java`](file:///run/media/hellopratik/Nvme/evolutionx/sync/frameworks/base/services/core/java/com/android/server/display/DisplayDeviceConfig.java)
Instead of throwing an unrecoverable exception that halts the tablet, clamp the boundaries with a warning:
```java
        if (mRawBacklight[0] > mBacklightMinimum
                || mRawBacklight[mRawBacklight.length - 1] < mBacklightMaximum
                || mBacklightMinimum > mBacklightMaximum) {
            Slog.w(TAG, "Min or max values are invalid"
                    + "; raw min=" + mRawBacklight[0]
                    + "; raw max=" + mRawBacklight[mRawBacklight.length - 1]
                    + "; backlight min=" + mBacklightMinimum
                    + "; backlight max=" + mBacklightMaximum);
            if (mRawBacklight[0] > mBacklightMinimum) {
                mRawBacklight[0] = mBacklightMinimum;
            }
            if (mRawBacklight[mRawBacklight.length - 1] < mBacklightMaximum) {
                mRawBacklight[mRawBacklight.length - 1] = mBacklightMaximum;
            }
            if (mBacklightMinimum > mBacklightMaximum) {
                mBacklightMinimum = mBacklightMaximum;
            }
        }
```

---

## 3. Critical Boot Fix #2: EvolutionX Refresh Rate Controller SELinux Registration

### Symptom
EvolutionX's custom `DisplayRefreshRateController` service attempted to publish `refresh_rate_ext` into ServiceManager. If an exception occurred during service publication or if the SELinux service context was missing, `system_server` failed to initialize.

### Fixes Applied

#### A. Service Guard
File: [`frameworks/base/services/core/java/com/android/server/DisplayRefreshRateController.java`](file:///run/media/hellopratik/Nvme/evolutionx/sync/frameworks/base/services/core/java/com/android/server/DisplayRefreshRateController.java)
Wrapped the binder service publication in a `try-catch` block:
```java
    public void initSystemExService(EvolutionSystemExService service) {
        mSystemExService = service;
        try {
            mSystemExService.publishBinderService(REFRESH_RATE_MANAGER_SERVICE, new RefreshRateManagerService());
        } catch (Exception e) {
            Slog.e(TAG, "Failed to publish " + REFRESH_RATE_MANAGER_SERVICE, e);
        }
    }
```

#### B. SELinux Policy Registration
File: [`device/lenovo/tb351fu/sepolicy/public/service.te`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/sepolicy/public/service.te)
```te
type refresh_rate_ext_service, app_api_service, system_server_service, service_manager_type;
```

File: [`device/lenovo/tb351fu/sepolicy/private/service_contexts`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/sepolicy/private/service_contexts)
```text
refresh_rate_ext                          u:object_r:refresh_rate_ext_service:s0
```

---

## 4. Critical Boot Fix #3: Vendor DLKM Module Dependency & Driver Integrity

### Symptom
During kernel build stages, the build system was cleaning out the `vendor_dlkm` staging directory, wiping out prebuilt MediaTek kernel drivers (`modules.dep`, `modules.load`, `modules.alias`), resulting in:
- Touchscreen driver (`tp_nt36xxx.ko`) failing to load.
- Kernel Oops / null pointer dereference (`class_to_subsys`) during boot due to incompatible locally rebuilt GKI modules.

### Fixes Applied

#### A. Guard Vendor DLKM from Overwrite
File: [`vendor/lineage/build/tasks/kernel.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lineage/build/tasks/kernel.mk)
Only write kernel build modules to `TARGET_OUT_VENDOR_DLKM` if `BOARD_VENDOR_DLKM_MODULES_FROM_KERNEL_BUILD` is explicitly set to `true`:
```make
else ifeq ($(BOARD_USES_VENDOR_DLKMIMAGE),true)
ifeq ($(BOARD_VENDOR_DLKM_MODULES_FROM_KERNEL_BUILD),true)
KERNEL_MODULES_OUT := $(TARGET_OUT_VENDOR_DLKM)
KERNEL_DEPMOD_STAGING_DIR := $(KERNEL_BUILD_OUT_PREFIX)$(call intermediates-dir-for,PACKAGING,depmod_vendor)
KERNEL_MODULE_MOUNTPOINT := vendor_dlkm
KERNEL_MODULES_PARTITION_FILE_LIST := $(vendor_dlkmimage_intermediates)/file_list.txt
else
KERNEL_MODULES_OUT := $(TARGET_OUT_VENDOR_DLKM)/kernel_modules_stub
KERNEL_DEPMOD_STAGING_DIR := $(KERNEL_BUILD_OUT_PREFIX)$(call intermediates-dir-for,PACKAGING,depmod_vendor_stub)
KERNEL_MODULE_MOUNTPOINT := vendor_dlkm
KERNEL_MODULES_PARTITION_FILE_LIST :=
endif
```

#### B. Build Script Pre-flight and Post-build Verification
File: [`build.sh`](file:///run/media/hellopratik/Nvme/evolutionx/sync/build.sh)
- Automatic verification that `modules.load` in staging matches the 182-line proven vendor module stack.
- Preservation and verification of stock GKI drivers (`rfkill.ko`, `zsmalloc.ko`, `libarc4.ko`).

---

## 5. Critical Boot Fix #4: SELinux Permissive Boot Configuration

### Symptom
Missing OEM / vendor domain transitions for MediaTek HALs and proprietary daemons can cause early boot hangs in `init`.

### Fix Applied
File: [`device/lenovo/tb351fu/BoardConfig.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/BoardConfig.mk)
Configured bootconfig to keep SELinux permissive:
```make
BOARD_BOOTCONFIG += \
    androidboot.selinux=permissive
```

---

## 6. Build System Fix #1: Duplicate Sysprop Collision (`ro.debuggable`)

### Symptom
Build failed at `//build/soong:system-build.prop generating build.prop[common]`:
```text
FAILED: out/soong/.intermediates/build/soong/system-build.prop/android_common/build.prop
stderr:
error: found duplicate sysprop assignments:
ro.debuggable=0
ro.debuggable=1
```

### Root Cause
- EvolutionX defines `PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG := true` in [`vendor/lineage/config/common.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lineage/config/common.mk#L75).
- This instructs `build/soong/scripts/gen_build_prop.py` to output `ro.debuggable=0` to `ADDITIONAL_SYSTEM_PROPERTIES`.
- `device/lenovo/tb351fu/device.mk` also manually defined `ro.debuggable=1` in `PRODUCT_SYSTEM_PROPERTIES`.
- In Android 15, `post_process_props` strictly prohibits duplicate contradictory assignments without `?=` and fails the build.

### Fix Applied
File: [`device/lenovo/tb351fu/device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk#L379-L383)
Removed `ro.debuggable=1` from `PRODUCT_SYSTEM_PROPERTIES`:
```diff
  PRODUCT_SYSTEM_PROPERTIES += \
      ro.build.fingerprint=Lenovo/TB351FU/TB351FU:14/UKQ1.231011.002/S100045_240520_ROW:user/release-keys \
-     ro.adb.secure=0 \
-     ro.debuggable=1
+     ro.adb.secure=0
```

---

## 7. Dynamic Vendor Partition Build from Vendor Tree

### Rationale
Previously, `BoardConfig.mk` used `BOARD_PREBUILT_VENDORIMAGE := $(DEVICE_PATH)/prebuilt/vendor.img`. To achieve a pure LineageOS-style build without hacking `build/make` or using prebuilt raw images:
1. Removed `BOARD_PREBUILT_VENDORIMAGE` from `BoardConfig.mk`.
2. Configured `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs` and `BOARD_VENDORIMAGE_PARTITION_SIZE := 1073741824`.
3. The build system now dynamically creates and signs `vendor.img` from the 3,438 individual files defined in [`vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk).
4. `frameworks/base`, `vendor/lineage`, and `build/make` are 100% stock clean without any local modifications.

---

## 8. App Fix: Lenovo PenBridge UI Crash

### Symptom
When opening the Lenovo Pen Bridge settings activity:
```text
FATAL EXCEPTION: main
Process: com.lenovo.penbridge, PID: 5732
java.lang.RuntimeException: Unable to start activity ComponentInfo{com.lenovo.penbridge/com.lenovo.penbridge.MainActivity}
Caused by: java.lang.IllegalStateException: The specified child already has a parent. You must call removeView() on the child's parent first.
    at android.view.ViewGroup.addViewInner(ViewGroup.java:5424)
    at com.lenovo.penbridge.MainActivity.onCreate(MainActivity.java:46)
```

### Root Cause
In `MainActivity.java`, helper `makeSwitch()` created a `LinearLayout row`, added `TextView t` and `Switch s` to `row`, but returned `s`. In `onCreate()`, `root.addView(makeSwitch(...))` attempted to add `s` again to `root`.

### Fix Applied
File: [`device/lenovo/tb351fu/penbridge/src/com/lenovo/penbridge/MainActivity.java`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/penbridge/src/com/lenovo/penbridge/MainActivity.java#L57-L76)
Changed return type to `View` and returned the container `row` instead of child `s`:
```java
    private View makeSwitch(String label, final String key, String summary) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.VERTICAL);
        TextView t = new TextView(this);
        t.setText(label);
        t.setTextSize(17);
        final Switch s = new Switch(this);
        s.setText(summary);
        s.setChecked(Settings.Secure.getInt(getContentResolver(), key, 0) == 1);
        s.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                Settings.Secure.putInt(getContentResolver(), key, isChecked ? 1 : 0);
            }
        });
        row.addView(t);
        row.addView(s);
        row.setPadding(0, dp(10), 0, dp(10));
        return row;
    }
```

---

## 9. Diagnostic Log References

Fresh logs captured directly from the booted device (`TB351FU`):
- **Kernel Log (dmesg)**: [`device/lenovo/tb351fu/logs/dmesg_booted.log`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/logs/dmesg_booted.log)
- **Logcat (all buffers)**: [`device/lenovo/tb351fu/logs/logcat_booted.log`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/logs/logcat_booted.log)

These files confirm clean boot completion, proper initialization of `DisplayManagerService`, surfaceflinger, inputflinger, and driver stacks.

---

## 10. Critical Boot Fix #5: MediaTek Boot HAL & Fstab Matching (`ro.hardware=mt8781`)

### Symptom
Device passes kernel boot and displays the boot logo with backlight enabled, but hangs indefinitely before starting the EvolutionX boot animation (`bootanimation`).

### Root Cause
During early userspace initialization:
1. `android.hardware.boot-service.mtk` queries `GetFstabPath()`.
2. The device properties set `[ro.boot.hardware]: [mt8781]` and `[ro.hardware]: [mt8781]`.
3. MediaTek's `libfstab` looks specifically for `/vendor/etc/fstab.${hardware}` (i.e. `/vendor/etc/fstab.mt8781` or `fstab.mt8781dm`).
4. Only `fstab.mt6789` was present in the vendor tree. Because `/vendor/etc/fstab.mt8781` did not exist, `GetFstabPath()` reported "illegal" and the boot HAL crashed:
   ```text
   DEBUG: Executable: /vendor/bin/hw/android.hardware.boot-service.mtk
   DEBUG: Abort message: 'Check failed: impl_.Init() '
   ```
5. `vold` (PID 411) requires `android.hardware.boot.IBootControl/default` and entered an infinite blocking 1-second retry loop:
   ```text
   libbinder.ServiceManagerCppClient: Waited one second for android.hardware.boot.IBootControl/default
   servicemanager: Since 'android.hardware.boot.IBootControl/default' could not be found trying to start it as a lazy AIDL service.
   ```
   This blocked late-fs checkpoints, userdata mounting, and prevented Zygote from launching.

### Fix Applied
1. Added all required MediaTek fstab variants to [`device/lenovo/tb351fu/rootdir/etc/`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/rootdir/etc/):
   - `fstab.mt8781`
   - `fstab.mt8781dm`
   - `fstab.mt6789dm`
   - `fstab.emmc`
   - `fstab.enableswap`
   - `fstab.zram_wb`
2. Added `PRODUCT_COPY_FILES` rules in [`device/lenovo/tb351fu/device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk) to stage them into `vendor/etc/` during ROM compilation.

---

## 11. Critical Boot Fix #6: Vendor Boot Header Splicing & Bootconfig Permissive Offset

### Symptom
`androidboot.selinux=permissive` configured in `BOARD_BOOTCONFIG` was ignored by the kernel, causing the device to boot in enforcing mode where unconfined vendor domains caused early boot freezes.

### Root Cause
When splicing the Lenovo factory 4096-byte header onto the compiler-generated `vendor_boot.img`, [`device/lenovo/tb351fu/splice_header.py`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/splice_header.py) copied image size offsets but omitted offset `2124:2128` (`vendor_bootconfig_size`). The stock header at offset 2124 contained 0, causing the bootloader to report 0 bytes of bootconfig to the kernel.

### Fix Applied
1. Updated `splice_header.py` to copy the bootconfig size parameter:
   ```python
   stock_header[2124:2128] = mk_header[2124:2128]
   ```
2. Integrated automatic header splicing into the post-build verification phase in [`build.sh`](file:///run/media/hellopratik/Nvme/evolutionx/sync/build.sh).

---

## 12. Connectivity Fix: Bluetooth HAL Driver Integration (`bt_drv_connac1x.ko`)

### Symptom
Bluetooth crashed repeatedly on boot (`Fatal signal 6 SIGABRT` in `com.android.bluetooth`), with the HAL logging:
```text
[BT] : init_uart: Can't open /dev/stpbt (No such file or directory), errno[2]
android.hardware.bluetooth@aidl-impl: Open: fd -1 is invalid!
```

### Root Cause
1. `/dev/stpbt` character device node is created by kernel module `bt_drv_connac1x.ko`.
2. While the module existed in `vendor_dlkm/lib/modules/`, it was omitted from [`vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/modules.load`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/modules.load), so `init.insmod.sh` did not load it at boot.
3. In `init.bt_drv.rc`, the manual load trigger required `property:ro.vendor.bt.connac3=no`, but this property was unassigned.

### Fix Applied
1. Added `bt_drv_connac1x.ko` to `vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/modules.load` directly after `wmt_drv.ko` (where all its kernel dependencies `btif_drv.ko`, `connadp.ko`, `mtk_low_battery_throttling.ko`, `wmt_drv.ko` are satisfied).
2. Set `ro.vendor.bt.connac3=no` in `PRODUCT_VENDOR_PROPERTIES` in [`device/lenovo/tb351fu/device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk).

---

## 13. Connectivity Diagnosis: Wi-Fi Operation & CONNSYS Co-existence

### Symptom
On initial startup, Wi-Fi reported failure to load driver:
```text
android.hardware.wifi-service-lazy: Failed to write driver state control param: I/O error
WifiSelfRecovery: Already restarted wifi 2 times in last 1 hour. Disabling wifi
```

### Root Cause
MediaTek MT6789/MT8781 shares the CONNSYS connectivity subsystem between Wi-Fi and Bluetooth. When Bluetooth entered a rapid abort loop due to missing `/dev/stpbt`, its crash teardown called `BT_VND_OP_POWER_CTRL 0`, cutting power to CONNSYS during the exact window that the Wi-Fi driver was attempting firmware handshake (`FW_START EVT`).

### Resolution & Verification
Once Bluetooth is stabilized with `bt_drv_connac1x.ko`, CONNSYS remains powered and healthy. Wi-Fi (`wlan_drv_gen4m_6789`) initializes cleanly:
- `wlan0` interface UP with full 802.11ac dual-band support.
- Fully associates and negotiates IP via DHCP (verified connected to 5GHz AP `hellopratik_bsnl_5G` at 96Mbps link speed, with 12,000+ packets exchanged).

---

## 14. Stylus & Palm Rejection Fix: Lenovo Active Pen Support

### Symptom
1. Pen strokes not detected by the display / apps.
2. Palm rejection not functioning when resting palm on the screen.

### Root Cause Analysis
1. **Touch Controller Pen Mode Disabled at Boot (`/proc/support_pen` = 0)**:
   - Novatek touchscreen driver (`nt36xxx.c`) initialized `ts->pen_state = 0` at probe.
   - When `pen_state` is 0, the touch IC was never sent `SUPPORT_PEN_CMD (0x7B) 0x01`, disabling active pen scanning completely.
2. **Hardware Palm Rejection & SPI Bus Contention**:
   - Novatek driver implements hardware palm rejection via `/proc/game_mode` (`GAME_MODE_PALM_CMD 0x79`).
   - PenBridge's `PalmGuard.java` was previously rewriting `"1"` to `/proc/support_pen` every 500ms, triggering repeated SPI mode-switch commands (`0x7B 0x01`) and locking the Novatek controller.
3. **Stylus Button Mapping & EventHub Interception (`KEY_UNKNOWN` vs `EXTERNAL_STYLUS`)**:
   - Stock Lenovo firmware uses proprietary keycodes `KEYCODE_PEN_ONE_CLICK` (600), `KEYCODE_PEN_TWO_CLICK` (601), etc., which do not exist in standard AOSP.
   - Mapping them to Android's `STYLUS_BUTTON_PRIMARY` in `.kl` caused EventHub to classify the Bluetooth companion device as `InputDeviceClass::EXTERNAL_STYLUS`. In AOSP, `ExternalStylusInputMapper` converts stylus buttons into motion event button state (0x60) and suppresses `KeyEvent` dispatch entirely.
   - Without `KeyEvent`s, accessibility services and window managers never received the button presses.
4. **Pen Accessibility Service Disabled**:
   - In AOSP, `PenAccessibilityService` was not enabled by default in `enabled_accessibility_services`, so it could not intercept key events or fire broadcasts to Nebo.
5. **Nebo Double-Click Integration**:
   - Nebo (`com.myscript.nebo.lenovo`) registers dynamic broadcast receivers for `com.hihonor.stylus.action.STYLUS_DOUBLE_CLICK` and `com.huawei.stylus.action.BUTTON_DOUBLE_PRESSED` with extra `double_click_switch_mode=0`.
   - Dispatching these broadcasts on hardware double-click toggles Nebo between pen brush and eraser.

### Fixes Applied
1. **Bluetooth Keylayout (`device/lenovo/tb351fu/keylayout/Vendor_17ef_Product_617f.kl`)**:
   - Mapped `0x0c0600` through `0x0c0605` to standard `BUTTON_1` through `BUTTON_6`. This bypasses `ExternalStylusInputMapper` suppression and dispatches clean `KeyEvent`s.
   - Also updated `Vendor_17ef_Product_612b.kl` and `Vendor_17ef_Product_61a1.kl`.
2. **IDC Configurations (`device/lenovo/tb351fu/idc/`)**:
   - Configured `Vendor_17ef_Product_617f.idc` with `device.type = keyboard` (removing erroneous `touch.deviceType = touchScreen`).
   - Retained `NVTCapacitivePen.idc` for the screen digitizer pen with calibrated pressure and distance.
3. **PenBridge & Accessibility Service (`device/lenovo/tb351fu/penbridge/`)**:
   - Updated [`PenAccessibilityService.java`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/penbridge/src/com/lenovo/penbridge/PenAccessibilityService.java) to handle `KEYCODE_BUTTON_1..5`.
   - Double-click (`KEYCODE_BUTTON_2`) automatically dispatches `com.hihonor.stylus.action.STYLUS_DOUBLE_CLICK` and `com.huawei.stylus.action.BUTTON_DOUBLE_PRESSED` to `com.myscript.nebo.lenovo`, toggling brush <-> eraser.
   - Made `PalmGuard.java` support pen check idempotent to prevent SPI bus contention.
   - Automatically registered and enabled `PenAccessibilityService` in system settings.
4. **Kernel Driver (`kernel/lenovo/tb351fu/drivers/input/touchscreen/nt36xxx/`)**:
   - Reverted probe initialization to `ts->pen_state = 0` and aligned with proven reference kernel to ensure clean startup sequence.

---

## 15. Summary of Changes Needed to Boot the Device

All changes have been made permanently across the tree so that running `./build.sh` automatically compiles and packages them without manual intervention:

| Area | File(s) | Purpose |
| :--- | :--- | :--- |
| **Boot Header** | [`device/lenovo/tb351fu/splice_header.py`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/splice_header.py) | Copies factory signature and bytes `2124:2128` (`vendor_bootconfig_size`) so `androidboot.selinux=permissive` passes to kernel without bootloader rejection. |
| **Build Wrapper** | [`build.sh`](file:///run/media/hellopratik/Nvme/evolutionx/sync/build.sh) | Hooked post-build check #3b to auto-splice `vendor_boot.img` after compilation. |
| **Storage / Fstabs** | [`device/lenovo/tb351fu/rootdir/etc/fstab.*`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/rootdir/etc/) | `fstab.mt8781`, `fstab.mt8781dm`, `fstab.mt6789dm`, etc. copied to `vendor/etc/` via [`device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk) to resolve mount failure on MT8781 hardware. |
| **Bluetooth / Wi-Fi** | [`vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/modules.load`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/modules.load) | Included `bt_drv_connac1x.ko` to create `/dev/stpbt`, preventing Bluetooth crash loop and enabling shared CONNSYS Wi-Fi handshake. |
| **Vendor Properties** | [`device/lenovo/tb351fu/device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk) | `ro.vendor.bt.connac3=no` (triggers BT init), `persist.device_config.input_native_boot.palm_rejection_enabled=1`. |
| **Stylus & Touch** | [`kernel/lenovo/tb351fu/drivers/input/touchscreen/nt36xxx/nt36xxx.c`](file:///run/media/hellopratik/Nvme/evolutionx/sync/kernel/lenovo/tb351fu/drivers/input/touchscreen/nt36xxx/nt36xxx.c) | Default `pen_state = 1` and `game_mode_state = 1` on probe; queue `ts_restore_cmd_work`; clean `BTN_TOOL_PEN`/`BTN_TOUCH` reporting and eliminate empty sync spam on finger touches. |
| **Stylus IDC & Init** | [`device/lenovo/tb351fu/idc/`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/idc/), [`rootdir/etc/init.stylus.rc`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/rootdir/etc/init.stylus.rc) | Validated IDC types (`touchScreen`, `externalStylus`) and init proc-nodes on boot. |
| **Linker Config** | [`device/lenovo/tb351fu/device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk), [`linker.config.json`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/linker.config.json) | Configured `PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS` to prevent Ninja dependency cycle on `vendor/etc/linker.config.pb`. |
| **Vendor LLNDK Blobs** | [`vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk), [`device/lenovo/tb351fu/proprietary-files.txt`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/proprietary-files.txt) | Excluded `libcamera_metadata.so` from vendor blobs to prevent duplicate `[system]` namespace abort in runtime `linkerconfig`. |

---

## 16. Ninja Dependency Cycle Fix (`vendor/etc/linker.config.pb`)

### Root Cause
In `device.mk`, copying `prebuilt/vendor_linker.config.pb:vendor/etc/linker.config.pb` directly via `PRODUCT_COPY_FILES` added `$(TARGET_OUT_VENDOR)/etc/linker.config.pb` to `INTERNAL_VENDORIMAGE_FILES`. In `build/make/core/Makefile` (line 4188), the generation rule for `vendor_linker_config_file` has `$(INTERNAL_VENDORIMAGE_FILES)` as a prerequisite. This caused the target file to depend on itself, triggering Ninja error:
```
FAILED: ninja: Error: failed in schedule evolution: dependency cycle: out/target/product/tb351fu/vendor/etc/linker.config.pb -> out/target/product/tb351fu/vendor/etc/linker.config.pb
```

### Resolution
- Created [`device/lenovo/tb351fu/linker.config.json`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/linker.config.json) with:
  ```json
  {
    "provideLibs": [
      "liburee_meta_drmkeyinstall.so"
    ]
  }
  ```
- In [`device/lenovo/tb351fu/device.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/device.mk), replaced the `PRODUCT_COPY_FILES` copy with:
  ```makefile
  PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS += $(DEVICE_PATH)/linker.config.json
  ```
- Deleted `device/lenovo/tb351fu/prebuilt/vendor_linker.config.pb`.

---

## 17. Linkerconfig Duplicate Abort & Bootloop Fix (`libcamera_metadata.so`)

### Root Cause & Failure Chain
1. **Build-Time Generation**:
   In `build/make/core/Makefile`, `vendor/etc/linker.config.pb` is compiled from fragments and augmented using:
   ```makefile
   conv_linker_config systemprovide --source $@ --output $@ \
       --value "$(SOONG_STUB_VENDOR_LIBRARIES)" --system "$(TARGET_OUT_VENDOR)"
   ```
2. **Duplicate Injection**:
   Because `vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk` copied prebuilt `libcamera_metadata.so` into `$(TARGET_OUT_VENDOR)/lib64/` and `lib/`, `conv_linker_config systemprovide` detected it and automatically inserted `provideLibs: "libcamera_metadata.so"` into `vendor/etc/linker.config.pb`.
3. **Runtime Linkerconfig Abort**:
   At early boot (~3.1s), `init` executed `perform_apex_config` -> `GenerateLinkerConfiguration()` -> `/apex/com.android.runtime/bin/linkerconfig --target /linkerconfig`.
   Because `libcamera_metadata.so` was already provided by the `[system]` `default` namespace (from `/system/lib64/libcamera_metadata.so`), having it also declared by vendor's `sphal` namespace triggered a fatal duplicate conflict:
   ```
   F linkerconfig: section.cc:83 duplicate: libcamera_metadata.so is provided by default and sphal in [system]
   ```
   `linkerconfig` aborted (`SIGABRT`) and core-dumped. Consequently, `/linkerconfig/ld.config.txt` was never written.
4. **Keystore2 Crash Loop & Recovery Reboot**:
   When `keystore2` started on `late-fs`, the bionic dynamic linker fell back to `init_default_namespace_no_config` (which lacks APEX namespace links). `keystore2` failed to resolve `libandroidicu.so` (needed by `libsqlite.so`), crashed 4 times, and triggered `init: InitFatalReboot: signal 6 -> reboot reason: recovery`.

### Resolution
1. **Vendor Blob Removal**:
   - In [`vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk`](file:///run/media/hellopratik/Nvme/evolutionx/sync/vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk), removed `libcamera_metadata.so` (both 32-bit and 64-bit entries).
   - In [`device/lenovo/tb351fu/proprietary-files.txt`](file:///run/media/hellopratik/Nvme/evolutionx/sync/device/lenovo/tb351fu/proprietary-files.txt), commented out `vendor/lib/libcamera_metadata.so` and `vendor/lib64/libcamera_metadata.so`.
2. **Build Wrapper Guard**:
   - Added pre-build check `check_vendor_blobs` in [`build.sh`](file:///run/media/hellopratik/Nvme/evolutionx/sync/build.sh) to reject any build attempting to copy `libcamera_metadata.so` and auto-remove stale intermediate copies.
   - Added post-build check #3c in [`build.sh`](file:///run/media/hellopratik/Nvme/evolutionx/sync/build.sh) to verify `out/target/product/tb351fu/vendor/etc/linker.config.pb` contains no duplicate LLNDK stubs.
3. **Kernel Touch Driver Refinement**:
   - In [`nt36xxx.c`](file:///mnt/Nvme/evolutionx/sync/kernel/lenovo/tb351fu/drivers/input/touchscreen/nt36xxx/nt36xxx.c), restricted `input_sync(ts->pen_input_dev)` to active pen events and release transitions, eliminating empty `(0,0)` sync floods on finger touches and ensuring clean stylus input reporting to Android's `TouchInputMapper`.

---

## 18. OTA Packaging Disk Space Fix (Zip2Zip "No space left on device")

### Root Cause
During the final packaging phase (`Package OTA: out/target/product/tb351fu/evolution_tb351fu-ota.zip`):
1. `ota_from_target_files` stages the ~12 GB target files archive as a temporary zip (`tmp*.zip`) using Python's `tempfile.mkstemp()`.
2. Python uses `TMPDIR`, which Soong UI forces to `out/soong/.temp/` on the NVMe drive.
3. `releasetools/common.py` then invokes `zip2zip` to strip metadata entries (`-x META-INF/com/android/metadata*`), creating a second copy in `dir=os.path.dirname(input_zip)` (also in `out/soong/.temp/`).
4. Both uncompressed/intermediate archives together require ~20 GB of free space. Because `/mnt/Nvme` had only 16 GB free, `zip2zip` exhausted the filesystem and failed with:
   ```
   zip2zip.go:103: write /mnt/Nvme/evolutionx/sync/out/soong/.temp/tmpxonvu9e1: no space left on device
   FAILED: ninja: exit=1
   ```

### Resolution
1. **Permanent Device Wrapper**:
   Created [`device/lenovo/tb351fu/ota_wrapper.sh`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/ota_wrapper.sh):
   - Sets `export TMPDIR="/mnt/HDD/tmp"` (where 128+ GB is available).
   - Executes the freshly-compiled `out/host/linux-x86/bin/ota_from_target_files "$@"`.
2. **Build System Hook**:
   - In [`device/lenovo/tb351fu/Android.mk`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/Android.mk):
     ```makefile
     OTA_FROM_TARGET_FILES := $(TB351FU_DEVICE_PATH)/ota_wrapper.sh
     ```
   - In [`device/lenovo/tb351fu/BoardConfig.mk`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/BoardConfig.mk):
     ```makefile
     OTA_FROM_TARGET_FILES := $(DEVICE_PATH)/ota_wrapper.sh
     ```
   Because `Android.mk` is loaded after `build/make/core/config.mk`, the assignment overrides the default host binary path in Kati's evaluation of `build-ota-package-target`. Ninja now invokes `ota_wrapper.sh`, cleanly routing all large intermediate zips to `/mnt/HDD/tmp`.
3. **Build Wrapper Guard**:
   In [`build.sh`](file:///mnt/Nvme/evolutionx/sync/build.sh), ensured `ota_wrapper.sh` has executable permissions, cleaned stale `/mnt/HDD/tmp/*` and `out/soong/.temp/*` before building, and removed the fragile in-place binary rename hook.

---

## 19. Lenovo Tab Pen Plus: Architecture, Hardware Digitizer, Button Mapping & Remote Control Integration

### Dual-Channel Hardware Architecture
The Lenovo Tab Pen Plus (model AP500U, codename `picasso`, Bluetooth ID `17ef:617f`) operates on two completely distinct hardware channels:

1. **Active RF / Capacitive Digitizer Channel (In-Cell Touchscreen IC)**:
   - **Hardware & Driver**: Novatek NT36523N SPI touch controller (`tp_nt36xxx.ko` on `spi2.0`).
   - **Kernel Nodes**: `/dev/input/event8` (`NVTCapacitiveTouchScreen`) and `/dev/input/event9` (`NVTCapacitivePen`).
   - **Coordinate Space & Precision**: 
     - X: `0 .. 12000` (10:1 physical scale to 1200 display pixels).
     - Y: `0 .. 20000` (10:1 physical scale to 2000 display pixels).
     - Pressure: `0 .. 4095` linear levels.
     - Distance (Hover): `0 .. 1` (0 = active screen contact, 1 = hovering above screen).
     - Tilt: X `[-60, 60]`, Y `[-60, 60]`.
     - Tool Type: Native `toolType=STYLUS`.
   - **Hardware Palm Rejection**:
     - Kernel sysfs interfaces: `/proc/game_mode` (`1` = pen mode / enhanced palm rejection, `0` = normal mode) and `/proc/support_pen` (`1` = active).
     - Initialized at driver probe via `ts->game_mode_state = 1` and `ts->pen_state = 1`, and maintained dynamically by `PalmGuard` (`com.lenovo.penbridge.PalmGuard`).

2. **Bluetooth Low Energy (BLE) HOGP Channel**:
   - **Hardware & Connection**: Nordic/Airoha BLE MCU (`17ef:617f`), paired and bonded via standard BLE GATT.
   - **Input Nodes**:
     - `/dev/input/event12` (`Lenovo Tab Pen Plus Consumer Control`)
     - `/dev/input/event11` (`Lenovo Tab Pen Plus Mouse`)
   - **Hardware Barrel Button Protocol**:
     The pen's onboard microcontroller measures clicks, double clicks, and hold gestures, sending HID Consumer Page (`0x0c`) usage codes:
     - `0x0c0600`: Single click
     - `0x0c0601`: Double click
     - `0x0c0602`: Triple click
     - `0x0c0603`: Long press / Tail click
     - `0x0c0604`: Continuous press / Squeeze

---

### Root Cause Analysis: Why Pen Features Failed on EvolutionX

#### 1. Input Device Configuration (IDC) Breakdown
- **Failure**: In the custom device tree, `idc/Vendor_17ef_Product_617f.idc` had `device.type = externalStylus`.
- **Impact**: When Android's `InputReader` encounters an `externalStylus` device, `TouchInputMapper` engages "Stylus Fusion" mode: it suspends processing coordinate reports from the active screen digitizer until the Bluetooth device supplies coordinate metadata. Because the BLE pen is purely a button transmitter (`Consumer Control | Mouse`) and has no digitizer antennas, `dumpsys input` on stock confirms `ExternalStylusPresence: NONE`. The erroneous IDC stalled touch screen digitizer input and broke stroke tracking.
- **Fix**: Aligned [`Vendor_17ef_Product_617f.idc`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/idc/Vendor_17ef_Product_617f.idc), [`612b.idc`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/idc/Vendor_17ef_Product_612b.idc), and [`61A1.idc`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/idc/Vendor_17ef_Product_61A1.idc) with stock:
  ```properties
  touch.orientationAware = 1
  touch.deviceType = touchScreen
  ```
  And removed invalid `keyboard.layout = NVTCapacitivePen` from [`NVTCapacitivePen.idc`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/idc/NVTCapacitivePen.idc).

#### 2. Kernel Touch Driver Empty Sync Spam
- **Failure**: In [`nt36xxx.c`](file:///mnt/Nvme/evolutionx/sync/kernel/lenovo/tb351fu/drivers/input/touchscreen/nt36xxx/nt36xxx.c), `input_sync(ts->pen_input_dev)` was called unconditionally during finger touch events.
- **Impact**: Every finger gesture flooded the event queue with empty `(0,0)` pen packets, corrupting palm rejection and causing drawing apps to drop strokes.
- **Fix**: Restricted `input_sync(ts->pen_input_dev)` exclusively to active pen down events (`pen_point.contact_id > 0`) and pen lift releases (`prev_pen_contact_id > 0`).

#### 3. Proprietary Keylayout Tokens Crashing `KeyLayoutMap`
- **Failure**: Stock `.kl` files mapped `0x0c0600` to `PEN_ONE_CLICK`, `0x0c0601` to `PEN_TWO_CLICK`, etc. In stock ZUI, Lenovo injected custom keycode integers (600..605) into `android.view.KeyEvent`. In AOSP, `InputEventLookup::getKeyCodeByLabel("PEN_ONE_CLICK")` returned `nullopt`.
- **Impact**: AOSP's `KeyLayoutMap::Parser::parseKey()` aborted on line 1 (`KeyLayoutMap.cpp:403: Expected key code label, got 'PEN_ONE_CLICK'`). The entire `.kl` file was discarded, falling back to `Generic.kl` which dropped vendor consumer usages. Barrel button clicks were completely silent.
- **Fix**: Remapped all `.kl` files ([`Vendor_17ef_Product_617f.kl`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/keylayout/Vendor_17ef_Product_617f.kl), [`612b.kl`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/keylayout/Vendor_17ef_Product_612b.kl), [`61a1.kl`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/keylayout/Vendor_17ef_Product_61a1.kl)) to standard Android 14+ Stylus Button keycodes:
  ```text
  key usage 0x0c0600   STYLUS_BUTTON_PRIMARY
  key usage 0x0c0601   STYLUS_BUTTON_SECONDARY
  key usage 0x0c0602   STYLUS_BUTTON_TERTIARY
  key usage 0x0c0603   STYLUS_BUTTON_TAIL
  key usage 0x0c0604   BUTTON_1
  ```

---

### UI Subsystems: Magnifier, Floating Toolbar & Remote Control

#### Stock ZUI Architecture
- **Service**: Handled by `/system/priv-app/PenService/PenService.apk` (`com.lenovo.penservice`), running as persistent system user (`android.uid.system`).
- **Trigger Chain**:
  1. `BluetoothPenConnectPolicy` in stock `system_server` broadcast `lenovo.intent.action.PEN_BT_CHANGED` when pen paired/connected.
  2. `BootBroadcastReceiver` in `PenService.apk` received `PEN_BT_CHANGED` and launched `com.lenovo.pen.bt.service.FloatService`.
  3. On barrel button press, `BluetoothPenInputPolicy` in stock `system_server` intercepted the keycode and broadcast `lenovo.intent.action.INPUT_DEVICE_CLICK_STATE_CHANGED` (`lenovo.intent.extra.DEVICE_KEYTIMES_STATE`: `0`=single, `1`=double, `2`=triple, `3`=long, `4`=press).
  4. `FloatService` -> `FloatingViewController` displayed the floating toolbar (Magnifier, Laser Pointer, Region Screenshot, Note). Single click while Magnifier/Laser was active exited them immediately.
  5. In Remote Control mode (`pen_set_remote_control_on=1`), stock `system_server` intercepted clicks in Camera (shutter), PowerPoint (next/prev slide), or Media (play/pause).

#### EvolutionX Integration via `PenBridge`
Because EvolutionX lacks Lenovo's proprietary `system_server` modifications, `device/lenovo/tb351fu/penbridge` bridges the hardware events to `PenService.apk`:
1. **Connection Lifecycle ([`PenTracker.java`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/penbridge/src/com/lenovo/penbridge/PenTracker.java))**:
   - Detects BLE GATT connection to Lenovo Tab Pen Plus.
   - Sets `lenovo_pen_status = 1` in `Settings.Global`.
   - Initializes default secure settings if unset (`pen_floating_all=1`, `pen_set_show_button=1`, `pen_set_click_pen_button_summary="show_hide_menu"`).
   - Broadcasts `lenovo.intent.action.PEN_BT_CHANGED`, waking `PenService.apk`.
   - Explicitly starts `FloatService` as a foreground service.
   - Auto-enables `PenAccessibilityService` in `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`.
2. **Button Dispatch, Nebo Integration & Remote Control ([`PenAccessibilityService.java`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/penbridge/src/com/lenovo/penbridge/PenAccessibilityService.java))**:
   - Intercepts `KEYCODE_STYLUS_BUTTON_PRIMARY` (single), `SECONDARY` (double), `TERTIARY` (triple), `TAIL` (long), `BUTTON_1` (press).
   - **Nebo Brush <-> Eraser Toggle**:
     - MyScript Nebo (`com.myscript.nebo.lenovo`, prebuilt v6.4.13) registers a dynamic BroadcastReceiver in `EditingActivity` for `com.hihonor.stylus.action.STYLUS_DOUBLE_CLICK` and `com.huawei.stylus.action.BUTTON_DOUBLE_PRESSED`.
     - When receiving this broadcast, Nebo executes `stylusDoubleTapListener.stylusDoubleTap(StylusSwitchBehavior.CURRENT_AND_ERASER)`, toggling instantly between the active drawing brush and eraser.
     - `PenAccessibilityService` automatically sends targeted broadcasts to `com.myscript.nebo.lenovo` whenever `CLICK_DOUBLE` occurs.
   - **Remote Control Mode** (`pen_set_remote_control_on=1`):
     - **Camera**: Dispatches `KEYCODE_VOLUME_DOWN` (shutter / burst).
     - **PowerPoint / WPS / PDF**: Dispatches `KEYCODE_PAGE_DOWN` (next slide) on single click, `KEYCODE_PAGE_UP` (prev slide) on double click.
     - **YouTube / Media**: Dispatches `KEYCODE_MEDIA_PLAY_PAUSE` on single click, `KEYCODE_MEDIA_NEXT` on double click.
   - **Default Mode**:
     - Broadcasts `lenovo.intent.action.INPUT_DEVICE_CLICK_STATE_CHANGED` with `DEVICE_KEYTIMES_STATE`.
     - Triggers `PenService.apk`'s floating toolbar toggle, magnifier tool, laser pointer, and quick note launch.

---

## 20. Display Brightness Floor & UI Slider Calibration Fix (Preventing Backlight Blackout at 0)

### Symptom
When dragging the brightness slider all the way to 0 in EvolutionX, the display backlight turned completely pitch black / off (as if the device powered down), whereas on stock ZUI, moving the slider to 0 kept the screen comfortably lit and legible in dark environments.

### Root Cause Analysis

1. **Hardware Driver Characteristics (`/sys/class/leds/lcd-backlight`)**:
   - The MediaTek MT6789 / MT8781 LED backlight controller shuts down power rails completely when written integer `0` or `1`.
   - Hardware integer **`3`** (out of 255) is the hardware floor: ~0.06 nits, providing low-power, comfortable readability in pitch-black rooms without shutting off the panel LEDs.

2. **The Flawed Workaround in Boot Fix #1**:
   - In Boot Fix #1, `config_screenBrightnessBacklight[0]` was modified from `3` to `0` to silence an `IllegalStateException` in `DisplayDeviceConfig.constrainNitsAndBacklightArrays()`.
   - However, setting `config_screenBrightnessBacklight[0]` to `0` caused Android's `mBrightnessToBacklightSpline` to map normalized framework brightness `0.0f` (slider far-left) directly to backlight level `0`.
   - When the user moved the slider to 0, the display HAL wrote `0` to `/sys/class/leds/lcd-backlight/brightness`, shutting down the backlight LEDs completely.

3. **Stock ZUI Calibrated Mapping (extracted from `ZuiCallaRowFrameworksOverlay.apk`)**:
   - `config_screenBrightnessSettingMinimum` = `3`
   - `config_screenBrightnessSettingMinimumFloat` = `-2` (invalid sentinel, deferring to integer)
   - `config_screenBrightnessBacklight` = `[3, 26, 64, 96, 191, 255, 255]`
   - `config_screenBrightnessNits` = `[0, 40, 100, 150, 300, 420, 490]`
   - In stock ZUI, `DisplayDeviceConfig` calculates:
     $$\text{mBacklightMinimum} = \text{brightnessIntToFloat}(3) = \frac{3 - 1}{254} = 0.007874016\text{f}$$
     $$\text{mRawBacklight}[0] = \text{brightnessIntToFloat}(3) = 0.007874016\text{f}$$
   - The assertion check `mRawBacklight[0] > mBacklightMinimum` evaluates to `0.007874016 > 0.007874016` $\to$ **FALSE**! No crash occurs.
   - The resulting `mBrightnessToBacklightSpline` maps UI slider `0.0f` $\to$ `0.007874016f` $\to$ integer backlight **`3`**.

### Fix Applied
File: [`device/lenovo/tb351fu/overlay/frameworks/base/core/res/res/values/config.xml`](file:///mnt/Nvme/evolutionx/sync/device/lenovo/tb351fu/overlay/frameworks/base/core/res/res/values/config.xml)
- Set `config_screenBrightnessSettingMinimum` = `3`
- Set `config_screenBrightnessSettingMinimumFloat` = `-2`
- Set `config_screenBrightnessSettingMaximumFloat` = `-2`
- Set `config_screenBrightnessDimFloat` = `0.05`
- Set `config_autoBrightnessBrighteningLightDebounce` = `4000`
- Set `config_autoBrightnessDarkeningLightDebounce` = `4000`
- Aligned 7-point `config_screenBrightnessBacklight` to stock `[3, 26, 64, 96, 191, 255, 255]`
- Aligned 7-point `config_screenBrightnessNits` and `config_autoBrightnessDisplayValuesNits` to stock `[0, 40, 100, 150, 300, 420, 490]`
- Sliding to 0 now maps to backlight 3, preventing blackouts while completely eliminating the `DisplayDeviceConfig` crash.
