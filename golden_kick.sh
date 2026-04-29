#!/system/bin/sh
exec > /dev/kmsg 2>&1
echo "V27: Golden Hardware Kickstart..."
sleep 5

# 1. Start Battery/Health
start health-hal-2-1

# 2. Bind Touch Manifest (v8.0)
mkdir -p /tmp/vintf
cat << 'EOF' > /tmp/vintf/manifest.xml
<manifest version="8.0" type="device">
    <hal format="aidl">
        <name>android.hardware.health</name>
        <version>4</version>
        <fqname>IHealth/default</fqname>
    </hal>
    <hal format="aidl">
        <name>vendor.lenovo.hardware.touchscreen</name>
        <version>2</version>
        <fqname>ITouchscreen/default</fqname>
    </hal>
</manifest>
EOF
mount --bind /tmp/vintf/manifest.xml /vendor/etc/vintf/manifest.xml

# 3. Start Touch
start touchscreen_hal_service
echo "V27: Hardware Ready."
