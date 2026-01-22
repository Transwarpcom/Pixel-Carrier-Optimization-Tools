#!/system/bin/sh
# action.sh - Triggered by KernelSU/Magisk Manager

MODDIR=${0%/*}
LOGFILE="$MODDIR/service.log"

echo "Applying Pixel Carrier Optimization..."

# Execute core logic immediately
if sh "$MODDIR/core.sh"; then
    echo "XML modifications applied."
    echo "Reloading Carrier Configuration (restarting phone process)..."
    killall com.android.phone
    echo "Done! Changes should be active."
else
    echo "Error: Failed to apply changes. Check log at $LOGFILE."
    exit 1
fi
