#!/system/bin/sh
# Independent companion for one pinned build266 runtime, never edits the owner.
OWNER=/data/adb/modules/leica_camera_nezha28
RUNTIME=/data/adb/leica-stock-sr-266
INDEX_SHA=22daf2f33c58775815a4614e2b195aa9bf3bcc6c085eb4e23b7cb189a05a8056
SOURCE_SHA=a2be1f124b95c3af028f353d53557c669b64123e26eee828ef8b73de4a44e85f
PRIVATE=/data/vendor/lc/harbo.json
TARGET=/odm/etc/camera/harbo_sr_config.json
PROFILES='myron-os4040 pandora-os4020 pandora popsicle-os4020 popsicle pudding-os4020 pudding-os4040 pudding'

file_hash() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
valid_hash() { [ "${#1}" = 64 ] && case "$1" in *[!0-9a-f]*) return 1;; *) return 0;; esac; }
reason() { REASON=$1; return 1; }
expected() {
  awk -v file="$1" '$2==file {n++; h=$1} END {if(n==1) print h; else exit 1}' "$OWNER/runtime.sha256"
}
verify_owner_file() {
  [ -f "$OWNER/$1" ] && [ ! -L "$OWNER/$1" ] || return 1
  wanted=$(expected "$1") || return 1
  valid_hash "$wanted" && [ "$(file_hash "$OWNER/$1")" = "$wanted" ]
}
owner_supported() {
  REASON=owner-unverified
  [ -d "$OWNER" ] && [ ! -L "$OWNER" ] || return 1
  [ ! -f "$OWNER/disable" ] && [ ! -f "$OWNER/remove" ] || { reason owner-disabled; return 1; }
  [ ! -d /data/adb/modules_update/leica_camera_nezha28 ] || { reason owner-update-pending; return 1; }
  [ "$(sed -n 's/^versionCode=//p' "$OWNER/module.prop")" = 266 ] || { reason requires-build266; return 1; }
  [ "$(file_hash "$OWNER/runtime.sha256")" = "$INDEX_SHA" ] || { reason different-build266-runtime; return 1; }
  for entry in service.sh session.sh platform.sh root-runtime.sh harbo/harbo_sr_config.json; do
    verify_owner_file "$entry" || { reason "owner-file:$entry"; return 1; }
  done
  [ "$(file_hash "$OWNER/harbo/harbo_sr_config.json")" = "$SOURCE_SHA" ] || reason private-json-mismatch
}
runtime_prepare() {
  [ ! -L "$RUNTIME" ] || return 1
  mkdir -p "$RUNTIME" || return 1
  chmod 700 "$RUNTIME" || return 1
  umask 077
}
select_profile() {
  # $1 is a clean non-recursive bind of /odm. All matches must be unique.
  VIEW=$1
  CORE=$(file_hash "$VIEW/lib64/hw/camera.qcom.core.so")
  valid_hash "$CORE" || { reason missing-stock-core; return 1; }
  PROFILE=
  for candidate in $PROFILES; do
    verify_owner_file "profiles/$candidate/core.sha256" || { reason "profile-core-index:$candidate"; return 1; }
    known=$(cat "$OWNER/profiles/$candidate/core.sha256")
    valid_hash "$known" || { reason invalid-profile-core; return 1; }
    [ "$known" = "$CORE" ] || continue
    [ -z "$PROFILE" ] || { reason ambiguous-stock-core; return 1; }
    PROFILE=$candidate
  done
  [ -n "$PROFILE" ] || { reason unsupported-stock-core; return 1; }
  for entry in stock-config.sha256 stock-native.sha256 scripts/native.js; do
    verify_owner_file "profiles/$PROFILE/$entry" || { reason "profile-file:$entry"; return 1; }
  done
  STOCK_SHA=$(awk '$2=="harbo_sr_config.json" {n++; h=$1} END {if(n==1) print h; else exit 1}' "$OWNER/profiles/$PROFILE/stock-config.sha256") || { reason absent-stock-json-index; return 1; }
  valid_hash "$STOCK_SHA" || { reason invalid-stock-json-hash; return 1; }
  STOCK_FILE=$RUNTIME/stock/$PROFILE/$STOCK_SHA.json
  REASON=profile-verified
}
capture_stock() {
  owner_supported || return 1
  runtime_prepare || { reason runtime-directory; return 1; }
  VIEW=$RUNTIME/stock-view
  [ ! -L "$VIEW" ] || { reason stock-view-symlink; return 1; }
  mkdir -p "$VIEW" || return 1
  # A plain --bind does NOT carry /odm/etc/camera or /odm/lib64 child mounts.
  # Never use --rbind here: that would copy the owner's P1 overlay as "stock".
  if awk -v v="$VIEW" '$5==v {f=1} END{exit !f}' /proc/self/mountinfo; then
    reason stock-view-busy; return 1
  fi
  mount --bind /odm "$VIEW" || { reason stock-view-bind; return 1; }
  VIEW_ACTIVE=1
  result=0
  if ! mount -o remount,bind,ro "$VIEW"; then reason stock-view-readonly; result=1
  elif ! select_profile "$VIEW"; then result=1
  elif [ -L "$VIEW/etc/camera/harbo_sr_config.json" ] || [ "$(file_hash "$VIEW/etc/camera/harbo_sr_config.json")" != "$STOCK_SHA" ]; then
    reason stock-json-mismatch; result=1
  else
    # Do not replace any file unless this exact stock hash has been established.
    if [ -L "$RUNTIME/stock" ] || [ -L "$RUNTIME/stock/$PROFILE" ] || [ -L "$STOCK_FILE" ]; then
      reason stock-cache-symlink; result=1
    elif ! mkdir -p "$RUNTIME/stock/$PROFILE"; then result=1
    elif [ -f "$STOCK_FILE" ]; then
      [ "$(file_hash "$STOCK_FILE")" = "$STOCK_SHA" ] || { reason stock-cache-mismatch; result=1; }
    elif [ -e "$STOCK_FILE.tmp" ] || [ -L "$STOCK_FILE.tmp" ]; then
      reason stock-temp-exists; result=1
    else
      if cp "$VIEW/etc/camera/harbo_sr_config.json" "$STOCK_FILE.tmp" &&
         [ "$(file_hash "$STOCK_FILE.tmp")" = "$STOCK_SHA" ]; then
        mv "$STOCK_FILE.tmp" "$STOCK_FILE" || result=1
      else reason stock-copy-failed; result=1
      fi
    fi
    if [ "$result" = 0 ]; then
      chmod 644 "$STOCK_FILE" && chcon u:object_r:vendor_configs_file:s0 "$STOCK_FILE" || result=1
    fi
  fi
  if umount "$VIEW"; then VIEW_ACTIVE=0; else reason stock-view-unmount; result=1; fi
  rmdir "$VIEW" 2>/dev/null || true
  [ "$result" = 0 ] || return 1
  printf '%s\n%s\n%s\n' "$PROFILE" "$CORE" "$STOCK_SHA" > "$RUNTIME/selection.txt"
}
prepare_private() {
  private_dir=${PRIVATE%/*}
  [ ! -L "$private_dir" ] && [ ! -L "$PRIVATE" ] || return 1
  if [ ! -e "$private_dir" ]; then
    mkdir "$private_dir" || return 1
    chmod 755 "$private_dir" && chcon u:object_r:vendor_file:s0 "$private_dir" || return 1
  fi
  [ -d "$private_dir" ] || return 1
  if [ -e "$PRIVATE" ]; then
    [ -f "$PRIVATE" ] && [ "$(file_hash "$PRIVATE")" = "$SOURCE_SHA" ] || return 1
  else
    cp "$OWNER/harbo/harbo_sr_config.json" "$PRIVATE" || return 1
  fi
  chmod 644 "$PRIVATE" && chcon u:object_r:vendor_file:s0 "$PRIVATE"
}
owns_mount_in() {
  mountinfo "$1" | awk -v target="$TARGET" '$5==target && $4 ~ /\/leica-stock-sr-266\/stock\/[a-z0-9-]+\/[a-f0-9]+\.json$/ {f=1} END{exit !f}'
}
mountinfo() { cat "/proc/$1/mountinfo" 2>/dev/null; }
readonly_mount_in() {
  mountinfo "$1" | awk -v target="$TARGET" '$5==target && ($6=="ro" || $6 ~ /^ro,/) && $4 ~ /\/leica-stock-sr-266\/stock\/[a-z0-9-]+\/[a-f0-9]+\.json$/ {f=1} END{exit !f}'
}
owns_mount() { owns_mount_in self; }
restore_mount() { if owns_mount; then umount "$TARGET"; fi; }
helper() {
  CLASSPATH="$MODDIR/helper.jar" /system/bin/app_process /system/bin local.leica.sr.HarboPrivateConfig "$@" </dev/null
}
