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

    # --- A. Basic Network Unlock ---
    log "Applying 5G & IMS Unlock..."
    # 5G SA/NSA (1=NSA, 2=SA)
    upsert_int_array "carrier_nr_availabilities_int_array" "$TARGET_FILE" 1 2

    # VoLTE / VoNR / VoWiFi / ViLTE
    upsert_boolean "carrier_volte_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "vonr_enabled_bool" "true" "$TARGET_FILE"
    upsert_boolean "vonr_setting_visibility_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_wfc_ims_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_vt_available_bool" "true" "$TARGET_FILE"

    # --- B. Subway & Signal Handover (QNS) ---
    log "Applying Signal Handover Optimizations..."
    # Reduce handover guard timer to 1s
    remove_key "qns.ho_restrict_time_with_low_rtp_quality_int_array" "$TARGET_FILE"
    upsert_int "qns.minimum_handover_guarding_timer_ms_int" 1000 "$TARGET_FILE"

    # Deep 5G Lock (Voice & Idle)
    # Lower threshold to -124dBm to prevent dropping 5G
    upsert_int_array "qns.voice_ngran_ssrsrp_int_array" "$TARGET_FILE" -120 -124
    upsert_int_array "qns.idle_ngran_ssrsrp_int_array" "$TARGET_FILE" -120 -124

    # VoWiFi Thresholds (Relax to -90dBm)
    upsert_int_array "qns.voice_wifi_rssi_int_array" "$TARGET_FILE" -85 -90
    upsert_int_array "qns.idle_wifi_rssi_int_array" "$TARGET_FILE" -85 -90

    # --- C. Traffic & Performance ---
    log "Applying Traffic & Performance Fixes..."
    # Unmetered 5G
    upsert_boolean "unmetered_nr_nsa_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_sa_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_nsa_mmwave_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_sa_mmwave_bool" "true" "$TARGET_FILE"

    # TCP Buffers
    upsert_string "tcp_buffersizes_string" "2097152,4194304,8388608,4096,1048576,4194304" "$TARGET_FILE"

    # --- D. Visual & UI ---
    log "Applying UI Enhancements..."
    # 5G+ Icon (N78)
    upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 78

    # 4G Icon
    upsert_boolean "show_4g_for_lte_data_icon_bool" "true" "$TARGET_FILE"
    upsert_boolean "editable_enhanced_4g_lte_bool" "true" "$TARGET_FILE"

    # Icon config - Update to display 5G_PLUS for connected_mmwave
    upsert_string "5g_icon_configuration_string" "connected_mmwave:5G_PLUS,connected:5G,connected_rrc_idle:5G,not_restricted_rrc_idle:5G,not_restricted_rrc_con:5G" "$TARGET_FILE"

    # Signal Bars (Honest Display)
    # 5G: [-125, -115, -105, -95]
    upsert_int_array "5g_nr_ssrsrp_thresholds_int_array" "$TARGET_FILE" -125 -115 -105 -95
    # LTE: [-125, -115, -105, -95]
    upsert_int_array "lte_rsrp_thresholds_int_array" "$TARGET_FILE" -125 -115 -105 -95
    # Signal Quality (SNR)
    upsert_int_array "5g_nr_ssrsrq_thresholds_int_array" "$TARGET_FILE" -43 -20 -15 -10

    # --- E. GPS/GNSS Fix ---
    log "Applying GPS Corrections..."
    # Use Broadcom v5 servers directly
    upsert_string "gps.normal_psds_server" "https://gllto.glpals.com/rto/v1/latest/rto.dat" "$TARGET_FILE"
    upsert_string "gps.longterm_psds_server_1" "https://gllto.glpals.com/7day/v5/latest/lto2.dat" "$TARGET_FILE"
    upsert_string "gps.realtime_psds_server" "https://gllto.glpals.com/rtistatus4.dat" "$TARGET_FILE"

    # --- F. Advanced / Misc ---
    log "Applying Advanced Fixes (APN, RCS)..."
    # APN Freedom
    remove_key "read_only_apn_types_string_array" "$TARGET_FILE"
    remove_key "read_only_apn_fields_string_array" "$TARGET_FILE"
    upsert_boolean "apn_expand_bool" "true" "$TARGET_FILE"

    # RCS Fix (Disable provisioning check)
    upsert_boolean "carrier_rcs_provisioning_required_bool" "false" "$TARGET_FILE"

    # SMS Reliability
    upsert_int "imssms.sms_max_retry_over_ims_count_int" 3 "$TARGET_FILE"

    # Video Call Data
    upsert_boolean "ignore_data_enabled_changed_for_video_calls" "true" "$TARGET_FILE"

    # Fix permissions
    chown radio:radio "$TARGET_FILE"
    chmod 660 "$TARGET_FILE"
done

log "Done. All changes applied."
