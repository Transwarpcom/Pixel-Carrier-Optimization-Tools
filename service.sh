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

# Target directory
TARGET_DIR="/data/user_de/0/com.android.phone/files"

# Wait for at least one target file to appear
FOUND_FILES=""
for i in $(seq 1 60); do
    # Find all carrier config files
    CANDIDATES=$(find "$TARGET_DIR" -type f -name "*carrier_config*.xml")
    FOUND_FILES=""
    for f in $CANDIDATES; do
        if echo "$f" | grep -qE "China_Unicom|China_Telecom"; then
            FOUND_FILES="$FOUND_FILES $f"
        fi
    done

    if [ -n "$FOUND_FILES" ]; then
        log "Found target file(s):$FOUND_FILES"
        break
    fi
    sleep 2
done

if [ -z "$FOUND_FILES" ]; then
    log "No target files (Unicom/Telecom) found after waiting. Exiting."
    exit 1
fi

# Function to remove existing key
remove_key() {
    local key="$1"
    local file="$2"
    # Remove single line entries (boolean, string, int)
    sed -i "/name=\"$key\"/d" "$file"

    # Remove array blocks.
    # We assume valid XML formatting where <int-array ...> is start and </int-array> is end.
    sed -i "/<int-array name=\"$key\"/,/<\/int-array>/d" "$file"
    sed -i "/<string-array name=\"$key\"/,/<\/string-array>/d" "$file"
    # Remove multi-line strings if any
    sed -i "/<string name=\"$key\">/,/<\/string>/d" "$file"
}

# Insert functions
upsert_boolean() {
    local key="$1"
    local value="$2"
    local file="$3"
    remove_key "$key" "$file"
    # Insert before closing tag (temporarily remove closing tag and append)
    sed -i "/<\/carrier_config>/d" "$file"
    echo "    <boolean name=\"$key\" value=\"$value\" />" >> "$file"
    echo "</carrier_config>" >> "$file"
}

upsert_string() {
    local key="$1"
    local value="$2"
    local file="$3"
    remove_key "$key" "$file"
    sed -i "/<\/carrier_config>/d" "$file"
    echo "    <string name=\"$key\">$value</string>" >> "$file"
    echo "</carrier_config>" >> "$file"
}

upsert_int() {
    local key="$1"
    local value="$2"
    local file="$3"
    remove_key "$key" "$file"
    sed -i "/<\/carrier_config>/d" "$file"
    echo "    <int name=\"$key\" value=\"$value\" />" >> "$file"
    echo "</carrier_config>" >> "$file"
}

upsert_int_array() {
    local key="$1"
    local file="$2"
    shift 2
    local count=$#
    remove_key "$key" "$file"

    local block="    <int-array name=\"$key\" num=\"$count\">"
    # Use loop to append items
    echo "$block" >> "$MODDIR/temp_block.xml"
    for item in "$@"; do
        echo "        <item value=\"$item\" />" >> "$MODDIR/temp_block.xml"
    done
    echo "    </int-array>" >> "$MODDIR/temp_block.xml"

    sed -i "/<\/carrier_config>/d" "$file"
    cat "$MODDIR/temp_block.xml" >> "$file"
    echo "</carrier_config>" >> "$file"
    rm "$MODDIR/temp_block.xml"
}

upsert_string_array() {
    local key="$1"
    local file="$2"
    shift 2
    local count=$#
    remove_key "$key" "$file"

    echo "    <string-array name=\"$key\" num=\"$count\">" > "$MODDIR/temp_block.xml"
    for item in "$@"; do
        echo "        <item value=\"$item\" />" >> "$MODDIR/temp_block.xml"
    done
    echo "    </string-array>" >> "$MODDIR/temp_block.xml"

    sed -i "/<\/carrier_config>/d" "$file"
    cat "$MODDIR/temp_block.xml" >> "$file"
    echo "</carrier_config>" >> "$file"
    rm "$MODDIR/temp_block.xml"
}

# --- Apply Changes ---
for TARGET_FILE in $FOUND_FILES; do
    log "Processing $TARGET_FILE..."

    # Backup
    if [ ! -f "$TARGET_FILE.bak" ]; then
        cp "$TARGET_FILE" "$TARGET_FILE.bak"
        chmod 660 "$TARGET_FILE.bak"
        chown radio:radio "$TARGET_FILE.bak"
    fi

    log "Applying 5G & IMS Unlock to $TARGET_FILE..."
    upsert_int_array "carrier_nr_availabilities_int_array" "$TARGET_FILE" 1 2
    upsert_boolean "carrier_volte_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_vonr_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_wfc_ims_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_wfc_ims_roaming_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_nsa_mmwave_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_nsa_sub6_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_sa_mmwave_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_sa_sub6_bool" "true" "$TARGET_FILE"

    log "Applying Subway Signal Optimization to $TARGET_FILE..."
    # QNS handover guarding timer (1000ms)
    upsert_int "qns_handover_guarding_timer_millis_int" 1000 "$TARGET_FILE"

    # qns.voice_ngran_ssrsrp_int_array (Lower to -124dBm)
    upsert_int_array "qns.voice_ngran_ssrsrp_int_array" "$TARGET_FILE" -124 -124 -124 -124

    log "Applying GPS Corrections to $TARGET_FILE..."
    # Replace agnss.goog PSDS/LTO servers with Broadcom (v5 for Pixel 6/7/8)
    URLS="https://gllto.glpals.com/7day/v5/latest/lto2.dat"
    URLS2="https://gllto1.glpals.com/7day/v5/latest/lto2.dat"
    upsert_string_array "gps.psds_servers_string_array" "$TARGET_FILE" "$URLS" "$URLS2"

    log "Applying UI Enhancements to $TARGET_FILE..."
    # Enable 5G+ for N78
    upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 77 78

    # Icon config
    upsert_string "5g_icon_configuration_string" "connected_mmwave:5G_PLUS,connected:5G,not_restricted_rrc_idle:5G,not_restricted_rrc_con:5G" "$TARGET_FILE"

    # Signal Bars
    upsert_int_array "lte_rsrp_thresholds_int_array" "$TARGET_FILE" -125 -115 -105 -95
    upsert_int_array "nr_rsrp_thresholds_int_array" "$TARGET_FILE" -125 -115 -105 -95

    # Fix permissions
    chown radio:radio "$TARGET_FILE"
    chmod 660 "$TARGET_FILE"
done

log "Done. Changes applied."
