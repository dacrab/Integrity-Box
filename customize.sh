#!/system/bin/sh

# Module and log directory paths
FLAG="/data/adb/Box-Brain"
LOG_DIR="$FLAG/Integrity-Box-Logs"
INSTALL_LOG="$LOG_DIR/Installation.log"
LOG_FILE="$LOG_DIR/DeviceType.log"
SCRIPT="$MODPATH/webroot/common_scripts"
MEOW="/data/adb/modules/playintegrityfix"
SDK=$(getprop ro.system.build.version.sdk)
TRICKY="/data/adb/tricky_store"
MODERN="$SCRIPT/UI"
LEGACY="$MODPATH/webroot"

# Shared helpers (PATCH_DATE, safemode_flags, rebuild_targets, ...)
[ -f "$MODPATH/common_func.sh" ] && . "$MODPATH/common_func.sh"

mkdir -p "$LOG_DIR" || true
mkdir -p "$MEOW"
mkdir -p "$TRICKY"

# Logger
debug() {
    echo "$1" | tee -a "$INSTALL_LOG"
}

# Verify module integrity
check_integrity() {
    debug "========================================="
    debug "          Integrity Box Installer    "
    debug "========================================="
    debug "Verifying Module Integrity"
    
    if [ -n "$ZIPFILE" ] && [ -f "$ZIPFILE" ]; then
        if [ -f "$MODPATH/verify.sh" ]; then
            if sh "$MODPATH/verify.sh"; then
                debug "Module integrity verified."
            else
                debug "ERROR: Module integrity check failed!"
                exit 1
            fi
        else
            debug "ERROR: Missing verification script!"
            exit 1
        fi
    fi
}

# Setup environment and permissions
setup_environment() {
    debug " Setting up Environment "
    chmod +x "$SCRIPT/key.sh"
    sh "$SCRIPT/key.sh"
}

# Log a custom-ROM hit once, disable built-in spoofing, report custom ROM
rom_hit() {
    echo "$TS | Custom ROM detected via $1" >> "$LOG_FILE" 2>/dev/null
    echo "Result: Custom ROM" >> "$LOG_FILE" 2>/dev/null
    echo "Detection Completed - $(date)" >> "$LOG_FILE" 2>/dev/null
    debug "ROM type: Custom ROM"
    touch "$FLAG/disablegms" "$FLAG/disablevending"
}

detect_rom() {
    local TS val
    TS="$(date '+%Y-%m-%d %H:%M:%S')"

    > "$LOG_FILE" 2>/dev/null
    echo "ROM Detection Started - $TS" >> "$LOG_FILE" 2>/dev/null

    local props="
        ro.build.flavor
        ro.lineage.version
        ro.mod.version
        ro.custom.device
        sys.eliteprops.keybox
        sys.eliteprops.photos
        sys.eliteprops.pixelprops
        ro.lineage.build.version.plat.sdk
        ro.infinity.version
        ro.axion.version
        ro.crdroid.device
    "
    for prop in $props; do
        val=$(getprop "$prop" 2>/dev/null)
        if [ -n "$val" ]; then
            rom_hit "prop: $prop=$val"
            return 1
        fi
    done

    local pkgs="
        org.lineageos.audiofx
        com.nikgapps.overlay.gmscore
        com.android.axion.sandbox
        org.omnirom.omnijaws
        org.omnirom.omnistyle
        org.evolution.updater
        com.caf.fmradio
        org.lineageos.etar
        com.bitgapps.playstore.overlay
        co.aospa.sense.settings.overlay
        org.lineageos.aperture
        org.lineageos.aperture.frameworksbaseoverlay
        android.aosp.overlay
        lineageos.platform
        com.libremobileos.freeform
        org.calyxos.backup.contacts
        net.pixelos.ota
        org.clover.settings.overlay
        com.bootleggers.shishufied.clockfont.LowerAtmosphere
        com.goolag.pif
        com.rising.updater
        com.infinity.updater
    "
    for pkg in $pkgs; do
        if pm path "$pkg" >/dev/null 2>&1; then
            rom_hit "package: $pkg"
            return 1
        fi
    done

    if getprop | grep -iq "lineage" 2>/dev/null; then
        rom_hit "getprop lineage"
        return 1
    fi

    if [ -f /system/build.prop ] && grep -iq "lineage" /system/build.prop 2>/dev/null; then
        rom_hit "/system/build.prop"
        return 1
    fi

    if [ -f /vendor/build.prop ] && grep -iq "lineage" /vendor/build.prop 2>/dev/null; then
        rom_hit "/vendor/build.prop"
        return 1
    fi

    local sensitive_pkgs="
        com.samsung.android.app.updatecenter
        com.samsung.android.biometrics.app.setting
        com.samsung.android.game.gos
        com.sec.android.soagent
        com.xiaomi.account
        com.wssyncmldm
        com.oplus.ota
        com.xiaomi.misettings
        com.oplus.romupdate
    "
    for pkg in $sensitive_pkgs; do
        if pm list packages -s 2>/dev/null | grep -q "^package:$pkg$"; then
            echo "$TS | PM_DETECTED | $pkg" >> "$LOG_FILE" 2>/dev/null
            touch "$FLAG/skip" 2>/dev/null
        elif find /system /product /system_ext /apex -type d -name "*$pkg*" 2>/dev/null | grep -q .; then
            echo "$TS | FS_DETECTED | $pkg" >> "$LOG_FILE" 2>/dev/null
            touch "$FLAG/skip" 2>/dev/null
        fi
    done

    touch "$FLAG/safemode" 2>/dev/null
    echo "$TS | ACTION | safemode flag created" >> "$LOG_FILE" 2>/dev/null
    echo "Result: Stock ROM" >> "$LOG_FILE" 2>/dev/null
    echo "Detection Completed - $(date)" >> "$LOG_FILE" 2>/dev/null
    debug " ROM type: Stock ROM"
    return 0
}

