#!/system/bin/sh

MODPATH="${0%/*}"
. $MODPATH/common_func.sh

# Paths
BOX="/data/adb/Box-Brain"
LOGDIR="$BOX/Integrity-Box-Logs"

CPP="$LOGDIR/spoofing.log"
PATCH_LOG="$LOGDIR/patch.log"
LOG="$LOGDIR/root.log"
LOGFILE="$LOGDIR/gapps.log"

SCRIPT_DIR="$MODPATH/webroot/common_scripts"
UPDATE="$SCRIPT_DIR/key.sh"

PROP="$MODPATH/module.prop"
BAK="$PROP.bak"

PATCH_FLAG="$BOX/patch"

PIF_PROP="$MODPATH/custom.pif.prop"
SKIP_FILE="$BOX/skip"
SPOOF_APPS="$BOX/per-app-spoofing"

PROP_MAIN="ro.build.version.security_patch"

TARGET_DIR="/data/adb/tricky_store"
FILE_PATH="$TARGET_DIR/security_patch.txt"

DIR="/sdcard/Download"
OUTJSON="/sdcard/meow.json"

BRAND_PROP=$(getprop ro.product.system.brand)

MIGRATE_OK=0

mkdir -p "$BOX" "$LOGDIR"
ensure_exec_permissions
recommended_settings
ensure_blacklist_entries

if [ -f "$BOX/root" ]; then
  rm -f "$BOX/root"
  find "$DIR" -type f \( -name "*_install_log_2026*" -o -name "*_action_log_2026*" \) | while read -r f; do
    echo "$(date '+%F %T') Deleted: $f" | tee -a "$LOG"
    rm -f "$f"
  done
  handle_delay
  exit 0
fi

if [ -e "$BOX/ota" ]; then
    rm -f "$MODPATH/system.prop"
    rm -f "$BOX/NoLineageProp"
    rm -rf "$BOX/override"
    rm -rf "$BOX/ota"
    touch "$BOX/safemode"
    echo " "
    echo " "
    echo "  DONE | REBOOT YOUR DEVICE"
    handle_delay
    exit 0
fi

[ -f $BOX/lsposed ] && { 
  echo "[*] Starting cleanup..."; 
  if getprop | grep -q "^\[dalvik.vm.dex2oat-flags\]"; then 
    echo "[*] Removing dalvik.vm.dex2oat-flags..."; 
    resetprop -p dalvik.vm.dex2oat-flags && echo "[OK] Property removed." || echo "[FAIL] Failed to remove property."; 
  fi; 
  rm -f $BOX/lsposed && echo "[OK] Cleanup complete."; 
  echo "[*] Done. Exiting."; 
  exit 0; 
}

if [ -f "$BOX/gapps" ]; then
  rm -f "$BOX/gapps"
  echo "====================================" | tee -a "$LOGFILE"
  echo "Starting Log Cleanup" | tee -a "$LOGFILE"
  echo "====================================" | tee -a "$LOGFILE"
  echo "" | tee -a "$LOGFILE"

  TARGETS="
