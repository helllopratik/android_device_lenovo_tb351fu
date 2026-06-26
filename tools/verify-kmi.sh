#!/bin/sh

set -eu

DEVICE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ANDROID_ROOT=$(CDPATH= cd -- "$DEVICE_DIR/../../.." && pwd)

KERNEL=${1:-$DEVICE_DIR/prebuilt/kernel}
MODULE_DIR=${2:-$ANDROID_ROOT/vendor/lenovo/tb351fu/proprietary/vendor_dlkm/lib/modules}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

kmi_from_release() {
    printf '%s\n' "$1" | sed -nE 's/^([0-9]+\.[0-9]+)\.[0-9]+-(android[0-9]+-[0-9]+)-.*/\1-\2/p'
}

[ -f "$KERNEL" ] || fail "kernel not found: $KERNEL"
[ -d "$MODULE_DIR" ] || fail "module directory not found: $MODULE_DIR"
command -v strings >/dev/null 2>&1 || fail "strings is required"
command -v modinfo >/dev/null 2>&1 || fail "modinfo is required"

KERNEL_RELEASE=$(strings "$KERNEL" | sed -nE 's/.*Linux version ([^ ]+).*/\1/p' | head -n 1)
[ -n "$KERNEL_RELEASE" ] || fail "could not read Linux version from $KERNEL"
KERNEL_KMI=$(kmi_from_release "$KERNEL_RELEASE")
[ -n "$KERNEL_KMI" ] || fail "could not parse KMI from kernel release: $KERNEL_RELEASE"

MODULE_COUNT=0
MISMATCH_COUNT=0

for module in "$MODULE_DIR"/*.ko; do
    [ -e "$module" ] || fail "no .ko files found in $MODULE_DIR"
    MODULE_COUNT=$((MODULE_COUNT + 1))
    MODULE_RELEASE=$(modinfo -F vermagic "$module" 2>/dev/null | sed -n '1{s/ .*//;p;}')
    if [ -z "$MODULE_RELEASE" ]; then
        printf 'error: no vermagic: %s\n' "$module" >&2
        MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
        continue
    fi
    MODULE_KMI=$(kmi_from_release "$MODULE_RELEASE")
    if [ "$MODULE_KMI" != "$KERNEL_KMI" ]; then
        printf 'error: KMI mismatch: %s (%s)\n' "$module" "$MODULE_RELEASE" >&2
        MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
    fi
done

printf 'kernel release: %s\n' "$KERNEL_RELEASE"
printf 'kernel KMI:     %s\n' "$KERNEL_KMI"
printf 'modules:        %s checked\n' "$MODULE_COUNT"

[ "$MISMATCH_COUNT" -eq 0 ] || fail "$MISMATCH_COUNT module(s) are incompatible"

printf 'result:         compatible KMI\n'
