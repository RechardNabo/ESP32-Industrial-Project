# AI Agent Build Prompt: ESP32 Dual-Partition OTA Firmware Update System

> **Scope:** Full-scale production implementation  
> **Target Platforms:** ESP32 (Arduino framework) · Flutter (cross-platform mobile/desktop) · Local Wi-Fi LAN  
> **Architecture Pattern:** mDNS Discovery → HTTP REST Handshake → Multipart Binary Streaming → Auto-Reboot  

---

## 1. Mission Statement

You are a senior embedded systems and mobile application engineer. Your task is to design, implement, and deliver a **complete, production-ready, scalable Over-The-Air (OTA) firmware update system** for the ESP32 microcontroller. The system requires **no external cloud dependency**, **no custom bootloader**, and **no manual IP configuration**. It must be deployable by a single field technician using only a Flutter mobile application and a compiled `.bin` binary exported from the Arduino IDE.

The architecture is a closed-loop, four-stage pipeline:

```
[ Arduino IDE ] ──(Export Binary)──> [ .bin File ]
                                          │
                                          ▼
[ Flutter App ] ──(1. Discover mDNS)──> [ ESP32 Web Server ]
   (Custom UI)  <──(2. Read Version)───  (Runs Main Loop)
                ───(3. Send Token)────>         │
                ───(4. Push Stream)───>   (Writes Flash)
                                                │
                                                ▼
                                         [ Auto-Reboot ]
```

Build every layer of this pipeline with **zero shortcuts**. Every component must be production-hardened.

---

## 2. Constraints & Non-Negotiables

| Constraint | Requirement |
|---|---|
| ESP32 framework | Arduino (not ESP-IDF bare metal) |
| OTA mechanism | Built-in `Update.h` + dual OTA partition scheme only |
| Network discovery | `ESPmDNS` library; no hardcoded IPs |
| Security | Pre-shared token + 60-second hardware watchdog timer |
| Binary validation | Magic byte `0xE9` check on first received chunk |
| Version control | Semantic versioning (SemVer `MAJOR.MINOR.PATCH`) |
| Flutter target | Android + iOS + Desktop (Windows/macOS/Linux) |
| Dependencies | Only well-maintained, pub.dev-published packages |
| Code quality | No placeholder comments, no stub functions — fully implemented |
| Error handling | Every failure path must have a defined recovery or user-facing message |

---

## 3. Deliverable Structure

Produce the following files, fully implemented:

```
/esp32_ota_project/
├── firmware/
│   ├── esp32_ota_server.ino          # Main Arduino sketch
│   ├── ota_config.h                  # Centralised config constants
│   ├── ota_handlers.h                # HTTP handler declarations
│   ├── ota_handlers.cpp              # HTTP handler implementations
│   └── partitions_ota.csv            # Custom dual-OTA partition table
│
└── flutter_app/
    ├── pubspec.yaml                  # All dependencies declared
    ├── lib/
    │   ├── main.dart                 # App entry point
    │   ├── models/
    │   │   ├── device_info.dart      # mDNS device model
    │   │   └── firmware_version.dart # SemVer model + comparison logic
    │   ├── services/
    │   │   ├── mdns_discovery.dart   # mDNS scanning service
    │   │   ├── ota_http_service.dart # All HTTP operations
    │   │   └── binary_validator.dart # .bin file pre-flight checks
    │   ├── screens/
    │   │   ├── discovery_screen.dart # Device scan UI
    │   │   ├── device_detail_screen.dart # Version info + OTA trigger
    │   │   └── update_progress_screen.dart # Upload progress UI
    │   └── widgets/
    │       ├── device_card.dart
    │       ├── version_badge.dart
    │       └── progress_indicator.dart
    └── assets/
        └── (app icon, splash assets)
```

---

## 4. ESP32 Firmware Specification

### 4.1 Partition Table (`partitions_ota.csv`)

Define a dual-OTA partition table compatible with 4 MB flash. Allocate:

- `nvs` — 24 KB
- `otadata` — 8 KB
- `app0` (OTA_0) — 1.8 MB
- `app1` (OTA_1) — 1.8 MB
- `spiffs` — remainder

Export this as a valid Arduino IDE custom partition CSV. Include instructions as a comment block at the top of the file for how to select it in `Tools → Partition Scheme`.

### 4.2 Configuration Header (`ota_config.h`)

Define **all** tuneable constants in one place:

