/**
 * @file web_routes.cpp
 * @brief Web UI route handler implementations (presentation layer).
 *
 * Migrated from web_ui.cpp — identical logic, now in presentation layer.
 * Serves PROGMEM web assets defined in web_ui_assets.h (auto-generated).
 * CORS preflight support for API endpoints.
 */

#include "src/presentation/web_routes.h"
#include "web_ui_assets.h"
#include "ota_config.h"

#include <Arduino.h>

// ============================================================================
// Asset Serving
// ============================================================================

/**
 * Serve a PROGMEM web asset with correct MIME type and caching headers.
 */
static void serveAsset(WebServer* server, size_t index) {
    if (index >= WEB_ASSETS_COUNT) {
        server->send(404, "text/plain", "Not found");
        return;
    }
    const WebAsset& asset = WEB_ASSETS[index];
    server->sendHeader("Access-Control-Allow-Origin", "*");
    server->sendHeader("Cache-Control", "no-cache");
    server->sendHeader("Content-Encoding", "identity");
    server->send_P(200, asset.content_type, asset.html, asset.length);
}

// ============================================================================
// CORS Preflight
// ============================================================================

static void sendCorsPreflight(WebServer* server, const char* methods) {
    server->sendHeader("Access-Control-Allow-Origin", "*");
    server->sendHeader("Access-Control-Allow-Methods", methods);
    server->sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server->send(204);
}

// ============================================================================
// Individual route handlers (no capturing lambdas — ESP32 WebServer compat)
// ============================================================================

static WebServer* gServer = nullptr;

static void handleRoot()          { serveAsset(gServer, 0); }  // "/" → index.html
static void handleIndexHtml()     { serveAsset(gServer, 1); }  // "/index.html"
static void handleAppJs()        { serveAsset(gServer, 2); }  // "/app.js"
static void handleStyleCss()      { serveAsset(gServer, 3); }  // "/style.css"

// ============================================================================
// Route Registration
// ============================================================================

void registerWebUiRoutes(WebServer* server) {
    gServer = server;

    // Static web assets — explicit routes (ESP32 WebServer needs plain function pointers)
    server->on("/", HTTP_GET, handleRoot);
    server->on("/index.html", HTTP_GET, handleIndexHtml);
    server->on("/app.js", HTTP_GET, handleAppJs);
    server->on("/style.css", HTTP_GET, handleStyleCss);

    // ---- CORS preflight for API endpoints ----

    server->on("/version", HTTP_OPTIONS, [server]() {
        sendCorsPreflight(server, "GET, OPTIONS");
    });

    server->on("/status", HTTP_OPTIONS, [server]() {
        sendCorsPreflight(server, "GET, OPTIONS");
    });

    server->on("/heartbeat", HTTP_OPTIONS, [server]() {
        sendCorsPreflight(server, "GET, POST, OPTIONS");
    });

    server->on("/unlock-ota", HTTP_OPTIONS, [server]() {
        sendCorsPreflight(server, "GET, OPTIONS");
    });

    server->on("/push-firmware", HTTP_OPTIONS, [server]() {
        sendCorsPreflight(server, "POST, OPTIONS");
    });

    LOG(LOG_LEVEL_INFO, "Web UI routes registered: /, /index.html, /app.js, /style.css");
}

// Helper for adding new assets: update WEB_ASSETS_COUNT, add a handler,
// and register the route. The index must match the WEB_ASSETS[] table order.
// To add a new web file:
//   1. Add the source module to data/web/src/
//   2. Re-run embed_web_assets.py
//   3. Add a static handler here and register it in registerWebUiRoutes()