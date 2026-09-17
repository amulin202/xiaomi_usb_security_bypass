#!/system/bin/sh
# Xiaomi USB Security Bypass - Magisk "Action" button
#
# Re-applies everything (props + settings + SecurityCenter prefs) without a
# reboot. Use it right after MIUI flipped a switch back during its online
# Mi-account / SIM check: the log output shows up right in the Magisk app.

MODDIR=${0%/*}
. "$MODDIR/common.sh"

say "Xiaomi USB Security Bypass: re-applying switches..."

apply_all

say "props: adbinstall=$(getprop persist.security.adbinstall) adbinput=$(getprop persist.security.adbinput) fastboot=$(getprop persist.fastboot.enable)"
say "securitycenter prefs rewritten: $SC_PREFS_CHANGED"
say "done."
