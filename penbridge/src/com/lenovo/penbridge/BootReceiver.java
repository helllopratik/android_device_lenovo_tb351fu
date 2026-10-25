package com.lenovo.penbridge;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Log.i("PenBridge", "boot received");
        try {
            context.startForegroundService(new Intent(context, BridgeService.class));
        } catch (Exception e) {
            Log.w("PenBridge", "start on boot failed", e);
        }
    }
}