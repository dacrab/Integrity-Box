# shellcheck shell=sh
RECORD="/data/adb/Box-Brain/Integrity-Box-Logs"
BOX="/data/adb/Box-Brain"
LOG_FILE="/data/adb/Box-Brain/Integrity-Box-Logs/action.log"

# Single source of truth for the security patch date (TrickyStore + resetprop)
export PATCH_DATE="2026-09-05"

# Property Backend Setup
RESETPROP="resetprop"
PROP_DELETE="resetprop --delete"
export PROP_WAIT="resetprop -w"
COMPACT_SUPPORTED=false

# Root Solution Detection & Binary Setup
detect_root_solution() {
    if [ -f "/data/adb/ksud" ] || [ -d "/data/adb/ksu" ]; then
        # KernelSU
        if [ -f "/data/adb/ksu/bin/resetprop" ]; then
            export PATH="/data/adb/ksu/bin:$PATH"
            echo "kernelsu"
        else
            echo "kernelsu_legacy"
        fi
    elif [ -f "/data/adb/apd" ] || [ -d "/data/adb/ap" ]; then
        # APatch
        if [ -f "/data/adb/ap/bin/resetprop" ]; then
            export PATH="/data/adb/ap/bin:$PATH"
            echo "apatch"
        else
            echo "apatch_legacy"
        fi
    elif [ -f "/data/adb/magisk" ] || [ -f "/data/adb/magisk/magisk" ]; then
        # Magisk
        echo "magisk"
    else
        echo "unknown"
    fi
}

ROOT_SOL=$(detect_root_solution)

# resetprop Feature Detection
check_compact_support() {
    resetprop --help 2>&1 | grep -q "compact"
}

setup_resetprop() {
    case "$ROOT_SOL" in
        magisk)
            # Check Magisk version for hexpatch fallback
            if [ -f /data/adb/magisk/util_functions.sh ]; then
                MAGISK_VER=$(grep -E '^MAGISK_VER_CODE=' /data/adb/magisk/util_functions.sh | tail -n 1 | cut -d= -f2 | tr -d '"')
                [ "$MAGISK_VER" -lt 27003 ] 2>/dev/null && RESETPROP="resetprop_hexpatch" || RESETPROP="resetprop -n"
            else
                RESETPROP="resetprop -n"
            fi
            check_compact_support && COMPACT_SUPPORTED=true
            ;;
        kernelsu|apatch)
            # Modern KSU/APatch with resetprop support
            RESETPROP="resetprop -n"
            PROP_DELETE="resetprop --delete"
            PROP_WAIT="resetprop -w"
            check_compact_support && COMPACT_SUPPORTED=true
            ;;
        kernelsu_legacy|apatch_legacy|unknown)
            # Legacy or unknown - limited setprop only
            RESETPROP="setprop"
            PROP_DELETE="setprop"  # Can't actually delete
            PROP_WAIT="sleep"
            ;;
    esac
}

safemode_flags() {
    local dir="/data/adb/Box-Brain"
    [ -f "$dir/safemode" ] || return 0
    for f in spoof-los-boot nuke-los-boot spoof-custom-rom-boot spoof-selinux-boot nuke-sus-boot NoLineageProp nodebug build tag encrypt hidehook twrp skip; do
        [ -f "$dir/$f" ] && rm -f "$dir/$f"
    done
}

set_perm_if_needed() {
    _file="$1"
    _perm="$2"
    
    # Skip if missing
    [ -e "$_file" ] || return 0
    
    # For 755: just check if owner executable bit is set
    [ -x "$_file" ] && return 0
    
    # Only chmod if not executable
    chmod "$_perm" "$_file" 2>/dev/null || true
}

# Compact Function
run_compact() {
    [ "$COMPACT_SUPPORTED" = true ] && resetprop -c 2>/dev/null
}

recommended_settings() {
    touch "$BOX/migrate_force"
    touch "$BOX/run_migrate"
}

