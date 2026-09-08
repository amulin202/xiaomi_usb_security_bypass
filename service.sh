#!/system/bin/sh
# Xiaomi USB Security Bypass - boot script
# Enables (without Mi account / SIM):
#   - USB debugging (Security settings)  -> persist.security.adbinput
#   - Install via USB                    -> persist.security.adbinstall
#   - FASTBOOT flashing mode             -> persist.fastboot.enable
#
# These props normally need the developer-options toggle, which on MIUI
# requires an online Mi-account + SIM verification. On a rooted device we
# simply force the underlying persist props to 1 at every boot.
# If SELinux blocks setprop (context u:object_r:system_prop), fall back to
# Magisk resetprop which bypasses the property_service SELinux check.

set_p() {
    # $1 = prop name, $2 = value
    setprop "$1" "$2" 2>/dev/null
    [ "$(getprop "$1")" = "$2" ] && return 0
    resetprop "$1" "$2" 2>/dev/null
    [ "$(getprop "$1")" = "$2" ] && return 0
    /product/bin/resetprop "$1" "$2" 2>/dev/null
    return 0
}

set_p persist.security.adbinstall 1
set_p persist.security.adbinput 1
set_p persist.fastboot.enable 1