check_arch() {
    debug " Checking CPU ABI"
    case "$(getprop ro.product.cpu.abi)" in
        armeabi-v7a|arm64-v8a)
            debug " Modern Hardware detected"
            debug " using Shadow Hook method"
            ;;
        *)
            debug " Legacy Hardware detected"
            debug " fallback to Dobby method"
            rm -rf "$MODPATH/zygisk" "$MODPATH/classes.dex"
            mv "$MODPATH/legacy/zygisk" "$MODPATH/zygisk"
            mv "$MODPATH/legacy/legacy.dex" "$MODPATH/classes.dex"

            find "$MODPATH/zygisk" -type f -exec chown 0:0 {} \; -exec chmod 644 {} \;
            chown 0:0 "$MODPATH/classes.dex"
            chmod 644 "$MODPATH/classes.dex"
            ;;
    esac
}

set_integritybox_profile() {
    debug " Setting IntegrityBox Profile"
        if [ "$SDK" -ge 33 ]; then
            touch "$FLAG/pixelify"
        else
            touch "$FLAG/legacy"
        fi
}

# Clean up old logs and files
cleanup() {
    chmod +x "$SCRIPT/cleanup.sh"
    sh "$SCRIPT/cleanup.sh"
}

# Create necessary directories if missing
prepare_directories() {
    debug " Preparing Required Directories  "
    [ ! -d "/data/adb/modules/playintegrityfix" ] && mkdir -p "/data/adb/modules/playintegrityfix"
    [ ! -f "$MODPATH/module.prop" ] && return 1
}

	
# Handle module prop file
handle_module_props() {
    debug " Handling Module Properties "
    touch "$MEOW/update"
    cp "$MODPATH/module.prop" "$MEOW/module.prop"
}

# Verify boot hash file
check_boot_hash() {
    debug " Creating Verified Boot Hash config"
    if [ ! -f "/data/adb/Box-Brain/hash.txt" ]; then
        touch "/data/adb/Box-Brain/hash.txt"
    fi
}

# Enable recommended settings
enable_recommended_settings() {
    if [ ! -f "$MEOW/service.sh" ]; then
        debug " Enabling Recommended Settings "
        touch "$FLAG/iframe_back_button"
        touch "$FLAG/migrate_force"
        touch "$FLAG/run_migrate"
        touch "$FLAG/noredirect"
        touch "$FLAG/ignore"
        touch "$FLAG/keyswitch"
    fi
}

# Final footer message
display_footer() {
    debug "_________________________________________"
    debug "             Installation Completed "
}

# Main installation flow
install_module() {
    check_integrity
    prepare_directories
    handle_module_props
    set_integritybox_profile
    setup_environment
    detect_rom
    cleanup
    check_boot_hash
    enable_recommended_settings
    check_arch
}

echo "
  ___     _                _ _        
 |_ _|_ _| |_ ___ __ _ _ _(_) |_ _  _ 
  | || ' \  _/ -_) _  | '_| |  _| || |
 |___|_||_\__\___\__, |_| |_|\__|\_, |
 | _ ) _____ __  |___/           |__/ 
 | _ \/ _ \ \ /                       
 |___/\___/_\_\                       
                                                
                                      
