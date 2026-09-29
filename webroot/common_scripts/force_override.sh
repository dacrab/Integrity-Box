#!/system/bin/sh

L=/data/adb/Box-Brain/Integrity-Box-Logs/ForceSpoof.log
mkdir -p "${L%/*}"

command -v resetprop >/dev/null 2>&1 || { echo "[ERROR] resetprop not found" | tee -a "$L"; exit 1; }

getprop | grep -i lineage | while read -r l; do
    p=${l#*[}; p=${p%%]*}
    echo "$(date '+%F %T') DEL $p" >> "$L"
    resetprop -d "$p"
done
