#!/system/bin/sh

UPDATE="/data/adb/modules_update/playintegrityfix"
HASHFILE="$UPDATE/hash"

if [ ! -f "$HASHFILE" ]; then
    echo " ✦ Hash file not found: $HASHFILE"
    exit 1
fi

while IFS='|' read -r RELPATH EXPECT_SHA256; do
    # Skip blank lines and comments
    case "$RELPATH" in ''|'#'*) continue ;; esac

    FILE="$UPDATE/$RELPATH"

    if [ ! -f "$FILE" ]; then
        echo " ✦ File $FILE not found!"
        exit 1
    fi

    ACTUAL_SHA256=$(sha256sum "$FILE" | awk '{print $1}')

    if [ "$ACTUAL_SHA256" != "$EXPECT_SHA256" ]; then
        echo " ✦ Hash mismatch for $FILE (Expected: $EXPECT_SHA256, Got: $ACTUAL_SHA256)"
        exit 1
    fi
done < "$HASHFILE"
