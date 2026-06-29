PRODUCT_RELEASE_CONFIG_MAPS += device/lenovo/tb351fu/release/release_config_map.textproto
DEVICE_PATH := device/lenovo/tb351fu

# Get non-open-source specific aspects
$(call inherit-product, vendor/lenovo/tb351fu/tb351fu-vendor.mk)

DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    $(DEVICE_PATH)/vintf/framework_compatibility_matrix.xml

# Enable A/B update support
AB_OTA_UPDATER := true

# Fastbootd
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot@1.1-impl-mock

# Dynamic Partitions List
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
    vendor_dlkm \
    odm_dlkm \
    system_dlkm

# Force OTA Package Generation
PRODUCT_BUILD_GENERIC_OTA_PACKAGE := true
PRODUCT_BUILD_RECOVERY_IMAGE := true
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
    splice_vendor_boot \
    librecovery_ui_default \
    librecovery_utils \
    otacerts

# SELinux Bypass Script
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/disable_selinux.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/disable_selinux.sh

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init.recovery.mt8781.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt8781.rc \
    $(DEVICE_PATH)/init.recovery.mt6789.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6789.rc \
    $(DEVICE_PATH)/init.recovery.project.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.project.rc \
    $(DEVICE_PATH)/recovery/load_recovery_modules.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/load_recovery_modules.sh \
    $(DEVICE_PATH)/recovery/watchdog_killer.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/watchdog_killer.sh \
    $(DEVICE_PATH)/prebuilt/NVTCapacitiveTouchScreen.idc:$(TARGET_COPY_OUT_RECOVERY)/root/system/usr/idc/NVTCapacitiveTouchScreen.idc \
    $(DEVICE_PATH)/prebuilt/vendor.lenovo.hardware.touchscreen-service:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/vendor.lenovo.hardware.touchscreen-service \
    $(DEVICE_PATH)/prebuilt/vendor.lenovo.hardware.touchscreen-V2-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/vendor.lenovo.hardware.touchscreen-V2-ndk.so \
    $(DEVICE_PATH)/golden_kick.sh:$(TARGET_COPY_OUT_RECOVERY)/root/sbin/golden_kick.sh

# Enable EROFS support (Required for ZUI 17)
PRODUCT_FS_COMPRESSION := true
TARGET_RECOVERY_FSTYPE_MOUNT_LIST := erofs,f2fs,ext4

# Shipping API Level
PRODUCT_SHIPPING_API_LEVEL := 34
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# VINTF
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# Force vendor_ramdisk creation
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/manifest.xml:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/manifest.xml

# Screen Density
PRODUCT_PRODUCT_PROPERTIES += \
    ro.sf.lcd_density=480
PRODUCT_APEX_SYSTEM_SERVER_JARS += com.android.crashrecovery:service-crashrecovery
WITH_DEXPREOPT := false
WITH_DEXPREOPT_DEBUG_INFO := false

PRODUCT_SYSTEM_EXT_BOOT_JARS += mediatek-common

# Input Device Configurations (Active Stylus)
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/idc/Vendor_17ef_Product_612b.idc:vendor/usr/idc/Vendor_17ef_Product_612b.idc \
    $(DEVICE_PATH)/idc/Vendor_17ef_Product_617f.idc:vendor/usr/idc/Vendor_17ef_Product_617f.idc \
    $(DEVICE_PATH)/idc/Vendor_17ef_Product_61A1.idc:vendor/usr/idc/Vendor_17ef_Product_61A1.idc \
    $(DEVICE_PATH)/keylayout/Vendor_17ef_Product_612b.kl:vendor/usr/keylayout/Vendor_17ef_Product_612b.kl \
    $(DEVICE_PATH)/keylayout/Vendor_17ef_Product_617f.kl:vendor/usr/keylayout/Vendor_17ef_Product_617f.kl \
    $(DEVICE_PATH)/keylayout/Vendor_17ef_Product_619e.kl:vendor/usr/keylayout/Vendor_17ef_Product_619e.kl \
    $(DEVICE_PATH)/keylayout/Vendor_17ef_Product_61a1.kl:vendor/usr/keylayout/Vendor_17ef_Product_61a1.kl

PRODUCT_COPY_FILES += $(LOCAL_PATH)/rootdir/etc/debug_logger.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/debug_logger.rc

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/audio/audio_policy_configuration.xml:vendor/etc/audio_policy_configuration.xml \
    $(DEVICE_PATH)/configs/audio/audio_policy_volumes.xml:vendor/etc/audio_policy_volumes.xml

-include $(LOCAL_PATH)/vndk34.mk



PRODUCT_SYSTEM_EXT_PROPERTIES += ro.control_privapp_permissions=log


PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/fstab.mt6789:vendor/etc/fstab.mt6789
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/fstab.mt6789:vendor/etc/fstab.mt8781
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/debug_logger.rc:vendor/etc/init/hw/debug_logger.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/factory_init.connectivity.common.rc:vendor/etc/init/hw/factory_init.connectivity.common.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/factory_init.connectivity.rc:vendor/etc/init/hw/factory_init.connectivity.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/factory_init.dcxo_nvram.rc:vendor/etc/init/hw/factory_init.dcxo_nvram.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/factory_init.project.rc:vendor/etc/init/hw/factory_init.project.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/factory_init.rc:vendor/etc/init/hw/factory_init.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.aee.rc:vendor/etc/init/hw/init.aee.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.cgroup.rc:vendor/etc/init/hw/init.cgroup.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.connectivity.common.rc:vendor/etc/init/hw/init.connectivity.common.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.connectivity.rc:vendor/etc/init/hw/init.connectivity.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init_connectivity.rc:vendor/etc/init/hw/init_connectivity.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.mt6789.rc:vendor/etc/init/hw/init.mt6789.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.mt6789.usb.rc:vendor/etc/init/hw/init.mt6789.usb.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.mt8781.rc:vendor/etc/init/hw/init.mt8781.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.mtkgki.rc:vendor/etc/init/hw/init.mtkgki.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.project.rc:vendor/etc/init/hw/init.project.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/init.sensor_2_0.rc:vendor/etc/init/hw/init.sensor_2_0.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/meta_init.connectivity.common.rc:vendor/etc/init/hw/meta_init.connectivity.common.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/meta_init.connectivity.rc:vendor/etc/init/hw/meta_init.connectivity.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/meta_init.dcxo_nvram.rc:vendor/etc/init/hw/meta_init.dcxo_nvram.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/meta_init.project.rc:vendor/etc/init/hw/meta_init.project.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/meta_init.rc:vendor/etc/init/hw/meta_init.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/meta_init.vendor.rc:vendor/etc/init/hw/meta_init.vendor.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/multi_init.rc:vendor/etc/init/hw/multi_init.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/teei_daemon.rc:vendor/etc/init/teei_daemon.rc
PRODUCT_COPY_FILES += $(DEVICE_PATH)/rootdir/etc/tinno_t808aa.init.rc:vendor/etc/init/hw/tinno_t808aa.init.rc
$(call inherit-product, vendor/lenovo/tb351fu/tb351fu-vendor-blobs.mk)
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/0102030405060708090a0b0c0d0e0f10.ta:vendor/thh/ta/0102030405060708090a0b0c0d0e0f10.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/020f0000000000000000000000000000.ta:vendor/thh/ta/020f0000000000000000000000000000.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/08030000000000000000000000000000.ta:vendor/thh/ta/08030000000000000000000000000000.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/08110000000000000000000000000000.ta:vendor/thh/ta/08110000000000000000000000000000.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/3bb8ce3f62e044b2926f3f10339ca6d7.ta:vendor/thh/ta/3bb8ce3f62e044b2926f3f10339ca6d7.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/40188311faf343488db888ad39496f9a.ta:vendor/thh/ta/40188311faf343488db888ad39496f9a.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/5020170115e016302017012521300000.ta:vendor/thh/ta/5020170115e016302017012521300000.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/5f7a5b3b29b041bca249524a031a00e3.ta:vendor/thh/ta/5f7a5b3b29b041bca249524a031a00e3.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/797e5bec0aa546dbb1d388f2b4250241.ta:vendor/thh/ta/797e5bec0aa546dbb1d388f2b4250241.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/abcd270ea5c44c58bcd3384a2fa2539e.ta:vendor/thh/ta/abcd270ea5c44c58bcd3384a2fa2539e.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/c09c9c5daa504b78b0e46eda61556c3a.ta:vendor/thh/ta/c09c9c5daa504b78b0e46eda61556c3a.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/c1882f2d885e4e13a8c8e2622461b2fa.ta:vendor/thh/ta/c1882f2d885e4e13a8c8e2622461b2fa.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/d91f322ad5a441d5955110eda3272fc0.ta:vendor/thh/ta/d91f322ad5a441d5955110eda3272fc0.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/e97c270ea5c44c58bcd3384a2fa2539e.ta:vendor/thh/ta/e97c270ea5c44c58bcd3384a2fa2539e.ta
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/thh/ta/isee_model.json:vendor/thh/ta/isee_model.json
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/bin/hw/mt6789/android.hardware.graphics.allocator-V2-service-mediatek.mt6789:vendor/bin/hw/android.hardware.graphics.allocator-V2-service-mediatek
PRODUCT_COPY_FILES += vendor/lenovo/tb351fu/proprietary/vendor/bin/hw/mt6789/camerahalserver:vendor/bin/hw/camerahalserver

PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.hwcomposer=mtk_common \
    ro.hardware.kmsetkey=beanpod \
    ro.hardware.gatekeeper=beanpod \
    ro.hardware.gralloc=common \
    ro.hardware.vulkan=mali \
    ro.hardware.egl=meow \
    dalvik.vm.heapstartsize=16m \
    dalvik.vm.heapgrowthlimit=384m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

PRODUCT_VENDOR_PROPERTIES += \
    ro.vendor.rc=/vendor/etc/init/hw/ \
    ro.vendor.init.sensor.rc=init.sensor_2_0.rc \
    ro.vendor.mtk.sensor.support=yes \
    ro.vendor.wlan.chrdev=wmt_chrdev_wifi \
    ro.vendor.wlan.gen=gen4m_6789 \
    ro.vendor.bt.platform=connac1x \
    ro.vendor.mediatek.platform=MT6789 \
    ro.vendor.mtk_camera_app_version=3 \
    ro.vendor.pref_scale_enable_cfg=1 \
    vendor.mtk.camera.app.fd.video=1 \
    camera.disable_zsl_mode=1 \
    media.c2.dmabuf.padding=3072 \
    media.c2.hal.selection=aidl \
    media.stagefright.thumbnail.prefer_hw_codecs=true


