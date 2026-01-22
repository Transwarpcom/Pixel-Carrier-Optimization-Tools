# Pixel Carrier Optimization

**Author:** transwarp
**Version:** v1.0

## Overview
This Magisk/KernelSU module optimizes the Android system for Pixel devices (tested on Pixel 8 shiba). It addresses common issues such as 5G restrictions, weak signal handover, and GPS configuration.

> **Note:** While this project is structured to support any carrier, it is currently configured for **China Unicom (Carrier ID 1436)**. If you need support for other carriers, please feel free to open an Issue or submit a Pull Request (PR) to modify the configuration.

## Features

### 5G & IMS Unlock
- Forces 5G SA/NSA availability.
- Enables VoLTE, VoNR, and VoWiFi.
- Unlocks unmetered 5G Sub6/mmWave.

### Signal & Handover Optimization (QNS)
- **Subway Mode:** More aggressive handover guarding timer (1000ms) to prevent signal stickiness.
- **5G Retention:** Lowers `qns.voice_ngran_ssrsrp` thresholds to -124dBm to stay on 5G longer before falling back to 4G.

### GPS/GNSS Fix
- Replaces inaccessible Google PSDS/LTO servers (`agnss.goog`) with Broadcom servers (`glpals.com`).
- Reduces battery drain caused by failed connection retries.

### UI Enhancements
- Enables **5G+** icon for N78 band.
- Adjusts signal bar thresholds so full bars are displayed at -95dBm (more honest/realistic for the region).

## Installation
1. Install via Magisk Manager or KernelSU.
2. Reboot your device.
3. The module will automatically inject configurations into the carrier config file after boot.

## How it Works
The module uses a background service (`service.sh`) to detect the generation of the carrier config XML file located at `/data/user_de/0/com.android.phone/files/`. It then performs live XML injection to upsert the optimized keys without modifying the system partition permanently.

## Requirements
- Pixel Device (Pixel 8 tested)
- Root access (Magisk or KernelSU)
- Target Carrier SIM (China Unicom for current config)

## Disclaimer
Use at your own risk. Modifying carrier configurations can affect network connectivity.
