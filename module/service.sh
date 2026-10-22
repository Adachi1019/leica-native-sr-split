#!/system/bin/sh
BUSYBOX=/data/adb/ksu/bin/busybox
[ -x "$BUSYBOX" ] || exit 1
if [ "${1:-}" != ash ]; then exec "$BUSYBOX" sh "$0" ash; fi
MODDIR=${0%/*}
. "$MODDIR/common.sh"
runtime_prepare || exit 1
exec >> "$RUNTIME/service.log" 2>&1
exec 9> "$RUNTIME/service.lock"
"$BUSYBOX" flock -n 9 || exit 0
echo waiting-owner > "$RUNTIME/status"
cleanup() {
  if [ "${VIEW_ACTIVE:-0}" = 1 ]; then umount "$VIEW" || true; fi
  restore_mount || true
  case "$(cat "$RUNTIME/status" 2>/dev/null)" in ready:*|waiting-*) echo stopped > "$RUNTIME/status";; esac
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM
if ! capture_stock; then echo "unsupported:$REASON" > "$RUNTIME/status"; exit 1; fi
last=
while [ -d "$MODDIR" ] && [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ]; do
  if ! owner_supported; then echo "unsupported:$REASON" > "$RUNTIME/status"; exit 1; fi
  pid=$(pidof vendor.qti.camera.provider-service_64)
  case "$pid" in ''|*[!0-9]*) sleep 3; continue;; esac
  ticks=$(awk '{print $22}' "/proc/$pid/stat")
  generation=$pid:$ticks
  if [ "$(getprop sys.leica_camera.runtime)" != "ready:$pid" ] || [ "$(getprop sys.leica_camera.guard)" != ready ]; then
    echo "waiting-owner:$generation" > "$RUNTIME/status"
    sleep 3; continue
  fi
  if [ "$last" != "$generation" ] || ! owns_mount || ! readonly_mount_in self; then
    echo "checking:$generation:$PROFILE" > "$RUNTIME/status"
    if [ "$(file_hash "$STOCK_FILE")" != "$STOCK_SHA" ]; then echo rejected-stock-cache > "$RUNTIME/status"; exit 1; fi
    if ! helper --check "$pid" "$ticks" || ! prepare_private; then
      echo "rejected-private-sdk:$generation" > "$RUNTIME/status"; exit 1
    fi
    current=$(file_hash "$TARGET")
    if [ "$current" != "$SOURCE_SHA" ] && [ "$current" != "$STOCK_SHA" ]; then
      echo rejected-unknown-global-json > "$RUNTIME/status"; exit 1
    fi
    if ! helper --apply "$pid" "$ticks"; then echo rejected-private-path > "$RUNTIME/status"; exit 1; fi
    if ! owns_mount; then
      if ! mount --bind "$STOCK_FILE" "$TARGET"; then
        echo failed-stock-mount > "$RUNTIME/status"; exit 1
      fi
    fi
    if ! mount -o remount,bind,ro "$TARGET"; then echo failed-readonly-mount > "$RUNTIME/status"; exit 1; fi
    if ! readonly_mount_in "$pid" || [ "$(file_hash "/proc/$pid/root$TARGET")" != "$STOCK_SHA" ]; then
      echo "failed-provider-namespace:$generation" > "$RUNTIME/status"; exit 1
    fi
    if [ "$(pidof vendor.qti.camera.provider-service_64)" != "$pid" ] || [ "$(awk '{print $22}' "/proc/$pid/stat")" != "$ticks" ]; then
      sleep 3; continue
    fi
    helper --verify-relocated "$pid" "$ticks" || { echo failed-private-readback > "$RUNTIME/status"; exit 1; }
    echo "ready:$generation:$PROFILE:stock-native+private-p1" > "$RUNTIME/status"
    echo "READY profile=$PROFILE provider=$generation stock=$STOCK_SHA"
    last=$generation
  fi
  ready="ready:$generation:$PROFILE:stock-native+private-p1"
  [ "$(cat "$RUNTIME/status")" = "$ready" ] || echo "$ready" > "$RUNTIME/status"
  sleep 3
done
