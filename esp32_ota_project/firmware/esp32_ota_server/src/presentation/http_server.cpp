/**
 * @file http_server.cpp
 * @brief HTTP server wrapper implementation.
 */

#include "src/presentation/http_server.h"
#include "ota_config.h"

HttpServer::HttpServer(int port) : _server(port) {}

void HttpServer::begin() {
    _server.begin();
}

void HttpServer::handleClient() {
    _server.handleClient();
}

WebServer* HttpServer::rawServer() {
    return &_server;
}

void registerAllRoutes(HttpServer& server) {
    // Delegated to each route module — called from app_entry.cpp
    // which calls registerWebUiRoutes, registerOtaRoutes, registerHeartbeatRoutes
}