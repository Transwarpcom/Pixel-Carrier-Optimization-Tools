#!/system/bin/sh
# core.sh - Core logic for XML modification and mounting
# Performs both direct modification and mount --bind overlay

# If MODDIR is not set, try to determine it
if [ -z "$MODDIR" ]; then
    MODDIR=${0%/*}
fi

LOGFILE="$MODDIR/service.log"
CACHE_DIR="$MODDIR/carrier_cache"

log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" >> "$LOGFILE"
}

# Target directory
TARGET_DIR="/data/user_de/0/com.android.phone/files"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
chmod 755 "$CACHE_DIR"

# Find files
FOUND_FILES=""
if [ -d "$TARGET_DIR" ]; then
    CANDIDATES=$(find "$TARGET_DIR" -type f -name "*carrier_config*.xml")
    for f in $CANDIDATES; do
        if echo "$f" | grep -qE "China_Unicom|China_Telecom|China_Mobile|China_Broadnet|1435|1436|2236|mccmnc_460_15"; then
            FOUND_FILES="$FOUND_FILES $f"
        fi
    done
fi

if [ -z "$FOUND_FILES" ]; then
    log "No target files found in core.sh run."
    return 1 2>/dev/null || exit 1
fi

# Function to remove existing key
remove_key() {
    local key="$1"
    local file="$2"
    sed -i "/name=\"$key\"/d" "$file"
    sed -i "/<int-array name=\"$key\"/,/<\/int-array>/d" "$file"
    sed -i "/<string-array name=\"$key\"/,/<\/string-array>/d" "$file"
    sed -i "/<string name=\"$key\">/,/<\/string>/d" "$file"
}

# Insert functions
prepare_file_for_append() {
    local file="$1"
    sed -i "s/<\/carrier_config>//g" "$file"
}

finish_file() {
    local file="$1"
    echo "</carrier_config>" >> "$file"
}

upsert_boolean() {
    local key="$1"
    local value="$2"
    local file="$3"
    remove_key "$key" "$file"
    prepare_file_for_append "$file"
    echo "    <boolean name=\"$key\" value=\"$value\" />" >> "$file"
    finish_file "$file"
}

upsert_string() {
    local key="$1"
    local value="$2"
    local file="$3"
    remove_key "$key" "$file"
    prepare_file_for_append "$file"
    echo "    <string name=\"$key\">$value</string>" >> "$file"
    finish_file "$file"
}

upsert_int() {
    local key="$1"
    local value="$2"
    local file="$3"
    remove_key "$key" "$file"
    prepare_file_for_append "$file"
    echo "    <int name=\"$key\" value=\"$value\" />" >> "$file"
    finish_file "$file"
}

upsert_int_array() {
    local key="$1"
    local file="$2"
    shift 2
    local count=$#
    remove_key "$key" "$file"

    local block="    <int-array name=\"$key\" num=\"$count\">"
    echo "$block" >> "$MODDIR/temp_block.xml"
    for item in "$@"; do
        echo "        <item value=\"$item\" />" >> "$MODDIR/temp_block.xml"
    done
    echo "    </int-array>" >> "$MODDIR/temp_block.xml"

    prepare_file_for_append "$file"
    cat "$MODDIR/temp_block.xml" >> "$file"
    finish_file "$file"
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

    prepare_file_for_append "$file"
    cat "$MODDIR/temp_block.xml" >> "$file"
    finish_file "$file"
    rm "$MODDIR/temp_block.xml"
}

# Apply changes to a specific file
apply_mods() {
    local TARGET_FILE="$1"

    # 5G SA/NSA
    upsert_int_array "carrier_nr_availabilities_int_array" "$TARGET_FILE" 1 2

    # VoLTE / VoNR / VoWiFi / ViLTE
    upsert_boolean "carrier_volte_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "vonr_enabled_bool" "true" "$TARGET_FILE"
    upsert_boolean "vonr_setting_visibility_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_wfc_ims_available_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_vt_available_bool" "true" "$TARGET_FILE"

    # QNS
    remove_key "qns.ho_restrict_time_with_low_rtp_quality_int_array" "$TARGET_FILE"
    upsert_int "qns.minimum_handover_guarding_timer_ms_int" 1000 "$TARGET_FILE"
    upsert_int_array "qns.voice_ngran_ssrsrp_int_array" "$TARGET_FILE" -120 -124
    upsert_int_array "qns.idle_ngran_ssrsrp_int_array" "$TARGET_FILE" -120 -124
    upsert_int_array "qns.voice_wifi_rssi_int_array" "$TARGET_FILE" -85 -90
    upsert_int_array "qns.idle_wifi_rssi_int_array" "$TARGET_FILE" -85 -90

    # Traffic
    upsert_boolean "unmetered_nr_nsa_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_sa_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_nsa_mmwave_bool" "true" "$TARGET_FILE"
    upsert_boolean "unmetered_nr_sa_mmwave_bool" "true" "$TARGET_FILE"
    upsert_string "tcp_buffersizes_string" "2097152,4194304,8388608,4096,1048576,4194304" "$TARGET_FILE"

    # UI Bands
    if echo "$TARGET_FILE" | grep -qE "China_Unicom|1436"; then
        upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 78
    elif echo "$TARGET_FILE" | grep -qE "China_Telecom|2236"; then
        upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 78
    elif echo "$TARGET_FILE" | grep -qE "China_Mobile|1435"; then
        upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 41 79
    elif echo "$TARGET_FILE" | grep -qE "China_Broadnet|mccmnc_460_15"; then
        upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 79
    else
        upsert_int_array "additional_nr_advanced_bands_int_array" "$TARGET_FILE" 41 78 79
    fi

    # UI Icons & Bars
    upsert_boolean "show_4g_for_lte_data_icon_bool" "true" "$TARGET_FILE"
    upsert_boolean "editable_enhanced_4g_lte_bool" "true" "$TARGET_FILE"
    upsert_string "5g_icon_configuration_string" "connected_mmwave:5G_PLUS,connected:5G,connected_rrc_idle:5G,not_restricted_rrc_idle:5G,not_restricted_rrc_con:5G" "$TARGET_FILE"
    upsert_int_array "5g_nr_ssrsrp_thresholds_int_array" "$TARGET_FILE" -125 -115 -105 -95
    upsert_int_array "lte_rsrp_thresholds_int_array" "$TARGET_FILE" -125 -115 -105 -95
    upsert_int_array "5g_nr_ssrsrq_thresholds_int_array" "$TARGET_FILE" -43 -20 -15 -10

    # GPS
    upsert_string "gps.normal_psds_server" "https://gllto.glpals.com/rto/v1/latest/rto.dat" "$TARGET_FILE"
    upsert_string "gps.longterm_psds_server_1" "https://gllto.glpals.com/7day/v5/latest/lto2.dat" "$TARGET_FILE"
    upsert_string "gps.realtime_psds_server" "https://gllto.glpals.com/rtistatus4.dat" "$TARGET_FILE"

    # Advanced
    remove_key "read_only_apn_types_string_array" "$TARGET_FILE"
    remove_key "read_only_apn_fields_string_array" "$TARGET_FILE"
    upsert_boolean "apn_expand_bool" "true" "$TARGET_FILE"
    upsert_boolean "carrier_rcs_provisioning_required_bool" "false" "$TARGET_FILE"
    upsert_int "imssms.sms_max_retry_over_ims_count_int" 3 "$TARGET_FILE"
    upsert_boolean "ignore_data_enabled_changed_for_video_calls" "true" "$TARGET_FILE"
}

# --- Loop processing ---
for ORIG_FILE in $FOUND_FILES; do
    log "Processing $ORIG_FILE..."
    FILENAME=$(basename "$ORIG_FILE")
    CACHE_FILE="$CACHE_DIR/$FILENAME"

    # 1. Modify Original File (In-Place)
    # Backup first
    if [ ! -f "$ORIG_FILE.bak" ]; then
        cp "$ORIG_FILE" "$ORIG_FILE.bak"
        chmod 660 "$ORIG_FILE.bak"
        chown radio:radio "$ORIG_FILE.bak"
    fi

    # Unmount if already mounted to allow modification of underlying file (if we want to mod it too)
    # But mounting over it hides it. We should mod the file, then mount.
    # Check if mounted
    if grep -q "$ORIG_FILE" /proc/mounts; then
        log "Unmounting existing overlay on $ORIG_FILE"
        umount "$ORIG_FILE"
    fi

    # Apply mods to original file directly
    log "Modifying original file directly..."
    apply_mods "$ORIG_FILE"

    # Fix perms/context on original
    chown radio:radio "$ORIG_FILE"
    chmod 660 "$ORIG_FILE"
    if [ -x "$(command -v restorecon)" ]; then
         restorecon "$ORIG_FILE"
    fi

    # 2. Create Cached Copy and Mount (Overlay)
    log "Creating cached copy for mount bind..."
    cp "$ORIG_FILE" "$CACHE_FILE"

    # Apply mods to cache file (redundant but ensures clean state if cp copied pre-mod)
    # Actually if we just modded ORIG_FILE, CACHE_FILE is already modded.
    # But to be safe against system overwrites, we should re-run apply_mods or just trust the copy.
    # Let's run apply_mods on CACHE_FILE to be 100% sure it has our keys even if ORIG_FILE was reverted by system in split second.
    apply_mods "$CACHE_FILE"

    # Set perms on cache file
    chmod 660 "$CACHE_FILE"
    chown radio:radio "$CACHE_FILE"
    if [ -x "$(command -v restorecon)" ]; then
         restorecon "$CACHE_FILE"
    fi

    # Mount bind
    log "Mounting $CACHE_FILE over $ORIG_FILE"
    mount --bind "$CACHE_FILE" "$ORIG_FILE"
    if [ $? -eq 0 ]; then
        log "Mount successful."
    else
        log "Mount failed!"
    fi
done
