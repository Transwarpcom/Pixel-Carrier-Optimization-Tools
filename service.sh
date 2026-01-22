#!/system/bin/sh
MODDIR=${0%/*}
LOGFILE="$MODDIR/service.log"

log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" >> "$LOGFILE"
}

log "Service started."

# Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
log "Boot completed."

# Execute core logic
# Wait for file to exist is handled inside service.sh because core.sh just checks once.
# But actually, core.sh as designed above checks once.
# We need the waiting loop here.

TARGET_DIR="/data/user_de/0/com.android.phone/files"
FOUND=0
for i in $(seq 1 60); do
    if [ -d "$TARGET_DIR" ]; then
        if ls "$TARGET_DIR" | grep -qE "carrier_config"; then
             FOUND=1
             break
        fi
    fi
    sleep 2
done

if [ "$FOUND" -eq 1 ]; then
    log "Files detected. Running core.sh..."
    sh "$MODDIR/core.sh"

    # Reload
    log "Reloading carrier config..."
    killall com.android.phone
else
    log "No carrier config files found after waiting."
fi
