#!/bin/bash
OUT_DIR=$1
DEVICE_PATH=$2
MKBOOTIMG=$3
MKBOOTFS=$4
LZ4=$5

echo "=================================================="
echo " MTK SPLICER: Initiating Native Make Reconstruction..."

# 1. Repack the LineageOS Recovery Ramdisk securely
${MKBOOTFS} ${OUT_DIR}/recovery/root | ${LZ4} -l -12 --favor-decSpeed > ${OUT_DIR}/vendor_ramdisk_custom.cpio.lz4

# 2. Delete the broken Single-Fragment AOSP vendor_boot
rm -f ${OUT_DIR}/vendor_boot.img

# 3. Reconstruct the image with the Prebuilt MTK Fragment 0
${MKBOOTIMG} \
  --header_version 4 \
  --pagesize 4096 \
  --vendor_cmdline "bootopt=64S3,32N2,64N2 bootconfig" \
  --dtb ${DEVICE_PATH}/prebuilt/dtb.dtb \
  --vendor_bootconfig ${DEVICE_PATH}/prebuilt/bootconfig \
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
