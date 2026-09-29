#!/system/bin/sh

MODPATH="/data/adb/modules/playintegrityfix"
UPDATEPATH="/data/adb/modules_update/playintegrityfix"

# Load common functions
if [ -f "$MODPATH/common_func.sh" ]; then
    . "$MODPATH/common_func.sh"
elif [ -f "$UPDATEPATH/common_func.sh" ]; then
    . "$UPDATEPATH/common_func.sh"
else
    echo "ERROR: common_func.sh not found"
    exit 1
fi

# Paths
RECORD="/data/adb/Box-Brain"
TRICKY_STORE="/data/adb/tricky_store"
KEYBOX="$TRICKY_STORE/keybox.xml"
LOG_FILE="$RECORD/Integrity-Box-Logs/keybox.log"
TEMP_FILE="$(mktemp -p /data/local/tmp)"
CLEANUP="$MODPATH/webroot/common_scripts/cleanup.sh"
UCLEANUP="$UPDATEPATH/webroot/common_scripts/cleanup.sh"
BACKUP_DIR="$RECORD/KeyBackup"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
KEYBOX_BACKUP="$BACKUP_DIR/keybox_$TIMESTAMP.xml"
SIM_KEY="/data/adb/teesim/keybox.xml"
SIM_KEYBACKUP="$SIM_KEY.bak"

log() {
    echo "$*" | tee -a "$LOG_FILE"
}

# Cleanup every temp file on exit, including the decode chain
TMP_FILES="$TEMP_FILE"
cleanup_tmp() { rm -f $TMP_FILES; }
trap cleanup_tmp EXIT

# Create directories
mkdir -p "$TRICKY_STORE" "$RECORD" "$RECORD/Integrity-Box-Logs" "$BACKUP_DIR"
touch "$LOG_FILE"

# Get busybox path
BB=$(P)

# Backup existing keybox with timestamp
if [ -s "$KEYBOX" ]; then
    cp -f "$KEYBOX" "$KEYBOX_BACKUP"
    log "Backed up default keybox"
fi

# Keybox download URL
KEYBOX_URL="https://raw.githubusercontent.com/MeowDump/MeowDump/refs/heads/main/Megatron"

# Known GitHub raw CDN IPs, used only as a last-resort DNS bypass
GITHUB_IPS="185.199.108.133 185.199.109.133 185.199.110.133 185.199.111.133"

# Try one transport. $1 = url, $2 = output, $3 = optional GitHub CDN IP.
# With an IP we use curl --resolve so TLS SNI and the Host header both
# stay correct; a bare https://IP/ URL would negotiate the wrong vhost.
_fetch() {
    _url="$1"
    _out="$2"
    _ip="$3"

    rm -f "$_out"

    if [ -n "$_ip" ] && command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 60 --insecure \
             --resolve "raw.githubusercontent.com:443:$_ip" \
             "$_url" -o "$_out" 2>/dev/null && [ -s "$_out" ] && return 0
    elif [ -n "$BB" ] && [ -z "$_ip" ]; then
        "$BB" wget -q --no-check-certificate -T 15 -t 1 -O "$_out" "$_url" 2>/dev/null && [ -s "$_out" ] && return 0
    elif [ -z "$_ip" ] && command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --timeout=15 --tries=1 -O "$_out" "$_url" 2>/dev/null && [ -s "$_out" ] && return 0
    elif [ -z "$_ip" ] && command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 60 --insecure "$_url" -o "$_out" 2>/dev/null && [ -s "$_out" ] && return 0
    fi

    return 1
}

# Download the keybox: retries, then a DNS-bypass pass over the CDN IPs.
download_keybox() {
    _url="$1"
    _out="$2"
    _attempts="${3:-3}"

    _n=1
    while [ "$_n" -le "$_attempts" ]; do
        log "Download attempt $_n/$_attempts..."
        _fetch "$_url" "$_out" && { log "Download succeeded"; return 0; }
        _n=$((_n + 1))
        [ "$_n" -le "$_attempts" ] && sleep 2
    done

    if [ "$_attempts" -gt 1 ]; then
        for _ip in $GITHUB_IPS; do
            log "Retrying via GitHub CDN ($_ip)..."
            _fetch "$_url" "$_out" "$_ip" && { log "Download succeeded (direct IP)"; return 0; }
        done
    fi

    return 1
}

log "Fetching keybox from GitHub..."
if ! download_keybox "$KEYBOX_URL" "$TEMP_FILE" "${KEYBOX_RETRIES:-3}"; then
    log "ERROR: Download failed - check your connection or DNS"
    exit 3
