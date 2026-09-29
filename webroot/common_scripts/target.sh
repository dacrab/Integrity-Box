#!/system/bin/sh
MODPATH="/data/adb/modules/playintegrityfix"
. $MODPATH/common_func.sh

rebuild_targets "com.android.vending com.google.android.gms com.google.android.gsf io.github.qwq233.keyattestation io.github.vvb2060.keyattestation com.google.android.apps.walletnfcrel com.google.android.apps.messaging"

exit 0
