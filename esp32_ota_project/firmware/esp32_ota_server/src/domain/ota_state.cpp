/**
 * @file ota_state.cpp
 * @brief OTA session state management implementation (domain layer).
 *
 * Pure logic for OTA unlock/watchdog state machine and rate limiting.
 * Migrated from ota_handlers.cpp — no WebServer or WiFi dependencies.
 */

#include "src/domain/ota_state.h"

// ============================================================================
// OTA Session State (module-level)
// ============================================================================

/** True when a valid token has unlocked the OTA session */
static bool otaActive = false;

/** Seconds remaining before the OTA window expires (counted down by watchdog) */
static unsigned long otaRemaining = 0;

// ============================================================================
// Rate Limiting State (module-level)
// ============================================================================

/** Number of failed token attempts from the currently tracked IP */
static int failedAttempts = 0;

/** IP address of the client currently being rate-limited */
static IPAddress lockedIp;

/** Timestamp when the lockout period expires (0 = not locked out) */
static unsigned long lockoutExpiry = 0;

// ============================================================================
// OTA Session Lifecycle
// ============================================================================

void otaStateUnlock() {
    otaActive = true;
    otaRemaining = OTA_TIMEOUT_SECONDS;
}

void otaStateReset() {
    otaActive = false;
    otaRemaining = 0;
}

void otaStateWatchdogTick() {
    if (!otaActive) {
        return;
    }

    if (otaRemaining > 0) {
        otaRemaining--;
    }

    if (otaRemaining == 0) {
        LOG_FMT(LOG_LEVEL_WARN, "OTA session watchdog expired — locking session");
        otaStateReset();
    }
}

bool otaStateIsActive() {
    return otaActive;
}

unsigned long otaStateRemainingSeconds() {
    return otaRemaining;
}

// ============================================================================
// Rate Limiting
// ============================================================================

bool otaIsRateLimited(const IPAddress& clientIp) {
    if (lockoutExpiry == 0) {
        return false;
    }

    unsigned long now = millis();

    // Lockout expired — clear it
    if (now >= lockoutExpiry) {
        lockoutExpiry = 0;
        failedAttempts = 0;
        return false;
    }

    // Only rate-limit the IP that triggered the lockout
    if (clientIp == lockedIp) {
        return true;
    }

    return false;
}

void otaRecordFailedAttempt(const IPAddress& clientIp) {
    // Reset counter if the IP changed
    if (clientIp != lockedIp) {
        failedAttempts = 0;
        lockedIp = clientIp;
    }

    failedAttempts++;
    LOG_FMT(LOG_LEVEL_WARN, "Failed unlock attempt #%d from %s",
            failedAttempts, clientIp.toString().c_str());

    if (failedAttempts >= OTA_MAX_FAILED_ATTEMPTS) {
        lockoutExpiry = millis() + (OTA_LOCKOUT_DURATION_S * 1000UL);
        LOG_FMT(LOG_LEVEL_ERROR, "Rate limit triggered for %s — locked for %d seconds",
                clientIp.toString().c_str(), OTA_LOCKOUT_DURATION_S);
    }
}

// ============================================================================
// Utility Functions
// ============================================================================

bool constantTimeCompare(const char* a, const char* b) {
    size_t len = strlen(OTA_SECRET_TOKEN);
    size_t aLen = strlen(a);
    uint8_t result = 0;

    // XOR every character of the expected token, regardless of early mismatch
    for (size_t i = 0; i < len; i++) {
        result |= a[i] ^ b[i];
    }

    // Also verify lengths match to prevent partial-match bypass
    return (result == 0) && (aLen == len);
}

String byteToHex(uint8_t b) {
    char buf[3];
    snprintf(buf, sizeof(buf), "%02X", b);
    return String(buf);
}