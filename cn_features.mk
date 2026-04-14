# CN Features for TB351FU

# Study App (Tianjiao)
PRODUCT_PACKAGES += ZuiGameHelper
PRODUCT_PACKAGES += \
    LFHTianjiaoTablet

# Permissions for Study App
PRODUCT_COPY_FILES += \
    vendor/lenovo/TB351FU/proprietary/product/etc/permissions/privapp-permissions-com.lenovo.lfh.tianjiao.tablet.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/privapp-permissions-com.lenovo.lfh.tianjiao.tablet.xml
