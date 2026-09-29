#!/system/bin/sh

LOG_FILE="/data/adb/Box-Brain/Integrity-Box-Logs/pifhook.log"
mkdir -p "$(dirname "$LOG_FILE")"

if ! command -v resetprop >/dev/null 2>&1; then
    echo "[ERROR] resetprop not found" | tee -a "$LOG_FILE"
    exit 1
fi

# Compact resetprop builds do not accept -p
IS_COMPACT=false
if ! resetprop --help 2>&1 | grep -q -- "-p"; then
    IS_COMPACT=true
fi

echo "[INFO] Script started at $(date)" > "$LOG_FILE"
echo "[INFO] resetprop: compact=$IS_COMPACT" >> "$LOG_FILE"

resetprop_delete() {
    if [ "$IS_COMPACT" = "true" ]; then
        resetprop -d "$1"
    else
        resetprop -p -d "$1"
    fi
}

# Remove custom-ROM GMS spoofing hooks. The pattern is anchored on the
# known namespaces so unrelated props containing the letters "pi" survive.
getprop | grep -E '\[(persist\.sys\.(pphooks|pihooks|pixelprops|pp|spoof|entryhooks)[^]]*|.*\.gms[^]]*)\]:' \
    | sed -E 's/^\[(.*)\]:.*/\1/' | while IFS= read -r prop; do
    echo "[DELETE] $prop" >> "$LOG_FILE"
    if resetprop_delete "$prop"; then
        echo "[OK] Deleted: $prop" >> "$LOG_FILE"
    else
        echo "[FAIL] Failed to delete: $prop" >> "$LOG_FILE"
    fi
done

echo "[INFO] Task completed at $(date)" >> "$LOG_FILE"
