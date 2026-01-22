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

# Target file
# Using wildcard because the file name might vary slightly or have a hash
TARGET_DIR="/data/user_de/0/com.android.phone/files"
TARGET_FILE=""
CARRIER_ID="1436"

# Wait for the file
for i in $(seq 1 60); do
    # Find file containing 1436 and China_Unicom
    TARGET_FILE=$(find "$TARGET_DIR" -name "*carrier_config*${CARRIER_ID}*.xml" | head -n 1)
    if [ -f "$TARGET_FILE" ]; then
        log "Found target file: $TARGET_FILE"
        break
    fi
    sleep 2
done

if [ ! -f "$TARGET_FILE" ]; then
    log "Target file not found after waiting. Exiting."
    exit 1
fi

# Backup
cp "$TARGET_FILE" "$TARGET_FILE.bak"
chmod 660 "$TARGET_FILE.bak"
chown radio:radio "$TARGET_FILE.bak"

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
    remove_key "$key" "$TARGET_FILE"
    # Insert before closing tag (temporarily remove closing tag and append)
    sed -i "/<\/carrier_config>/d" "$TARGET_FILE"
    echo "    <boolean name=\"$key\" value=\"$value\" />" >> "$TARGET_FILE"
    echo "</carrier_config>" >> "$TARGET_FILE"
}

upsert_string() {
    local key="$1"
    local value="$2"
    remove_key "$key" "$TARGET_FILE"
    sed -i "/<\/carrier_config>/d" "$TARGET_FILE"
    echo "    <string name=\"$key\">$value</string>" >> "$TARGET_FILE"
    echo "</carrier_config>" >> "$TARGET_FILE"
}

upsert_int() {
    local key="$1"
    local value="$2"
    remove_key "$key" "$TARGET_FILE"
    sed -i "/<\/carrier_config>/d" "$TARGET_FILE"
    echo "    <int name=\"$key\" value=\"$value\" />" >> "$TARGET_FILE"
    echo "</carrier_config>" >> "$TARGET_FILE"
}

upsert_int_array() {
    local key="$1"
    shift
    local count=$#
    remove_key "$key" "$TARGET_FILE"

    local block="    <int-array name=\"$key\" num=\"$count\">"
    # Use loop to append items
    echo "$block" >> "$MODDIR/temp_block.xml"
    for item in "$@"; do
        echo "        <item value=\"$item\" />" >> "$MODDIR/temp_block.xml"
    done
    echo "    </int-array>" >> "$MODDIR/temp_block.xml"

    sed -i "/<\/carrier_config>/d" "$TARGET_FILE"
    cat "$MODDIR/temp_block.xml" >> "$TARGET_FILE"
    echo "</carrier_config>" >> "$TARGET_FILE"
    rm "$MODDIR/temp_block.xml"
}

upsert_string_array() {
    local key="$1"
    shift
    local count=$#
    remove_key "$key" "$TARGET_FILE"

    echo "    <string-array name=\"$key\" num=\"$count\">" > "$MODDIR/temp_block.xml"
    for item in "$@"; do
        echo "        <item value=\"$item\" />" >> "$MODDIR/temp_block.xml"
    done
    echo "    </string-array>" >> "$MODDIR/temp_block.xml"

    sed -i "/<\/carrier_config>/d" "$TARGET_FILE"
    cat "$MODDIR/temp_block.xml" >> "$TARGET_FILE"
    echo "</carrier_config>" >> "$TARGET_FILE"
    rm "$MODDIR/temp_block.xml"
}

# --- Apply Changes ---

log "Applying 5G & IMS Unlock..."
upsert_int_array "carrier_nr_availabilities_int_array" 1 2
upsert_boolean "carrier_volte_available_bool" "true"
upsert_boolean "carrier_vonr_available_bool" "true"
upsert_boolean "carrier_wfc_ims_available_bool" "true"
upsert_boolean "carrier_wfc_ims_roaming_available_bool" "true"
upsert_boolean "unmetered_nr_nsa_mmwave_bool" "true"
upsert_boolean "unmetered_nr_nsa_sub6_bool" "true"
upsert_boolean "unmetered_nr_sa_mmwave_bool" "true"
upsert_boolean "unmetered_nr_sa_sub6_bool" "true"

log "Applying Subway Signal Optimization..."
# QNS handover guarding timer (1000ms)
upsert_int "qns_handover_guarding_timer_millis_int" 1000

# qns.voice_ngran_ssrsrp_int_array (Lower to -124dBm)
upsert_int_array "qns.voice_ngran_ssrsrp_int_array" -124 -124 -124 -124

log "Applying GPS Corrections..."
# Replace agnss.goog PSDS/LTO servers with Broadcom
URLS="http://gllto.glpals.com/7day/v2/latest/lto2.dat"
URLS2="http://gllto.glpals.com/7day/v2/latest/lto.dat"
URLS3="http://gllto1.glpals.com/7day/v2/latest/lto2.dat"
URLS4="http://gllto1.glpals.com/7day/v2/latest/lto.dat"
upsert_string_array "gps.psds_servers_string_array" "$URLS" "$URLS2" "$URLS3" "$URLS4"

log "Applying UI Enhancements..."
# Enable 5G+ for N78
upsert_int_array "additional_nr_advanced_bands_int_array" 77 78

# Icon config
upsert_string "5g_icon_configuration_string" "connected_mmwave:5G_PLUS,connected:5G,not_restricted_rrc_idle:5G,not_restricted_rrc_con:5G"

# Signal Bars
upsert_int_array "lte_rsrp_thresholds_int_array" -125 -115 -105 -95
upsert_int_array "nr_rsrp_thresholds_int_array" -125 -115 -105 -95

# Fix permissions
chown radio:radio "$TARGET_FILE"
chmod 660 "$TARGET_FILE"

log "Done. Changes applied."
