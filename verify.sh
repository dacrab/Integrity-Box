#!/system/bin/sh

UPDATE="/data/adb/modules_update/playintegrityfix"
HASHFILE="$UPDATE/hash"

if [ ! -s "$HASHFILE" ]; then
    echo "Hash file missing or empty: $HASHFILE"
    exit 1
fi

CHECKED=0

while IFS='|' read -r RELPATH EXPECT_SHA256 || [ -n "$RELPATH" ]; do
    [ -z "$RELPATH" ] && continue
    FILE="$UPDATE/$RELPATH"

    if [ ! -f "$FILE" ]; then
        echo "File $FILE not found!"
        exit 1
    fi

    ACTUAL_SHA256=$(sha256sum "$FILE" | awk '{print $1}')

    if [ "$ACTUAL_SHA256" != "$EXPECT_SHA256" ]; then
        echo "Hash mismatch for $FILE (Expected: $EXPECT_SHA256, Got: $ACTUAL_SHA256)"
        exit 1
    fi

    CHECKED=$((CHECKED + 1))
done < "$HASHFILE"

if [ "$CHECKED" -eq 0 ]; then
    echo "No entries to verify in $HASHFILE"
    exit 1
fi