fi

# Check download succeeded
if [ ! -s "$TEMP_FILE" ]; then
    log "ERROR: Download failed - check internet connection"
    rm -f "$TEMP_FILE"
    exit 3
fi

# Decode the downloaded file
# The file is encoded as: base64 > hex > ROT13
log "Decoding keybox file..."

TMP_HEX="$(mktemp -p /data/local/tmp)"
TMP_FILES="$TMP_FILES $TMP_HEX"

# The upstream payload is base64 nested KEYBOX_DEPTH times around a hex
# layer. Base64 only until the remaining bytes are pure hex, which is the
# layer the hex decoder expects. A hex string is itself valid base64, so
# "keep decoding until it fails" would never terminate.
is_hex() {
    case "$1" in
        ""|*[!0-9A-Fa-f]*) return 1 ;;
    esac
    [ $(( ${#1} % 2 )) -eq 0 ]
}

CURRENT="$TEMP_FILE"
DEPTH=0
while [ "$DEPTH" -lt "${KEYBOX_DEPTH:-16}" ] && ! is_hex "$(cat "$CURRENT")"; do
    DEPTH=$((DEPTH + 1))
    NEXT="$(mktemp -p /data/local/tmp)"
    TMP_FILES="$TMP_FILES $NEXT"

    if ! base64 -d "$CURRENT" > "$NEXT" 2>/dev/null || [ ! -s "$NEXT" ]; then
        rm -f "$NEXT"
        break
    fi

    rm -f "$CURRENT"
    CURRENT="$NEXT"
done
log "Base64 unwrapped (depth $DEPTH)"

# Hex decode (xxd is absent on most Android builds, fall back to busybox)
if command -v xxd >/dev/null 2>&1; then
    xxd -r -p "$CURRENT" > "$TMP_HEX" 2>/dev/null
elif [ -n "$BB" ] && "$BB" xxd -r -p "$CURRENT" > "$TMP_HEX" 2>/dev/null; then
    :
else
    log "ERROR: No hex decoder available (xxd)"
    exit 5
fi

if [ ! -s "$TMP_HEX" ]; then
    log "ERROR: Hex decoding failed"
    exit 5
fi
rm -f "$CURRENT"

# ROT13 decode
DECODED="$(mktemp -p /data/local/tmp)"
TMP_FILES="$TMP_FILES $DECODED"

if ! tr 'A-Za-z' 'N-ZA-Mn-za-m' < "$TMP_HEX" > "$DECODED"; then
    log "ERROR: ROT13 decoding failed"
    exit 6
fi
rm -f "$TMP_HEX"

# Only publish a keybox that actually decoded into something.
# The real payload uses <Keybox ...>, so match case-insensitively.
if [ ! -s "$DECODED" ] || ! grep -qi "<keybox" "$DECODED"; then
    log "ERROR: Decoded payload is not a keybox, keeping the current one"
    if [ -s "$KEYBOX_BACKUP" ]; then
        cp -f "$KEYBOX_BACKUP" "$KEYBOX"
        log "Restored backup keybox"
    fi
    exit 7
fi

mv -f "$DECODED" "$KEYBOX"
log "Keybox successfully updated"

# Clean temporary files
if [ -f "$CLEANUP" ]; then
  sh "$CLEANUP" > /dev/null 2>&1
elif [ -f "$UCLEANUP" ]; then
  sh "$UCLEANUP" > /dev/null 2>&1
fi

# OMK Keybox Support
OMK_DIR="/data/misc/keystore/omk"
OMK_KEYBOX="$OMK_DIR/keybox.xml"
OMK_KEYBOX_BAK="$OMK_DIR/keybox.xml.bak"

if [ -d "$OMK_DIR" ]; then
    if [ -s "$OMK_KEYBOX" ]; then
        cp -f "$OMK_KEYBOX" "$OMK_KEYBOX_BAK"
        log "OMK key backup created"
    fi
    cp -f "$KEYBOX" "$OMK_KEYBOX"
    log "Keybox added to OMK directory"
fi

# Backup TEE SIM keybox with timestamp
if [ -s "$SIM_KEY" ]; then
    cp -f "$SIM_KEY" "$SIM_KEYBACKUP"
    log "TEE-SIM key backup created"
fi

# Copy keybox to SIM path
if [ -d "/data/adb/teesim" ] && [ -s "$KEYBOX" ]; then
    cp -f "$KEYBOX" "$SIM_KEY"
    log "Keybox added to TEEsim directory"
fi
