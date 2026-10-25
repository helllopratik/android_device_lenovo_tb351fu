package com.lenovo.penbridge;

import android.util.Log;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public final class PenRaw {

    private static final String TAG = "PenRaw";

    public static final int REPORT_SIZE = 648;
    public static final int MAX_REPORTS = 16;

    public static final int FRAME_OFFSET = 8;
    public static final int FRAME_STRIDE = 40;

    private static boolean sLibraryLoaded = false;
    static {
        try {
            System.loadLibrary("penraw_jni");
            sLibraryLoaded = true;
        } catch (Throwable t) {
            Log.w(TAG, "libpenraw_jni not loaded: " + t.getMessage());
            sLibraryLoaded = false;
        }
    }

    public static final class Frame {
        public int frameNo;
        public int dataType;
        public int frameT;
        public int status;
        public int toolType;
        public int tiltX;
        public int tiltY;
        public long x;
        public long y;
        public long p;
        public long ageMs;

        public boolean active() {
            return p > 0;
        }

        @Override
        public String toString() {
            return "Frame{s=" + status + " x=" + x + " y=" + y + " p=" + p
                    + " t=" + frameT + " tilt=(" + tiltX + "," + tiltY + ")}";
        }
    }

    private static native int nativeOpen();

    private static native int nativeClose();

    private static native int nativeGetValues(byte[] out);

    private int mFd = -1;
    private final byte[] mBuf = new byte[REPORT_SIZE];
    private Frame mLast = new Frame();
    private boolean mHave = false;
    private long mLastReadMs = 0;

    public synchronized boolean open() {
        if (!sLibraryLoaded)
            return false;
        if (mFd >= 0)
            return true;
        try {
            mFd = nativeOpen();
            if (mFd < 0) {
                Log.w(TAG, "open /dev/lenovo_penraw failed fd=" + mFd);
                return false;
            }
            Log.i(TAG, "penraw opened fd=" + mFd);
            return true;
        } catch (Throwable t) {
            Log.w(TAG, "nativeOpen failed: " + t.getMessage());
            return false;
        }
    }

    public synchronized void close() {
        if (!sLibraryLoaded)
            return;
        if (mFd >= 0) {
            try {
                nativeClose();
            } catch (Throwable ignored) {
            }
            mFd = -1;
        }
    }

    public synchronized void poll() {
        if (!sLibraryLoaded || mFd < 0)
            return;
        int num = nativeGetValues(mBuf);
        if (num < 0) {
            Log.e(TAG, "ioctl failed err=" + num);
            return;
        }
        if (num <= 0)
            return;
        ByteBuffer b = ByteBuffer.wrap(mBuf).order(ByteOrder.LITTLE_ENDIAN);
        int n = Math.min(num, MAX_REPORTS);
        Frame f = null;
        for (int i = 0; i < n; i++) {
            int base = FRAME_OFFSET + i * FRAME_STRIDE;
            Frame fr = new Frame();
            fr.frameNo = b.get(base) & 0xff;
            fr.dataType = b.get(base + 1) & 0xff;
            fr.frameT = b.getShort(base + 2) & 0xffff;
            fr.status = b.get(base + 8);
            fr.toolType = b.get(base + 9);
            fr.tiltX = b.get(base + 10);
            fr.tiltY = b.get(base + 11);
            fr.x = b.getLong(base + 16);
            fr.y = b.getLong(base + 24);
            fr.p = b.getLong(base + 32);
            f = fr;
        }
        if (f != null) {
            if (!mHave) {
                mLast = f;
                mHave = true;
                mLastReadMs = 0;
            } else if (f.frameNo != mLast.frameNo || f.frameT != mLast.frameT) {
                mLast = f;
                mLastReadMs = android.os.SystemClock.uptimeMillis();
            }
        }
    }

    public synchronized Frame last() {
        if (!mHave || mLastReadMs == 0) {
            Frame e = new Frame();
            e.status = -1;
            e.ageMs = Long.MAX_VALUE;
            return e;
        }
        return lastInto(new Frame());
    }

    public synchronized Frame lastInto(Frame out) {
        if (!mHave || mLastReadMs == 0) {
            out.status = -1;
            out.ageMs = Long.MAX_VALUE;
            return out;
        }
        out.frameNo = mLast.frameNo;
        out.dataType = mLast.dataType;
        out.frameT = mLast.frameT;
        out.status = mLast.status;
        out.toolType = mLast.toolType;
        out.tiltX = mLast.tiltX;
        out.tiltY = mLast.tiltY;
        out.x = mLast.x;
        out.y = mLast.y;
        out.p = mLast.p;
        out.ageMs = android.os.SystemClock.uptimeMillis() - mLastReadMs;
        return out;
    }

    public synchronized boolean have() {
        return mHave && mLastReadMs != 0;
    }
}