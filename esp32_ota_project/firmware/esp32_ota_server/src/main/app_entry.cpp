/**
 * @file app_entry.cpp
 * @brief Application entry point implementation (main layer).
 *
 * Orchestrates all subsystem initialisation and the main loop.
 * Migrated from esp32_ota_server.ino — identical logic, now
 * using the layered architecture.
 */

#include "src/main/app_entry.h"
#include "ota_config.h"
#include "src/domain/ota_state.h"
#include "src/infrastructure/wifi_connection.h"
#include "src/infrastructure/heartbeat_hw.h"
#include "src/presentation/ota_routes.h"
#include "src/presentation/heartbeat_routes.h"
#include "src/presentation/web_routes.h"

#include <WiFi.h>
#include <ESPmDNS.h>
#include <WebServer.h>

// ============================================================================
// Global HTTP Server
// ============================================================================

/** Web server instance listening on HTTP_PORT */
static WebServer server(HTTP_PORT);

// ============================================================================
// Application Setup
// ============================================================================

void appSetup() {
    // Step 1: Serial initialisation
    Serial.begin(115200);
    delay(100);
    Serial.println();
    Serial.println("===============================");
    Serial.println(" ESP32 OTA Server Starting");
    Serial.println("===============================");

    LOG_FMT(LOG_LEVEL_INFO, "Firmware version: %s", FIRMWARE_VERSION);

    // Step 2: Initialise heartbeat (reads persisted interval from NVS)
    heartbeatHwInit();

    // Step 3: Wi-Fi connection (blocking, with deep-sleep retry)
    connectWifi();

    // Step 4: Start mDNS responder
    if (MDNS.begin(MDNS_HOSTNAME)) {
        LOG_FMT(LOG_LEVEL_INFO, "mDNS responder started — http://%s.local/", MDNS_HOSTNAME);
        // Advertise HTTP service so Flutter can discover via _http._tcp
        MDNS.addService("http", "tcp", HTTP_PORT);
    } else {
        LOG(LOG_LEVEL_ERROR, "mDNS responder failed to start");
    }

    // Step 5: Register HTTP route handlers (web UI, OTA, heartbeat)
    registerWebUiRoutes(&server);
    registerOtaRoutes(&server);
    registerHeartbeatRoutes(&server);

    // Step 6: Start HTTP server
    server.begin();
    LOG_FMT(LOG_LEVEL_INFO, "HTTP server started on port %d", HTTP_PORT);

    // Step 7: Start the heartbeat hardware timer (ISR-driven, 500 ms tick)
    heartbeatHwStart();

    // Step 8: Log ready state
    Serial.println("===============================");
    LOG_FMT(LOG_LEVEL_INFO, "Ready — IP: %s  mDNS: %s.local  Version: %s  Heartbeat: %lums",
            WiFi.localIP().toString().c_str(), MDNS_HOSTNAME, FIRMWARE_VERSION,
            (unsigned long)heartbeatHwGetInterval());
    Serial.println("===============================");
}

// ============================================================================
// Application Loop
// ============================================================================

void appLoop() {
    // Process incoming HTTP requests
    server.handleClient();

    // ESP32 Arduino core v3: MDNS.update() removed — mDNS is handled
    // automatically by the underlying lwIP mdns daemon. No manual update needed.

    // OTA watchdog: decrement the unlock window counter every 1 second
    if (otaStateIsActive()) {
        unsigned long now = millis();
        // Use non-blocking millisecond timer (not delay())
        static unsigned long lastTick = 0;
        if (now - lastTick >= 1000UL) {
            lastTick = now;
            otaStateWatchdogTick();
        }
    }

    // Heartbeat runs in hardware timer ISR — nothing needed in loop()
    // The LED toggles and tick count increments automatically.
}