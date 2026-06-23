# ESP32 Dual-Partition OTA Firmware Update System

A complete, production-ready Over-The-Air (OTA) firmware update system for ESP32 microcontrollers. No cloud dependency, no custom bootloader, no manual IP configuration — just a Flutter mobile/desktop app and a compiled `.bin` binary.

## Prerequisites

### Firmware (ESP32)

| Requirement | Version |
|---|---|
| Arduino IDE | 2.x or newer |
| ESP32 Board Package | ≥ 2.0.14 |
| ESP32 Flash Size | 4 MB minimum |
| Libraries | WebServer, ESPmDNS, Update (built-in) |

### Flutter App

| Requirement | Version |
|---|---|
| Flutter SDK | ≥ 3.10.0 |
| Dart SDK | ≥ 3.0.0 |
| Target Platforms | Android, iOS, Windows, macOS, Linux |

## Project Structure

```
esp32_ota_project/
├── firmware/
│   ├── esp32_ota_server.ino      # Main Arduino sketch
│   ├── ota_config.h              # All configuration constants
│   ├── ota_handlers.h            # HTTP handler declarations
│   ├── ota_handlers.cpp           # HTTP handler implementations
│   ├── partitions_ota.csv         # Custom dual-OTA partition table
│   └── firmware_tests.cpp         # Unity unit tests
│
├── flutter_app/
│   ├── pubspec.yaml               # Dependencies
│   ├── lib/
│   │   ├── main.dart              # App entry point
│   │   ├── models/
│   │   │   ├── device_info.dart    # mDNS device model
│   │   │   └── firmware_version.dart # SemVer model + comparison
│   │   ├── services/
│   │   │   ├── mdns_discovery.dart  # mDNS scanning service
│   │   │   ├── ota_http_service.dart # All HTTP operations
│   │   │   └── binary_validator.dart # .bin pre-flight checks
│   │   ├── providers/
│   │   │   └── upload_state.dart    # Riverpod state management
│   │   ├── screens/
│   │   │   ├── discovery_screen.dart     # Device scan UI
│   │   │   ├── device_detail_screen.dart  # Version info + OTA trigger
│   │   │   └── update_progress_screen.dart # Upload progress UI
│   │   └── widgets/
│   │       ├── device_card.dart
│   │       ├── version_badge.dart
│   │       └── progress_indicator.dart
│   └── test/
│       ├── firmware_version_test.dart
│       ├── binary_validator_test.dart
│       ├── upload_state_test.dart
│       └── ota_http_service_test.dart
│
├── README.md                       # This file
├── ARCHITECTURE.md                 # System architecture documentation
└── VERSIONING.md                   # Versioning strategy
```

## ESP32 Firmware Setup

### 1. Configure Partition Scheme

Copy `firmware/partitions_ota.csv` to the Arduino ESP32 partitions directory:

```
~/.arduino15/packages/esp32/hardware/esp32/<version>/tools/partitions/partitions_ota.csv
```

Or reference it via Tools → Partition Scheme → "Custom" in Arduino IDE 2.x.

### 2. Configure Wi-Fi and Security

Edit `firmware/ota_config.h`:

```cpp
#define WIFI_SSID            "YOUR_SSID"
#define WIFI_PASSWORD        "YOUR_PASSWORD"
#define OTA_SECRET_TOKEN     "SecretFlash2026"   // Change this!
#define MDNS_HOSTNAME        "my-esp32"           // Change this!
#define FIRMWARE_VERSION     "1.0.0"              // Increment before each build
```

### 3. Build and Flash

1. Open `esp32_ota_server.ino` in Arduino IDE
2. Select your ESP32 board (Tools → Board → ESP32 Dev Module)
3. Select the custom partition scheme (Tools → Partition Scheme)
4. Set flash size to 4MB (Tools → Flash Size → 4MB)
5. Compile and upload via USB

### 4. Export Binary for OTA

