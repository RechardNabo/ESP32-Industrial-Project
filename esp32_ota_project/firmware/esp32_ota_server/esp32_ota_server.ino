/**
 * @file esp32_ota_server.ino
 * @brief Main Arduino sketch for the ESP32 OTA firmware update server.
 *
 * This file is a slim entry point that delegates to the clean-architecture
 * modules in src/. All application logic lives in:
 *   - src/domain/       — Pure business logic (state machines, validation)
 *   - src/infrastructure/ — Hardware/platform specifics (Wi-Fi, NVS, ISR timers)
 *   - src/presentation/ — HTTP routes and web serving
 *   - src/main/         — Application orchestration (setup, loop)
 *
 * See README.md for the full architecture diagram.
 */

#include "src/main/app_entry.h"

void setup() {
    appSetup();
}

void loop() {
    appLoop();
}