```cpp
// Network identity
#define MDNS_HOSTNAME        "my-esp32"
#define WIFI_SSID            "YOUR_SSID"
#define WIFI_PASSWORD        "YOUR_PASSWORD"

// Firmware identity
#define FIRMWARE_VERSION     "1.0.0"

// HTTP server
#define HTTP_PORT            80

// Security
#define OTA_SECRET_TOKEN     "SecretFlash2026"
#define OTA_UNLOCK_PATH      "/unlock-ota"
#define OTA_PUSH_PATH        "/push-firmware"
#define OTA_VERSION_PATH     "/version"
#define OTA_STATUS_PATH      "/status"

// Watchdog
#define OTA_TIMEOUT_SECONDS  60

// Binary validation
#define ESP_MAGIC_BYTE       0xE9
```

No magic strings or numbers anywhere else in the codebase.

### 4.3 Main Sketch (`esp32_ota_server.ino`)

Implement the following `setup()` sequence in order:

1. Serial initialisation at 115200 baud
2. Wi-Fi station mode connection with **blocking retry loop** (max 30 seconds, then deep sleep for 5 seconds and retry)
3. mDNS server start with `MDNS_HOSTNAME`
4. HTTP web server route registration (see §4.4)
5. HTTP server start on `HTTP_PORT`
6. Log ready state to Serial including IP address, mDNS hostname, and firmware version

Implement `loop()` to:

- Call `server.handleClient()` every iteration
- Call `MDNS.update()` every iteration
- If `ota_active` flag is true, decrement the watchdog counter each second and call `ota_watchdog_tick()` which resets the OTA state and responds with `503` on timeout

### 4.4 HTTP Route Handlers (`ota_handlers.cpp`)

Implement all four endpoints. Each handler must set correct HTTP status codes and `Content-Type: application/json` on all responses.

#### `GET /version`

Returns:
```json
{ "version": "1.0.0", "hostname": "my-esp32", "uptime_s": 3421 }
```

#### `GET /status`

Returns:
```json
{
  "ota_unlocked": false,
  "ota_remaining_s": 0,
  "free_heap": 218432,
  "flash_size": 4194304,
  "chip_model": "ESP32",
  "mac": "AA:BB:CC:DD:EE:FF"
}
```

#### `GET /unlock-ota?token=<TOKEN>`

- Extract `token` query parameter
- Compare with constant-time string comparison to `OTA_SECRET_TOKEN` (avoid timing attacks)
- On match: set `ota_active = true`, reset watchdog counter, return `200`:
  ```json
  { "unlocked": true, "expires_in_s": 60 }
  ```
- On mismatch: return `401`:
  ```json
  { "unlocked": false, "error": "Invalid token" }
  ```
- If already unlocked: return `200` with remaining seconds

#### `POST /push-firmware` (multipart/form-data)

This is the core handler. Implement in full:

1. **Guard clause:** If `ota_active == false`, return `403`:
   ```json
   { "error": "OTA session not unlocked" }
   ```
2. **Begin OTA:** Call `Update.begin(UPDATE_SIZE_UNKNOWN)`; if it fails, return `500` with `Update.errorString()`
3. **Magic byte check:** Buffer the very first received byte and assert it equals `ESP_MAGIC_BYTE` (`0xE9`). On failure, call `Update.abort()`, reset OTA state, return `400`:
   ```json
   { "error": "Invalid binary: magic byte mismatch", "expected": "0xE9", "received": "<hex>" }
   ```
4. **Stream write loop:** Write all incoming chunks via `Update.write()`. Track bytes written. On any write error, abort and return `500`.
5. **Finalise:** Call `Update.end(true)`. If it returns false, return `500` with error string.
6. **On success:**
   - Reset `ota_active = false`
   - Return `200`:
     ```json
     { "success": true, "bytes_written": 184320, "message": "Rebooting..." }
     ```
   - Call `ESP.restart()` after a 500 ms delay (allow response to flush)

### 4.5 Watchdog Timer Implementation

Use a non-blocking millisecond timer (not `delay()`). Implement `ota_watchdog_tick()`:

- Called from `loop()` every 1000 ms while `ota_active == true`
- Decrements a counter initialised to `OTA_TIMEOUT_SECONDS`
- When counter reaches 0:
  - Set `ota_active = false`
  - Log timeout event to Serial
  - Do **not** reboot; allow the main loop to continue normally

### 4.6 Error Recovery & Resilience

