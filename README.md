# KernelSU LSPosed & eUICC Hot-Reboot Fix

[English](README.md) | [简体中文](README_CN.md)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![KernelSU Compatible](https://img.shields.io/badge/KernelSU-Supported-brightgreen.svg)]()
[![Magisk / APatch](https://img.shields.io/badge/Magisk%20%2F%20APatch-Supported-orange.svg)]()
[![Android 12-15](https://img.shields.io/badge/Android-12%20--%2015-green.svg)]()

A specialized KernelSU / Magisk / APatch module providing **Zero-Unlock (免BL) LSPosed revival** alongside an unprecedented **eUICC / OMAPI protection and recovery layer** across soft reboots (hot reboots).

---

## 🔍 Background & The Core Problem

On modern Android devices (especially Qualcomm Snapdragon platforms running Xiaomi HyperOS / AOSP), users who rely on:
1. **Removable / Physical eUICC cards** (e.g., 5ber, eSIM.gg, or embedded eSIMs) managed via **EasyEUICC** / OpenEUICC, and
2. **Soft reboots (Hot Reboots / Zygote restarts)** to revive frameworks like LSPosed or apply system tweaks,

frequently encounter a critical breakdown:

> **"No removable eSIM card accessible by this app is detected on this device. Insert a compatible card or a USB reader."**

Prior to this project, **only a full cold reboot (powering off the phone completely)** could bring the eSIM card back into an accessible state.

---

## 🔬 Technical Root Cause

### 1. ISO 7816-4 Logical Channel Exhaustion
Smartcard communications (including eSIM / eUICC applets) adhere to the ISO/IEC 7816-4 and GlobalPlatform specifications. Logical channels on a smartcard are strictly **stateful**:
* When an app like EasyEUICC opens a logical channel to the ISD-R (Issuer Security Domain Root), that channel remains occupied on the physical chip until explicitly closed via a `MANAGE CHANNEL [CLOSE]` APDU (`00 70 80 xx`).
* When a soft reboot occurs (`kill -9 zygote` or framework crash), Android terminates processes abruptly without lifecycle callbacks. No channel close APDU is transmitted to the card.

### 2. Baseband Hardware Continuity
During a standard cold reboot, the PMIC resets power rails, completely cutting off voltage (`VCC`) to the SIM tray, which causes a hardware Power-On Reset (POR). 
During a **hot reboot**, however:
* The Linux kernel and the Modem Subsystem (MSS / baseband DSP / Hexagon QDSP6) are **never restarted**.
* The SIM card remains continuously powered.
* Consequently, the physical eUICC chip considers all previous logical channels to remain actively in use. When new channel requests are sent after reboot, the card rejects them with error `6A 81` (*Function not supported / Channel not available*).

### 3. Vendor Secure Element HAL Desynchronization
* The native vendor HAL (`android.hardware.secure_element`) runs as an independent daemon managed directly by `init` (not Zygote).
* Because it is not restarted during a hot reboot, its internal state machine, QMI UIM driver bindings, and client handles remain attached to the dead sessions.

### 4. Framework AccessControlEnforcer Deadlock
* Upon Zygote restart, `com.android.se` (`SecureElementService`) re-initializes and attempts to load ARA-M rules via `initializeAccessControl()` in `Terminal.java`.
* Because channel allocation fails, `mAccessControlEnforcer` is set to `null`.
* Any subsequent OMAPI `openLogicalChannel()` call from EasyEUICC throws a `SecurityException` / `IllegalArgumentException`, causing EasyEUICC to report zero accessible ports.

---

## 💡 The Solution

This module introduces a **3-stage synchronization and recovery pipeline**:

```
[User triggers Action / Soft Reboot]
           │
           ▼
[Stage 1: Pre-Reboot Teardown]
   ├── Force-stop EasyEUICC (im.angry.easyeuicc)
   └── Force-stop Secure Element service (com.android.se)
           │
           ▼
[Stage 2: Core Revival & Hot Reboot]
   ├── Native binary executes LSPosed ZygiskSU bridge injection
   └── Restarts Zygote / system_server
           │
           ▼
[Stage 3: Post-Reboot Hardware & HAL Reset]
   ├── Kill vendor HAL daemon (pkill -9 android.hardware.secure_element)
   │     └─► init automatically respawns HAL with fresh QMI client handle
   ├── Cycle baseband radio power (svc telephony radio off -> on)
   │     └─► Baseband asserts ATR (Answer-to-Reset) sequence on UICC bus
   └── Restart com.android.se to bind cleanly to fresh HAL
```

---

## 🚀 Key Features

* **Complete eUICC Protection Across Hot Reboots**: Retain full access to your 5ber / eSIM.gg cards in EasyEUICC without ever needing to cold-reboot the device.
* **Zero-Unlock (免BL) LSPosed Revival**: Restores LSPosed daemon and ZygiskSU injection seamlessly on locked bootloader / root environments.
* **100% Offline & Clean Installation**: All obsolete author telemetry and dead remote JSON requests (`jx.yhyun.asia` 404 queries) have been purged. Flashing is instantaneous and completely offline.
* **Standalone CLI Recovery Tool (`fix-euicc`)**: Installed directly to `/system/bin/fix-euicc`. If any external app or system crash triggers an unexpected soft reboot, simply execute `su -c fix-euicc` in Termux or root shell to restore eUICC functionality immediately.

---

## 📦 Project Structure

```
├── .github/
│   └── workflows/
│       └── release.yml          # Automated GitHub Actions workflow to build flashable zip
├── system/
│   └── bin/
│       └── fix-euicc            # Standalone CLI recovery tool
├── webroot/
│   └── index.html               # Module WebUI page for KernelSU
├── action.sh                    # KernelSU Action script (handles revival & eUICC lifecycle)
├── customize.sh                 # Clean offline module installer
├── service.sh                   # Background service monitor
├── module.prop                  # Magisk / KernelSU metadata
├── main                         # Original native revival executable (SHA-256 verified)
├── YHyc                         # Auxiliary native helper
├── build.py                     # Python script to package flashable ZIP
├── LICENSE                      # GNU General Public License v3.0
└── README.md                    # Documentation
```

---

## 🛠️ Installation

1. Download the latest `KernelSU_LSPosed_eUICC_Fix.zip` from [Releases](../../releases).
2. Open **KernelSU Manager**, **Magisk**, or **APatch**.
3. Select **Modules** -> **Install from Storage**, and pick the downloaded zip.
4. Reboot your device once to finalize installation.

---

## 📱 Usage

### Method 1: Via KernelSU Manager (Recommended)
1. Open **KernelSU Manager**.
2. Navigate to the **Modules** tab.
3. Locate **KernelSU LSPosed & eUICC Fix** and tap the **Action** button.
4. The module will automatically:
   - Close active eUICC channels cleanly.
   - Perform the hot reboot and revive LSPosed.
   - Reset the vendor Secure Element HAL and cycle the UICC interface.
5. Re-open **EasyEUICC**; your eSIM profiles will be immediately recognized.

### Method 2: Standalone CLI (After Third-Party Soft Reboots)
If another module or app triggered a hot reboot and your eSIM card becomes inaccessible, run in **Termux** or any root shell:
```bash
su -c fix-euicc
```
Within 2 seconds, the Secure Element HAL and UICC channels will be reset, and EasyEUICC will detect your card.

---

## 🔨 Building from Source

To compile the flashable module ZIP locally:

```bash
# Clone the repository
git clone https://github.com/<your-username>/KernelSU-LSPosed-eUICC-Fix.git
cd KernelSU-LSPosed-eUICC-Fix

# Build flashable zip
python3 build.py
```
The output file `KernelSU_LSPosed_eUICC_Fix.zip` will be generated in the root directory.

---

## 📜 Credits & License

* Original revival binary by **酷安@月虹yh**.
* eUICC OMAPI recovery research, channel leak mitigation, and packaging by **Antigravity**.
* Licensed under the [GNU General Public License v3.0](LICENSE).
