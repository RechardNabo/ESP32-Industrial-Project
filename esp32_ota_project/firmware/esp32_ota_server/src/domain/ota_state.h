/**
 * @file ota_state.h
 * @brief OTA session state management (domain layer — no hardware dependencies).
 *
 * Encapsulates the OTA unlock/watchdog state machine and rate-limiting logic.
 * This module is pure domain logic; it has no dependency on WebServer, WiFi,
 * or any ESP32 peripheral. HTTP route handlers in the presentation layer
 * delegate to these functions for state transitions and queries.
 */

#ifndef OTA_STATE_H
#define OTA_STATE_H

#include <Arduino.h>
#include <IPAddress.h>
#include "ota_config.h"

// ============================================================================
// OTA Session State
// ============================================================================

/**
 * Unlock the OTA session for OTA_TIMEOUT_SECONDS.
 * Called when the token validation succeeds.
 */
void otaStateUnlock();

/**
 * Reset (lock) the OTA session.
 * Called after a successful firmware push, a watchdog timeout,
 * or an unrecoverable error.
 */
void otaStateReset();

/**
 * Tick the OTA watchdog — decrements the remaining seconds counter.
 * Called from loop() every 1 second while the OTA session is active.
 * When the counter reaches zero, the session is automatically locked.
 */
void otaStateWatchdogTick();

/** Returns true if an OTA session is currently unlocked. */
bool otaStateIsActive();

/** Returns the number of seconds remaining in the current OTA unlock window. */
unsigned long otaStateRemainingSeconds();

// ============================================================================
// Rate Limiting
// ============================================================================

/**
 * Check if the given client IP is currently rate-limited.
 *
 * @param clientIp  The IP address of the requesting client
 * @return          true if the client is locked out
 */
bool otaIsRateLimited(const IPAddress& clientIp);

/**
 * Record a failed token attempt from the given IP.
 *
 * After OTA_MAX_FAILED_ATTEMPTS failures from the same IP within the
 * configured window, the IP is locked out for OTA_LOCKOUT_DURATION_S seconds.
 *
 * @param clientIp  The IP address of the requesting client
 */
void otaRecordFailedAttempt(const IPAddress& clientIp);

// ============================================================================
// Utility (domain-level, no side effects)
// ============================================================================

/**
 * Constant-time string comparison to prevent timing attacks.
 *
 * Compares two null-terminated strings byte-by-byte, always examining
 * every character regardless of where the first mismatch occurs.
 *
 * @param a  First string (typically the user-supplied token)
 * @param b  Second string (typically OTA_SECRET_TOKEN)
 * @return   true if strings match, false otherwise
 */
bool constantTimeCompare(const char* a, const char* b);

/**
 * Convert a byte value to its two-character uppercase hex string.
 *
 * @param b  Byte value (0x00–0xFF)
 * @return   String like "E9" or "00"
 */
String byteToHex(uint8_t b);

#endif // OTA_STATE_H