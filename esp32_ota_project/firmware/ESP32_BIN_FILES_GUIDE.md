# ESP32 Build Output — .bin Files Guide

**Board:** DOIT ESP32 DevKit V1 (d1_uno32)
**Flash:** 4 MB, 80 MHz, QIO
**Build directory:** `firmware/esp32_ota_server/build/esp32.esp32.d1_uno32/`

---

## Summary Table

| # | File | Size | Flash Offset | Purpose |
|---|------|------|-------------|---------|
| 1 | `esp32_ota_server.ino.bootloader.bin` | 23 KB | `0x1000` | Stage-1 bootloader |
| 2 | `esp32_ota_server.ino.partitions.bin` | 3 KB | `0x8000` | Partition table |
| 3 | `boot_app0.bin` | 8 KB | `0xe000` | OTA boot stub |
| 4 | **`esp32_ota_server.ino.bin`** | 1012 KB | `0x10000` | **Application firmware (upload this for OTA)** |
| 5 | `esp32_ota_server.ino.merged.bin` | 4 MB | `0x0` | All-in-one flash image |

---

## Each File Explained

### 1. `esp32_ota_server.ino.bootloader.bin` — Bootloader

**What it is:** The first-stage bootloader loaded by the ESP32 ROM bootloader on power-up.

**What it does:**
- Initializes the flash chip and RAM
- Reads the partition table to find the OTA slot to boot
- Validates the application image checksum
- Loads the application into RAM and transfers execution

**Flash offset:** `0x1000`
**Used when:** Full initial flash (first-time programming or recovering a bricked board). Not needed for OTA updates.

---

### 2. `esp32_ota_server.ino.partitions.bin` — Partition Table

**What it is:** A 0xC00-byte table describing how the 4 MB flash is divided into regions.

**Your current layout (from build output):**

| Partition | Type | SubType | Offset | Size |
|-----------|------|---------|--------|------|
| nvs | data | nvs | 0x9000 | 20 KB |
| otadata | data | ota | 0xe000 | 8 KB |
| app0 (OTA_0) | app | ota_0 | 0x10000 | 1.25 MB |
| app1 (OTA_1) | app | ota_1 | 0x150000 | 1.25 MB |
| spiffs | data | spiffs | 0x290000 | 1.375 MB |
| coredump | data | coredump | 0x3F0000 | 64 KB |

**What it does:**
- Tells the bootloader where OTA slot 0 and slot 1 live
- Defines NVS (stores WiFi credentials, settings)
- Defines otadata (stores which OTA slot is currently active)
- Defines SPIFFS (file system for web assets served by the ESP32)

**Flash offset:** `0x8000`
**Used when:** First-time flash, or if you changed the partition scheme. Never changed during OTA.

> **Note:** Your `partitions_ota.csv` source file defines 1.8 MB OTA slots, but the actual built partition table uses the **default** 1.25 MB scheme. This means the Arduino IDE built with `PartitionScheme=default`, not your custom `partitions_ota.csv`. To use 1.8 MB slots, select your custom partition scheme in Arduino IDE under Tools > Partition Scheme.

---

### 3. `boot_app0.bin` — OTA Boot App

**What it is:** A small application that the Espressif OTA bootloader runs when no valid OTA app is found, or as a fallback during OTA slot switching.

**What it does:**
- Prepares the RTC (real-time clock) memory for OTA operations
- Handles the initial boot app setup before the real firmware runs
- Required by the ESP-IDF OTA boot mechanism to properly manage the OTA slot selection stored in the `otadata` partition

**Flash offset:** `0xe000` (overlaps the `otadata` partition start — this is intentional; the boot app lives at this fixed location)
**Used when:** First-time flash only. Part of the minimal OTA framework.

---

### 4. `esp32_ota_server.ino.bin` — Application Firmware

**What it is:** Your compiled application code — the actual ESP32 OTA server firmware with WiFi, mDNS, HTTP endpoints, and OTA update handling.

**What it does:**
- Connects to WiFi and advertises via mDNS
- Serves `/version`, `/status`, `/unlock-ota`, `/push-firmware` HTTP endpoints
- Handles firmware uploads and validates the 0xE9 magic byte
- Manages the OTA slot swap and reboot

**Flash offset:** `0x10000` (OTA slot 0 on first flash)
**Size:** 1012 KB (fits easily in the 1.25 MB OTA slot)
**Used when:**
- **First-time flash:** Written to `0x10000` (OTA_0) via USB/serial
- **OTA update:** This is the file you upload through the Flutter app — the ESP32 writes it to the *other* OTA slot (OTA_1) and swaps on reboot

> **This is the .bin file you upload for OTA updates.**

---

### 5. `esp32_ota_server.ino.merged.bin` — Merged Flash Image

**What it is:** A single 4 MB binary containing ALL four files above concatenated at their correct offsets, padded with `0xFF` (erased flash) in between.

**What it does:**
- Contains bootloader + partition table + boot_app0 + application in one file
- Flashed starting at offset `0x0` to replace the ENTIRE flash contents

