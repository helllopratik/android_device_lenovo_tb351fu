# Lenovo Tab Plus (TB351FU) - Kernel Upgrade & Stylus Digitizer Integration Guide

This document records the exact procedure used to align the EvolutionX kernel and vendor modules with the official Lenovo ZUI stock firmware (`TB351FU_ROW_OPEN_USER_M15125.2_A16_ZUI_17.5.10.199_ST_260713`), and details the active digitizer activation mechanism for the Lenovo Tab Pen Plus (AP500U Picasso, `17ef:617f`).

---

## 1. Stock Kernel & Prebuilt Specifications

### Kernel Version
- **Stock Build**: `TB351FU_ROW_OPEN_USER_M15125.2_A16_ZUI_17.5.10.199_ST_260713` (Android 16 / ZUI 17.5)
- **Kernel Release**: `Linux version 6.12.23-android16-5-g2d954fcf3d1b-ab13586339-4k`
- **Compiler**: Android Clang 19.0.1 (r536225), LLD 19.0.1
- **Architecture**: `aarch64`, 4 KiB page size (`SMP PREEMPT`)
- **GKI KMI**: `android16-6.12` generation 5

### Upgraded Files
| Component | Source | Target in Tree | Status |
| :--- | :--- | :--- | :--- |
| **Kernel Image** | Extracted from stock `boot.img` | `device/lenovo/tb351fu/prebuilt/kernel` | Upgraded to 6.12.23 (18.7 MB compressed LZ4) |
| **DTBO Image** | Decrypted stock bundle `dtbo.img` | `device/lenovo/tb351fu/prebuilt/dtbo.img` | Upgraded to ZUI 17.5.10.199 build |
| **Device Tree Blob** | Stock `vendor_boot.img` | `device/lenovo/tb351fu/prebuilt/dtb.dtb` | 100% SHA256 match (`4840a638b2...`) |
| **Vendor Modules** | Live stock device `/vendor_dlkm/lib/modules/` | `vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/` | All 185 `.ko` modules upgraded to 6.12.23 |
| **Touchscreen KO** | Live stock device `tp_nt36xxx.ko` | `device/lenovo/tb351fu/prebuilt/vendor_ramdisk/lib/modules/tp_nt36xxx.ko` | Upgraded |

---

## 2. Vendor Modules (`.ko`) Extraction Procedure

To pull vendor modules directly from a running stock device:

```bash
# 1. Package all vendor_dlkm modules on device as root
adb shell "su -c 'tar -czf /data/local/tmp/stock_vendor_modules.tar.gz -C /vendor_dlkm/lib/modules . && chmod 666 /data/local/tmp/stock_vendor_modules.tar.gz'"

# 2. Pull archive to host
adb pull /data/local/tmp/stock_vendor_modules.tar.gz /path/to/extracted/

# 3. Extract and synchronize into proprietary vendor tree
tar -xzf stock_vendor_modules.tar.gz -C vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/
cp vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules/tp_nt36xxx.ko device/lenovo/tb351fu/prebuilt/vendor_ramdisk/lib/modules/
```

All 185 loadable modules (including `tp_nt36xxx.ko`, `wlan_drv_gen4m_6789.ko`, `mali_kbase_mt6789_a16w_jm.ko`, audio, and camera drivers) are verified for KMI `6.12.23-android16-5-g2d954fcf3d1b`.

---

## 3. Stylus Active Digitizer Reverse Engineering & Fixes

### Ground Truth from Bluetooth HCI Snoop Log (`btsnoop_hci.log`)
When the **Lenovo Tab Pen Plus (AP500U Picasso)** connects, stock ZUI performs the following minimal sequence:

1. **GATT Characteristic Notification**:
   - Service: `0000fe40-cc7a-482a-984a-7f2ed5b3e512`
   - Characteristic: `0000fe41-cc7a-482a-984a-7f2ed5b3e512` (Handle `0x003e`)
   - Descriptor (CCCD): `00002902-0000-1000-8000-00805f9b34fb` (Handle `0x003f`)
   - Write Request to Handle `0x003f`: `[0x01, 0x00]` (ENABLE_NOTIFICATION)

2. **Digitizer Activation Command**:
   - Write Command (Opcode `0x52` / `WRITE_TYPE_NO_RESPONSE`) to Handle `0x003e`:
     ```text
     Payload: [0x08, 0x06, 0x0d]
     ```
   - Pen Acknowledgment Notification:
     ```text
     Handle 0x003e -> [0x00]
     ```

