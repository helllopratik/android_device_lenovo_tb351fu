package com.lenovo.penbridge;

import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;

public final class PalmGuard {

    private static final String TAG = "PalmGuard";
    private static final String PROC_GAME_MODE = "/proc/game_mode";
    private static final String PROC_SUPPORT_PEN = "/proc/support_pen";
    private static final long REFRESH_MS = 500;

    private final android.content.Context mContext;
    private volatile PenRaw mPenRaw;
    private long mLastConfigMs = 0;
    private boolean mConfigEnabled = true;
    private boolean mConfigAppAllowed = true;
    private long mLastPenCheckMs = 0;
    private boolean mPenActive = false;
    private int mLastMode = -1;

    // 0 = normal, 1 = pen mode (enhanced palm rejection), 2 = game mode (palm rejection off)
    private static final int MODE_PEN = 1;
    private static final int MODE_NORMAL = 0;

    public PalmGuard(android.content.Context context) {
        mContext = context;
    }

    public void setPenRaw(PenRaw penRaw) {
        mPenRaw = penRaw;
    }

    public boolean supported() {
        return new File(PROC_GAME_MODE).exists() || new File(PROC_SUPPORT_PEN).exists();
    }

    public synchronized void update() {
        long now = SystemClock.uptimeMillis();
        if (now - mLastConfigMs < REFRESH_MS)
            return;
        mLastConfigMs = now;
        mConfigEnabled = Settings.Secure.getInt(mContext.getContentResolver(),
                SettingsKeys.SECURE_ANTI_ACCIDENTAL_TOUCH, 1) == 1;
        mConfigAppAllowed = appAllowed();
        boolean penConnected = BridgeService.sInstance != null
                && BridgeService.sInstance.tracker() != null
                && BridgeService.sInstance.tracker().isConnected();
        PenRaw.Frame f = mPenRaw != null ? mPenRaw.last() : null;
        mPenActive = f != null && f.ageMs < 1000;
        mLastPenCheckMs = now;

        ensureSupportPen();

        boolean penMode = mConfigEnabled && mConfigAppAllowed && (penConnected || mPenActive);
        int mode = penMode ? MODE_PEN : MODE_NORMAL;
        if (mode == mLastMode)
            return;
        mLastMode = mode;
        writeMode(mode);
    }

    private boolean mSupportPenEnsured = false;

    private void ensureSupportPen() {
        if (mSupportPenEnsured) return;
        try {
            File f = new File(PROC_SUPPORT_PEN);
            if (f.exists()) {
                try (FileOutputStream fos = new FileOutputStream(f)) {
                    fos.write("1".getBytes("US-ASCII"));
                    fos.flush();
                    mSupportPenEnsured = true;
                }
            }
        } catch (Exception ignored) {
        }
    }

    private void writeMode(int mode) {
        try (FileOutputStream fos = new FileOutputStream(PROC_GAME_MODE)) {
            fos.write(String.valueOf(mode).getBytes("US-ASCII"));
            fos.flush();
            Log.i(TAG, "game_mode set to " + mode);
        } catch (Exception e) {
            Log.w(TAG, "write game_mode failed: " + e);
            mLastMode = -1;
        }
    }

    private boolean appAllowed() {
        if (!mConfigEnabled)
            return true;
        String mode = Settings.Secure.getString(mContext.getContentResolver(),
                SettingsKeys.SECURE_PALM_REJECTION_APPS);
        if (!"custom".equalsIgnoreCase(mode))
            return true;
        String top = topPackage();
        if (top == null)
            return true;
        String s = Settings.Secure.getString(mContext.getContentResolver(),
                SettingsKeys.SECURE_PALM_REJECTION_CUSTOM_PACKAGES);
        if (s == null)
            return false;
        for (String p : s.split("[|,;\\s]+")) {
            if (!p.isEmpty() && p.equals(top))
                return true;
        }
        return false;
    }

    private String topPackage() {
        try {
            android.app.ActivityManager am = (android.app.ActivityManager)
                    mContext.getSystemService(android.content.Context.ACTIVITY_SERVICE);
            java.util.List<android.app.ActivityManager.RunningTaskInfo> tasks = am.getRunningTasks(1);
            if (tasks != null && !tasks.isEmpty() && tasks.get(0).topActivity != null) {
                return tasks.get(0).topActivity.getPackageName();
            }
        } catch (Exception e) {
            Log.w(TAG, "getRunningTasks failed", e);
        }
        return null;
    }

    public void reset() {
        mLastMode = -1;
        writeMode(MODE_NORMAL);
    }
}