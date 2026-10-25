package com.lenovo.penbridge;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import java.util.HashSet;
import java.util.Set;

public final class PenTracker {

    private static final String TAG = "PenTracker";

    private static final String[] PEN_NAMES = {
            "Lenovo Tab Pen Plus", "Lenovo Tab Pen Pro", "Lenovo Precision Pen",
            "Lenovo Active Pen", "Lenovo Pen", "Tab Pen Plus", "PICASSO",
            "Tab Pen Pro", "Lenovo Precision Pen 2", "Lenovo Precision Pen 3"
    };

    private final Context mContext;
    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private final Set<String> mConnectedPens = new HashSet<>();
    private BluetoothAdapter mAdapter;
    private boolean mRegistered = false;
    private boolean mConnected = false;
    private BluetoothDevice mCurrentDevice = null;

    private final Runnable mPoll = new Runnable() {
        @Override
        public void run() {
            update();
            mHandler.postDelayed(this, 5000);
        }
    };

    public PenTracker(Context context) {
        mContext = context;
        BluetoothManager bm = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
        mAdapter = bm != null ? bm.getAdapter() : null;
    }

    public void register() {
        if (mRegistered)
            return;
        mRegistered = true;
        IntentFilter f = new IntentFilter();
        f.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
        f.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
        f.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED);
        f.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
        mContext.registerReceiver(mReceiver, f);
        mPoll.run();
    }

    public void unregister() {
        if (mRegistered) {
            mRegistered = false;
            mContext.unregisterReceiver(mReceiver);
            mHandler.removeCallbacks(mPoll);
        }
    }

    private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            BluetoothDevice device =
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice.class);
            if (device != null && matches(device.getName())) {
                String action = intent.getAction();
                if (BluetoothDevice.ACTION_ACL_CONNECTED.equals(action)) {
                    mConnectedPens.add(device.getAddress());
                } else if (BluetoothDevice.ACTION_ACL_DISCONNECTED.equals(action)) {
                    mConnectedPens.remove(device.getAddress());
                }
            }
            update();
        }
    };

    private static boolean matches(String name) {
        if (name == null)
            return false;
        String n = name.trim();
        if (n.isEmpty())
            return false;
        for (String s : PEN_NAMES) {
            if (n.equalsIgnoreCase(s))
                return true;
        }
        return n.toLowerCase().contains("pen") && n.toLowerCase().contains("lenovo");
    }

    private synchronized void update() {
        boolean connected = false;
        BluetoothDevice connectedDevice = null;
        Set<BluetoothDevice> bonded = new HashSet<>();
        try {
            if (mAdapter != null && mAdapter.isEnabled()) {
                bonded.addAll(mAdapter.getBondedDevices());
            }
        } catch (SecurityException e) {
            Log.w(TAG, "bluetooth access denied", e);
        }
        BluetoothManager bm = mContext.getSystemService(BluetoothManager.class);
        for (BluetoothDevice d : bonded) {
            if (!matches(d.getName()))
                continue;
            try {
                if (bm != null
                        && bm.getConnectionState(d, BluetoothProfile.GATT) == BluetoothProfile.STATE_CONNECTED) {
                    connected = true;
                    connectedDevice = d;
                    break;
                } else if (mConnectedPens.contains(d.getAddress())) {
                    connected = true;
                    connectedDevice = d;
                    break;
                }
            } catch (SecurityException e) {
                Log.w(TAG, "bluetooth access denied", e);
            }
        }
        setConnected(connected, connectedDevice);
    }

    private synchronized void setConnected(boolean connected, BluetoothDevice device) {
        if (connected == mConnected)
            return;
        mConnected = connected;
        mCurrentDevice = device;
        Log.i(TAG, "pen connected=" + connected + (device != null ? (" device=" + device.getName()) : ""));

        ContentResolver cr = mContext.getContentResolver();

        try {
            Settings.Global.putInt(cr,
                    SettingsKeys.GLOBAL_PEN_BT_STATUS,
                    connected ? SettingsKeys.PEN_STATUS_CONNECTED : 0);

            if (connected) {
                String name = device != null && device.getName() != null ? device.getName() : "Lenovo Tab Pen Plus";
                Settings.Global.putString(cr, "pen_name", name);
                Settings.Global.putString(cr, "pen_sn", "HVFC0NXN");

                if (Settings.Secure.getInt(cr, "pen_floating_all", -1) == -1) {
                    Settings.Secure.putInt(cr, "pen_floating_all", 1);
                }
                if (Settings.Secure.getInt(cr, "pen_set_show_button", -1) == -1) {
                    Settings.Secure.putInt(cr, "pen_set_show_button", 1);
                }
                if (Settings.Secure.getString(cr, "pen_set_click_pen_button_summary") == null) {
                    Settings.Secure.putString(cr, "pen_set_click_pen_button_summary", "show_hide_menu");
                }
                if (Settings.Secure.getInt(cr, "pen_set_quick_create_click_notes", -1) == -1) {
                    Settings.Secure.putInt(cr, "pen_set_quick_create_click_notes", 1);
                }
                if (Settings.System.getInt(cr, "pen_dynamic_palm_rejection", -1) == -1) {
                    Settings.System.putInt(cr, "pen_dynamic_palm_rejection", 1);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "failed writing pen settings", e);
        }

        // Broadcast to PenService (BootBroadcastReceiver & BtPenReceiver)
        try {
            Intent intent = new Intent("lenovo.intent.action.PEN_BT_CHANGED");
            intent.putExtra("status", connected ? 1 : 0);
            if (device != null) {
                intent.putExtra("address", device.getAddress());
                intent.putExtra("name", device.getName());
            } else {
                intent.putExtra("address", "");
                intent.putExtra("name", "Lenovo Tab Pen Plus");
            }
            intent.putExtra("level", -1);
            mContext.sendBroadcast(intent);
            Log.i(TAG, "broadcasted lenovo.intent.action.PEN_BT_CHANGED status=" + (connected ? 1 : 0));
        } catch (Exception e) {
            Log.w(TAG, "failed to send PEN_BT_CHANGED", e);
        }

        // Connect/disconnect BLE GATT to activate Parker active digitizer
        if (connected && device != null) {
            PenGattManager.getInstance().connect(mContext, device);
        } else if (!connected) {
            PenGattManager.getInstance().disconnect();
        }

        // Explicitly start FloatService when pen connects
        if (connected) {
            try {
                Intent fsIntent = new Intent();
                fsIntent.setComponent(new ComponentName("com.lenovo.penservice", "com.lenovo.pen.bt.service.FloatService"));
                mContext.startService(fsIntent);
                Log.i(TAG, "started FloatService");
            } catch (Exception e) {
                Log.w(TAG, "failed starting FloatService: " + e);
            }

            ensureAccessibilityService();
        }
    }

    public void ensureAccessibilityService() {
        try {
            ContentResolver cr = mContext.getContentResolver();
            String serviceComponent = mContext.getPackageName() + "/" + PenAccessibilityService.class.getName();
            String enabled = Settings.Secure.getString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
            if (enabled == null || !enabled.contains(serviceComponent)) {
                String target = (enabled == null || enabled.isEmpty())
                        ? serviceComponent
                        : enabled + ":" + serviceComponent;
                Settings.Secure.putString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, target);
                Settings.Secure.putInt(cr, Settings.Secure.ACCESSIBILITY_ENABLED, 1);
                Log.i(TAG, "auto-enabled PenAccessibilityService: " + target);
            }
        } catch (Exception e) {
            Log.w(TAG, "failed to auto-enable PenAccessibilityService", e);
        }
    }

    public synchronized boolean isConnected() {
        return mConnected;
    }

    public synchronized String describedState() {
        return mConnected ? "Pen connected" : "Pen disconnected";
    }
}