No additional commands (G-sensor toggle, wakeup loops, or mode switching) are sent. Sending `[0x05, 0x02]` (G-sensor calibrate) puts the pen into accelerometer test mode and deactivates the digitizer RF transmitter.

### Input Stack & Keycode Separation
- **Digitizer Driver**: `tp_nt36xxx.ko` registers `/dev/input/event9` (`NVTCapacitivePen`).
  - Native Event Capabilities: `BTN_DIGI` (`0x140`), `BTN_TOUCH`, `BTN_STYLUS`, `BTN_STYLUS2`, `ABS_X`, `ABS_Y`, `ABS_PRESSURE`, `ABS_DISTANCE`, `ABS_TILT_X`, `ABS_TILT_Y`.
  - Proximity Beacon: Driver sends key 249 / 331 (`KEY_STYLUS` / `KEYCODE_STYLUS_BUTTON_PRIMARY`) to `NVTCapacitiveTouchScreen` (`event8`).
- **Physical Bluetooth Barrel Buttons**: Handled by `/dev/input/event12` (`Lenovo Tab Pen Plus Consumer Control`) mapped via `Vendor_17ef_Product_617f.kl`:
  - `0x0c0600` -> `BUTTON_1` (Single Click)
  - `0x0c0601` -> `BUTTON_2` (Double Click)
  - `0x0c0602` -> `BUTTON_3` (Triple Click)
  - `0x0c0603` -> `BUTTON_4` (Long Press)
  - `0x0c0604` -> `BUTTON_5` (Press / Hold)
  - `0x0c0605` -> `BUTTON_6` (Disconnect)

`PenAccessibilityService` was modified to ONLY intercept `BUTTON_1..BUTTON_5`, preventing it from capturing proximity `KEYCODE_STYLUS_BUTTON_PRIMARY` and stealing input focus from drawing applications.

### IDC Configuration
- Stock firmware uses **no IDC file** for `NVTCapacitivePen`.
- Android's native `InputReader` automatically sets up `NVTCapacitivePen` with `MULTI_TOUCH` gesture mode and normalized pressure `0.0..1.0`.

### Required System Properties & Settings
- **SurfaceFlinger**:
  - `ro.surface_flinger.set_pen_timer_ms=10000`
  - `ro.surface_flinger.set_touch_timer_ms=2000`
- **Stylus Identification**:
  - `ro.vendor.config.lgsi.pen.event.name=NVTCapacitivePen`
  - `ro.vendor.config.lgsi.pen_info=0x617F:0x17EF:Lenovo Tab Pen Plus`
  - `ro.vendor.config.lgsi.btpen.name.row=Lenovo Tab Pen Plus`
  - `ro.vendor.config.lgsi.pen.bluetooth_key.support=1`
- **Touch IC Sysfs Nodes (Root / Init)**:
  - `/proc/support_pen` = `1`
  - `/proc/game_mode` = `1` (hardware palm rejection mode)
- **Settings.System**:
  - `pen_dynamic_palm_rejection` = `1`
  - `key_pen_mode_disable_utouch` = `1`
  - `lenovo_pen_status` = `1`

---

## 4. Build Configuration Fixes

### A. Prebuilt Stock Kernel Alignment (`BoardConfig.mk`)
To guarantee 100% binary ABI compatibility with the 185 stock vendor DLKM modules and prevent empty `modules.load` or GKI module vermagic mismatch:
```make
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_FORCE_PREBUILT_KERNEL := true
```
This packages the official `6.12.23-android16-5-g2d954fcf3d1b-ab13586339-4k` kernel image directly into `boot.img`.

### B. IDC Device Classification
- **Bluetooth Pen (`Vendor_17ef_Product_617f.idc`)**:
  ```properties
  # Lenovo Tab Pen Plus (AP500U Picasso)
  device.type = externalStylus
  ```
  `device.type = externalStylus` prevents Android `EventHub` from mapping the Bluetooth device as an external mouse/trackpad pointer (`POINTER` mode), routing it instead to `InputDeviceClass::EXTERNAL_STYLUS` to fuse with the touchscreen digitizer.
- **Internal Digitizer (`NVTCapacitivePen.idc`)**:
  ```properties
  touch.deviceType = touchScreen
  touch.orientationAware = 1
  ```
  Ensures 1:1 screen mapping and dispatch of `TOOL_TYPE_STYLUS` events.

### C. Direct Boot Awareness (`PenBridge`)
`android:directBootAware="true"` is declared on `<application>` in `penbridge/AndroidManifest.xml` so the background GATT activation service can run before user credential unlock (Direct Boot / `RUNNING_LOCKED`).
