package com.lenovo.penbridge;

public final class SettingsKeys {

    public static final String GLOBAL_PEN_BT_STATUS = "lenovo_pen_status";
    public static final String GLOBAL_STYLUS_CHANGE_ICON = "stylus_change_icon";

    public static final String SECURE_SHOW_STYLUS_POINTER = "stylus_pointer_icon_enabled";
    public static final String SECURE_ANTI_ACCIDENTAL_TOUCH = "pen_activity_anti_accidental_touch";
    public static final String SECURE_PALM_REJECTION_APPS = "pen_activity_palm_rejection_apps";
    public static final String SECURE_PALM_REJECTION_CUSTOM_PACKAGES = "pen_palm_rejection_custom_packages";
    public static final String SECURE_DYNAMIC_PALM_REJECTION = "pen_dynamic_palm_rejection";
    public static final String SECURE_BIGPALM_PACKAGES = "pen_bigpalm_packages";

    public static final int PEN_STATUS_CONNECTED = 1;

    private SettingsKeys() {
    }
}