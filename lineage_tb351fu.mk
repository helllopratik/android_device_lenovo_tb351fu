# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

# Inherit from tb351fu device
$(call inherit-product, device/lenovo/tb351fu/device.mk)

PRODUCT_DEVICE := tb351fu
PRODUCT_NAME := lineage_tb351fu
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Lenovo Tab Plus
PRODUCT_MANUFACTURER := Lenovo
PRODUCT_MAINTAINER := helllopratik
LINEAGE_MAINTAINER := helllopratik

PRODUCT_GMS_CLIENTID_BASE := android-lenovo

# Use private release keys for build signature (satisfies Trust interface checks)
PRODUCT_DEFAULT_DEV_CERTIFICATE := device/lenovo/tb351fu/security/releasekey

