/**
 * @file heartbeat_hw.h
 * @brief Heartbeat hardware timer management (infrastructure layer).
 *
 * Manages the ESP32 hardware timer ISR, LED GPIO, and NVS-persisted
 * interval configuration. This module bridges the domain layer's
 * validation logic with the platform-specific hardware APIs.
 *
 * Usage:
 *   heartbeatHwInit()       — call once in setup()
 *   heartbeatHwStart()      — start the hardware timer
 *   heartbeatHwStop()       — stop the hardware timer
 *   heartbeatHwGetInterval() — read current interval
 *   heartbeatHwSetInterval() — change interval (validates, writes NVS, restarts timer)
 *   heartbeatHwGetTickCount() — read total ticks since boot
 *   heartbeatHwIsRunning()  — check if timer is active
 */

#ifndef HEARTBEAT_HW_H
#define HEARTBEAT_HW_H

#include <stdint.h>

/** Initialise the heartbeat hardware subsystem.
 *  - Reads stored interval from NVS (or uses HEARTBEAT_INTERVAL_MS).
 *  - Configures the LED GPIO as output.
 *  - Prepares (but does not start) the hardware timer.
 *  Must be called once in setup() before heartbeatHwStart().
 */
void heartbeatHwInit();

/** Start the hardware timer. The ISR begins firing at the configured interval.
 *  Safe to call multiple times — no-op if already running.
 */
void heartbeatHwStart();

/** Stop the hardware timer and turn off the LED.
 *  Safe to call when already stopped.
 */
void heartbeatHwStop();

/** Return the active tick interval in milliseconds. */
uint32_t heartbeatHwGetInterval();

/**
 * Change the tick interval at runtime.
 *  - Validates via domain layer (10–60000 ms).
 *  - Writes new value to NVS (persists across OTA / reboot).
 *  - Restarts the hardware timer with the new period.
 *  - Returns true on success, false if the value was out of range.
 */
bool heartbeatHwSetInterval(uint32_t new_interval_ms);

/** Return the total number of heartbeat ticks since the last reset. */
uint32_t heartbeatHwGetTickCount();

/** Return true if the hardware timer is currently running. */
bool heartbeatHwIsRunning();

#endif // HEARTBEAT_HW_H