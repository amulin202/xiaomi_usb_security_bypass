#!/system/bin/sh
# Module installer - ensure scripts are executable
chmod 0755 "$MODPATH/service.sh" 2>/dev/null || true
chmod 0755 "$MODPATH/system.prop" 2>/dev/null || true