/sdcard/Android/litegapps/litegapps_controller.log
/tmp/NikGapps
/tmp/NikGapps/logfiles
/tmp/NikGapps/addonscripts
/tmp/NikGapps/logfiles/package_log
/sdcard/NikGapps
/tmp/recovery.log
/tmp/NikGapps.log
/tmp/Mount.log
/tmp/installation_size.log
/tmp/busybox.log
/tmp/Logs-*.tar.gz
/tmp/bitgapps_debug_logs_*.tar.gz
/sdcard/bitgapps_debug_logs_*.tar.gz
/system/etc/bitgapps_debug_logs_*.tar.gz
/sdcard/Download/*_install_log_2026*
/sdcard/Download/*_action_log_2026*
"

  for path in $TARGETS; do
    if echo "$path" | grep -q '\*'; then
      files=$(find "$(dirname "$path")" -type f -name "$(basename "$path")" 2>/dev/null)
    else
      files=$(find "$path" -type f 2>/dev/null)
    fi

    if [ -n "$files" ]; then
      echo "Found: $path" | tee -a "$LOGFILE"
      echo "$files" | tee -a "$LOGFILE"
      echo "$files" | while read -r f; do
        echo "Deleting: $f" | tee -a "$LOGFILE"
        rm -rf "$f" 2>&1 | tee -a "$LOGFILE"
      done
    elif [ -d "$path" ]; then
      echo "Deleting directory: $path" | tee -a "$LOGFILE"
      rm -rf "$path" 2>&1 | tee -a "$LOGFILE"
    fi
  done

  echo "" | tee -a "$LOGFILE"
  echo "Cleanup complete." | tee -a "$LOGFILE"
  echo "====================================" | tee -a "$LOGFILE"
  handle_delay
  exit 0
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$CPP"; }

reset_tricky_store

sh "$UPDATE" || { sleep 10; exit 1; }
echo " "

if [ -f "$BOX/keymint" ]; then
    "$SCRIPT_DIR/keymint.sh"
fi

# Mode (descriptive only; the flags themselves are read by the called scripts)
ARGDESC=""

[ -f "$BOX/use_qpr2" ]        && ARGDESC="$ARGDESC QPR2 "
[ -f "$BOX/use_advanced" ]    && ARGDESC="$ARGDESC ADVANCED "
[ -f "$BOX/use_strong" ]      && ARGDESC="$ARGDESC STRONG "
[ -f "$BOX/use_match" ]       && ARGDESC="$ARGDESC MATCH "
[ -f "$BOX/skip_json" ]       && ARGDESC="$ARGDESC SKIP_JSON "
[ -f "$BOX/skip_patch" ]      && ARGDESC="$ARGDESC SKIP_PATCH "
[ -f "$BOX/skip_keybox" ]     && ARGDESC="$ARGDESC SKIP_KEYBOX "
[ -f "$BOX/verbose_mode" ]    && ARGDESC="$ARGDESC VERBOSE "
[ -f "$BOX/force_spoof_off" ] && ARGDESC="$ARGDESC NO_SPOOF "

i=1
while [ "$i" -le 9 ]; do
    [ -f "$BOX/top_$i" ] && ARGDESC="$ARGDESC top=$i" && break
    i=$((i + 1))
done

i=1
while [ "$i" -le 9 ]; do
    [ -f "$BOX/depth_$i" ] && ARGDESC="$ARGDESC depth=$i" && break
    i=$((i + 1))
done

[ -n "$ARGDESC" ] && log_step "MODE" "$ARGDESC"

# Keybox Handling
for f in keybox keybox2; do
    KEY_FLAG="$BOX/$f"
    SRC="$TARGET_DIR/$f.xml"

    [ "$f" = "keybox2" ] && DEST="/sdcard/aosp.xml" || DEST="/sdcard/$f.xml"

    su -c "[ -e \"$KEY_FLAG\" ] && [ -r \"$SRC\" ] && cat \"$SRC\" > \"$DEST\" && sync" >/dev/null 2>&1
done

# Fingerprint
if [ -f "$MODPATH/osm0sis.sh" ]; then
    echo " "
    sh "$MODPATH/osm0sis.sh" && log_step "UPDATED" "Fingerprint" || log_step "FAILED" "osm0sis.sh"
else
    echo " "
    log_step "WARNING" "Missing osm0sis.sh, re-flash the module"
fi

# Migrate
MARGS=""
MDESC=""

[ -f "$BOX/migrate_force" ]    && MARGS="$MARGS -f" && MDESC="$MDESC force "
[ -f "$BOX/migrate_override" ] && MARGS="$MARGS -o" && MDESC="$MDESC override "
[ -f "$BOX/migrate_advanced" ] && MARGS="$MARGS -a" && MDESC="$MDESC advanced "

HAS_JSON=0
HAS_PROP=0
[ -f "$BOX/migrate_json" ] && HAS_JSON=1
[ -f "$BOX/migrate_prop" ] && HAS_PROP=1

if [ "$HAS_JSON" -eq 1 ] && [ "$HAS_PROP" -eq 1 ]; then
    log_step "WARNING" "Migrate Format Conflict"
    MARGS="$MARGS -p"
    MDESC="$MDESC prop"
elif [ "$HAS_JSON" -eq 1 ]; then
    MARGS="$MARGS -j"
    MDESC="$MDESC json"
elif [ "$HAS_PROP" -eq 1 ]; then
    MARGS="$MARGS -p"
    MDESC="$MDESC prop"
fi

if [ -f "$BOX/run_migrate" ]; then
    if sh "$MODPATH/migrate.sh" $MARGS >>"$CPP" 2>&1; then
        MIGRATE_OK=1
        log_step "MIGRATE" "Pixel RAW Fingerprint"
    else
        log_step "WARNING" "migrate.sh failed ($MDESC)"
    fi
else
    log_step "SKIPPED" "migrate.sh disabled"
fi

# Expiry Handling
if [ "$MIGRATE_OK" -eq 1 ] && [ -f "$BOX/remove_expiry" ]; then
    sed -i '/Released On:/d;/Estimated Expiry:/d' "$PIF_PROP"
    log_step "REMOVED" "Expiry comment removed"
else
    log_step "SKIPPED" "Expiry handling"
fi

# JSON Export
if [ "$MIGRATE_OK" -eq 1 ] && [ -f "$BOX/json" ] && [ ! -f "$BOX/skip_json" ] && [ -f "$PIF_PROP" ]; then
    {
        echo "{"
        echo '  "BuildFields": {'
        first=1
        skip_section=0
        while IFS= read -r line; do
            case "$line" in
                "# Advanced Settings"*) skip_section=1; continue ;;
                "# Build Fields"*|"# System Properties"*) skip_section=0; continue ;;
                \#*|"") continue ;;
            esac
            [ "$skip_section" -eq 1 ] && continue
            case "$line" in
                *=*) ;;
                *) continue ;;
            esac
            key="${line%%=*}"
            val="${line#*=}"
            key="${key#*.}"
            key="${key#*}"
            [ "$first" -eq 0 ] && echo ","
            printf '    "%s": "%s"' "$key" "$val"
            first=0
        done < "$PIF_PROP"
        echo
        echo "  }"
        echo "}"
    } > "$OUTJSON"
    log_step "CREATED" "PIF.json to $OUTJSON"
else
    log_step "SKIPPED" "PIF.json dump"
fi


# Targets
rebuild_targets "com.android.vending com.google.android.gms com.google.android.gsf io.github.qwq233.keyattestation io.github.vvb2060.keyattestation com.google.android.apps.walletnfcrel com.google.android.apps.messaging"

# Write security_patch.txt based on patch flag
if [ -f "$PATCH_FLAG" ]; then
  echo "system=prop" > "$FILE_PATH" 2>>"$PATCH_LOG"
  log_step "UPDATED" "Patch to Stock"

else
  echo "all=$PATCH_DATE" > "$FILE_PATH" 2>>"$PATCH_LOG"
  log_step "SPOOFED" "Tricky Patch to $PATCH_DATE"

  CURRENT_PROP="$(getprop "$PROP_MAIN" | tr -d ' \t\r\n')"
  log_patch "Current $PROP_MAIN: $CURRENT_PROP"

  # Skip resetprop if skip file exists
  if [ -f "$SKIP_FILE" ]; then
    log_step "SKIPPED" "Skip file present, resetprop disabled"

  # Skip resetprop only for Oplus devices
  elif [ "$BRAND_PROP" = "oplus" ]; then
    log_step "ONEPLUS" "Avoiding due to hardware issues"

  else
    if [ "$CURRENT_PROP" != "$PATCH_DATE" ]; then
      if command -v resetprop >/dev/null 2>&1; then
        resetprop "$PROP_MAIN" "$PATCH_DATE"
        log_step "PATCHED" "$PROP_MAIN to $PATCH_DATE"
      else
        log_step "FAILED" "resetprop not found"
      fi
    else
      log_step "MASKING" "System & Vendor patch not required"
    fi
  fi
fi

log_patch "Patch handling complete"
log_patch " "

for proc in com.google.android.gms.unstable com.google.android.gms com.android.vending; do
  kill_process "$proc"
done

log_step "RESTART" "Google Service Processes"

sh "$SCRIPT_DIR/cleanup.sh" >/dev/null 2>&1; 

# Execute teesim.sh unless explicitly disabled (script ships with TEEsim installs; skip when absent)
if [ ! -e "$BOX/teesim" ] && [ -f "$SCRIPT_DIR/teesim.sh" ]; then
    sh "$SCRIPT_DIR/teesim.sh"
    log_step "WRITING" "TEEsim Build fields"
fi

# Restore per-App-Spoofing value
if [ -f "$PIF_PROP" ]; then
    if [ -f "$SPOOF_APPS" ]; then
        sed -i 's/^spoofApps=.*/spoofApps=1/' "$PIF_PROP"
    else
        sed -i 's/^spoofApps=.*/spoofApps=0/' "$PIF_PROP"
    fi
