/**
 * @file heartbeat_hw.cpp
 * @brief Heartbeat hardware timer implementation (infrastructure layer).
 *
 * Migrated from heartbeat.cpp — identical logic, now in infrastructure layer.
 * Uses heartbeat_domain.h for validation and nvs_storage.h for persistence.
 */

#include "src/infrastructure/heartbeat_hw.h"
#include "src/domain/heartbeat_domain.h"
#include "src/infrastructure/nvs_storage.h"
#include "ota_config.h"

#include <Arduino.h>

// ============================================================================
// Private State
// ============================================================================

/** Active interval in milliseconds. Read from NVS or default. */
static volatile uint32_t _interval_ms = HEARTBEAT_INTERVAL_MS;

/** Total tick counter, incremented in ISR only. */
static volatile uint32_t _tick_count = 0;

/** Current LED state (toggled in ISR). */
static volatile bool _led_state = false;

/** Whether the hardware timer is currently running. */
static volatile bool _running = false;

/** ESP32 hardware timer handle. */
static hw_timer_t* _timer = nullptr;

// ============================================================================
// ISR
// ============================================================================

/**
 * Hardware timer ISR. Fires every _interval_ms milliseconds.
 * Toggles LED and increments tick counter. Keeps execution to absolute minimum.
 */
void IRAM_ATTR _heartbeat_isr() {
    _led_state = !_led_state;
    digitalWrite(HEARTBEAT_LED_PIN, _led_state ? HIGH : LOW);
    _tick_count++;
}

// ============================================================================
// Lifecycle
// ============================================================================

void heartbeatHwInit() {
    // 1. Configure LED pin
    pinMode(HEARTBEAT_LED_PIN, OUTPUT);
    digitalWrite(HEARTBEAT_LED_PIN, LOW);

    // 2. Read persisted interval from NVS
    uint32_t stored = nvsReadUInt(HEARTBEAT_NVS_NAMESPACE, HEARTBEAT_NVS_KEY_INTERVAL, 0);

    if (stored >= 10 && stored <= 60000) {
        // Valid stored value — use it
        _interval_ms = stored;
    } else {
        // No stored value or out of range — persist the compile-time default
        _interval_ms = HEARTBEAT_INTERVAL_MS;
        nvsWriteUInt(HEARTBEAT_NVS_NAMESPACE, HEARTBEAT_NVS_KEY_INTERVAL, _interval_ms);
    }

    // 3. Allocate hardware timer (but do NOT start it yet)
    //    ESP32 Arduino core v3: timerBegin() takes frequency instead of (num, prescaler).
    //    APB_CLK = 80 MHz, prescaler 80 → 1 MHz = 1,000,000 Hz
    _timer = timerBegin(1000000);

    LOG_FMT(LOG_LEVEL_INFO,
            "Heartbeat initialised — interval: %lu ms, LED pin: %d",
            (unsigned long)_interval_ms, HEARTBEAT_LED_PIN);
}

void heartbeatHwStart() {
    if (_running || _timer == nullptr) return;

    // Attach ISR to timer: fire every _interval_ms * 1000 µs
    // ESP32 Arduino core v3: timerAttachInterrupt takes 2 args (no edge flag)
    timerAttachInterrupt(_timer, &_heartbeat_isr);

    // Set alarm: auto-reload, period in microseconds
    // ESP32 Arduino core v3: timerAlarm() replaces timerAlarmWrite + timerAlarmEnable
    // Cast away volatile — the value is stable at this point (not modified by ISR).
    uint64_t alarm_us = (uint64_t)_interval_ms * 1000ULL;
    timerAlarm(_timer, alarm_us, true, 0);   // true = auto-reload, 0 = fire repeatedly

    // In v3, after timerAlarm() on a stopped timer, we must explicitly
    // restart the counter for the alarm to fire.
    timerStart(_timer);

    _running = true;

    Serial.print("[HEARTBEAT] Timer started — ");
    Serial.print((unsigned long)_interval_ms);
    Serial.println(" ms tick");
}

void heartbeatHwStop() {
    if (!_running || _timer == nullptr) return;

    // ESP32 Arduino core v3: timerAlarmDisable → timerStop
    timerStop(_timer);
    timerDetachInterrupt(_timer);
    _running = false;

    // Turn LED off when stopped
    digitalWrite(HEARTBEAT_LED_PIN, LOW);
    _led_state = false;

    Serial.println("[HEARTBEAT] Timer stopped");
}

// ============================================================================
// Runtime Queries
// ============================================================================

uint32_t heartbeatHwGetInterval() {
    return _interval_ms;
}

bool heartbeatHwSetInterval(uint32_t new_interval_ms) {
    // Validate using domain layer
    if (!heartbeatValidateInterval(new_interval_ms)) {
        LOG_FMT(LOG_LEVEL_ERROR,
                "Heartbeat interval out of range: %lu ms (must be 10–60000)",
                (unsigned long)new_interval_ms);
        return false;
    }

    // Stop timer while reconfiguring
    bool was_running = _running;
    if (was_running) {
        heartbeatHwStop();
    }

    // Update active interval
    _interval_ms = new_interval_ms;

    // Persist to NVS — survives reboot and OTA updates
    nvsWriteUInt(HEARTBEAT_NVS_NAMESPACE, HEARTBEAT_NVS_KEY_INTERVAL, _interval_ms);

    LOG_FMT(LOG_LEVEL_INFO, "Heartbeat interval changed to %lu ms (persisted to NVS)",
            (unsigned long)_interval_ms);

    // Restart timer if it was running before
    if (was_running) {
        heartbeatHwStart();
    }

    Serial.print("[HEARTBEAT] Interval changed to ");
    Serial.print(new_interval_ms);
    Serial.println(" ms, timer restarted");

    return true;
}

uint32_t heartbeatHwGetTickCount() {
    return _tick_count;
}

bool heartbeatHwIsRunning() {
    return _running;
}