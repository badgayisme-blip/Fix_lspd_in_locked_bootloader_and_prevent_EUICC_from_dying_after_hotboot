#!/system/bin/sh

MODDIR="${0%/*}"

# Set component permissions
chmod 755 "$MODDIR/main" 2>/dev/null
chmod 755 "$MODDIR/YHyc" 2>/dev/null
chmod 755 "$MODDIR/service.sh" 2>/dev/null
chmod 755 "$MODDIR/action.sh" 2>/dev/null
[ -f "$MODDIR/system/bin/fix-euicc" ] && chmod 755 "$MODDIR/system/bin/fix-euicc" 2>/dev/null

ui_print "========================================"
ui_print " KernelSU LSPosed & eUICC Fix           "
ui_print "========================================"
ui_print "- All components and permissions ready."
ui_print "- eUICC hot-reboot protection enabled."
ui_print "- Standalone 'fix-euicc' CLI installed."
ui_print "- 100% offline installation completed."
