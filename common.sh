#!/system/bin/sh
# Xiaomi USB Security Bypass - shared logic
#
# Sourced by post-fs-data.sh / service.sh / action.sh via:
#
#     MODDIR=${0%/*}
#     . "$MODDIR/common.sh"
#
# MIUI keeps the "USB install" / "USB debugging (Security settings)" /
# "FASTBOOT flashing mode" switches in two independent layers:
#
#   1. persist props (see system.prop) -> read by system_server
#      persist.security.adbinstall / persist.security.adbinput / persist.fastboot.enable
#
#   2. com.miui.securitycenter shared_prefs + the matching Android settings rows
#      -> read by SecurityCenter, which is what really gates `adb install` and
#         which flips the developer-options toggle back to "off" when the online
#         Mi-account + SIM check fails.
#
# Tapping the toggle in developer options always runs that online check, so
# instead of fighting the UI this module forces both layers to the "enabled"
# state on every boot, before SecurityCenter is even started.

SC_PKG="com.miui.securitycenter"
SC_PREFS_DIR="/data/data/$SC_PKG/shared_prefs"

# Candidate preference files. remote_provider_preferences.xml is the one used
# by MIUI 12/13 (it is the cloud-provider cache that holds the switches); the
# others are covered for builds that keep the same keys elsewhere.
SC_PREF_FILES="
$SC_PREFS_DIR/remote_provider_preferences.xml
$SC_PREFS_DIR/common_settings.xml
$SC_PREFS_DIR/permcenter_settings.xml
$SC_PREFS_DIR/permission_settings.xml
"

# "<key>=<value>" entries enforced in every existing candidate file above
# (written as <boolean .../> entries). Values mirror what the UI writes when
# the toggle is legitimately enabled on a device with Mi account + SIM.
SC_PREF_KV="
security_adb_install_enable=true
permcenter_install_intercept_enabled=false
usb_install_enabled=true
adb_install_enabled=true
install_via_usb=true
security_usb_install_enable=true
miui_usb_install_enabled=true
adb_install_need_confirm=false
security_adb_install_need_confirm=false
"

# The same list on a single line, for `awk -v`: Android's /system/bin/awk
# (one-true-awk) rejects a -v value containing a newline with "newline in
# string", which silently broke the rewrite before.
SC_PREF_KV_1LINE=$(printf '%s' "$SC_PREF_KV" | tr '\n' ' ')

# "<key>=<value>" rows written to the global/secure/system settings namespaces.
SC_SETTINGS_KV="
adb_enabled=1
development_settings_enabled=1
adb_install_enabled=1
usb_install_enabled=1
security_adb_install_enable=1
security_usb_install_enable=1
miui_usb_install_enabled=1
adb_install_need_confirm=0
security_adb_install_need_confirm=0
install_non_market_apps=1
verifier_verify_adb_installs=0
package_verifier_enable=0
"

LOG_TAG="XiaomiUsbBypass"

# logcat-only logging (stdout of boot scripts is not visible to the user)
log_i() {
    log -t "$LOG_TAG" "$*" 2>/dev/null || true
}

# stdout + logcat logging, for action.sh (its output shows in the Magisk app)
say() {
    echo "$*"
    log_i "$*"
}

# ---------------------------------------------------------------------------
# props
# ---------------------------------------------------------------------------

# set_prop <name> <value>
# setprop can be refused by SELinux for persist.security.*; resetprop bypasses
# the property_service check, so it is used as a fallback.
set_prop() {
    setprop "$1" "$2" 2>/dev/null
    [ "$(getprop "$1")" = "$2" ] && return 0
    resetprop "$1" "$2" 2>/dev/null
    [ "$(getprop "$1")" = "$2" ] && return 0
    /product/bin/resetprop "$1" "$2" 2>/dev/null
    return 0
}

# ---------------------------------------------------------------------------
# SecurityCenter shared_prefs
# ---------------------------------------------------------------------------

# Give a file back the ownership / mode / label that prefs files in this folder
# normally carry, so SecurityCenter (uid system) keeps being able to read it.
fix_prefs_perms() {
    [ -f "$1" ] || return 0
    chown system:system "$1" 2>/dev/null
    chmod 0660 "$1" 2>/dev/null
    restorecon "$1" 2>/dev/null
}

