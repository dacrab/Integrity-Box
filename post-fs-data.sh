#!/system/bin/sh
MODPATH="${0%/*}"
. $MODPATH/common_func.sh

boot="/data/adb/service.d"
mkdir -p "$BOX/Integrity-Box-Logs"
mkdir -p "$boot"

# Handle Vending-specific prop
if [ -f "$BOX/enablevending" ]; then
    set_simpleprop persist.sys.pixelprops.vending true
fi

if [ -f "$BOX/disablevending" ]; then
    set_simpleprop persist.sys.pixelprops.vending false
fi

# Handle GMS-specific props
if [ -f "$BOX/enablegms" ]; then
    setprop persist.sys.pihooks.disable.gms_key_attestation_block false
    setprop persist.sys.pihooks.disable.gms_props false
    setprop persist.sys.pihooks.enabled_features 1
    setprop persist.sys.pihooks.disable 0
    setprop persist.sys.kihooks.disable 0
fi

if [ -f "$BOX/disablegms" ]; then
    setprop persist.sys.pihooks.disable.gms_key_attestation_block true
    setprop persist.sys.pihooks.disable.gms_props true
    setprop persist.sys.pihooks.enabled_features 0
    setprop persist.sys.pihooks.disable 1
    setprop persist.sys.kihooks.disable 1
fi

# Verify backend perms
_scripts="$MODPATH/webroot/common_scripts"
for _f in \
    "$MODPATH/webroot/UpdateTranslation.sh" \
    "$boot/prop.sh" \
    "$boot/hash.sh" \
    "$boot/lineage.sh" \
    "$boot/.box_cleanup.sh" \
    "$_scripts/autopilot.sh" \
    "$_scripts/target.sh" \
    "$_scripts/gms.sh" \
    "$_scripts/webui.sh" \
    "$_scripts/resetprop.sh" \
    "$_scripts/Report.sh" \
    "$_scripts/force_override.sh" \
    "$_scripts/override_lineage.sh" \
    "$_scripts/keymint.sh" \
    "$_scripts/hma.sh"
do
    set_perm_if_needed "$_f" 755
done

if [ -e "$BOX/ota" ]; then
    rm -f "$MODPATH/system.prop"
    rm -f "$BOX/NoLineageProp"
    rm -rf "$BOX/override"
    rm -rf "$BOX/ota"
    touch "$BOX/safemode"
fi

##########################################
# adapted from Play Integrity Fork by @osm0sis
# source: https://github.com/osm0sis/PlayIntegrityFork
# license: GPL-3.0
##########################################

# First check if Magisk directory exists
if [ -d "/data/adb/magisk" ]; then
    echo "Magisk detected."

    if [ -d "$MODPATH/zygisk" ]; then
        # Remove Play Services and Play Store from Magisk DenyList when set to Enforce in normal mode
        if magisk --denylist status; then
            magisk --denylist rm com.google.android.gms
            magisk --denylist rm com.android.vending
        fi

        # Run common tasks for installation and boot-time
        . "$MODPATH/common_setup.sh"
    else
        # Add Play Services DroidGuard and Play Store processes to Magisk DenyList for better results in scripts-only mode
        magisk --denylist add com.google.android.gms com.google.android.gms.unstable
        magisk --denylist add com.android.vending
    fi

else
    echo "Skipped denylist, Bro's not using Magisk"
fi

# Conditional early sensitive properties

# Shared warranty/debug/secure/Realme battery
spoof_warranty_props

# OnePlus
resetprop_if_diff ro.is_ever_orange 0

# Microsoft
for PROP in $(resetprop | grep -oE 'ro.*.build.tags'); do
    resetprop_if_diff $PROP release-keys
done

# Other
for PROP in $(resetprop | grep -oE 'ro.*.build.type'); do
    resetprop_if_diff $PROP user
done
if ! $SKIPDELPROP; then
    delprop_if_exist ro.boot.verifiedbooterror
    delprop_if_exist ro.boot.verifyerrorpart
fi
resetprop_if_diff ro.boot.veritymode.managed yes

exit 0