- If `Update.begin()` fails due to insufficient space, log the available partition size
- After a failed OTA attempt, ensure the currently running partition is **never** corrupted (the `Update.h` framework guarantees this — document this behaviour with a comment)
- On Wi-Fi disconnect during OTA: the TCP connection will drop, `Update.abort()` will be called by the guard clause on the next request attempt

---

## 5. Flutter Application Specification

### 5.1 Dependencies (`pubspec.yaml`)

Include and justify each dependency:

| Package | Purpose |
|---|---|
| `multicast_dns` | mDNS/Bonjour device discovery |
| `http` | HTTP client for version, unlock, and status calls |
| `dio` | Multipart streaming upload with progress callback |
| `file_picker` | Cross-platform `.bin` file selection |
| `provider` or `riverpod` | State management |
| `package_info_plus` | App version metadata |
| `permission_handler` | Runtime permissions (local network on iOS) |
| `path` | Cross-platform path utilities |

### 5.2 `FirmwareVersion` Model (`firmware_version.dart`)

Implement a full SemVer model:

```dart
class FirmwareVersion implements Comparable<FirmwareVersion> {
  final int major;
  final int minor;
  final int patch;

  // Factory constructor from string "1.2.3"
  factory FirmwareVersion.parse(String versionString);

  // Returns true if this version is newer than other
  bool isNewerThan(FirmwareVersion other);

  // Returns true if versions are identical
  bool isEqualTo(FirmwareVersion other);

  @override
  int compareTo(FirmwareVersion other);

  @override
  String toString(); // "1.2.3"
}
```

Handle malformed strings gracefully — return `FirmwareVersion(0, 0, 0)` with a logged warning.

### 5.3 mDNS Discovery Service (`mdns_discovery.dart`)

Implement `MdnsDiscoveryService`:

```dart
class MdnsDiscoveryService {
  // Scans for _http._tcp services matching hostname pattern
  // Returns a stream of DeviceInfo objects as they are discovered
  Stream<DeviceInfo> discoverDevices({Duration timeout = const Duration(seconds: 10)});

  // Resolves a single known hostname to its current IP
  Future<String?> resolveHostname(String hostname);
}
```

`DeviceInfo` model must contain: `hostname`, `ipAddress`, `port`, `lastSeen`.

Scan for `_http._tcp.local` service type. Filter results to only devices whose hostname contains `"esp32"` or matches the configured pattern. Handle platform-specific permissions for iOS local network access.

### 5.4 OTA HTTP Service (`ota_http_service.dart`)

Implement `OtaHttpService` with the following methods — all return typed result objects, **never** raw `http.Response`:

```dart
class OtaHttpService {
  final String baseUrl; // e.g. "http://10.0.1.45:80"

  Future<DeviceStatusResult> fetchStatus();
  Future<VersionCheckResult> fetchVersion();
  Future<UnlockResult> unlockOta(String token);
  Future<UploadResult> pushFirmware({
    required File binFile,
    required void Function(double progress, int bytesTransferred, int totalBytes) onProgress,
  });
}
```

`pushFirmware` must use `Dio` with a `FormData` multipart upload. Bind the `onSendProgress` callback to the `onProgress` parameter. Handle `DioException` types individually:
- `connectionTimeout` → user-facing: "Device unreachable"
- `receiveTimeout` → user-facing: "Upload timed out — device may have rebooted successfully"
- `badResponse` → parse JSON error body and surface the `"error"` field
- `cancel` → user-facing: "Upload cancelled"

### 5.5 Binary Validator (`binary_validator.dart`)

Pre-flight check **before** any network operation:

```dart
class BinaryValidator {
  static Future<ValidationResult> validate(File file) async {
    // 1. File exists and is readable
    // 2. File size > 0 and < 2 MB (configurable)
    // 3. File extension is ".bin"
    // 4. Read first byte: must equal 0xE9
    // 5. Return ValidationResult with isValid, errorMessage
  }
}
```

This client-side magic byte check is in **addition** to the server-side check — fail fast before consuming network bandwidth.

### 5.6 Screens

#### Discovery Screen (`discovery_screen.dart`)

- Animated scan indicator while `MdnsDiscoveryService.discoverDevices()` runs
- List of discovered `DeviceCard` widgets, each showing hostname + IP
- Manual IP entry text field as fallback
- Pull-to-refresh to re-scan
- Empty state with "No ESP32 devices found" message and retry button

#### Device Detail Screen (`device_detail_screen.dart`)

