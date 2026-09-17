#!/system/bin/sh
# Xiaomi USB Security Bypass - late boot hook
#
# Runs after the system has finished booting, i.e. when `settings` (system_server)
# is reachable. post-fs-data.sh has normally already patched SecurityCenter's
# preferences before the app started; the same idempotent pass is repeated here
# so that a build which rewrites them from its own cloud cache still ends up with
# the switches enabled. The app is only restarted when a file really changed.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

apply_all
