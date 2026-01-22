#!/system/bin/sh

SKIPUNZIP=0

ui_print "****************************************"
ui_print "*      Pixel Carrier Optimization      *"
ui_print "*           By transwarp               *"
ui_print "****************************************"
ui_print "* Unlocking 5G SA/NSA, VoLTE, VoNR..."
ui_print "* Optimizing Signal Handover (QNS)..."
ui_print "* Fixing GPS PSDS Sources..."
ui_print "* Applying UI Enhancements..."
ui_print "****************************************"

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
