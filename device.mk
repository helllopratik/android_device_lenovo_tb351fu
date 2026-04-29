DEVICE_PATH := device/lenovo/tb351fu

# Get non-open-source specific aspects
$(call inherit-product, vendor/lenovo/tb351fu/tb351fu-vendor.mk)

DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    $(DEVICE_PATH)/vintf/framework_compatibility_matrix.xml

# Enable A/B update support
AB_OTA_UPDATER := true

# Mandatory A/B Partition List
AB_OTA_PARTITIONS := \
    boot \
    dtbo \
    init_boot \
    product \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm

# Force OTA Package Generation
PRODUCT_BUILD_GENERIC_OTA_PACKAGE := true
TARGET_OTA_ASSERT_DEVICE := tb351fu,TB351FU
PRODUCT_ENFORCE_USES_LIBRARIES := false

# A/B OTA tools
PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script \
    update_engine \
    update_engine_sideload \
    update_verifier

# Force Recovery Binary & UI
PRODUCT_PACKAGES += \
    recovery \
    librecovery_ui_default \
    librecovery_utils \
    otacerts

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init.recovery.mt8781.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt8781.rc \
    $(DEVICE_PATH)/init.recovery.mt6789.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6789.rc \
    $(DEVICE_PATH)/init.recovery.project.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.project.rc \
    $(DEVICE_PATH)/recovery/load_recovery_modules.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/load_recovery_modules.sh \
    $(DEVICE_PATH)/prebuilt/NVTCapacitiveTouchScreen.idc:$(TARGET_COPY_OUT_RECOVERY)/root/system/usr/idc/NVTCapacitiveTouchScreen.idc \
    $(DEVICE_PATH)/prebuilt/vendor.lenovo.hardware.touchscreen-service:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/vendor.lenovo.hardware.touchscreen-service \
    $(DEVICE_PATH)/prebuilt/vendor.lenovo.hardware.touchscreen-V2-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/vendor.lenovo.hardware.touchscreen-V2-ndk.so \
    $(DEVICE_PATH)/golden_kick.sh:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/golden_kick.sh

# Enable EROFS support (Required for ZUI 17)
PRODUCT_FS_COMPRESSION := true
TARGET_RECOVERY_FSTYPE_MOUNT_LIST := erofs,f2fs,ext4

# Shipping API Level
PRODUCT_SHIPPING_API_LEVEL := 34

# Screen Density
PRODUCT_PRODUCT_PROPERTIES += \
    ro.sf.lcd_density=480
