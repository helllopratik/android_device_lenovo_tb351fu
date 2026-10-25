#include <jni.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <string.h>
#include <errno.h>

#define PENRAW_DEVICE "/dev/lenovo_penraw"

/* ioctl: _IOR('P', 0, struct io_pen_report), report size = 648 bytes
   (4-byte header + pad to 8 + 16 x 40-byte lenovo_pen_info frames) */
#define PENRAW_REPORT_SIZE 648
/* Prefix to avoid clashing with bionic's kernel-uapi _IOC/_IOR macros, whose
   size argument goes through _IOC_TYPECHECK (sizeof) — not what the driver
   expects for a raw 648-byte report. */
#define PENRAW_IOC(dir, type, nr, size) (((dir) << 30) | ((type) << 8) | (nr) | ((size) << 16))
#define PENRAW_IOC_READ 2
#define PENRAW_IOR(type, nr, size) PENRAW_IOC(PENRAW_IOC_READ, (type), (nr), (size))
#define PENRAW_GET_VALUES PENRAW_IOR('P', 0, PENRAW_REPORT_SIZE)

static int g_fd = -1;

static jint nativeOpen(JNIEnv *env, jclass clazz) {
    (void)env; (void)clazz;
    if (g_fd >= 0)
        return g_fd;
    g_fd = open(PENRAW_DEVICE, O_RDONLY | O_CLOEXEC);
    return g_fd;
}

static jint nativeClose(JNIEnv *env, jclass clazz) {
    (void)env; (void)clazz;
    if (g_fd >= 0) {
        close(g_fd);
        g_fd = -1;
    }
    return 0;
}

static jint nativeGetValues(JNIEnv *env, jclass clazz, jbyteArray out) {
    (void)clazz;
    jsize cap = (*env)->GetArrayLength(env, out);
    if (g_fd < 0 || cap < PENRAW_REPORT_SIZE)
        return -1;
    unsigned char buf[PENRAW_REPORT_SIZE];
    memset(buf, 0, sizeof(buf));
    if (ioctl(g_fd, PENRAW_GET_VALUES, buf) < 0)
        return -errno;
    (*env)->SetByteArrayRegion(env, out, 0, PENRAW_REPORT_SIZE, (const jbyte *)buf);
    return (jint)buf[0];
}

static const JNINativeMethod gMethods[] = {
    {"nativeOpen",       "()I",   (void *)nativeOpen},
    {"nativeClose",      "()I",   (void *)nativeClose},
    {"nativeGetValues",  "([B)I", (void *)nativeGetValues},
};

jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    (void)reserved;
    JNIEnv *env = NULL;
    if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_6) != JNI_OK)
        return JNI_ERR;
    jclass clazz = (*env)->FindClass(env, "com/lenovo/penbridge/PenRaw");
    if (clazz == NULL)
        return JNI_ERR;
    if ((*env)->RegisterNatives(env, clazz, gMethods, 3) != 0)
        return JNI_ERR;
    return JNI_VERSION_1_6;
}