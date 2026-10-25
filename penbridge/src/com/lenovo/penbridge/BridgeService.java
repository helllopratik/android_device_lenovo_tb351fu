package com.lenovo.penbridge;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class BridgeService extends Service {

    private static final String TAG = "PenBridge";
    private static final String CHANNEL = "pen_bridge";
    private static final long POLL_INTERVAL_MS = 40;

    public static volatile BridgeService sInstance;

    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private PenTracker mTracker;
    private PenRaw mPenRaw;
    private HoverCursor mCursor;
    private PalmGuard mPalmGuard;
    private long mPenXMax = 12000;
    private long mPenYMax = 20000;

    public PenTracker tracker() {
        return mTracker;
    }

    public PenRaw penRaw() {
        return mPenRaw;
    }

    private final Runnable mPoll = new Runnable() {
        @Override
        public void run() {
            if (mPenRaw != null) {
                mPenRaw.poll();
                PenRaw.Frame f = mPenRaw.last();
                if (mCursor != null)
                    mCursor.update(f);
            }
            if (mPalmGuard != null)
                mPalmGuard.update();
            mHandler.postDelayed(this, POLL_INTERVAL_MS);
        }
    };

    private boolean mSyncing = false;
    private void syncPointerSettings(Uri uri) {
        if (mSyncing) return;
        mSyncing = true;
        try {
            Uri globalUri = Settings.Global.getUriFor(SettingsKeys.GLOBAL_STYLUS_CHANGE_ICON);
            Uri secureUri = Settings.Secure.getUriFor(SettingsKeys.SECURE_SHOW_STYLUS_POINTER);
            if (uri == null || uri.equals(globalUri)) {
                String lenovo = Settings.Global.getString(getContentResolver(), SettingsKeys.GLOBAL_STYLUS_CHANGE_ICON);
                if (lenovo != null && !lenovo.trim().isEmpty()) {
                    boolean on = "1:1".equals(lenovo) || "0:1".equals(lenovo) || lenovo.endsWith(":1");
                    int currentAosp = Settings.Secure.getInt(getContentResolver(), SettingsKeys.SECURE_SHOW_STYLUS_POINTER, 0);
                    if (currentAosp != (on ? 1 : 0)) {
                        Settings.Secure.putInt(getContentResolver(), SettingsKeys.SECURE_SHOW_STYLUS_POINTER, on ? 1 : 0);
                    }
                }
            } else if (uri.equals(secureUri)) {
                int aosp = Settings.Secure.getInt(getContentResolver(), SettingsKeys.SECURE_SHOW_STYLUS_POINTER, 0);
                String currentLenovo = Settings.Global.getString(getContentResolver(), SettingsKeys.GLOBAL_STYLUS_CHANGE_ICON);
                String wantLenovo = (aosp == 1) ? "1:1" : "1:0";
                if (currentLenovo == null || !currentLenovo.equals(wantLenovo)) {
                    Settings.Global.putString(getContentResolver(), SettingsKeys.GLOBAL_STYLUS_CHANGE_ICON, wantLenovo);
                }
            }
        } catch (Exception ignored) {
        } finally {
            mSyncing = false;
        }
    }

    private final ContentObserver mSettingsObserver = new ContentObserver(mHandler) {
        @Override
        public void onChange(boolean selfChange, Uri uri) {
            if (mPalmGuard != null)
                mPalmGuard.update();
            if (mCursor != null && !mCursor.enabled())
                mCursor.hideNow();
            syncPointerSettings(uri);
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        sInstance = this;
        startForegroundCompat();
        mPenRaw = new PenRaw();
        mPenRaw.open();
        mPenXMax = readAbsRange("ABS_X");
        mPenYMax = readAbsRange("ABS_Y");
        mTracker = new PenTracker(this);
        mTracker.register();
        mTracker.ensureAccessibilityService();
        mCursor = new HoverCursor(this);
        mCursor.setCoordinateScale(mPenXMax, mPenYMax);
        mPalmGuard = new PalmGuard(this);
        mPalmGuard.setPenRaw(mPenRaw);
        registerSettingsObserver();
        syncPointerSettings(null);
        mHandler.post(mPoll);
        Log.i(TAG, "bridge started, penraw ranges " + mPenXMax + "x" + mPenYMax
                + ", palm support=" + mPalmGuard.supported());
    }

    private void registerSettingsObserver() {
        try {
            getContentResolver().registerContentObserver(
                    Settings.Secure.getUriFor(SettingsKeys.SECURE_ANTI_ACCIDENTAL_TOUCH),
                    false, mSettingsObserver);
            getContentResolver().registerContentObserver(
                    Settings.Secure.getUriFor(SettingsKeys.SECURE_SHOW_STYLUS_POINTER),
                    false, mSettingsObserver);
            getContentResolver().registerContentObserver(
                    Settings.Global.getUriFor(SettingsKeys.GLOBAL_STYLUS_CHANGE_ICON),
                    false, mSettingsObserver);
        } catch (Exception e) {
            Log.w(TAG, "observer failed", e);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        mHandler.removeCallbacks(mPoll);
        try {
            getContentResolver().unregisterContentObserver(mSettingsObserver);
        } catch (Exception ignored) {
        }
        if (mTracker != null)
            mTracker.unregister();
        if (mCursor != null)
            mCursor.destroy();
        if (mPalmGuard != null)
            mPalmGuard.reset();
        if (mPenRaw != null)
            mPenRaw.close();
        sInstance = null;
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void startForegroundCompat() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Pen services",
                NotificationManager.IMPORTANCE_MIN));
        Notification n = new Notification.Builder(this, CHANNEL)
                .setContentTitle("Pen services")
                .setContentText("Lenovo pen support active")
                .setSmallIcon(android.R.drawable.ic_menu_edit)
                .setOngoing(true)
                .build();
        try {
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } catch (Exception e) {
            startForeground(1, n);
        }
    }

    private long readAbsRange(String axis) {
        String want = axis.equals("ABS_X") ? "0000" : "0001";
        Pattern linePat = Pattern.compile("^ABS:\\s*([0-9a-fA-F]+)\\s+\\S+\\s+:\\s+([0-9a-fA-F]+)\\s+([0-9a-fA-F]+)");
        try (BufferedReader r = new BufferedReader(new FileReader("/proc/bus/input/devices"))) {
            String line;
            boolean inPen = false;
            while ((line = r.readLine()) != null) {
                if (line.startsWith("N:")) {
                    inPen = line.contains("NVTCapacitivePen");
                    continue;
                }
                if (!inPen)
                    continue;
                Matcher m = linePat.matcher(line);
                if (m.matches() && m.group(1).equalsIgnoreCase(want)) {
                    return Long.parseLong(m.group(3), 16);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "abs range read failed", e);
        }
        return axis.equals("ABS_X") ? 12000 : 20000;
    }
}