#!/system/bin/sh
MODPATH="${0%/*}"
. $MODPATH/common_func.sh

BOX="/data/adb/Box-Brain"
boot="/data/adb/service.d"
placeholder="$MODPATH/webroot/common_scripts"
mkdir -p "$BOX/Integrity-Box-Logs"
mkdir -p "$boot"

# Grant perms 
if [ -f "$placeholder/autopilot.sh" ]; then
    chmod 755 "$placeholder/autopilot.sh"
fi

# Skip disabling built-in spoofing when zygiskless mode is enabled 
if [ -f "$BOX/zygisk" ]; then
    [ -f "$BOX/disablegms" ] && rm -f "$BOX/disablegms"
    [ -f "$BOX/disablevending" ] && rm -f "$BOX/disablevending"
fi

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

# Create all placeholder files only if they don't exist
for file in kill aosp patch xml tee user ulock stop start nogms lineage selinux hide resetprop faq nuke zygisknext yesgms; do
    [ -f "$placeholder/$file" ] || touch "$placeholder/$file"
done

# Verify backend perms
for _f in \
    "$MODPATH/webroot/UpdateTranslation.sh" \
    "$boot/prop.sh" \
    "$boot/hash.sh" \
    "$boot/lineage.sh" \
    "$boot/.box_cleanup.sh" \
    "$placeholder/autopilot.sh" \
    "$placeholder/target.sh" \
    "$placeholder/resetprop.sh" \
    "$placeholder/Report.sh" \
    "$placeholder/force_override.sh" \
    "$placeholder/override_lineage.sh" \
    "$placeholder/keymint.sh" \
    "$placeholder/extract_boot.sh"
do
    set_perm_if_needed "$_f" 755
done


##########################################
# adapted from Play Integrity Fork by @osm0sis
# source: https://github.com/osm0sis/PlayIntegrityFork
# license: GPL-3.0
##########################################

# First check if Magisk directory exists
setup_resetprop

if [ "$ROOT_SOL" = "magisk" ]; then
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
fi

# Conditional early sensitive properties

# Realme
resetprop_if_diff ro.boot.realmebootstate green

# OnePlus
resetprop_if_diff ro.is_ever_orange 0

# Microsoft and other vendors ship test-keys / eng build types
resetprop 2>/dev/null | sed -n 's/^\[\(ro\.[^]]*build\.tags\)\]:.*/\1/p' | while read -r PROP; do
    resetprop_if_diff "$PROP" release-keys
done

resetprop 2>/dev/null | sed -n 's/^\[\(ro\.[^]]*build\.type\)\]:.*/\1/p' | while read -r PROP; do
    resetprop_if_diff "$PROP" user
done
if ! $SKIPDELPROP; then
    delprop_if_exist ro.boot.verifiedbooterror
    delprop_if_exist ro.boot.verifyerrorpart
fi
resetprop_if_diff ro.boot.veritymode.managed yes

exit 0
