#!/system/bin/sh
while true; do
    pkill -9 watchdogd
    sleep 5
done