"

# Set fingerprint on installation 
if [ -f "$MEOW/custom.pif.prop" ]; then
    cp "$MEOW/custom.pif.prop" "$MODPATH/custom.pif.prop"
elif [ ! -f "$MEOW/service.sh" ]; then
    if [ "$SDK" -le 31 ]; then
        cp "$MODPATH/toolkit/legacy.prop" "$MODPATH/custom.pif.prop"
    else
        cp "$MODPATH/toolkit/pixelify.prop" "$MODPATH/custom.pif.prop"
    fi
fi

# Conflicting module id would load twice
if [ -d /data/adb/modules/playintegrity ]; then
    rm -rf "/data/adb/modules/playintegrity"
fi

# Write security patch file if missing
[ -f "$TRICKY/security_patch.txt" ] || echo "all=$PATCH_DATE" > "$TRICKY/security_patch.txt"

# Start the installation process
install_module

if [ -f "$FLAG/modern" ]; then
    debug " Modern UI style detected"

    if [ -f "$MODERN/index.html" ] && [ -f "$MODERN/style.css" ] && [ -f "$MODERN/script.js" ]; then
        debug " Switching to Modern UI layout"
    
        [ -f "$LEGACY/index.html" ] && mv -f "$LEGACY/index.html" "$LEGACY/index.html.bak"
        [ -f "$LEGACY/style.css" ] && mv -f "$LEGACY/style.css" "$LEGACY/style.css.bak"
        [ -f "$LEGACY/script.js" ] && mv -f "$LEGACY/script.js" "$LEGACY/script.js.bak"

        cp -f "$MODERN/index.html" "$LEGACY/index.html"
        cp -f "$MODERN/style.css" "$LEGACY/style.css"
        cp -f "$MODERN/script.js" "$LEGACY/script.js"
    else
        debug " Modern UI source files missing, keeping legacy layout"
    fi
fi

# Install boot scripts (sources live in service.d/)
boot="/data/adb/service.d"
mkdir -p "$boot"
for _s in .box_cleanup.sh lineage.sh hash.sh prop.sh; do
    cp -f "$MODPATH/service.d/$_s" "$boot/$_s"
done

##########################################
# adapted from Play Integrity Fork by @osm0sis
# source: https://github.com/osm0sis/PlayIntegrityFork
# license: GPL-3.0
##########################################

# Zygiskless installation
if [ -e /sdcard/zygisk ] || [ -f /data/adb/Box-Brain/zygisk ]; then
    debug " Proceeding Zygiskless Installation"
    debug " Disabled: Zygisk Attestation fallback"
    debug " Enabled:  Pixel Mode"
    touch "$FLAG/zygisk"
    touch "$FLAG/keybox"
    touch "$FLAG/json"
    sed -i 's/^description=.*/description=Pixel Mode enabled, all zygisk related components have been disabled/' "$MODPATH/module.prop"
    rm -rf $MODPATH/app_replace_list.txt \
        $MODPATH/autopif2.sh $MODPATH/classes.dex \
        $MODPATH/common_setup.sh $MODPATH/custom.app_replace_list.txt \
        $MODPATH/custom.pif.json \
        $MODPATH/legacy \
        $MODPATH/pif.json $MODPATH/pif.prop $MODPATH/zygisk \
        $MEOW/custom.app_replace_list.txt \
        $MEOW/custom.pif.json \
        $MEOW/skippersistprop \
        $MEOW/system

# Copy any disabled app files to updated module
elif [ -d "$MEOW/system" ]; then
    debug " Restoring disabled ROM apps configuration"
    cp -afL "$MEOW/system" "$MODPATH"
fi

# Warn if potentially conflicting modules are installed
if [ -d /data/adb/modules/MagiskHidePropsConf ]; then
    debug " MagiskHidePropsConfig (MHPC) module may cause issues with PIF"
    debug " Disable or remove it"
fi

# Run common tasks for installation and boot-time
if [ -d "$MODPATH/zygisk" ]; then
    . $MODPATH/common_func.sh
    . $MODPATH/common_setup.sh
fi

# Clean up any leftover files from previous deprecated methods
rm -f /data/data/com.google.android.gms/cache/pif.prop /data/data/com.google.android.gms/pif.prop \
    /data/data/com.google.android.gms/cache/pif.json /data/data/com.google.android.gms/pif.json

# Remove flag from /sdcard to avoid detection 
[ -f /sdcard/zygisk ] || [ -d /sdcard/zygisk ] && rm -rf /sdcard/zygisk

display_footer
exit 0