- Displays `DeviceStatusResult` fields: hostname, IP, free heap, uptime, chip model, MAC
- `VersionBadge` widget showing current device version
- File picker button to select `.bin` file
- After file selection: show selected filename, file size, and pre-flight validation result
- If validation passes and selected version > device version: enable "Begin OTA Update" button
- If selected version ≤ device version: show warning badge "Already up to date" — require explicit override toggle to proceed
- "Begin OTA Update" button triggers unlock then upload sequence

#### Update Progress Screen (`update_progress_screen.dart`)

Navigate to this screen immediately after the user confirms the upload. Do **not** use a dialog — this must be a full screen to prevent accidental dismissal.

Display:
- Phase indicator: `Unlocking → Validating → Uploading → Rebooting`
- Linear progress bar (0–100%) during upload phase
- Bytes transferred / total bytes (formatted: `"184 KB / 892 KB"`)
- Transfer speed in KB/s (rolling 1-second average)
- Estimated time remaining
- On success: full-screen success state with "Device rebooted successfully" and version comparison (`"1.0.0 → 1.1.0"`)
- On failure: full-screen error state with error message, technical detail (collapsible), and "Retry" button

---

## 6. Security Implementation Detail

### Token Comparison (Firmware)

Do **not** use `strcmp()` for token comparison — it exits early on mismatch, enabling timing attacks. Implement a constant-time comparison:

```cpp
bool constantTimeCompare(const char* a, const char* b) {
  size_t len = strlen(OTA_SECRET_TOKEN);
  uint8_t result = 0;
  for (size_t i = 0; i < len; i++) {
    result |= a[i] ^ b[i];
  }
  return (result == 0) && (strlen(a) == strlen(b));
}
```

### Token Transmission (Flutter)

- The token is **never** stored in plaintext in a config file committed to version control
- It is entered by the user at runtime in a `SecureTextField` (obscured input)
- It is transmitted over HTTP as a query parameter — document that for production deployments over untrusted networks, HTTPS with a self-signed certificate should be implemented as a future enhancement

### OTA Lockout After Failure

After 3 consecutive failed token attempts from the same IP within a 60-second window, the firmware must reject all `/unlock-ota` requests with `429 Too Many Requests` for 5 minutes. Implement a simple in-memory counter — no external state required.

---

## 7. Scalability & Production Hardening

### Multi-Device Support (Flutter)

The Flutter app must support **simultaneous discovery** of multiple ESP32 devices on the same subnet. The discovery screen must list all devices. The user selects one device to update — the app must manage state per-device, not globally.

### Firmware Versioning Strategy

Document the following versioning convention in a `VERSIONING.md` file at the project root:

