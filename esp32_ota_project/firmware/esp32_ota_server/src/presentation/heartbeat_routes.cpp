/**
 * @file heartbeat_routes.cpp
 * @brief Heartbeat HTTP route handler implementations (presentation layer).
 *
 * Migrated from heartbeat.cpp — HTTP handler logic extracted from the
 * hardware module. Hardware operations delegate to heartbeat_hw (infrastructure).
 */

#include "src/presentation/heartbeat_routes.h"
#include "src/infrastructure/heartbeat_hw.h"
#include "ota_config.h"

#include <Arduino.h>

// ============================================================================
// HTTP Handlers
// ============================================================================

/**
 * GET /heartbeat
 * Returns JSON:
 *   {
 *     "interval_ms": 500,
 *     "tick_count": 12345,
 *     "led_pin": 2,
 *     "running": true
 *   }
 */
static void handleHeartbeatGet(WebServer* server) {
    server->sendHeader("Access-Control-Allow-Origin", "*");

    // Read values from infrastructure layer (ISR-safe single reads)
    uint32_t ticks = heartbeatHwGetTickCount();
    uint32_t interval = heartbeatHwGetInterval();
    bool running = heartbeatHwIsRunning();

    char json[256];
    snprintf(json, sizeof(json),
        "{\"interval_ms\":%lu,\"tick_count\":%lu,\"led_pin\":%d,\"running\":%s}",
        (unsigned long)interval,
        (unsigned long)ticks,
        HEARTBEAT_LED_PIN,
        running ? "true" : "false");
    server->send(200, "application/json", json);
}

/**
 * POST /heartbeat?interval=N
 * Reconfigures the heartbeat interval. Writes to NVS so it survives
 * across OTA updates and reboots.
 */
static void handleHeartbeatPost(WebServer* server) {
    server->sendHeader("Access-Control-Allow-Origin", "*");
    if (!server->hasArg("interval")) {
        server->send(400, "application/json",
            "{\"error\":\"Missing 'interval' query parameter\"}");
        return;
    }

    unsigned long val = server->arg("interval").toInt();
    if (val == 0) {
        server->send(400, "application/json",
            "{\"error\":\"Invalid interval value — must be integer >= 10\"}");
        return;
    }

    if (heartbeatHwSetInterval((uint32_t)val)) {
        char json[256];
        snprintf(json, sizeof(json),
            "{\"interval_ms\":%lu,\"tick_count\":%lu,\"message\":\"Interval updated and persisted to NVS\"}",
            (unsigned long)heartbeatHwGetInterval(),
            (unsigned long)heartbeatHwGetTickCount());
        server->send(200, "application/json", json);
    } else {
        server->send(400, "application/json",
            "{\"error\":\"Interval must be 10–60000 ms\"}");
    }
}

void registerHeartbeatRoutes(WebServer* server) {
    server->on("/heartbeat", HTTP_GET, [server]() { handleHeartbeatGet(server); });
    server->on("/heartbeat", HTTP_POST, [server]() { handleHeartbeatPost(server); });

    LOG(LOG_LEVEL_INFO, "Heartbeat endpoints registered: GET/POST /heartbeat");
}