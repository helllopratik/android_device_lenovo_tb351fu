#
# BoardConfig.mk
#

DEVICE_PATH := device/lenovo/tb351fu

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic

# Platform
TARGET_BOARD_PLATFORM := mt6789
TARGET_BOOTLOADER_BOARD_NAME := t808aa

# Kernel
TARGET_NO_KERNEL := false
BOARD_BOOT_HEADER_VERSION := 4
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x26f00000
BOARD_TAGS_OFFSET := 0x07c80000
BOARD_KERNEL_TAGS_OFFSET := 0x07c80000
BOARD_DTB_OFFSET := 0x07c80000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 bootconfig androidboot.force_normal_boot=0
TARGET_KERNEL_SOURCE := kernel/lenovo/tb351fu
TARGET_KERNEL_CONFIG := t808aa_defconfig
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt

# Lineage Kernel Configs
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_CLANG_COMPILE := true
TARGET_KERNEL_PLATFORM_TARGET := 
include vendor/lineage/config/BoardConfigKernel.mk

# VINTF
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/manifest_hwcomposer.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.audio.service-aidl.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.bluetooth-service-mediatek.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.boot-service.mtk.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.wifi-service.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/lights-mtk-default.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/power-mediatek.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/thermal-mediatek.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/vibrator-mtk-default.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.security.keymint-service.beanpod.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.gatekeeper-service.beanpod.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/android.hardware.sensors-multihal.xml
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/vintf/vendor.lenovo.hardware.touchscreen-service.xml

DEVICE_VENDOR_COMPATIBILITY_MATRIX_FILE += $(DEVICE_PATH)/vintf/vendor_compatibility_matrix.xml
DEVICE_PRODUCT_COMPATIBILITY_MATRIX_FILE += $(DEVICE_PATH)/vintf/product_compatibility_matrix.xml

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_HAS_NO_RECOVERY := true
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_USES_VENDOR_BOOTIMAGE := true
BOARD_USES_METADATA_PARTITION := true

# Partitions: File systems
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_F2FS := true

# Verification (AVB)
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888

# Dolby & Stylus Configs (Placeholders to be expanded in device.mk and vendor tree)
TARGET_SUPPORTS_DOLBY_ATMOS := true
TARGET_SUPPORTS_LENOVO_PEN := true

# Build broken fixes for blindly copied blobs
BUILD_BROKEN_ELF_PREBUILT_ERRORS := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true
BUILD_BROKEN_INCORRECT_PARTITION_IMAGES := true
BUILD_BROKEN_DUP_RULES := true
