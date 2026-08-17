#
# BoardConfig.mk - Lenovo Tab Plus (TB351FU)
# OrangeFox 14.1 (Android 16) - RECOVERY CALIBRATION
#

DEVICE_PATH := device/lenovo/tb351fu

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

# Platform
TARGET_BOARD_PLATFORM := mt6789
TARGET_BOOTLOADER_BOARD_NAME := t808aa
BOARD_HAS_MTK_HARDWARE := true
BOARD_USES_MTK_COMMON := true

# Properties
ADDITIONAL_DEFAULT_PROPERTIES += \
    ro.hardware=mt8781 \
    ro.board.platform=mt6789 \
    ro.boot.dynamic_partitions=true \
    ro.boot.selinux=permissive \
    ro.secure=0 \
    ro.debuggable=1 \
    ro.adb.secure=1 \
    ro.orangefox.no_apex_mount=1 \
    ro.crypto.state=unencrypted \
    ro.crypto.type=none \
    tw_include_crypto=false \
    persist.sys.usb.config=mtp \
    sys.usb.config=mtp \
    tw_brightness_path="/sys/class/leds/lcd-backlight/brightness" \
    tw_max_brightness=2047 \
    tw_default_brightness=1200 \
    ro.orangefox.boot=1

# Treble
PRODUCT_FULL_TREBLE_OVERRIDE := true
BOARD_VNDK_VERSION := current

# Boot Header
BOARD_BOOT_HEADER_VERSION := 4
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_KERNEL_PAGESIZE := 4096

# Kernel Offsets & Name
TARGET_NO_KERNEL := false
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00000000
BOARD_RAMDISK_OFFSET := 0x26f00000
BOARD_TAGS_OFFSET := 0x07c80000
BOARD_KERNEL_TAGS_OFFSET := 0x07c80000
BOARD_DTB_OFFSET := 0x07c80000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 bootconfig androidboot.selinux=permissive

# Kernel
#
# Stock ZUI 17 uses a Google-derived 4 KiB Android 16 6.12 GKI. The proprietary
# vendor modules were built for KMI 6.12-android16-5, so they must not be
# paired with the legacy Lenovo 5.10 source tree or a different GKI KMI
# generation.  Android platform upgrades do not require a new kernel KMI.
TARGET_KERNEL_SOURCE := kernel/lenovo/TB351FU
TARGET_KERNEL_CONFIG := gki_defconfig
TARGET_KERNEL_ADDITIONAL_CONFIGS := $(DEVICE_PATH)/kernel.config
TARGET_KERNEL_CLANG_COMPILE := true
TARGET_KERNEL_NO_GCC := true
TARGET_KERNEL_LLVM_BINUTILS := true
TARGET_KERNEL_RUST_VERSION := 1.88.0

# Export required environment variables for Rust
RUST_LIBSRC := $(abspath prebuilts/rust/linux-x86/1.88.0/lib/rustlib/src/rust/library)

BOARD_KERNEL_IMAGE_NAME := Image.lz4

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt
BOARD_PREBUILT_DTBIMAGE := $(DEVICE_PATH)/prebuilt/dtb.dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# AVB
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_PARTITION_SIZE := 8388608

# AVB Partition Signings
BOARD_AVB_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_BOOT_ROLLBACK_INDEX := $(BOARD_AVB_ROLLBACK_INDEX)
BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_DTBO_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_DTBO_ALGORITHM := SHA256_RSA4096
BOARD_AVB_DTBO_ROLLBACK_INDEX := $(BOARD_AVB_ROLLBACK_INDEX)
BOARD_AVB_DTBO_ROLLBACK_INDEX_LOCATION := 3

BOARD_AVB_VENDOR_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VENDOR_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX := $(BOARD_AVB_ROLLBACK_INDEX)
BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION := 5

BOARD_AVB_INIT_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_INIT_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX := $(BOARD_AVB_ROLLBACK_INDEX)
BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX_LOCATION := 6

BOARD_AVB_VBMETA_SYSTEM := system

# Fragment 0 / Platform Support
BOARD_RAMDISK_FRAGMENT_0_NAME := platform
BOARD_RAMDISK_FRAGMENT_0_TYPE := platform
BOARD_RAMDISK_FRAGMENT_0_FMT := lz4_legacy
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2
BOARD_AVB_VBMETA_SYSTEM_PARTITION_SIZE := 8388608

BOARD_AVB_VBMETA_VENDOR := vendor
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 4
BOARD_AVB_VBMETA_VENDOR_PARTITION_SIZE := 8388608

# Bootconfig
BOARD_BOOTCONFIG := kernel.rcu_nocbs=all kernel.rcutree.enable_rcu_lazy=1 kernel.rcupdate.rcu_cpu_stall_cputime=1 androidboot.selinux=permissive

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_HAS_NO_RECOVERY := false
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_USES_VENDOR_BOOTIMAGE := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_USES_METADATA_PARTITION := true
TARGET_SKIP_OTA_PACKAGE := false
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# Path
BOARD_BOOTDEVICE_PATH := 11270000.ufshci

