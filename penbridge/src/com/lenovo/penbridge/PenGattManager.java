package com.lenovo.penbridge;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.LinkedList;
import java.util.Queue;
import java.util.Set;
import java.util.UUID;

public final class PenGattManager {

    private static final String TAG = "PenGatt";

    // Lenovo Parker / Pen proprietary GATT Service and Characteristic
    public static final UUID BTPEN_COMMON_SERVICE =
            UUID.fromString("0000fe40-cc7a-482a-984a-7f2ed5b3e512");
    public static final UUID BTPEN_COMMON_CHARACTERISTIC =
            UUID.fromString("0000fe41-cc7a-482a-984a-7f2ed5b3e512");
    public static final UUID CLIENT_CHARACTERISTIC_CONFIG =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private static PenGattManager sInstance;

    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private Context mContext;
    private BluetoothGatt mGatt;
    private BluetoothGattCharacteristic mCharac;
    private boolean mConnecting = false;
    private final Queue<byte[]> mWriteQueue = new LinkedList<>();
    private boolean mWriting = false;
    private boolean mInitialized = false;

    private final Runnable mWriteTimeoutWatchdog = new Runnable() {
        @Override
        public void run() {
            synchronized (PenGattManager.this) {
                if (mWriting) {
                    Log.w(TAG, "GATT write timed out after 350ms, resetting mWriting");
                    mWriting = false;
                    processQueue();
                }
            }
        }
    };

    public static synchronized PenGattManager getInstance() {
        if (sInstance == null) {
            sInstance = new PenGattManager();
        }
        return sInstance;
    }

    private PenGattManager() {}

    public synchronized void ensureConnected(Context context) {
        if (context == null) return;
        mContext = context.getApplicationContext();
        if (mGatt != null && mCharac != null) {
            if (!mInitialized) {
                sendInitSequence();
            }
            return;
        }

        BluetoothManager bm = mContext.getSystemService(BluetoothManager.class);
        if (bm == null) return;
        BluetoothAdapter adapter = bm.getAdapter();
        if (adapter == null || !adapter.isEnabled()) return;

        try {
            Set<BluetoothDevice> bonded = adapter.getBondedDevices();
            if (bonded != null) {
                for (BluetoothDevice d : bonded) {
                    String name = d.getName();
                    if (name != null && (name.contains("Pen") || name.contains("pen") || name.contains("PICASSO"))) {
                        connect(mContext, d);
                        break;
                    }
                }
            }
        } catch (SecurityException e) {
            Log.w(TAG, "SecurityException in ensureConnected", e);
        }
    }

    public synchronized void connect(Context context, BluetoothDevice device) {
        if (device == null) return;
        mContext = context.getApplicationContext();

        if (mGatt != null) {
            Log.d(TAG, "GATT already active or connecting");
            if (mCharac != null) {
                if (!mInitialized) {
                    sendInitSequence();
                }
                return;
            }
            disconnect();
        }

        Log.i(TAG, "Connecting GATT to pen: " + device.getAddress() + " (" + device.getName() + ")");
        mConnecting = true;
        mInitialized = false;
        try {
            mGatt = device.connectGatt(mContext, false, mGattCallback, BluetoothDevice.TRANSPORT_LE);
        } catch (SecurityException e) {
            Log.e(TAG, "SecurityException connecting GATT", e);
            mConnecting = false;
        }
    }

    public synchronized void disconnect() {
        Log.i(TAG, "Disconnecting GATT");
        mConnecting = false;
        mCharac = null;
        mInitialized = false;
        mWriteQueue.clear();
        mWriting = false;
        mHandler.removeCallbacks(mWriteTimeoutWatchdog);
        if (mGatt != null) {
            try {
                mGatt.disconnect();
                mGatt.close();
            } catch (Exception e) {
                Log.w(TAG, "Error closing GATT", e);
            }
            mGatt = null;
        }
    }

    public synchronized void wakeup() {
        if (mCharac != null && mGatt != null) {
            Log.i(TAG, "Re-sending pen activation command: [08 06 0d]");
            enqueueWrite(new byte[]{0x08, 0x06, 0x0d});
        }
    }

    public synchronized void sendTouchfilmMode(int mode) {
        if (mode == 0) {
            Log.i(TAG, "Setting Touchfilm Mode 0: [08 05]");
            enqueueWrite(new byte[]{0x08, 0x05});
        } else if (mode == 1) {
            Log.i(TAG, "Setting Touchfilm Mode 1: [08 04]");
            enqueueWrite(new byte[]{0x08, 0x04});
        }
    }

    public synchronized void sendInitSequence() {
        Log.i(TAG, "=== Sending stock ZUI verified pen activation command: [08 06 0d] ===");
        mWriteQueue.clear();
        mWriting = false;
        mHandler.removeCallbacks(mWriteTimeoutWatchdog);

        // Stock ZUI TB351FU HCI snoop capture verified: single [0x08, 0x06, 0x0d] command
        enqueueWrite(new byte[]{0x08, 0x06, 0x0d});

        mInitialized = true;
    }

    private synchronized void enqueueWrite(byte[] data) {
        mWriteQueue.offer(data);
        processQueue();
    }

