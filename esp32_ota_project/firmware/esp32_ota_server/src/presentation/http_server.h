/**
 * @file http_server.h
 * @brief HTTP server wrapper (presentation layer).
 *
 * Wraps the ESP32 WebServer with a thin facade. The main entry point
 * creates an HttpServer and passes it to the route registration functions.
 */

#ifndef HTTP_SERVER_H
#define HTTP_SERVER_H

#include <WebServer.h>
#include "ota_config.h"

class HttpServer {
public:
    /** Construct an HTTP server listening on the given port. */
    explicit HttpServer(int port = HTTP_PORT);

    /** Start accepting connections. */
    void begin();

    /** Process one incoming request (call in loop()). */
    void handleClient();

    /** Get the underlying WebServer pointer for route registration. */
    WebServer* rawServer();

private:
    WebServer _server;
};

/**
 * Register all HTTP routes on the given server:
 *   - Web UI static assets + CORS
 *   - OTA endpoints (/version, /status, /unlock-ota, /push-firmware)
 *   - Heartbeat endpoints (GET/POST /heartbeat)
 */
void registerAllRoutes(HttpServer& server);

#endif // HTTP_SERVER_H