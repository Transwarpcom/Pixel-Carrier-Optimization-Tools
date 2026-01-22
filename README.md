# Pixel Carrier Optimization

**Author:** transwarp
**Version:** v1.4

## Overview
This Magisk/KernelSU module optimizes the Android system for Pixel devices (tested on Pixel 8 shiba). It addresses common issues such as 5G restrictions, weak signal handover, and GPS configuration.

> **Note:** While this project is structured to support any carrier, it is currently configured for **China Unicom** and **China Telecom**. If you need support for other carriers, please feel free to open an Issue or submit a Pull Request (PR).

## Features

### 5G & IMS Unlock
- **5G SA/NSA:** Force enables Standalone (SA) and Non-Standalone (NSA) modes.
- **VoLTE & VoNR:** Enables Voice over LTE and Voice over New Radio.
- **VoWiFi:** Enables WiFi Calling with relaxed signal thresholds (works in more rooms).
- **ViLTE:** Enables Video over LTE.

### Signal & Handover Optimization (QNS)
- **Subway Mode:** Shortens handover guarding timer (1s) to allow faster escape from bad base stations.
- **Deep 5G Lock:** Lowers `qns.voice_ngran_ssrsrp` thresholds to -124dBm to prevent premature fallback to 4G/3G.
- **Signal Recovery:** Relaxed signal quality (SNR) requirements.

### GPS/GNSS Fix
- Replaces inaccessible Google PSDS/LTO servers (`agnss.goog`) with Broadcom servers (`glpals.com`).
- Uses correct v5 URLs for Pixel 6/7/8.
- Restores A-GPS functionality for faster locking.

### UI Enhancements
- Enables **5G+** icon for N78 band.
- **Honest Signal Bars:** Adjusts thresholds so full bars are displayed at -95dBm.
- Shows "4G" icon instead of "LTE".
- Enables "Enhanced 4G LTE" toggle in settings.

### Advanced Features
- **APN Freedom:** Unlocks APN editing (IPv4/v6 settings).
- **RCS Fix:** Disables carrier provisioning check to fix "Verifying number" stuck issues.
- **Unmetered 5G:** Marks 5G as unmetered (bypasses some carrier throttling logic).
- **TCP Optimization:** Tuned buffer sizes.

## Installation
1. Install via Magisk Manager or KernelSU.
2. Reboot your device.
3. The module will automatically inject configurations into the carrier config file after boot.

## How it Works
The module uses a background service (`service.sh`) to detect the generation of carrier config XML files located at `/data/user_de/0/com.android.phone/files/`. It scans for files belonging to China Unicom or China Telecom and performs live XML injection to upsert the optimized keys.

## Requirements
- Pixel Device (Pixel 8 tested)
- Root access (Magisk or KernelSU)
- Target Carrier SIM (China Unicom or China Telecom)

## Disclaimer
Use at your own risk. Modifying carrier configurations can affect network connectivity.
