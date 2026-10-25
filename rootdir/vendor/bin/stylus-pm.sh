#!/system/bin/sh
# Stylus power management - prevent Novatek touch controller autosuspend
# This keeps the pen connected by disabling power management on the touch controller

# Find and configure Novatek touch controller
for dev in /sys/bus/i2c/devices/*/name; do
    name=$(cat $dev 2>/dev/null)
    case "$name" in
        nt36*|NT36*|novatek*|Novatek*)
            dir=$(dirname $dev)
            echo "on" > $dir/power/control 2>/dev/null
            echo "enabled" > $dir/power/wakeup 2>/dev/null
            echo 0 > $dir/power/autosuspend_delay_ms 2>/dev/null
            log -t stylus "Disabled autosuspend for $name at $dir"
            ;;
    esac
done

for dev in /sys/bus/i2c/devices/*/i2c-dev/*/device/name; do
    [ -f "$dev" ] || continue
    name=$(cat $dev 2>/dev/null)
    case "$name" in
        nt36*|NT36*|novatek*|Novatek*)
            dir=$(dirname $dev)
            echo "on" > $dir/power/control 2>/dev/null
            ;;
    esac
done

# Find and configure Novatek touch controller on SPI (TB351FU has NT36523 on spi2.0)
for dev in /sys/bus/spi/devices/*/modalias; do
    [ -f "$dev" ] || continue
    alias=$(cat $dev 2>/dev/null)
    case "$alias" in
        *NVT*|*nvt*|*nt36*|*NT36*)
            dir=$(dirname $dev)
            echo "on" > $dir/power/control 2>/dev/null
            echo "enabled" > $dir/power/wakeup 2>/dev/null
            echo 0 > $dir/power/autosuspend_delay_ms 2>/dev/null
            log -t stylus "Disabled autosuspend for SPI device $alias at $dir"
            ;;
    esac
done

# Enable active stylus support and enhanced palm rejection in touch IC
if [ -f /proc/support_pen ]; then
    echo 1 > /proc/support_pen 2>/dev/null
    chmod 0666 /proc/support_pen 2>/dev/null
    log -t stylus "Enabled /proc/support_pen"
fi

if [ -f /proc/game_mode ]; then
    echo 1 > /proc/game_mode 2>/dev/null
    chmod 0666 /proc/game_mode 2>/dev/null
    log -t stylus "Enabled /proc/game_mode (enhanced palm rejection)"
fi

chmod 0666 /proc/fw_pen_state 2>/dev/null
chmod 0666 /proc/gesture_mode 2>/dev/null
chmod 0666 /dev/lenovo_penraw 2>/dev/null

# Enable Android native palm rejection flag in inputflinger and stock settings
device_config put input_native_boot palm_rejection_enabled 1 2>/dev/null
settings put system pen_dynamic_palm_rejection 1 2>/dev/null
settings put system key_pen_mode_disable_utouch 1 2>/dev/null
settings put system lenovo_pen_status 1 2>/dev/null

# Enable wakeup for all virtual input devices (stylus)
for dev in /sys/devices/virtual/input/input*/power; do
    [ -d "$dev" ] || continue
    echo "enabled" > $dev/wakeup 2>/dev/null
done

# Log found stylus input devices
for input in /dev/input/event*; do
    [ -c "$input" ] || continue
    name=$(cat /sys/class/input/$(basename $input)/device/name 2>/dev/null)
    case "$name" in
        *NVTCapacitivePen*|*Pen*|*Stylus*)
            log -t stylus "Found stylus input device: $input ($name)"
            ;;
    esac
done

# Ensure PenBridge has required runtime permissions and is running
pm grant com.lenovo.penbridge android.permission.BLUETOOTH_CONNECT 2>/dev/null
pm grant com.lenovo.penbridge android.permission.BLUETOOTH_SCAN 2>/dev/null
pm grant com.lenovo.penbridge android.permission.POST_NOTIFICATIONS 2>/dev/null
am start-foreground-service --user 0 com.lenovo.penbridge/.BridgeService 2>/dev/null
