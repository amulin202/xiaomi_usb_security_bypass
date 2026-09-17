#!/system/bin/sh
# Module installer - make the scripts executable after Magisk unpacks the zip
chmod 0755 "$MODPATH/service.sh" 2>/dev/null || true
chmod 0755 "$MODPATH/post-fs-data.sh" 2>/dev/null || true
chmod 0755 "$MODPATH/action.sh" 2>/dev/null || true
chmod 0644 "$MODPATH/common.sh" 2>/dev/null || true
chmod 0644 "$MODPATH/system.prop" 2>/dev/null || true