- `MAJOR` — Breaking hardware or protocol change
- `MINOR` — New feature, backwards-compatible
- `PATCH` — Bug fix only
- The version string in `ota_config.h` **must** be manually incremented before each build and OTA push
- A CI/CD hook recommendation: fail the build if `FIRMWARE_VERSION` in the new `.bin` is ≤ the version on the target device (enforced by the Flutter app's version gate)

### Logging Strategy (Firmware)

Define a `LOG(level, msg)` macro that:
- Prints to Serial in format: `[LEVEL][timestamp_ms] message`
- Can be disabled at compile time by defining `OTA_DISABLE_LOGS`
- Levels: `INFO`, `WARN`, `ERROR`

### Flutter State Management

Use `Riverpod` (preferred) or `Provider`. Define the following providers:

- `discoveredDevicesProvider` — `StreamProvider<List<DeviceInfo>>`
- `selectedDeviceProvider` — `StateProvider<DeviceInfo?>`
- `deviceStatusProvider(baseUrl)` — `FutureProvider<DeviceStatusResult>`
- `uploadStateProvider` — `StateNotifierProvider<UploadStateNotifier, UploadState>`

`UploadState` is a sealed class with variants: `Idle`, `Unlocking`, `Uploading(progress, speed, eta)`, `Success(oldVersion, newVersion)`, `Failure(message, detail)`.

---

## 8. Testing Requirements

### Firmware (Unit-Testable Logic)

Write Arduino-compatible unit tests (using `AUnit` or `Unity` framework) for:

- `FirmwareVersion` string parsing edge cases
- `constantTimeCompare()` correctness
- Watchdog counter decrement and reset logic
- Magic byte extraction from a mock buffer

### Flutter (Widget + Integration Tests)

Write tests for:

- `FirmwareVersion.parse()` with valid, invalid, and edge-case strings
- `FirmwareVersion.isNewerThan()` — all comparison combinations
- `BinaryValidator.validate()` with a fixture `.bin` file containing `0xE9` as first byte
- `OtaHttpService.fetchVersion()` with a mock HTTP server returning a JSON fixture
- `UploadStateNotifier` state transitions: `Idle → Unlocking → Uploading → Success`
- Discovery screen renders device cards when `discoveredDevicesProvider` emits data
- Progress screen cannot be dismissed via back button during upload (uses `WillPopScope`)

---

## 9. Documentation Requirements

Produce the following documentation files:

### `README.md` (Project Root)

- Prerequisites (Arduino IDE version, ESP32 board package version, Flutter SDK version)
- Hardware requirements (ESP32 board, 4 MB flash minimum)
- Step-by-step setup: partition scheme selection, Wi-Fi credentials, token configuration
- Build and export instructions (Arduino IDE → Sketch → Export Compiled Binary)
- Flutter app build instructions for Android, iOS, and desktop
- Troubleshooting table (10 common failure modes + resolution)

### `ARCHITECTURE.md`

- Full architecture diagram (ASCII + description)
- Data flow sequence diagram (UML-style, text-based)
- Security model description
- Partition layout explanation with diagram
- Future enhancement roadmap:
  1. HTTPS with self-signed certificates
  2. Rollback support (revert to previous OTA slot on boot failure)
  3. Delta/diff OTA to reduce binary transfer size
  4. Multi-device batch update orchestration from Flutter
  5. Audit log stored in NVS (last 10 OTA events with timestamp and version)

### `VERSIONING.md`

As described in §7.

---

## 10. Code Quality Standards

Apply these standards to **every file** produced:

| Standard | Rule |
|---|---|
| Comments | Every function has a one-line doc comment describing its contract |
| Magic values | Zero. All literals are named constants |
| Error handling | No silent failures. Every error path logs and returns a typed result |
| Naming | snake_case for Dart, camelCase for C++/Arduino, SCREAMING_SNAKE for constants |
| File length | No single `.dart` or `.cpp` file exceeds 300 lines — refactor if needed |
| Dead code | None. Every declared symbol is used |
| TODOs | None. The implementation is complete |

---

## 11. Execution Order for the Agent

Execute deliverables in this sequence to allow incremental validation:

1. **`partitions_ota.csv`** and **`ota_config.h`** — foundation, no dependencies
2. **`ota_handlers.cpp` / `ota_handlers.h`** — core firmware logic
3. **`esp32_ota_server.ino`** — integrates all firmware components
4. **`firmware_version.dart`** and **`device_info.dart`** — Flutter models, pure Dart
5. **`binary_validator.dart`** — pure Dart, file I/O only
6. **`mdns_discovery.dart`** — platform service
7. **`ota_http_service.dart`** — network service
8. **State management providers** — wires models and services
9. **Screens and widgets** — UI layer, depends on all above
10. **`pubspec.yaml`** and **`main.dart`** — app wiring
11. **Tests** — validate all components
12. **Documentation files** — `README.md`, `ARCHITECTURE.md`, `VERSIONING.md`

---

## 12. Acceptance Criteria

The implementation is complete when all of the following are true:

- [ ] ESP32 sketch compiles without warnings using Arduino IDE with ESP32 board package ≥ 2.0.14
- [ ] Custom partition table is selected and device boots to `app0` slot on first flash
- [ ] `http://my-esp32.local/version` returns valid JSON within 2 seconds of device boot
- [ ] Token mismatch returns `401`; correct token returns `200` and sets `ota_active`
- [ ] A `.bin` file with first byte `0xE9` uploads successfully and device reboots to new version
- [ ] A `.bin` file with incorrect magic byte is rejected with `400` before any flash write occurs
- [ ] Watchdog fires after 60 seconds if no upload completes; device does not reboot
- [ ] Flutter app discovers device on local subnet without manual IP entry
- [ ] Flutter version gate blocks upload when selected file version ≤ device version
- [ ] Upload progress screen shows real-time KB/s and ETA
- [ ] All Flutter tests pass with `flutter test`
- [ ] All firmware unit tests pass
- [ ] `README.md` contains complete setup instructions reproducible by a developer unfamiliar with the project

---

*End of prompt. Produce all deliverables in full. Do not summarise, stub, or defer any component.*
