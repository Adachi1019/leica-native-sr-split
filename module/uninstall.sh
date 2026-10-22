#!/system/bin/sh
BUSYBOX=/data/adb/ksu/bin/busybox
[ -x "$BUSYBOX" ] || exit 1
if [ "${1:-}" != ash ]; then exec "$BUSYBOX" sh "$0" ash; fi
MODDIR=${0%/*}
. "$MODDIR/common.sh"
: > "$MODDIR/disable"
runtime_prepare || exit 1
exec 9> "$RUNTIME/service.lock"
"$BUSYBOX" flock 9 || exit 1
# Keep the tiny P1 JSON while any provider may still reference it.
restore_mount || true
echo 'Companion mount removed. Reboot to discard the private in-memory path.'
echo 'Original JSON cache and private P1 JSON retained; no photographs touched.'
