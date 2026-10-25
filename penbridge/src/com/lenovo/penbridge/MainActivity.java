package com.lenovo.penbridge;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.View;
import android.widget.CompoundButton;
import android.widget.LinearLayout;
import android.widget.Switch;
import android.widget.TextView;

public final class MainActivity extends Activity {

    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private TextView mStatus;
    private final Runnable mRefresh = new Runnable() {
        @Override
        public void run() {
            refresh();
            mHandler.postDelayed(this, 2000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        startService(new Intent(this, BridgeService.class));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(20), dp(20), dp(20));

        TextView title = new TextView(this);
        title.setText("Lenovo Pen bridge");
        title.setTextSize(22);
        title.setPadding(0, 0, 0, dp(16));
        root.addView(title);

        mStatus = new TextView(this);
        mStatus.setTextSize(14);
        mStatus.setPadding(0, 0, 0, dp(16));
        root.addView(mStatus);

        root.addView(makeSwitch("Show pointer on hover",
                SettingsKeys.SECURE_SHOW_STYLUS_POINTER,
                "Draws a cursor while the pen hovers over the screen."));
        root.addView(makeSwitch("Accidental touch protection",
                SettingsKeys.SECURE_ANTI_ACCIDENTAL_TOUCH,
                "Ignore palm touches while writing with the pen. Synced with the pen app."));

        setContentView(root);
        mHandler.post(mRefresh);
    }

    private View makeSwitch(String label, final String key, String summary) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.VERTICAL);
        TextView t = new TextView(this);
        t.setText(label);
        t.setTextSize(17);
        final Switch s = new Switch(this);
        s.setText(summary);
        s.setChecked(Settings.Secure.getInt(getContentResolver(), key, 0) == 1);
        s.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                Settings.Secure.putInt(getContentResolver(), key, isChecked ? 1 : 0);
            }
        });
        row.addView(t);
        row.addView(s);
        row.setPadding(0, dp(10), 0, dp(10));
        return row;
    }

    private void refresh() {
        BridgeService svc = BridgeService.sInstance;
        StringBuilder sb = new StringBuilder();
        if (svc != null && svc.tracker() != null) {
            sb.append(svc.tracker().describedState()).append("\n");
        }
        if (svc != null && svc.penRaw() != null && svc.penRaw().have()) {
            PenRaw.Frame f = svc.penRaw().last();
            sb.append("pen surface: active, last frame ").append(f).append("\n");
        } else {
            sb.append("pen surface: idle (hover or write with the pen)\n");
        }
        sb.append("Hover pointer: ")
                .append(Settings.Secure.getInt(getContentResolver(),
                        SettingsKeys.SECURE_SHOW_STYLUS_POINTER, 0) == 1 ? "on" : "off");
        sb.append("\nPalm rejection: ")
                .append(Settings.Secure.getInt(getContentResolver(),
                        SettingsKeys.SECURE_ANTI_ACCIDENTAL_TOUCH, 0) == 1 ? "on" : "off");
        mStatus.setText(sb.toString());
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onDestroy() {
        mHandler.removeCallbacks(mRefresh);
        super.onDestroy();
    }
}