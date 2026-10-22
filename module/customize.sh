#!/system/bin/sh
[ "${KSU:-false}" = true ] || abort 'This companion build requires KernelSU.'
MODDIR=$MODPATH
. "$MODPATH/common.sh"
(cd "$MODPATH" && sha256sum -c files.sha256 >/dev/null) || abort 'Companion checksum mismatch.'
owner_supported || abort "Requires the pinned Leica 0.266 runtime: $REASON"
capture_stock || abort "Device stock SR configuration rejected: $REASON"
set_perm_recursive "$MODPATH" 0 0 0755 0644
for file in post-fs-data.sh service.sh action.sh uninstall.sh; do set_perm "$MODPATH/$file" 0 0 0755; done
ui_print "- Detected device: $(getprop ro.product.device)"
ui_print "- Automatically selected build266 patch profile: $PROFILE"
ui_print '- Captured this device original SR JSON; no bundled 17 Pro JSON is used.'
ui_print '- Keep Leica 0.266 enabled. Reboot and unlock to activate.'
ui_print '- This multi-profile candidate requires photo validation on each device.'
