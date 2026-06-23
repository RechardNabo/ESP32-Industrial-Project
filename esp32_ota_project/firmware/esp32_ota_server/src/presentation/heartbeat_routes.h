/**
 * @file heartbeat_routes.h
 * @brief Heartbeat HTTP route registration and handlers (presentation layer).
 *
 * Registers GET/POST /heartbeat on the WebServer. Hardware timer management
 * is delegated to the infrastructure layer (heartbeat_hw).
 */

#ifndef HEARTBEAT_ROUTES_H
#define HEARTBEAT_ROUTES_H

#include <WebServer.h>

/**
 * Register /heartbeat GET (and optional POST) routes on the given server.
 *
 * GET  /heartbeat           → JSON with interval, tick_count, led_pin
 * POST /heartbeat?interval=N → reconfigure interval (writes NVS)
 */
void registerHeartbeatRoutes(WebServer* server);

#endif // HEARTBEAT_ROUTES_H