# patch_sc_prefs_file <file>
#   0 -> nothing to do (file missing or already correct)
#   1 -> file was rewritten
#   2 -> rewrite failed
patch_sc_prefs_file() {
    target="$1"
    [ -f "$target" ] || return 0

    stale=0
    for kv in $SC_PREF_KV; do
        key=${kv%%=*}
        val=${kv#*=}
        # exactly one entry with that name, and it carries the wanted value
        if [ "$(grep -c "name=\"$key\"" "$target" 2>/dev/null)" != "1" ]; then
            stale=1
            break
        fi
        if ! grep -q "name=\"$key\" value=\"$val\"" "$target" 2>/dev/null; then
            stale=1
            break
        fi
    done
    [ "$stale" = "1" ] || return 0

    tmp="/data/local/tmp/.sc_prefs.$$.xml"
    rm -f "$tmp"
    # stderr is captured so a failing awk shows up in the log instead of
    # silently producing an empty file
    awk_err=$(awk -v kv="$SC_PREF_KV_1LINE" '
        BEGIN {
            n = split(kv, a, " ")
            for (i = 1; i <= n; i++) {
                if (a[i] == "") continue
                eq = index(a[i], "=")
                keys[++m] = substr(a[i], 1, eq - 1)
                vals[m] = substr(a[i], eq + 1)
            }
        }
        {
            # drop every existing entry we manage, whatever its value is
            for (i = 1; i <= m; i++)
                if (index($0, "name=\"" keys[i] "\"") > 0) next
            # re-add them right before the closing tag
            if (index($0, "</map>") > 0)
                for (i = 1; i <= m; i++)
                    printf "    <boolean name=\"%s\" value=\"%s\" />\n", keys[i], vals[i]
            print
        }
    ' "$target" 2>&1 > "$tmp")

    if [ ! -s "$tmp" ] || ! grep -q "</map>" "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        log_i "ERROR: rewrite failed for $target: $awk_err"
        return 2
    fi

    # one-shot backup, so the rewrite can be rolled back by hand
    cp -f "$target" "$target.usb_bypass.bak" 2>/dev/null
    fix_prefs_perms "$target.usb_bypass.bak"

    # overwrite in place: keeps the inode, owner and SELinux label of the original
    if ! cat "$tmp" > "$target" 2>/dev/null; then
        rm -f "$tmp"
        return 2
    fi
    rm -f "$tmp"
    fix_prefs_perms "$target"
    return 1
}

# Patch all candidate files; SC_PREFS_CHANGED = number of rewritten files.
SC_PREFS_CHANGED=0
patch_sc_prefs_all() {
    SC_PREFS_CHANGED=0
    for f in $SC_PREF_FILES; do
        patch_sc_prefs_file "$f"
        case "$?" in
            1)
                SC_PREFS_CHANGED=$((SC_PREFS_CHANGED + 1))
                log_i "patched prefs: $f"
                ;;
            2)
                log_i "ERROR: could not patch prefs: $f"
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Android settings rows
# ---------------------------------------------------------------------------

wait_for_boot() {
    i=0
    while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 60 ]; do
        sleep 2
        i=$((i + 1))
    done
}

# `settings` talks to system_server, hence the boot wait in the callers.
write_settings_keys() {
    for ns in global secure system; do
        for kv in $SC_SETTINGS_KV; do
            settings put "$ns" "${kv%%=*}" "${kv#*=}" 2>/dev/null
        done
    done
}

# ---------------------------------------------------------------------------
# SecurityCenter process
# ---------------------------------------------------------------------------

sc_running() {
    pidof "$SC_PKG" >/dev/null 2>&1
}

# SecurityCenter caches its preferences in memory, so a file that changed while
# it was running is only picked up after a restart. It is a core MIUI app with
# sticky services, so it comes back on its own; the explicit start is only a
# safety net for the case where it does not.
restart_sc_if_running() {
    sc_running || return 0
    log_i "restarting $SC_PKG so it reloads the patched switches"
    am force-stop "$SC_PKG" 2>/dev/null
    sleep 2
    if ! sc_running; then
        am start -n "$SC_PKG/.MainActivity" >/dev/null 2>&1 ||
            monkey -p "$SC_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    fi
}

# ---------------------------------------------------------------------------
# everything at once (service.sh / action.sh)
# ---------------------------------------------------------------------------

apply_all() {
    set_prop persist.security.adbinstall 1
    set_prop persist.security.adbinput 1
    set_prop persist.fastboot.enable 1

    wait_for_boot
    write_settings_keys

    patch_sc_prefs_all
    [ "$SC_PREFS_CHANGED" -gt 0 ] && restart_sc_if_running

    log_i "done: adbinstall=$(getprop persist.security.adbinstall) adbinput=$(getprop persist.security.adbinput) fastboot=$(getprop persist.fastboot.enable) prefs_rewritten=$SC_PREFS_CHANGED"
}
