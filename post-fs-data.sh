#!/system/bin/sh
# Xiaomi USB Security Bypass - early boot hook
#
# post-fs-data runs after /data is mounted but before zygote and every app
# process start. That makes it the safe moment to rewrite SecurityCenter's
# shared_prefs: nothing has the file open yet, so the patched values are the
# ones the app loads when it starts - no restart and no UI flicker needed.
#
# Only the preference layer is handled here. The props come from system.prop
# (applied by Magisk at the same stage) and the settings rows need system_server,
# so those live in service.sh.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

# /data/data/<pkg> can appear a moment after post-fs-data on some builds.
i=0
while [ ! -d "$SC_PREFS_DIR" ] && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done

patch_sc_prefs_all
log_i "post-fs-data: prefs_rewritten=$SC_PREFS_CHANGED"
