LOCAL_PATH := $(call my-dir)
TB351FU_DEVICE_PATH := $(LOCAL_PATH)

include $(CLEAR_VARS)
LOCAL_MODULE := splice_vendor_boot
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE): $(PRODUCT_OUT)/vendor_boot.img
	bash $(TB351FU_DEVICE_PATH)/rebuild_vendor_boot.sh $(PRODUCT_OUT) $(TB351FU_DEVICE_PATH) out/host/linux-x86/bin/mkbootimg out/host/linux-x86/bin/mkbootfs out/host/linux-x86/bin/lz4
	touch $@
