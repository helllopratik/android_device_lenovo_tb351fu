#!/bin/bash
#
# Copyright (C) 2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=TB351FU
VENDOR=lenovo

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true

# Extract the device-specific blobs
extract "${MY_DIR}/proprietary-files.txt" "/home/hellopratik/Desktop/new_updated/TB351FU_ROW_OPEN_USER_M15125.2_A16_ZUI_17.5.10.073_ST_260213/LineageOS_Build/system_dump" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
