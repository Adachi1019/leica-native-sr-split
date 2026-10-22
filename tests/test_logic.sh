#!/bin/sh
set -eu
# MinGit on Windows does not include the full Unix coreutils set.
# These wrappers operate on host test fixtures only, never on Android.
if ! command -v sed >/dev/null 2>&1; then sed() { "$PYTHON_EXE" "$HOST_TOOLS" sed "$@"; }; fi
if ! command -v cat >/dev/null 2>&1; then cat() { "$PYTHON_EXE" "$HOST_TOOLS" cat "$@"; }; fi
if ! command -v cp >/dev/null 2>&1; then cp() { "$PYTHON_EXE" "$HOST_TOOLS" cp "$@"; }; fi
. module/common.sh
OWNER=$PWD/build/fixtures/owner
RUNTIME=$PWD/build/fixtures/runtime
file_hash() { "$PYTHON_EXE" "$HASH_HELPER" "$1"; }
INDEX_SHA=$(file_hash "$OWNER/runtime.sha256")
SOURCE_SHA=$(file_hash "$OWNER/harbo/harbo_sr_config.json")
owner_supported
for profile in $PROFILES; do
  select_profile "$PWD/build/fixtures/views/$profile"
  [ "$PROFILE" = "$profile" ]
  [ "$STOCK_SHA" = "$(file_hash "$PWD/build/fixtures/views/$profile/etc/camera/harbo_sr_config.json")" ]
done
echo 'PASS: all eight profiles select their own core and stock JSON hash'
for version in 229 248 254 265 267; do
  printf 'versionCode=%s\n' "$version" > "$OWNER/module.prop"
  if owner_supported; then echo 'FAIL: version accepted'; exit 1; fi
  [ "$REASON" = requires-build266 ]
done
printf 'versionCode=266\n' > "$OWNER/module.prop"
owner_supported
echo 'PASS: non-266 versions rejected before applying any changes'
cp "$OWNER/runtime.sha256" "$OWNER/runtime.sha256.saved"
printf '# tampered\n' >> "$OWNER/runtime.sha256"
if owner_supported; then echo 'FAIL: modified runtime accepted'; exit 1; fi
[ "$REASON" = different-build266-runtime ]
cp "$OWNER/runtime.sha256.saved" "$OWNER/runtime.sha256"
echo 'PASS: modified runtime manifest rejected'
selected=pandora
file=$OWNER/profiles/$selected/scripts/native.js
cp "$file" "$file.saved"
printf '// tampered\n' >> "$file"
if select_profile "$PWD/build/fixtures/views/$selected"; then echo 'FAIL: modified profile accepted'; exit 1; fi
cp "$file.saved" "$file"
echo 'PASS: modified profile script rejected'
file=$PWD/build/fixtures/views/pandora/lib64/hw/camera.qcom.core.so
cp "$file" "$file.saved"
printf 'unknown core' > "$file"
if select_profile "$PWD/build/fixtures/views/pandora"; then echo 'FAIL: unknown core accepted'; exit 1; fi
[ "$REASON" = unsupported-stock-core ]
cp "$file.saved" "$file"
echo 'PASS: unknown original camera core rejected'
file=$OWNER/profiles/pudding/core.sha256
cp "$file" "$file.saved"
cp "$OWNER/profiles/pandora/core.sha256" "$file"
"$PYTHON_EXE" "$REINDEX_HELPER" "$OWNER"
INDEX_SHA=$(file_hash "$OWNER/runtime.sha256")
if select_profile "$PWD/build/fixtures/views/pandora"; then echo 'FAIL: ambiguous core accepted'; exit 1; fi
[ "$REASON" = ambiguous-stock-core ]
cp "$file.saved" "$file"
cp "$OWNER/runtime.sha256.saved" "$OWNER/runtime.sha256"
INDEX_SHA=$(file_hash "$OWNER/runtime.sha256")
owner_supported
echo 'PASS: ambiguous profile core rejected'
mountinfo() { printf '%s\n' "$FIXTURE_MOUNTINFO"; }
FIXTURE_MOUNTINFO="45 2 254:52 /adb/leica-stock-sr-266/stock/pandora/012345abcdef.json $TARGET rw,noatime - f2fs /dev/fixture rw"
owns_mount
if readonly_mount_in self; then echo 'FAIL: writable bind treated as readonly'; exit 1; fi
echo 'PASS: writable owned bind remains identifiable for failure cleanup'
FIXTURE_MOUNTINFO="45 2 254:52 /adb/leica-stock-sr-266/stock/pandora/012345abcdef.json $TARGET ro,noatime - f2fs /dev/fixture rw"
readonly_mount_in self
FIXTURE_MOUNTINFO="45 2 254:52 /adb/other-module/stock.json $TARGET ro,noatime - f2fs /dev/fixture rw"
if owns_mount; then echo 'FAIL: foreign bind treated as owned'; exit 1; fi
echo 'PASS: readonly ownership checked and foreign module bind rejected'

# A first installation on another phone must not depend on an older repair.
PRIVATE=$PWD/build/fixtures/first-install-private/harbo.json
chcon() { return 0; }
chmod() { return 0; } # Windows host has no Android ownership/SELinux semantics.
prepare_private
[ "$(file_hash "$PRIVATE")" = "$SOURCE_SHA" ]
prepare_private
printf 'foreign config' > "$PRIVATE"
if prepare_private; then echo 'FAIL: foreign private JSON overwritten'; exit 1; fi
echo 'PASS: fresh-device private directory created and foreign JSON rejected'