    private synchronized void processQueue() {
        if (mWriting || mWriteQueue.isEmpty() || mGatt == null || mCharac == null) {
            return;
        }

        byte[] data = mWriteQueue.poll();
        if (data == null) return;

        mWriting = true;
        mHandler.removeCallbacks(mWriteTimeoutWatchdog);
        mHandler.postDelayed(mWriteTimeoutWatchdog, 250);

        try {
            int res;
            if (Build.VERSION.SDK_INT >= 33) {
                res = mGatt.writeCharacteristic(mCharac, data, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
            } else {
                mCharac.setValue(data);
                mCharac.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
                boolean ok = mGatt.writeCharacteristic(mCharac);
                res = ok ? 0 : -1;
            }
            StringBuilder sb = new StringBuilder();
            for (byte b : data) {
                sb.append(String.format("%02X ", b));
            }
            Log.i(TAG, "writeCharacteristic [" + sb.toString().trim() + "] return_code=" + res);
            if (res == 0) {
                // WRITE_TYPE_NO_RESPONSE completes asynchronously without onCharacteristicWrite on some BLE stacks
                mHandler.postDelayed(() -> {
                    synchronized (PenGattManager.this) {
                        mWriting = false;
                        mHandler.removeCallbacks(mWriteTimeoutWatchdog);
                        processQueue();
                    }
                }, 50);
            } else {
                mWriting = false;
                mHandler.removeCallbacks(mWriteTimeoutWatchdog);
                mHandler.postDelayed(this::processQueue, 50);
            }
        } catch (SecurityException e) {
            Log.e(TAG, "SecurityException writing characteristic", e);
            mWriting = false;
            mHandler.removeCallbacks(mWriteTimeoutWatchdog);
        }
    }

    private final BluetoothGattCallback mGattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            Log.i(TAG, "onConnectionStateChange status=" + status + " newState=" + newState);
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                mConnecting = false;
                Log.i(TAG, "GATT connected, discovering services in 300ms...");
                mHandler.postDelayed(() -> {
                    try {
                        gatt.discoverServices();
                    } catch (SecurityException e) {
                        Log.e(TAG, "SecurityException discovering services", e);
                    }
                }, 300);
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                synchronized (PenGattManager.this) {
                    mConnecting = false;
                    mCharac = null;
                    mInitialized = false;
                    mWriting = false;
                    mWriteQueue.clear();
                    mHandler.removeCallbacks(mWriteTimeoutWatchdog);
                }
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            Log.i(TAG, "onServicesDiscovered status=" + status);
            if (status == BluetoothGatt.GATT_SUCCESS) {
                BluetoothGattService service = gatt.getService(BTPEN_COMMON_SERVICE);
                if (service != null) {
                    BluetoothGattCharacteristic charac = service.getCharacteristic(BTPEN_COMMON_CHARACTERISTIC);
                    if (charac != null) {
                        Log.i(TAG, "Found Lenovo Common Characteristic (0000fe41)!");
                        synchronized (PenGattManager.this) {
                            mCharac = charac;
                        }

                        // Enable notification as done in stock BaseBluetoothPolicy.setCharacteristicNotificationInternal
                        try {
                            boolean notifSet = gatt.setCharacteristicNotification(charac, true);
                            Log.i(TAG, "setCharacteristicNotification returned " + notifSet);
                            BluetoothGattDescriptor desc = charac.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG);
                            if (desc != null) {
                                Log.i(TAG, "Writing CCCD descriptor 00002902 to enable notification...");
                                synchronized (PenGattManager.this) {
                                    mWriting = true;
                                }
                                mHandler.removeCallbacks(mWriteTimeoutWatchdog);
                                mHandler.postDelayed(mWriteTimeoutWatchdog, 500);

                                if (Build.VERSION.SDK_INT >= 33) {
                                    gatt.writeDescriptor(desc, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                                } else {
                                    desc.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                                    gatt.writeDescriptor(desc);
                                }
                            } else {
                                Log.w(TAG, "CCCD descriptor 00002902 not found on 0000fe41; sending init directly");
                                mHandler.postDelayed(() -> sendInitSequence(), 150);
                            }
                        } catch (SecurityException e) {
                            Log.e(TAG, "SecurityException enabling notification", e);
                            mHandler.postDelayed(() -> sendInitSequence(), 150);
                        }
                    } else {
                        Log.w(TAG, "Characteristic 0000fe41 not found in service 0000fe40");
                    }
                } else {
                    Log.w(TAG, "Lenovo Pen GATT service 0000fe40 not found. Services available:");
                    for (BluetoothGattService s : gatt.getServices()) {
                        Log.w(TAG, "  service: " + s.getUuid());
                        for (BluetoothGattCharacteristic c : s.getCharacteristics()) {
                            Log.w(TAG, "    char: " + c.getUuid());
                        }
                    }
                }
            }
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            Log.i(TAG, "onDescriptorWrite status=" + status + " (" + (status == BluetoothGatt.GATT_SUCCESS ? "SUCCESS" : "FAIL") + ")");
            synchronized (PenGattManager.this) {
                mWriting = false;
                mHandler.removeCallbacks(mWriteTimeoutWatchdog);
            }
            // Stock sleeps 150ms after descriptor write before sending commands
            mHandler.postDelayed(() -> sendInitSequence(), 150);
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            Log.i(TAG, "onCharacteristicWrite status=" + status + " (" + (status == BluetoothGatt.GATT_SUCCESS ? "SUCCESS" : "FAIL") + ")");
            synchronized (PenGattManager.this) {
                mWriting = false;
                mHandler.removeCallbacks(mWriteTimeoutWatchdog);
            }
            mHandler.post(PenGattManager.this::processQueue);
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            byte[] val = characteristic.getValue();
            if (val != null) {
                StringBuilder sb = new StringBuilder();
                for (byte b : val) {
                    sb.append(String.format("%02X ", b));
                }
                Log.i(TAG, "onCharacteristicChanged: [" + sb.toString().trim() + "]");
            }
        }
    };
}