**Flash offset:** `0x0`
**Size:** 4 MB (full flash size)
**Used when:**
- **Factory fresh programming** — erase and write everything in one shot
- **Recovering a bricked ESP32** — restores the full flash image
- **Production programming** — fastest way to flash a complete device

> **Warning:** Flashing the merged image erases ALL flash contents including NVS (WiFi credentials), SPIFFS (web assets), and OTA slot data. Use only for initial setup or recovery.

---

## OTA Token

The ESP32 firmware requires a pre-shared token to unlock the OTA session before uploading firmware.

**OTA Token:** `SecretFlash2026`

This token is defined in `ota_config.h` as `OTA_SECRET_TOKEN`. You must enter it in the Flutter app's "OTA Token" field before the "Begin OTA Update" button becomes active.

The token is valid for a limited time window (default: 60 seconds after unlock). After expiry, you must unlock again.

---

## Binary Validation (Flutter App)

The Flutter app validates .bin files before upload:

| Check | Rule |
|-------|------|
| File extension | Must end in `.bin` |
| File size | 1 byte – 4 MB |
| Magic byte | First byte must be `0xE9` (ESP32 app image header) |

**Which files pass validation:**

| File | Magic Byte | Passes? | Reason |
|------|-----------|---------|--------|
| `esp32_ota_server.ino.bin` | `0xE9` | **Yes** | Valid ESP32 app image |
| `esp32_ota_server.ino.merged.bin` | `0xFF` | No | Starts with erased flash padding, not an app image |
| `esp32_ota_server.ino.bootloader.bin` | `0xE9` | No (misleading) | Passes magic byte but is a bootloader, not an app — will brick the OTA slot |
| `esp32_ota_server.ino.partitions.bin` | `0xAA 0x50` | No | Partition table has different magic bytes |
| `boot_app0.bin` | `0x01` | No | Boot stub, not an app image |

> **Important:** Only upload `esp32_ota_server.ino.bin` via OTA. The other .bin files are for USB/serial flashing only. Uploading the wrong file will corrupt the OTA slot and require USB recovery.

---

## Which File to Use When

| Scenario | File to Use | How |
|----------|------------|-----|
| **OTA firmware update (via Flutter app)** | `esp32_ota_server.ino.bin` | Upload through the `/push-firmware` endpoint |
| **First-time programming via USB** | All 4 individual files | Use `esptool.py` with correct offsets (see below) |
| **First-time programming (quick)** | `esp32_ota_server.ino.merged.bin` | Flash at offset `0x0` with `esptool.py` |
| **Bricked board recovery** | `esp32_ota_server.ino.merged.bin` | Erase flash first, then flash merged image |
| **Only app changed (USB flash)** | `esp32_ota_server.ino.bin` | Flash at offset `0x10000` |

---

## esptool Commands

### Full Flash (first time or recovery)

```bash
# Erase entire flash (recovery only)
esptool.py --port COM3 erase_flash

# Flash merged image (simplest — one command)
esptool.py --port COM3 --baud 921600 write_flash 0x0 esp32_ota_server.ino.merged.bin

# OR flash individual files (equivalent, more control)
esptool.py --port COM3 --baud 921600 write_flash \
  0x1000 esp32_ota_server.ino.bootloader.bin \
  0x8000 esp32_ota_server.ino.partitions.bin \
  0xe000 boot_app0.bin \
  0x10000 esp32_ota_server.ino.bin
```

### App-Only Flash (USB, no OTA)

```bash
esptool.py --port COM3 --baud 921600 write_flash 0x10000 esp32_ota_server.ino.bin
```

### OTA Update (over WiFi — no USB needed)

Upload `esp32_ota_server.ino.bin` through the Flutter app or via curl:

```bash
# Step 1: Unlock OTA (token: SecretFlash2026)
curl "http://esp32-ota.local/unlock-ota?token=SecretFlash2026"

# Step 2: Push firmware
curl -X POST http://esp32-ota.local/push-firmware \
  -F "firmware=@esp32_ota_server.ino.bin"
```

---

## Partition Layout Visual (4 MB Flash)

```
0x000000 ├──────────────────────────────┤
         │  (reserved / unused)          │
0x001000 ├──────────────────────────────┤  ← Bootloader
         │  bootloader.bin              │    (23 KB)
0x008000 ├──────────────────────────────┤  ← Partition Table
         │  partitions.bin              │    (3 KB)
0x009000 ├──────────────────────────────┤
         │  NVS (WiFi creds, settings)   │    (20 KB)
0x00E000 ├──────────────────────────────┤  ← OTA Boot App
         │  boot_app0.bin + otadata      │    (8 KB + 8 KB)
0x010000 ├──────────────────────────────┤  ← OTA Slot 0
         │  esp32_ota_server.ino.bin     │    (1.25 MB)
0x150000 ├──────────────────────────────┤  ← OTA Slot 1
         │  (empty — OTA writes here)    │    (1.25 MB)
0x290000 ├──────────────────────────────┤  ← SPIFFS
         │  Web assets, files            │    (1.375 MB)
0x3F0000 ├──────────────────────────────┤  ← Core Dump
         │  Crash data                   │    (64 KB)
0x400000 ├──────────────────────────────┘
         4 MB
```