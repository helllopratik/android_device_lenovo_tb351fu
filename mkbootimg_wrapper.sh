#!/bin/bash

# Execute the standard AOSP mkbootimg command with all arguments passed by the compiler
system/tools/mkbootimg/mkbootimg.py "$@"

# Find the output file from the arguments (e.g. --vendor_boot out/.../vendor_boot.img)
OUTPUT_FILE=""
for i in "${!@}"; do
    if [[ "${!i}" == "--vendor_boot" ]]; then
        next=$((i+1))
        OUTPUT_FILE="${!next}"
    fi
done

if [[ -n "$OUTPUT_FILE" && -f "$OUTPUT_FILE" ]]; then
    echo "=================================================="
    echo " MTK SPLICER: Intercepted vendor_boot.img!"
    echo " Grafting 4096-Byte Lenovo Factory Signature..."
    
    # Run the Python splicing logic inline
    python3 device/lenovo/tb351fu/splice_header.py "$OUTPUT_FILE"
    
    echo " MTK SPLICER: Ultimate Hijack Image generated!"
    echo "=================================================="
fi
