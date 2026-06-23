/**
 * @file heartbeat_domain.h
 * @brief Heartbeat domain logic (pure validation and queries — no hardware deps).
 *
 * Provides interval validation and state queries for the heartbeat subsystem.
 * Hardware-specific operations (ISR, NVS, timer) live in the infrastructure layer.
 */

#ifndef HEARTBEAT_DOMAIN_H
#define HEARTBEAT_DOMAIN_H

#include <Arduino.h>
#include "ota_config.h"

// ============================================================================
// Constants
// ============================================================================

/** Minimum allowed heartbeat interval in milliseconds */
static constexpr uint32_t HB_MIN_INTERVAL_MS = 10;

/** Maximum allowed heartbeat interval in milliseconds */
static constexpr uint32_t HB_MAX_INTERVAL_MS = 60000;

// ============================================================================
// Validation
// ============================================================================

/**
 * Validate a heartbeat interval value.
 *
 * @param interval_ms  The proposed interval in milliseconds
 * @return             true if the interval is within [HB_MIN_INTERVAL_MS, HB_MAX_INTERVAL_MS]
 */
inline bool heartbeatValidateInterval(uint32_t interval_ms) {
    return (interval_ms >= HB_MIN_INTERVAL_MS && interval_ms <= HB_MAX_INTERVAL_MS);
}

#endif // HEARTBEAT_DOMAIN_H