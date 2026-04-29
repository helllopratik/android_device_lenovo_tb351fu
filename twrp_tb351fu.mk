#
# twrp_tb351fu.mk - Lenovo Tab Plus (TB351FU)
# OrangeFox 14.1 (Android 16)
#

# Global variables for the build system (MUST BE BEFORE ORANGEFOX)
BOARD_BOOT_HEADER_VERSION := 4
TARGET_SCREEN_WIDTH := 1200
TARGET_SCREEN_HEIGHT := 2000
TW_THEME := portrait_hdpi

# Brightness / Backlight (Defined here to satisfy OrangeFox early-check)
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 128
TW_SCREEN_BLANK_ON_BOOT := true

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit from our custom device configuration
$(call inherit-product, device/lenovo/tb351fu/device.mk)

# Inherit from OrangeFox
$(call inherit-product, bootable/recovery/orangefox.mk)

PRODUCT_DEVICE := tb351fu
PRODUCT_NAME := twrp_tb351fu
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Tab Plus
PRODUCT_MANUFACTURER := Lenovo

PRODUCT_GMS_CLIENTID_BASE := android-lenovo
