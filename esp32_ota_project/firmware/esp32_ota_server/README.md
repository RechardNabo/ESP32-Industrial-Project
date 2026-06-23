# ESP32 OTA Server — Clean Architecture

## Architecture Overview

The firmware follows a **clean architecture** pattern with four layers, each with a clear responsibility and dependency direction (outer layers depend on inner layers, never the reverse).

```
┌─────────────────────────────────────────────────────────────┐
│                    src/main/ (Orchestration)                  │
│  app_entry.cpp — setup() and loop() coordination            │
├─────────────────────────────────────────────────────────────┤
│                 src/presentation/ (HTTP Routes)               │
│  ota_routes.cpp — /version, /status, /unlock-ota,             │
│                   /push-firmware                               │
│  heartbeat_routes.cpp — GET/POST /heartbeat                   │
│  web_routes.cpp — Static assets (/index.html, /style.css,    │
│                   /app.js) + CORS preflight                    │
│  http_server.cpp — WebServer wrapper                          │
├─────────────────────────────────────────────────────────────┤
│               src/infrastructure/ (Hardware/Platform)         │
│  wifi_connection.cpp — Wi-Fi connect + deep-sleep retry       │
│  heartbeat_hw.cpp — Hardware timer ISR, LED GPIO, timer ops   │
│  nvs_storage.cpp — Preferences/NVS read/write wrappers        │
├─────────────────────────────────────────────────────────────┤
│                 src/domain/ (Pure Business Logic)              │
│  ota_state.cpp — OTA unlock/watchdog state machine,           │
│                  rate limiting, constant-time compare           │
│  heartbeat_domain.h — Interval validation (inline)            │
└─────────────────────────────────────────────────────────────┘
```

### Dependency Rule

```
domain → (no dependencies — pure logic)
infrastructure → domain
presentation → domain, infrastructure
main → all layers
```

- **Domain** has ZERO hardware, WiFi, or WebServer imports — only `Arduino.h` for basic types and `ota_config.h` for constants.
- **Infrastructure** wraps ESP32-specific APIs (Preferences, WiFi, hardware timers) and calls domain validation.
- **Presentation** handles HTTP I/O via `WebServer*`, delegating state queries/transitions to domain functions.
- **Main** orchestrates init order and the run loop.

### Remaining Root Files

| File | Purpose |
|------|---------|
| `esp32_ota_server.ino` | Slim entry point — `#include "src/main/app_entry.h"`, calls `appSetup()`/`appLoop()` |
| `ota_config.h` | Centralized `#define` constants, logging macros — included by all layers |
| `web_ui_assets.h` | Auto-generated PROGMEM assets — do not edit |
| `partitions_ota.csv` | Dual-OTA partition table |
| `embed_web_assets.py` | Script to regenerate `web_ui_assets.h` from `data/web/*` |

### Data Flow

```
HTTP Request
    │
    ▼
Presentation Layer (ota_routes, heartbeat_routes, web_routes)
    │
    ├── GET /version     → reads FIRMWARE_VERSION from ota_config.h
    ├── GET /status      → calls otaStateIsActive(), otaStateRemainingSeconds() + ESP getters
    ├── GET /unlock-ota  → calls constantTimeCompare() from domain → otaStateUnlock()
    ├── POST /push-firmware → calls otaStateIsActive() guard → Update API → otaStateReset()
    ├── GET/POST /heartbeat → calls heartbeatHw*() from infrastructure
    └── Static assets → PROGMEM from web_ui_assets.h

OTA Watchdog (in loop):
    │
    ▼
appLoop() → if otaStateIsActive() → otaStateWatchdogTick() every 1s

Heartbeat ISR (hardware timer):
    │
    ▼
heartbeat_hw.cpp::_heartbeat_isr() — toggles LED, increments tick count
```

## Key Design Decisions

1. **No behavior changes** — Every API endpoint produces identical JSON responses. The refactoring is purely structural.
2. **Domain layer is hardware-free** — `ota_state.cpp` has no `#include <WebServer.h>` or `#include <WiFi.h>`. Pure logic and state transitions only.
3. **ISR stays with hardware** — The `_heartbeat_isr()` and `hw_timer_t*` management remain in `infrastructure/heartbeat_hw.cpp` because they're tightly coupled to ESP32 timer APIs.
4. **NVS abstracted** — `nvs_storage.cpp` wraps `Preferences` so domain logic doesn't directly call NVS.
5. **Upload callback pattern preserved** — The multipart upload handler (`otaUploadHandler`) needs global `WebServer*` access, so it stays in the presentation layer with a module-level `gServer` pointer, same as the original.
6. **Arduino IDE compatibility** — All `.cpp` files under `src/` are compiled automatically by the Arduino IDE. The sketch root only has the `.ino` entry point, config headers, and the auto-generated assets.

## Migration Map

| Old File | New Location | Notes |
|----------|-------------|-------|
| `ota_handlers.h/.cpp` | `src/domain/ota_state.h/.cpp` + `src/presentation/ota_routes.h/.cpp` | State logic → domain; HTTP handling → presentation |
| `heartbeat.h/.cpp` | `src/domain/heartbeat_domain.h` + `src/infrastructure/heartbeat_hw.h/.cpp` + `src/infrastructure/nvs_storage.h/.cpp` + `src/presentation/heartbeat_routes.h/.cpp` | Validation → domain; ISR/timer → infrastructure; HTTP → presentation |
| `web_ui.h/.cpp` | `src/presentation/web_routes.h/.cpp` | Renamed for consistent naming |
| `esp32_ota_server.ino` (connectWifi + setup/loop) | `src/infrastructure/wifi_connection.h/.cpp` + `src/main/app_entry.h/.cpp` | WiFi → infrastructure; orchestration → main |

## To Build

1. Open `esp32_ota_server.ino` in Arduino IDE
2. Select board: ESP32 Dev Module (or your variant)
3. Select partition scheme: Custom (pointing to `partitions_ota.csv`)
4. Compile and upload

If modifying the web UI:
1. Edit files in `data/web/` (index.html, style.css, app.js)
2. Run: `python3 embed_web_assets.py`
3. Recompile the sketch