# determine downloader binary
detect_downloader() {
  # curl
  if command -v curl >/dev/null 2>&1; then
    DOWNLOADER=$(command -v curl)
    DL_MODE="curl"
    return
  fi

  # wget
  if command -v wget >/dev/null 2>&1; then
    DOWNLOADER=$(command -v wget)
    DL_MODE="wget"
    return
  fi

  # Magisk BusyBox
  if [ -x /data/adb/magisk/busybox ]; then
    DOWNLOADER="/data/adb/magisk/busybox"
    DL_MODE="busybox"
    return
  fi

  # KSU BusyBox
  if [ -x /data/adb/ksu/bin/busybox ]; then
    DOWNLOADER="/data/adb/ksu/bin/busybox"
    DL_MODE="busybox"
    return
  fi

  # Built-in toybox wget
  if toybox wget --help >/dev/null 2>&1; then
    DOWNLOADER="toybox"
    DL_MODE="toybox"
    return
  fi

  # nothing available
  DOWNLOADER=""
  DL_MODE=""
}

wait_for_network() {
  max_wait=${1:-30} # seconds
  step=2
  waited=0

  while [ $waited -lt $max_wait ]; do
    if command -v ping >/dev/null 2>&1; then
      ping -c 1 1.1.1.1 >/dev/null 2>&1 && return 0
    fi

    if [ -n "$DOWNLOADER" ]; then
      if [ "$DL_MODE" = "curl" ]; then
        /system/bin/curl -s --head --connect-timeout 5 https://raw.githubusercontent.com >/dev/null 2>&1 && return 0
      elif [ "$DL_MODE" = "wget" ]; then
        /system/bin/wget --spider --timeout=5 --tries=1 https://raw.githubusercontent.com >/dev/null 2>&1 && return 0
      elif [ "$DL_MODE" = "busybox" ]; then
        /data/adb/magisk/busybox wget --spider --timeout=5 --tries=1 https://raw.githubusercontent.com >/dev/null 2>&1 && return 0
      fi
    fi

    sleep $step
    waited=$((waited+step))
  done

  return 1
}

chup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$RECORD/pixel.log"
}

set_simpleprop() {
    local PROP="$1"
    local VALUE="$2"
    local CURRENT

    CURRENT="$(getprop "$PROP" 2>/dev/null)"

    if [ -n "$CURRENT" ]; then
        setprop "$PROP" "$VALUE" >/dev/null 2>&1
        chup "Set $PROP to $VALUE"
    else
        chup "Skipping $PROP, property does not exist"
    fi
}

# Track results
log_step() {
  local status="$1"
  local task="$2"
  local timestamp
  
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  printf -- "%-10s %s\n" "$status" "$task"
  printf "[%s] %-10s %s\n" "$timestamp" "$status" "$task" >> "$LOG_FILE"
}

# Exit delay (no-op: root managers close the action UI themselves).
handle_delay() { :; }

log_patch() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$RECORD/patch.log"
}

# Kill GMS / Vending Processes
kill_process() {
  TARGET="$1"
  PID=$(pidof "$TARGET")
  if [ -n "$PID" ]; then
    kill -9 $PID
    log "- Killed $TARGET"
  else
    log "- $TARGET not running"
  fi
}
  
