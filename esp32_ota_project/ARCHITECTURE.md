# Architecture

## System Overview

The ESP32 OTA system is a closed-loop, four-stage pipeline operating entirely on the local Wi-Fi network with zero cloud dependency.

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

## Partition Layout

The ESP32 4 MB flash is divided as follows:

```
┌─────────────────────────────────────────────┐
│  Offset    │  Size     │  Name     │ Type    │
├─────────────────────────────────────────────┤
│  0x9000    │  24 KB    │  nvs      │ data    │
│  0xF000    │  8 KB     │  otadata  │ ota     │
│  0x10000   │  1.8 MB   │  app0     │ ota_0   │
│  0x1F0000  │  1.8 MB   │  app1     │ ota_1   │
│  0x3D0000  │  ~192 KB  │  spiffs   │ spiffs  │
└─────────────────────────────────────────────┘
```

- **nvs**: Non-volatile storage for Wi-Fi credentials and configuration
- **otadata**: Boot partition selector — tells the bootloader which OTA slot to run
- **app0 (OTA_0)**: Primary firmware partition (1.8 MB)
- **app1 (OTA_1)**: Secondary firmware partition (1.8 MB)
- **spiffs**: File system for any remaining space

On first flash, the firmware runs from app0. OTA updates write to app1, then the otadata partition is updated to point to app1 on next boot. If the new firmware fails, the bootloader can fall back to app0.

## Data Flow Sequence

```
Flutter App                          ESP32
    │                                  │
    │──── mDNS Discovery ─────────────>│  (broadcasts _http._tcp)
    │                                  │
    │<─── mDNS Response ──────────────│  (hostname, IP, port)
    │                                  │
    │──── GET /version ──────────────>│
    │                                  │
    │<─── {version, hostname, uptime} │
    │                                  │
    │──── GET /status ────────────────>│
    │                                  │
    │<─── {ota_unlocked, heap, mac}   │
    │                                  │
    │──── GET /unlock-ota?token=X ───>│
    │                                  │
    │<─── {unlocked: true, expires: 60}│  [60-second window starts]
    │                                  │
    │──── POST /push-firmware ────────>│
    │     (multipart/form-data)        │
    │     [chunk 1: magic byte 0xE9]   │── validate magic byte
    │     [chunk 2..N: binary data]     │── Update.write()
    │                                  │
    │<─── {success: true, bytes: N}    │
    │                                  │── ESP.restart() after 500ms
    │                                  │
    │                    [Device reboots into new firmware]
```

## Security Model

### Authentication Layer

- **Pre-shared token**: Hardcoded in `ota_config.h` on the ESP32, entered at runtime in the Flutter app
- **Constant-time comparison**: The `/unlock-ota` handler uses `constantTimeCompare()` which XORs every byte, preventing timing side-channels
- **Session window**: After successful unlock, the OTA session remains active for 60 seconds. The watchdog timer decrements each second and auto-locks on expiry

### Rate Limiting

- **3 attempts per 60-second window** from the same IP address
- **5-minute lockout** after 3 consecutive failures
- **429 Too Many Requests** response during lockout
- In-memory only — resets on device reboot

### Binary Validation

1. **Client-side**: Flutter `BinaryValidator` checks file extension, size (max 2 MB), and first byte (must be 0xE9) before any network traffic
2. **Server-side**: The `/push-firmware` handler validates the first byte of each upload — if it's not 0xE9, the update is aborted before any flash write occurs
3. **Double protection**: Both layers ensure no invalid data reaches the flash partition

### OTA Lockout After Success

After a successful firmware push:
- The `ota_active` flag is immediately reset to `false`
- The 60-second watchdog counter is zeroed
- A new unlock token is required for any subsequent OTA

## Component Architecture

### ESP32 Firmware

```
┌──────────────────────────────────────────┐
│            esp32_ota_server.ino           │
│  ┌─────────────┐  ┌──────────────────┐   │
│  │ Wi-Fi Setup  │  │  mDNS Responder  │   │
│  └─────────────┘  └──────────────────┘   │
│  ┌──────────────────────────────────────┐ │
│  │          WebServer (port 80)          │ │
│  │  ┌──────────┐  ┌─────────────────┐  │ │
│  │  │ /version │  │    /status       │  │ │
│  │  └──────────┘  └─────────────────┘  │ │
│  │  ┌──────────┐  ┌─────────────────┐  │ │
│  │  │ /unlock  │  │ /push-firmware  │  │ │
│  │  └──────────┘  └─────────────────┘  │ │
│  └──────────────────────────────────────┘ │
│  ┌──────────────────────────────────────┐ │
│  │    Watchdog Timer (60s countdown)     │ │
│  └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

### Flutter Application

```
┌──────────────────────────────────────────┐
│              Flutter App (Riverpod)       │
│                                           │
│  ┌──────────────┐  ┌──────────────────┐  │
│  │ MdnsDiscovery │  │  BinaryValidator │  │
│  │   Service      │  │    Service       │  │
│  └───────┬───────┘  └────────┬─────────┘  │
│          │                    │            │
│  ┌───────┴────────────────────┴────────┐  │
│  │          OtaHttpService             │  │
│  │  (fetchVersion, fetchStatus,        │  │
│  │   unlockOta, pushFirmware)          │  │
│  └───────────────┬────────────────────┘  │
│                  │                        │
│  ┌───────────────┴────────────────────┐  │
│  │       Riverpod Providers           │  │
│  │  discoveredDevices (Stream)         │  │
│  │  selectedDevice (State)            │  │
│  │  deviceStatus (Future)             │  │
│  │  uploadState (StateNotifier)        │  │
│  └───────┬────────────┬──────────────┘  │
│          │            │                    │
│  ┌───────┴──┐  ┌──────┴───────┐          │
│  │Discovery │  │Device Detail │          │
│  │ Screen   │  │   Screen     │          │
│  └──────────┘  └──────┬──────┘          │
│                  ┌─────┴────────┐        │
│                  │Update Progress│        │
│                  │    Screen     │        │
│                  └──────────────┘        │
└──────────────────────────────────────────┘
```

## Future Enhancements

1. **HTTPS with self-signed certificates** — encrypt all traffic including the OTA token
2. **Rollback support** — detect boot failure in the new partition and automatically revert to the previous OTA slot using the ESP32 boot validation API
3. **Delta/diff OTA** — reduce binary transfer size by sending only the differences between versions
4. **Multi-device batch update** — orchestrate simultaneous OTA updates to multiple ESP32s from a single Flutter instance
5. **Audit log in NVS** — store the last 10 OTA events (timestamp, version, result) in non-volatile storage for post-mortem analysis