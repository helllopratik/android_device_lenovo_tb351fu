#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#  ota_wrapper.sh — Redirect huge OTA temp files to HDD partition
#  Lenovo Tab Plus 2024 (tb351fu)
# ═══════════════════════════════════════════════════════════════════════════
set -e

# Redirect multi-GB OTA packaging temporary payload to HDD (/mnt/HDD/tmp)
# which has 120+ GB free, preventing "no space left on device" on NVMe.
export TMPDIR="/mnt/HDD/tmp"
mkdir -p "$TMPDIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

REAL_BIN="$TOP_DIR/out/host/linux-x86/bin/ota_from_target_files"

if [ ! -x "$REAL_BIN" ]; then
    echo "ERROR: ota_from_target_files not found or not executable at: $REAL_BIN" >&2
    exit 1
fi

echo "====================================================================="
echo "[tb351fu] Packaging OTA update with redirected TMPDIR=$TMPDIR"
echo "====================================================================="

exec "$REAL_BIN" "$@"