In Arduino IDE: **Sketch → Export Compiled Binary**

This creates a `.bin` file in the sketch folder — this is the file you push via the Flutter app.

## Flutter App Setup

### 1. Install Dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Build

```bash
# Android
flutter run

# iOS (requires Xcode + CocoaPods)
cd ios && pod install && cd ..
flutter run

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 3. Run Tests

```bash
flutter test
```

## Usage Workflow

1. **Power on ESP32** — it connects to Wi-Fi and advertises via mDNS
2. **Open Flutter app** — it discovers the device automatically
3. **Select device** — view firmware version, free heap, MAC address
4. **Choose .bin file** — app validates magic byte (0xE9) locally
5. **Enter OTA token** — the pre-shared secret from `ota_config.h`
6. **Start update** — app unlocks OTA session, uploads binary, progress bar shows real-time stats
7. **Device reboots** — new firmware is running

## API Reference

The ESP32 exposes five HTTP endpoints:

| Method | Path | Description |
|---|---|---|
| GET | `/version` | Firmware version, hostname, uptime |
| GET | `/status` | OTA state, free heap, flash size, chip model, MAC |
| GET | `/heartbeat` | Heartbeat interval, tick count, LED pin, running state |
| GET | `/unlock-ota?token=X` | Unlock OTA session with pre-shared token |
| POST | `/heartbeat?interval=N` | Change heartbeat interval (ms), persists across OTA |
| POST | `/push-firmware` | Upload binary (multipart/form-data) |

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| Device not found via mDNS | Different subnet or mDNS blocked | Use manual IP entry in the app |
| 403 Forbidden on upload | OTA session not unlocked | Send unlock request with correct token first |
| 400 Magic byte mismatch | File is not a valid ESP32 binary | Re-export compiled binary from Arduino IDE |
| 401 Invalid token | Wrong token | Check `OTA_SECRET_TOKEN` in `ota_config.h` |
| 429 Too Many Requests | 3+ failed unlock attempts | Wait 5 minutes or reboot the ESP32 |
| Upload timeout | Wi-Fi instability | Reduce distance, check signal strength |
| Device doesn't reboot | OTA write incomplete | Check logs; `Update.end()` returned false |
| Partition scheme error | Wrong partition table | Ensure `partitions_ota.csv` is selected |
| Not enough space | Binary too large for OTA slot | Check binary size < 1.8 MB |
| Flutter can't discover on iOS | Local network permission denied | Add `NSLocalNetworkUsageDescription` to Info.plist |

## Heartbeat

The ESP32 runs a **hardware-timer-driven 500 ms heartbeat** that is fully independent of the main loop:

- **ISR-driven**: Uses ESP32 hardware timer 0 with a 1 µs tick resolution. The LED toggles and tick counter increment inside the ISR — no software polling, no drift.
- **Persistent across OTA**: The interval (default 500 ms) is stored in **NVS** under namespace `hb_cfg` / key `interval`. When new firmware boots, it reads the stored value — so a firmware update **cannot** accidentally change the tick period.
- **Runtime reconfiguration**: Send `POST /heartbeat?interval=1000` to change the interval at runtime. The new value is written to NVS immediately and the hardware timer is restarted.
- **GET /heartbeat** returns:
  ```json
  {"interval_ms": 500, "tick_count": 12345, "led_pin": 2, "running": true}
  ```

The LED on **GPIO 2** (builtin LED on most ESP32 dev boards) toggles every tick, providing a visible alive indicator.

## Security Consider

- Token comparison uses constant-time algorithm to prevent timing attacks
- Rate limiting: 3 failed token attempts → 5-minute lockout per IP
- OTA session auto-locks after 60 seconds (watchdog timer)
- No HTTPS in current version — for production over untrusted networks, implement self-signed certificates
- Token transmitted as HTTP query parameter — visible in logs; use HTTPS for production

## License

This project is provided as-is for educational and production use. No warranty implied.