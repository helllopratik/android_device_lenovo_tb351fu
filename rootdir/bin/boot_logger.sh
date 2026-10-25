#!/system/bin/sh
# Persistent boot logger for Lenovo Tab Plus 2024 (TB351FU)
# Captures kernel dmesg, logcat, properties, and process trees to /metadata/
# so logs survive reboots even when Android fails to boot to userspace.

LOGDIR="/metadata/bootlogs"
mkdir -p "$LOGDIR"
chmod 0777 "$LOGDIR"

echo "[$(date)] boot_logger started (PID: $$)" > "$LOGDIR/logger_status.txt"
sync

# 1. Early snapshots
dmesg > "$LOGDIR/dmesg_early.txt" 2>&1
getprop > "$LOGDIR/props_early.txt" 2>&1
sync

# 2. Archive pstore if available
if [ -d /sys/fs/pstore ]; then
    mkdir -p "$LOGDIR/pstore"
    cp -r /sys/fs/pstore/* "$LOGDIR/pstore/" 2>/dev/null
fi

# 3. Continuous logcat stream to file
logcat -b all -v threadtime -f "$LOGDIR/logcat.txt" &
LOGCAT_PID=$!
echo "logcat PID: $LOGCAT_PID" >> "$LOGDIR/logger_status.txt"

# 4. Periodic dmesg, prop, and process list refresh
(
    count=0
    while [ $count -lt 300 ]; do
        dmesg > "$LOGDIR/dmesg.txt" 2>&1
        getprop > "$LOGDIR/props.txt" 2>&1
        ps -A > "$LOGDIR/ps.txt" 2>&1
        sync
        count=$((count + 1))
        sleep 2
    done
) &

echo "[$(date)] boot_logger active and streaming" >> "$LOGDIR/logger_status.txt"
sync