# Dynamic Partitions
BOARD_SUPPORTS_DYNAMIC_PARTITIONS := true
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
BOARD_SUPER_PARTITION_GROUPS := lenovo_dynamic_partitions
BOARD_LENOVO_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext vendor product vendor_dlkm odm_dlkm system_dlkm
BOARD_LENOVO_DYNAMIC_PARTITIONS_SIZE := 8589934592

# Filesystem Types
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

# Partition Sizes
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648
BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE := 1073741824
BOARD_PRODUCTIMAGE_PARTITION_SIZE := 3221225472
BOARD_VENDORIMAGE_PARTITION_SIZE := 1073741824
BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE := 104857600
BOARD_ODM_DLKMIMAGE_PARTITION_SIZE := 104857600
BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE := 104857600
BOARD_USERDATAIMAGE_PARTITION_SIZE := 116235436032

# Copy-out paths
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

# Graphics
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true
TW_THEME := portrait_hdpi
TARGET_SCREEN_WIDTH := 1200
TARGET_SCREEN_HEIGHT := 2000

# OrangeFox / TWRP Specifics
FOX_RECOVERY_INSTALL_DIR := /system/bin
FOX_RECOVERY_SYSTEM_PART := /dev/block/mapper/system
FOX_RECOVERY_VENDOR_PART := /dev/block/mapper/vendor
TW_DEVICE_VERSION := V54
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXTRA_LANGUAGES := true
TW_INCLUDE_NTFS_3G := true
TW_USE_TOOLBOX := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_REPACKTOOLS := true
TW_HAS_MTP := true

# Fragment 0 / Platform Support
# Fragment 0 / Platform Support
# Note: Multiple ramdisk fragments crash the Soong compiler in Android 16.
# We will use an Android Make Hook to construct the multi-fragment vendor_boot natively.

# Brightness
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 1200

# Storage
TW_INTERNAL_STORAGE_PATH := /data/media
TW_INTERNAL_STORAGE_MOUNT_POINT := data
TW_EXTERNAL_STORAGE_PATH := /external_sd
TW_EXTERNAL_STORAGE_MOUNT_POINT := external_sd
TW_DEFAULT_EXTERNAL_STORAGE := true
RECOVERY_SDCARD_ON_DATA := true

# Crypto & Decryption (Android 16 / FBE v2)
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
BOARD_USES_METADATA_PARTITION := true

# Module Loading
TW_LOAD_VENDOR_BOOT_MODULES := true

# Fixes
BOARD_GENFS_LABELS_VERSION := 202604
SELINUX_IGNORE_NEVERALLOWS := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_ERRORS := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true
BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true
BUILD_BROKEN_VERIFY_USES_LIBRARIES := true
RELAX_USES_LIBRARY_CHECK := true
ADDITIONAL_DEFAULT_PROPERTIES += persist.sys.disable_rescue=true
BOARD_RAMDISK_USE_LZ4 := true

# SELinux
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/system_ext/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/system_ext/private
BOARD_VENDOR_SEPOLICY_DIRS += device/lineage/sepolicy/mosey/vendor

BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/private

# MTK Specific
BOARD_MTK_ENABLE_GENERIC_HAL := true

# VINTF
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# OTA / Bootloader Safety
TARGET_NO_PRELOADER := true
TARGET_NO_LK := true

# OrangeFox Additions
FOX_MAINTAINER_PATCH_VERSION := 1
TW_DEVICE_VERSION := V54-FINAL
FOX_VANILLA := 1
FOX_ENABLE_APP_MANAGER := 1
FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER := 1
FOX_USE_BASH_SHELL := 1
FOX_USE_NANO_EDITOR := 1
FOX_USE_TAR_BINARY := 1
FOX_USE_SED_BINARY := 1
FOX_USE_XZ_UTILS := 1
FOX_REPLACE_BUSYBOX_UTILS := 1

include vendor/lineage/config/BoardConfigLineage.mk

# Lineage Health HAL — Charging Control (soong_config_set API, post-July 2026 vendor sync)
# Confirmed live on device: /sys/devices/platform/charger/charging_enabled exists and reads "1"
# The old TARGET_HEALTH_CHARGING_CONTROL_* Make variables were removed (commit 6e3765ec).
# Use soong_config_set(lineage_health, ...) instead.
#
# charging_control_supports_toggle = true  → enables the charging control feature (ChargingControl HAL)
# charging_control_charging_path          → sysfs node to write 0/1 to enable/disable charging
# charging_control_charging_enabled       → value to write to ENABLE charging
# charging_control_charging_disabled      → value to write to DISABLE/limit charging
$(call soong_config_set,lineage_health,charging_control_charging_path,/sys/devices/platform/charger/charging_enabled)
$(call soong_config_set,lineage_health,charging_control_charging_enabled,1)
$(call soong_config_set,lineage_health,charging_control_charging_disabled,0)

# Recovery Graphics Fixes
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_RECOVERY_OUI_PIXEL_FORMAT := BGRA_8888
RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true


