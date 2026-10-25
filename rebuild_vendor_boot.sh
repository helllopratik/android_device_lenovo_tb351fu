#!/bin/bash
OUT_DIR=$1
DEVICE_PATH=$2
MKBOOTIMG=$3
MKBOOTFS=$4
LZ4=$5

echo "=================================================="
echo " MTK SPLICER: Initiating Native Make Reconstruction..."

# 1. Repack the LineageOS Recovery Ramdisk (enforce ADB authentication)
REC_SRC="${DEVICE_PATH}/prebuilt/recovery_ramdisk"
if [ ! -d "$REC_SRC" ]; then
    REC_SRC="${OUT_DIR}/recovery/root"
fi
sed -i 's/ro.adb.secure=0/ro.adb.secure=1/g' ${REC_SRC}/prop.default 2>/dev/null || true
grep -q "ro.adb.secure=1" ${REC_SRC}/prop.default || echo "ro.adb.secure=1" >> ${REC_SRC}/prop.default
# Remove conflicting AOSP default boot HAL manifest fragment to resolve servicemanager VINTF parse error
rm -f ${REC_SRC}/system/etc/vintf/manifest/android.hardware.boot-service.default.xml
# TB351FU: wait up to 60s for the DRM panel (card0 registers ~30s into recovery boot)
sed -i '/ro.recovery.ui.graphics_timeout_ms/d' ${REC_SRC}/prop.default 2>/dev/null || true
echo "ro.recovery.ui.graphics_timeout_ms=60000" >> ${REC_SRC}/prop.default
${MKBOOTFS} ${REC_SRC} | ${LZ4} -l -9 > ${OUT_DIR}/vendor_ramdisk_custom.cpio.lz4

# 2. Prepare bootconfig
cp ${DEVICE_PATH}/prebuilt/bootconfig ${OUT_DIR}/vendor_bootconfig_custom
grep -q "androidboot.selinux" ${OUT_DIR}/vendor_bootconfig_custom || echo "androidboot.selinux=permissive" >> ${OUT_DIR}/vendor_bootconfig_custom


# 3. Reconstruct the image with the Prebuilt MTK Fragment 0
rm -f ${OUT_DIR}/vendor_boot.img
${MKBOOTIMG} \
  --header_version 4 \
  --pagesize 4096 \
  --vendor_cmdline "bootopt=64S3,32N2,64N2 bootconfig" \
  --dtb ${DEVICE_PATH}/prebuilt/dtb.dtb \
  --vendor_bootconfig ${OUT_DIR}/vendor_bootconfig_custom \
  --ramdisk_type platform --ramdisk_name "" --vendor_ramdisk_fragment ${DEVICE_PATH}/prebuilt/vendor_ramdisk00 \
  --ramdisk_type recovery --ramdisk_name "recovery" --vendor_ramdisk_fragment ${OUT_DIR}/vendor_ramdisk_custom.cpio.lz4 \
  --vendor_boot ${OUT_DIR}/vendor_boot.img

# 4. Splice the Lenovo 4096-Byte Signature
python3 ${DEVICE_PATH}/splice_header.py ${OUT_DIR}/vendor_boot.img

# 5. Add AVB Hash Footer for vbmeta compliance
out/host/linux-x86/bin/avbtool add_hash_footer \
  --image ${OUT_DIR}/vendor_boot.img \
  --partition_name vendor_boot \
  --partition_size 67108864 \
  --algorithm SHA256_RSA4096 \
  --key external/avb/test/data/testkey_rsa4096.pem

echo " MTK SPLICER: Perfect vendor_boot generation complete!"
echo "=================================================="