hide_recovery_folders() {
    [ -f /data/adb/Box-Brain/twrp ] || return

    SRC="/sdcard"
    DEST="/data/adb/recovery_backups"
    mkdir -p "$DEST"

    FOLDERS="TWRP OrangeFox FOX PBRP PitchBlack Recovery"

    random_str() { head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12; }

    for F in $FOLDERS; do
        DIR="$SRC/$F"
        [ -d "$DIR" ] || continue

        if [ -f "$DIR/.twrps" ]; then
            rm -f "$DIR/.twrps" 2>/dev/null
            if [ -f "$DIR/.twrps" ]; then
                NEWF=".$(random_str)_$(date +%s)"
                mv "$DIR" "$SRC/$NEWF" 2>/dev/null
                DIR="$SRC/$NEWF"
                rm -f "$DIR/.twrps" 2>/dev/null
            fi
        fi

        SUB=$(find "$DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".*" 2>/dev/null | wc -l)

        if [ "$SUB" -gt 0 ]; then
            mv "$DIR" "$DEST/$(random_str)" 2>/dev/null
        else
            rm -rf "$DIR" 2>/dev/null
        fi
    done
}

delete_if_exist() {
    path="$1"
    if [ -e "$path" ]; then
        rm -rf "$path"
        log "Deleted: $path"
    fi
}

# Rebuild the TrickyStore target list and sync the OMK injector config.
# Shared by the action runner and the WebUI target runner (were duplicated).
# $1 = space-separated seed packages, always included.
rebuild_targets() {
    _seed="$1"
    _target_dir="/data/adb/tricky_store"
    _target="$_target_dir/target.txt"
    _tmp="${_target}.new.$$"
    _skip="/data/adb/Box-Brain/skip"
    _blacklist="/data/adb/Box-Brain/blacklist.txt"
    _orig_selinux="$(getenforce 2>/dev/null || echo Permissive)"

    mkdir -p "$_target_dir" 2>/dev/null

    # TrickyStore cannot read target.txt while SELinux is enforcing, but never
    # leave the device permissive if this function dies partway through.
    _restore_enforcing() {
        [ "$_orig_selinux" = "Enforcing" ] && [ ! -f "$_skip" ] && setenforce 1
        return 0
    }
    if [ ! -f "$_skip" ] && [ "$_orig_selinux" = "Enforcing" ]; then
        setenforce 0
        trap _restore_enforcing EXIT INT TERM
    fi

    [ -f "$_target" ] && mv -f "$_target" "${_target}.bak" && log_step "BACKUP" "Previous target.txt"

    _tee_broken="false"
    [ -f "$_target_dir/tee_status" ] && [ "$(grep -E '^teeBroken=' "$_target_dir/tee_status" | cut -d '=' -f2)" = "true" ] && _tee_broken="true"

    for _pkg in $_seed; do
        echo "$_pkg" >> "$_tmp"
    done

    cmd package list packages -3 2>/dev/null | cut -d ":" -f2 | while read -r _pkg; do
        [ -z "$_pkg" ] && continue
        grep -Fxq "$_pkg" "$_tmp" || echo "$_pkg" >> "$_tmp"
    done

    sed -i 's/^[[:space:]]*//;s/[[:space:]]*$//' "$_tmp"
    sort -u "$_tmp" -o "$_tmp"

    if [ -s "$_blacklist" ]; then
        sed -i 's/^[[:space:]]*//;s/[[:space:]]*$//' "$_blacklist"
        # grep exits 1 when every line is filtered; keep the file if it still has content
        if grep -Fvxf "$_blacklist" "$_tmp" > "${_tmp}.filtered" || [ -s "${_tmp}.filtered" ]; then
            mv -f "${_tmp}.filtered" "$_tmp"
            log_step "FILTERED" "Blacklisted targets removed"
        else
            rm -f "${_tmp}.filtered"
            log_step "SKIPPED" "All targets blacklisted, keeping list"
        fi
    else
        log_step "SKIPPED" "Blacklist not configured"
    fi

    [ "$_tee_broken" = "true" ] && sed -i 's/$/!/' "$_tmp" && log_step "NOTED" "TEE-broken device suffix applied"

    mv -f "$_tmp" "$_target" && log_step "UPDATED" "Target package list"

    trap - EXIT INT TERM 2>/dev/null
    if [ ! -f "$_skip" ] && [ "$_orig_selinux" = "Enforcing" ]; then
        setenforce 1
    fi

    sync_omk_injector "$_target"
}

# Sync TrickyStore target.txt into the OMK injector.toml scoop list.
# $1 = path to target.txt
sync_omk_injector() {
    _target="$1"
    _omk_dir="/data/misc/keystore/omk"
    _toml="$_omk_dir/injector.toml"
    _tmp_toml="${_toml}.tmp.$$"
    _scoop="/data/local/tmp/.omk_scoop_$$"

    [ -d "$_omk_dir" ] || return 0

    {
        echo "scoop = ["
        while IFS= read -r _pkg || [ -n "$_pkg" ]; do
            [ -z "$_pkg" ] && continue
            echo "  \"${_pkg%!}\","
        done < "$_target"
        echo "]"
    } > "$_scoop" 2>/dev/null

    if [ -f "$_toml" ]; then
        sed -n '1,/^scoop[[:space:]]*=[[:space:]]*\[/p' "$_toml" | sed '$d' > "$_tmp_toml" 2>/dev/null
        cat "$_scoop" >> "$_tmp_toml" 2>/dev/null
        sed -n '/^[[:space:]]*\]/,$p' "$_toml" | sed '1d' >> "$_tmp_toml" 2>/dev/null
        mv -f "$_tmp_toml" "$_toml" 2>/dev/null
        rm -f "$_scoop" 2>/dev/null
        log_step "SYNCED" "Targets in injector.toml"
    else
        {
            echo '# Only packages listed in `scoop` are intercepted.'
            echo ''
            cat "$_scoop"
            echo ''
            echo '[main]'
            echo 'enabled = true'
            echo 'log_level = "debug"'
            echo ''
            echo '[filter]'
            echo 'enabled = true'
            echo 'deny_packages = []'
            echo 'block_android_package = true'
            echo 'allow_unknown_package = false'
            echo ''
            echo '# Do not edit if you have no idea about the things below'
            echo '[intercept]'
            echo 'get_security_level = true'
            echo 'get_key_entry = true'
            echo 'update_subcomponent = true'
            echo 'list_entries = true'
            echo 'delete_key = true'
            echo 'grant = true'
            echo 'ungrant = true'
            echo 'get_number_of_entries = true'
            echo 'list_entries_batched = true'
            echo 'get_supplementary_attestation_info = true'
        } > "$_toml" 2>/dev/null
        rm -f "$_scoop" 2>/dev/null
        log_step "CREATED" "Missing injector.toml for OMK"
    fi
}

# Locate a usable busybox binary (echoes its path; empty when none found).
find_busybox() {
    for bb in /data/adb/modules/busybox-ndk/system/*/busybox \
              /data/adb/ksu/bin/busybox \
              /data/adb/ap/bin/busybox \
              /data/adb/magisk/busybox; do
        [ -x "$bb" ] && { echo "$bb"; return; }
    done
}


writelog() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    /system/bin/log -t PATCH_OVERRIDE "$1"
}

ensure_blacklist_entries() {
    BLACKLIST="/data/adb/Box-Brain/blacklist.txt"

    # Ensure directory & file exist
    mkdir -p "$(dirname "$BLACKLIST")"
    [ -f "$BLACKLIST" ] || touch "$BLACKLIST"

    # list of blacklisted packages 
    REQUIRED_ENTRIES="
io.github.vvb2060.mahoshojo
com.reveny.nativecheck
icu.nullptr.nativetest
com.android.nativetest
io.liankong.riskdetector
me.garfieldhan.holmes
luna.safe.luna
com.zhenxi.hunter
io.github.a13e300.ksuwebui
com.topjohnwu.magisk
com.dergoogler.mmrl.wx
com.dergoogler.mmrl
org.frknkrc44.hma_oss
bin.mt.plus
ch.protonvpn.android
com.android.chrome
com.google.android.apps.docs
com.google.android.apps.photos
com.google.android.contactkeys
com.google.android.safetycore
com.google.android.youtube
com.google.ar.core
com.heytap.browser
com.kimcy929.screenrecorder
com.kowx712.supermanager
com.metrolist.music
mark.via.gp
org.swiftapps.swiftbackup
"

    for entry in $REQUIRED_ENTRIES; do
        # Exact match only
        if ! grep -qxF "$entry" "$BLACKLIST"; then
            echo "$entry" >> "$BLACKLIST"
        fi
    done
}

ensure_exec_permissions() {
  local DIR="/data/adb/modules/playintegrityfix"

  [ -d "$DIR" ] || return 0

  for file in "$DIR"/*.sh; do
    [ -f "$file" ] || continue

    if [ ! -x "$file" ]; then
      chmod +x "$file"
    fi
  done
}

##########################################
# adapted from Play Integrity Fork by @osm0sis & Shamiko by @Lsposed Team
# source: https://github.com/osm0sis/PlayIntegrityFork
# license: GPL-3.0
##########################################

export SKIPDELPROP=false
[ -f "$MODPATH/skipdelprop" ] && SKIPDELPROP=true

# Core Property Functions
# resetprop_if_diff <prop> <expected>
resetprop_if_diff() {
    local NAME="$1"
    local EXPECTED="$2"
    local CURRENT
    
    case "$ROOT_SOL" in
        magisk|kernelsu|apatch)
            CURRENT="$(resetprop "$NAME")"
            [ -z "$CURRENT" ] || [ "$CURRENT" = "$EXPECTED" ] || $RESETPROP "$NAME" "$EXPECTED"
            ;;
        *)
            CURRENT="$(getprop "$NAME")"
            [ -z "$CURRENT" ] || [ "$CURRENT" = "$EXPECTED" ] || setprop "$NAME" "$EXPECTED" 2>/dev/null
            ;;
    esac
}

# resetprop_if_match <prop> <match> <new_value>
resetprop_if_match() {
    local NAME="$1"
    local MATCH="$2"
    local VALUE="$3"
    local CURRENT
    
    case "$ROOT_SOL" in
        magisk|kernelsu|apatch)
            CURRENT="$(resetprop "$NAME")"
            ;;
        *)
            CURRENT="$(getprop "$NAME")"
            ;;
    esac
    
    case "$CURRENT" in
        *"$MATCH"*) $RESETPROP "$NAME" "$VALUE" ;;
    esac
}

# delprop_if_exist <prop>
delprop_if_exist() {
    case "$ROOT_SOL" in
        magisk|kernelsu|apatch)
            [ -n "$(resetprop "$1")" ] && $PROP_DELETE "$1"
            ;;
        *)
            # Can't delete on legacy, set to empty
            setprop "$1" "" 2>/dev/null
            ;;
    esac
}

# persistprop <prop> <value>
persistprop() {
    [ "$ROOT_SOL" = "kernelsu_legacy" ] || [ "$ROOT_SOL" = "apatch_legacy" ] || [ "$ROOT_SOL" = "unknown" ] && return 0
    
    local NAME="$1"
    local NEWVALUE="$2"
    local CURVALUE
    CURVALUE="$(resetprop "$NAME")"

    if ! grep -q "$NAME" "$MODPATH/uninstall.sh" 2>/dev/null; then
        if [ "$CURVALUE" ]; then
            [ "$NEWVALUE" = "$CURVALUE" ] || echo "resetprop -n -p \"$NAME\" \"$CURVALUE\"" >> "$MODPATH/uninstall.sh"
        else
            echo "resetprop -p --delete \"$NAME\"" >> "$MODPATH/uninstall.sh"
        fi
    fi
    resetprop -n -p "$NAME" "$NEWVALUE"
}

# Hexpatch Fallback
resetprop_hexpatch() {
    [ "$ROOT_SOL" != "magisk" ] && return 1
    
    case "$1" in
        -f|--force) local FORCE=1; shift;;
    esac 

    local NAME="$1"
    local NEWVALUE="$2"
    local CURVALUE
    CURVALUE="$(resetprop "$NAME")"

    [ ! "$NEWVALUE" ] || [ ! "$CURVALUE" ] && return 1
    [ "$NEWVALUE" = "$CURVALUE" ] && [ ! "$FORCE" ] && return 2

    local NEWLEN=${#NEWVALUE}
    if [ -f /dev/__properties__ ]; then
        local PROPFILE=/dev/__properties__
    else
    local PROPFILE
    PROPFILE="/dev/__properties__/$(resetprop -Z "$NAME")"
    fi
    [ ! -f "$PROPFILE" ] && return 3
    local NAMEOFFSET
    NAMEOFFSET=$(strings -t d "$PROPFILE" | grep "$NAME" | head -1 | cut -d\  -f1)

    local NEWHEX
    NEWHEX="$(printf '%02x' "$NEWLEN")$(printf "$NEWVALUE" | od -A n -t x1 -v | tr -d ' \n')$(printf "%$((92-NEWLEN))s" | sed 's/ /00/g')"
    echo -ne "\x00\x00" | dd obs=1 count=2 seek=$((NAMEOFFSET-96)) conv=notrunc of="$PROPFILE" 2>/dev/null
    echo -ne "$(printf "$NEWHEX" | sed -e 's/.\{2\}/&\\x/g' -e 's/^/\\x/' -e 's/\\x$//')" | dd obs=1 count=93 seek=$((NAMEOFFSET-93)) conv=notrunc of="$PROPFILE" 2>/dev/null
}

boot_log() {
    echo "$1" | tee -a "$RECORD/boot.log"
}

wait_for_boot() {
    boot_log "Waiting for Android to finish booting..."
    local count=0
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
        count=$((count + 1))
        [ "$count" -ge 300 ] && { boot_log "Boot wait timeout"; return 1; }
    done
    sleep 3
    boot_log "Initialising, please wait."
    boot_log " "
}

reset_tricky_store() {
    # Tricky Store
    if [ -d "/data/adb/tricky_store/key_db" ]; then
        rm -rf "/data/adb/tricky_store/key_db"
        mkdir -p "/data/adb/tricky_store/key_db"
    fi

    # TEE Simulator 
    if [ -d "/data/adb/tricky_store/persistent_keys" ]; then
        rm -rf "/data/adb/tricky_store/persistent_keys"
        mkdir -p "/data/adb/tricky_store/persistent_keys"
    fi
}
