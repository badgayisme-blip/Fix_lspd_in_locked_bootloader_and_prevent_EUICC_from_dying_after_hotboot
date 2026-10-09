#!/system/bin/sh
MODDIR="/data/adb/modules/YH_YC"

# Ensure execution permissions
chmod 755 "$MODDIR/main" 2>/dev/null
chmod 755 "$MODDIR/YHyc" 2>/dev/null

# [1] Pre-hotreboot: Cleanly stop EasyEUICC and Secure Element service to prevent channel leaks
am force-stop im.angry.easyeuicc 2>/dev/null
am force-stop com.android.se 2>/dev/null

# [2] Execute the native revival binary to restart Zygote & restore LSPosed
"$MODDIR/main" --fix-lsp

# [3] Post-hotreboot: Reset vendor Secure Element HAL and cycle baseband radio to restore eUICC
pkill -9 -f android.hardware.secure_element 2>/dev/null
svc telephony radio off 2>/dev/null
sleep 1
svc telephony radio on 2>/dev/null
sleep 1
am force-stop com.android.se 2>/dev/null
