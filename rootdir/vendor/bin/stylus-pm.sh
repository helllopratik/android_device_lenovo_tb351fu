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