fi

# Update module description
update_description() {
    bb="$(find_busybox)"
    [ -z "$bb" ] && return 0

    # Model
    MODEL=""
    [ -f "$PIF_PROP" ] && MODEL=$($bb sed -n 's/^MODEL=//p' "$PIF_PROP" | $bb head -n1)
    [ -z "$MODEL" ] && MODEL="Unknown"

    # Targets
    T=0
    [ -f "$TARGET_DIR/target.txt" ] && T=$($bb grep -c '.' "$TARGET_DIR/target.txt" 2>/dev/null | $bb tr -d ' ')
    [ -z "$T" ] && T=0

    # Spoofed apps
    S=0
    SPOOF_APPS_VAL=""
    [ -f "$PIF_PROP" ] && SPOOF_APPS_VAL=$($bb sed -n 's/^spoofApps=//p' "$PIF_PROP" | $bb head -n1)

    if [ "$SPOOF_APPS_VAL" = "1" ]; then
        [ -f "/data/adb/modules/playintegrityfix/apps.txt" ] && S=$($bb grep -c '.' "/data/adb/modules/playintegrityfix/apps.txt" 2>/dev/null | $bb tr -d ' ')
        [ -z "$S" ] && S=0
    fi

    # Blocked
    B=0
    [ -f "$BOX/blacklist.txt" ] && B=$($bb grep -c '.' "$BOX/blacklist.txt" 2>/dev/null | $bb tr -d ' ')
    [ -z "$B" ] && B=0

    DESC="$MODEL    Targets: $T    Spoofed: $S    Blocked: $B"

    [ ! -f "$BAK" ] && $bb cp "$PROP" "$BAK"
    $bb sed -i '/^description=/d' "$PROP"
    echo "description=$DESC" >> "$PROP"
}

update_description || true

echo "    -- ACTION COMPLETED SUCCESSFULLY --"
handle_delay
exit 0
