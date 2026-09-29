#!/system/bin/sh

MODDIR="/data/adb/modules/playintegrityfix"
[ -f "$MODDIR/common_func.sh" ] && . "$MODDIR/common_func.sh"

# CONFIG
FILE_PATH="/data/adb/tricky_store/security_patch.txt"
SKIP_FILE="/data/adb/Box-Brain/skip"
LOG_DIR="/data/adb/Box-Brain/Integrity-Box-Logs"
LOG_FILE="$LOG_DIR/prop_patch.log"

writelog() {
    TS="$(date '+%Y-%m-%d %H:%M:%S')"
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf "%s | %s\n" "$TS" "$1" >> "$LOG_FILE"
}

abort() {
    writelog "ERROR | $1"
    exit 1
}

# SAFE MODE CHECK
if [ -f "/data/adb/Box-Brain/safemode" ]; then
    mkdir -p "$LOG_DIR" 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') : Safemode active, script aborted." >> "$LOG_DIR/safemode.log"
    safemode_flags
    exit 1
fi

# RESETPROP CHECK
if ! command -v resetprop >/dev/null 2>&1; then
    abort "resetprop not found, cannot continue"
fi

# PROP SET FUNCTION
setprop_safe() {
    PROP=$1
    VALUE=$2
    CURRENT=$(getprop "$PROP")

    if [ "$CURRENT" = "$VALUE" ]; then
        writelog "OK: $PROP already set to $VALUE"
        return
    fi

    if resetprop "$PROP" "$VALUE"; then
        writelog "OK: Set $PROP to $VALUE (was: $CURRENT)"
    else
        writelog "FAIL: Failed to set $PROP (current: $CURRENT)"
    fi
}

# START LOG
writelog "Starting Security Patch Override"

# Exit if module is disabled 
if [ -f "/data/adb/modules/playintegrityfix/disable" ]; then
    writelog "Integrity Box is disabled, exiting..."
    exit 0
fi

# SAVE PATCH DATE
mkdir -p "/data/adb/tricky_store"
echo "all=$PATCH_DATE" > "$FILE_PATH" 2>>"$LOG_FILE"

# APPLY SYSTEM+VENDOR SECURITY PATCH
if [ -f "$SKIP_FILE" ]; then
    writelog "Sensitive device detected, skipping ro.vendor.build.security_patch"
else
    setprop_safe ro.vendor.build.security_patch "$PATCH_DATE"
    setprop_safe ro.build.version.security_patch "$PATCH_DATE"
fi

# FINAL VERIFICATION
BUILD_VAL=$(getprop ro.build.version.security_patch)
VENDOR_VAL=$(getprop ro.vendor.build.security_patch)

if [ -f "$SKIP_FILE" ]; then
    writelog "Sensitive device detected, Vendor patch override intentionally skipped"
else
    writelog "Vendor Patch Applied: $VENDOR_VAL"
    writelog "System Patch Applied: $BUILD_VAL"
fi

writelog "Script Finished Successfully"
exit 0
