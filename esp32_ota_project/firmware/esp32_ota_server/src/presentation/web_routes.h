/**
 * @file web_routes.h
 * @brief Web UI static asset routes and CORS handlers (presentation layer).
 *
 * Registers routes for serving the SPA HTML, CSS, JavaScript from PROGMEM,
 * and CORS preflight responses for API endpoints.
 */

#ifndef WEB_ROUTES_H
#define WEB_ROUTES_H

#include <WebServer.h>

/**
 * Register the web UI routes on the given server.
 *   GET /           → serves the SPA HTML page
 *   GET /style.css  → serves the CSS
 *   GET /app.js     → serves the JavaScript
 *   OPTIONS /*      → CORS preflight responses
 */
void registerWebUiRoutes(WebServer* server);

#endif // WEB_ROUTES_H