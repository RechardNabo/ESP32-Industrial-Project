/**
 * @file ota_routes.h
 * @brief OTA HTTP route registration and handlers (presentation layer).
 *
 * Registers all OTA-related HTTP endpoints on the WebServer and
 * delegates state logic to the domain layer (ota_state).
 */

#ifndef OTA_ROUTES_H
#define OTA_ROUTES_H

#include <WebServer.h>

/**
 * Register all OTA HTTP route handlers on the given server instance.
 *
 * Sets up GET /version, GET /status, GET /unlock-ota, POST /push-firmware.
 *
 * @param server  Pointer to the WebServer instance to register routes on.
 */
void registerOtaRoutes(WebServer* server);

#endif // OTA_ROUTES_H