package com.lenovo.penbridge;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;

public final class HoverCursor {

    private static final String TAG = "HoverCursor";

    private static final int SIZE_DP = 28;
    private static final int HIDE_AFTER_MS = 150;

    private final Context mContext;
    private final WindowManager mWm;
    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private CursorView mView;
    private float mScaleX = 1f;
    private float mScaleY = 1f;

    private final Runnable mHide = new Runnable() {
        @Override
        public void run() {
            hideNow();
        }
    };

    private static final class CursorView extends View {
        private final Bitmap mArrow;

        CursorView(Context context, int px) {
            super(context);
            mArrow = makeArrow(px);
        }

        private static Bitmap makeArrow(int size) {
            Bitmap b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
            Canvas c = new Canvas(b);
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setStyle(Paint.Style.FILL);
            p.setColor(0xE6101010);
            float s = size;
            Path body = new Path();
            body.moveTo(0f, 0f);
            body.lineTo(s * 0.62f, 0.14f * s);
            body.lineTo(0.34f * s, 0.34f * s);
            body.lineTo(s * 0.14f, 0.62f * s);
            body.lineTo(0f, 0f);
            c.drawPath(body, p);
            p.setColor(0xFFE8E8E8);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(size * 0.05f);
            c.drawPath(body, p);
            return b;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            canvas.drawBitmap(mArrow, 0f, 0f, null);
        }
    }

    public HoverCursor(Context context) {
        mContext = context;
        mWm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
    }

    public void setCoordinateScale(long xMax, long yMax) {
        if (xMax > 0 && yMax > 0) {
            android.graphics.Point size = new android.graphics.Point();
            mWm.getDefaultDisplay().getRealSize(size);
            if (size.x > 0 && size.y > 0) {
                mScaleX = 10f * (float) size.x / (float) xMax;
                mScaleY = 10f * (float) size.y / (float) yMax;
                Log.i(TAG, "scale " + mScaleX + "x" + mScaleY + " (" + xMax + "x" + yMax + " -> " + size.x + "x" + size.y + ")");
            }
        }
    }

    private void ensureWindow(int initialX, int initialY) {
        if (mView != null)
            return;
        int dp = (int) (SIZE_DP * mContext.getResources().getDisplayMetrics().density);
        mView = new CursorView(mContext, dp);
        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                dp, dp,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.START;
        lp.x = initialX;
        lp.y = initialY;
        try {
            mWm.addView(mView, lp);
        } catch (Exception e) {
            Log.w(TAG, "addView with TYPE_APPLICATION_OVERLAY failed, trying TYPE_INTERNAL_SYSTEM_WINDOW", e);
            lp.type = 2003; // WindowManager.LayoutParams.TYPE_INTERNAL_SYSTEM_WINDOW
            try {
                mWm.addView(mView, lp);
            } catch (Exception e2) {
                Log.e(TAG, "addView failed completely", e2);
                mView = null;
            }
        }
    }

    public synchronized void update(PenRaw.Frame f) {
        if (!enabled() || f == null || f.status < 0 || f.p > 0 || f.ageMs >= HIDE_AFTER_MS) {
            hideNow();
            return;
        }

        int x = (int) (f.x * mScaleX);
        int y = (int) (f.y * mScaleY);

        if (mView == null) {
            ensureWindow(x, y);
        } else {
            WindowManager.LayoutParams lp = (WindowManager.LayoutParams) mView.getLayoutParams();
            if (lp != null && (lp.x != x || lp.y != y)) {
                lp.x = x;
                lp.y = y;
                try {
                    mWm.updateViewLayout(mView, lp);
                } catch (Exception e) {
                    Log.e(TAG, "updateViewLayout failed", e);
                }
            }
        }

        mHandler.removeCallbacks(mHide);
        mHandler.postDelayed(mHide, HIDE_AFTER_MS);
    }

    public synchronized void hideNow() {
        mHandler.removeCallbacks(mHide);
        if (mView != null) {
            try {
                mWm.removeView(mView);
            } catch (Exception ignored) {
            }
            mView = null;
        }
    }

    public boolean enabled() {
        String lenovo = Settings.Global.getString(mContext.getContentResolver(),
                SettingsKeys.GLOBAL_STYLUS_CHANGE_ICON);
        if (lenovo != null && !lenovo.trim().isEmpty()) {
            return "1:1".equals(lenovo) || "0:1".equals(lenovo) || lenovo.endsWith(":1");
        }
        return Settings.Secure.getInt(mContext.getContentResolver(),
                SettingsKeys.SECURE_SHOW_STYLUS_POINTER, 0) == 1;
    }

    public synchronized void destroy() {
        hideNow();
    }
}