/**
 * @file app_entry.h
 * @brief Application entry point declarations (main layer).
 *
 * Declares the init and loop functions that are called from
 * the Arduino sketch .ino file. This keeps the .ino file minimal
 * and moves all real logic into the src/ architecture.
 */

#ifndef APP_ENTRY_H
#define APP_ENTRY_H

/**
 * Application-level setup — called from Arduino setup().
 * Orchestrates all subsystem initialisation:
 *   1. Serial
 *   2. Heartbeat hardware init
 *   3. Wi-Fi connection
 *   4. mDNS responder
 *   5. HTTP route registration
 *   6. HTTP server start
 *   7. Heartbeat hardware timer start
 */
void appSetup();

/**
 * Application-level loop — called from Arduino loop().
 * Processes HTTP requests and ticks the OTA watchdog.
 */
void appLoop();

#endif // APP_ENTRY_H