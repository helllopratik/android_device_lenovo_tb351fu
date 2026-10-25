package com.lenovo.penbridge;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

public class PenAccessibilityService extends AccessibilityService {

    private static final String TAG = "PenAccessibility";

    public static final String ACTION_INPUT_DEVICE_CLICK_STATE_CHANGED =
            "lenovo.intent.action.INPUT_DEVICE_CLICK_STATE_CHANGED";
    public static final String EXTRA_DEVICE_KEYTIMES_STATE =
            "lenovo.intent.extra.DEVICE_KEYTIMES_STATE";
    public static final String EXTRA_LENOVO_HANDLER =
            "lenovo.intent.extra.LENOVO_HANDLER";

    public static final int CLICK_SINGLE = 0;
    public static final int CLICK_DOUBLE = 1;
    public static final int CLICK_TRIPLE = 2;
    public static final int CLICK_LONG = 3;
    public static final int CLICK_PRESS = 4;

    private static final String SETTING_REMOTE_CONTROL = "pen_set_remote_control_on";

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        Log.i(TAG, "PenAccessibilityService connected, ensuring Parker pen GATT connection...");
        PenGattManager.getInstance().ensureConnected(this);
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        int keyCode = event.getKeyCode();
        int action = event.getAction();

        int clickType = -1;
        switch (keyCode) {
            case KeyEvent.KEYCODE_BUTTON_1:
                clickType = CLICK_SINGLE;
                break;
            case KeyEvent.KEYCODE_BUTTON_2:
                clickType = CLICK_DOUBLE;
                break;
            case KeyEvent.KEYCODE_BUTTON_3:
                clickType = CLICK_TRIPLE;
                break;
            case KeyEvent.KEYCODE_BUTTON_4:
                clickType = CLICK_LONG;
                break;
            case KeyEvent.KEYCODE_BUTTON_5:
                clickType = CLICK_PRESS;
                break;
        }

        if (clickType != -1) {
            if (action == KeyEvent.ACTION_UP) {
                handleClick(clickType);
            }
            return true;
        }

        return super.onKeyEvent(event);
    }

    private void handleClick(int clickType) {
        Log.i(TAG, "Stylus button click: type=" + clickType);

        String topPkg = getTopPackageName();

        // 1. Nebo: Double click toggles between current tool (brush) and eraser
        if (clickType == CLICK_DOUBLE) {
            sendNeboDoubleTap();
        }

        // 2. Remote control
        boolean remoteControlOn = Settings.Secure.getInt(
                getContentResolver(), SETTING_REMOTE_CONTROL, 0) == 1;

        if (remoteControlOn && handleRemoteControl(topPkg, clickType)) {
            return;
        }

        // 3. Broadcast to Lenovo PenService (FloatService / BtPenEvents)
        broadcastClickState(clickType);
    }

    private void sendNeboDoubleTap() {
        try {
            Intent honorIntent = new Intent("com.hihonor.stylus.action.STYLUS_DOUBLE_CLICK");
            honorIntent.setPackage("com.myscript.nebo.lenovo");
            sendBroadcast(honorIntent);

            Intent huaweiIntent = new Intent("com.huawei.stylus.action.BUTTON_DOUBLE_PRESSED");
            huaweiIntent.setPackage("com.myscript.nebo.lenovo");
            huaweiIntent.putExtra("double_click_switch_mode", 0);
            sendBroadcast(huaweiIntent);

            Log.i(TAG, "Dispatched double-tap broadcast to Nebo (brush <-> eraser toggle)");
        } catch (Exception e) {
            Log.w(TAG, "Failed sending double-tap to Nebo", e);
        }
    }

    private boolean handleRemoteControl(String topPkg, int clickType) {
        if (topPkg == null) {
            return false;
        }

        Log.d(TAG, "handleRemoteControl: topPkg=" + topPkg + ", clickType=" + clickType);

        if (isCameraPackage(topPkg)) {
            if (clickType == CLICK_SINGLE) {
                sendKey(KeyEvent.KEYCODE_VOLUME_DOWN);
                return true;
            }
        }

        if (isPresentationPackage(topPkg)) {
            if (clickType == CLICK_SINGLE) {
                sendKey(KeyEvent.KEYCODE_PAGE_DOWN);
                return true;
            } else if (clickType == CLICK_DOUBLE) {
                sendKey(KeyEvent.KEYCODE_PAGE_UP);
                return true;
            }
        }

        if (isMediaPackage(topPkg)) {
            if (clickType == CLICK_SINGLE) {
                sendKey(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE);
                return true;
            } else if (clickType == CLICK_DOUBLE) {
                sendKey(KeyEvent.KEYCODE_MEDIA_NEXT);
                return true;
            }
        }

        return false;
    }

    private void broadcastClickState(int clickType) {
        Intent intent = new Intent(ACTION_INPUT_DEVICE_CLICK_STATE_CHANGED);
        intent.putExtra(EXTRA_DEVICE_KEYTIMES_STATE, clickType);
        intent.putExtra(EXTRA_LENOVO_HANDLER, 0);
        sendBroadcast(intent);
        Log.i(TAG, "Broadcasted " + ACTION_INPUT_DEVICE_CLICK_STATE_CHANGED + " state=" + clickType);
    }

    private String getTopPackageName() {
        try {
            AccessibilityNodeInfo root = getRootInActiveWindow();
            if (root != null && root.getPackageName() != null) {
                return root.getPackageName().toString();
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed getting active window package", e);
        }
        return null;
    }

    private boolean isCameraPackage(String pkg) {
        String p = pkg.toLowerCase();
        return p.contains("camera") || p.equals("org.lineageos.aperture");
    }

    private boolean isPresentationPackage(String pkg) {
        String p = pkg.toLowerCase();
        if (p.contains("nebo")) {
            return false;
        }
        return p.contains("powerpoint") || p.contains("presentation") || p.contains("wps") || p.contains("pdf");
    }

    private boolean isMediaPackage(String pkg) {
        String p = pkg.toLowerCase();
        return p.contains("youtube") || p.contains("tiktok") || p.contains("music") || p.contains("spotify")
                || p.contains("vlc") || p.contains("player");
    }

    private void sendKey(int keyCode) {
        AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        long now = SystemClock.uptimeMillis();
        KeyEvent down = new KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0);
        KeyEvent up = new KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0);
        try {
            if (am != null) {
                am.dispatchMediaKeyEvent(down);
                am.dispatchMediaKeyEvent(up);
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed dispatchMediaKeyEvent for " + keyCode, e);
        }
    }
}
