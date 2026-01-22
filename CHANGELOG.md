# Changelog

## v2.0
- **Action Support:** Added `action.sh` to allow applying updates immediately from KernelSU/Magisk Manager without rebooting.
- **Refactoring:** Moved core XML modification logic to `core.sh` for better reusability.
- **Reliability:** Added `killall com.android.phone` to force carrier config reload.
- **Broadnet Fix:** Fixed China Broadnet detection using MCC/MNC (460_15) instead of missing Carrier ID.

## v1.9
- **Broadnet Fix:** Updated detection logic to support China Broadnet via file pattern `mccmnc_460_15`.

## v1.8
- **Reliability:** Improved script robustness with `restorecon` and safe XML editing.
- **Detection:** Expanded carrier detection to include Carrier IDs (1435, 1436, 2236).

## v1.7
- **5G+:** Configured specific 5G Advanced bands for China Mobile (n41, n79), Unicom (n78), Telecom (n78), and Broadnet (n79).

## v1.6
- **Carriers:** Added support for China Mobile and China Broadnet.

## v1.5
- **UI:** Enabled 5G+ icon for connected mmWave/Advanced bands.

## v1.4
- **Optimization:** Comprehensive update with deep signal lock (-124dBm), subway mode (1s handover), APN unlock, and RCS fix.

## v1.3
- **Carriers:** Added support for China Telecom.

## v1.2
- **GPS:** Fixed GPS PSDS servers to use Broadcom v5 URLs.

## v1.1
- **GPS:** Fixed GPS PSDS URLs to resolve DNS errors.

## v1.0
- Initial release with 5G SA/NSA unlock and basic optimizations for China Unicom.
