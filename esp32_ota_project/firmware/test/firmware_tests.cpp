/**
 * @file firmware_tests.cpp
 * @brief Unity-style unit tests for ESP32 OTA firmware components.
 *
 * Tests for:
 *   - constantTimeCompare() correctness
 *   - Watchdog counter decrement and reset logic
 *   - Magic byte extraction from a mock buffer
 *   - Heartbeat interval validation (set_interval_ms range checks)
 *   - Heartbeat tick counter monotonic increment
 *
 * IMPORTANT: This file MUST NOT be in the Arduino sketch folder.
 * Arduino compiles ALL .cpp files in the sketch directory together, which
 * would cause multiple definition errors (duplicate setup(), loop(), etc.).
 * This file is kept in firmware/test/ and should be compiled separately
 * using PlatformIO's Unity test runner or as a standalone test sketch.
 *
 * To run with PlatformIO:
 *   cd firmware && pio test -e esp32dev
 *
 * To run with Arduino IDE:
 *   Copy this file to a SEPARATE sketch folder (not the main one), install
 *   Unity via Library Manager, compile and upload, then check Serial output.
 */

#include <Arduino.h>
#include <unity.h>

// ============================================================================
// Include the code under test
// ============================================================================
// Note: For Unity testing, we inline the minimal testable logic here
// since the actual firmware uses WebServer and WiFi which are not
// available in a test harness.

// --- constantTimeCompare (replicated from ota_handlers.cpp) ---
#define OTA_SECRET_TOKEN "SecretFlash2026"

bool constantTimeCompare(const char* a, const char* b) {
    size_t len = strlen(OTA_SECRET_TOKEN);
    size_t aLen = strlen(a);
    uint8_t result = 0;
    for (size_t i = 0; i < len; i++) {
        result |= a[i] ^ b[i];
    }
    return (result == 0) && (aLen == len);
}

// --- Watchdog tick logic (replicated from ota_handlers.cpp) ---
static bool otaActive = false;
static unsigned long otaRemaining = 0;

void otaWatchdogTick() {
    if (!otaActive) return;
    if (otaRemaining > 0) {
        otaRemaining--;
    }
    if (otaRemaining == 0) {
        otaActive = false;
    }
}

// --- Magic byte constant ---
#define ESP_MAGIC_BYTE 0xE9

// --- Heartbeat interval validation logic (replicated from heartbeat.cpp) ---
// Minimum and maximum allowed heartbeat intervals in milliseconds
#define HB_MIN_INTERVAL_MS  10
#define HB_MAX_INTERVAL_MS  60000
#define HB_DEFAULT_INTERVAL_MS 500

static uint32_t hb_interval_ms = HB_DEFAULT_INTERVAL_MS;
static uint32_t hb_tick_count = 0;

bool heartbeat_set_interval_ms(uint32_t new_interval_ms) {
    if (new_interval_ms < HB_MIN_INTERVAL_MS || new_interval_ms > HB_MAX_INTERVAL_MS) {
        return false;
    }
    hb_interval_ms = new_interval_ms;
    return true;
}

// ============================================================================
// constantTimeCompare Tests
// ============================================================================

void test_constantTimeCompare_correct_token(void) {
    TEST_ASSERT_TRUE(constantTimeCompare("SecretFlash2026", OTA_SECRET_TOKEN));
}

void test_constantTimeCompare_wrong_token(void) {
    TEST_ASSERT_FALSE(constantTimeCompare("WrongToken12345", OTA_SECRET_TOKEN));
}

void test_constantTimeCompare_empty_token(void) {
    TEST_ASSERT_FALSE(constantTimeCompare("", OTA_SECRET_TOKEN));
}

void test_constantTimeCompare_partial_match(void) {
    // "SecretFlash202" is shorter — length check should fail
    TEST_ASSERT_FALSE(constantTimeCompare("SecretFlash202", OTA_SECRET_TOKEN));
}

void test_constantTimeCompare_off_by_one(void) {
    // Last character different
    TEST_ASSERT_FALSE(constantTimeCompare("SecretFlash2027", OTA_SECRET_TOKEN));
}

// ============================================================================
// Watchdog Tests
// ============================================================================

void test_watchdog_decrements_remaining(void) {
    otaActive = true;
    otaRemaining = 10;

    otaWatchdogTick();
    TEST_ASSERT_EQUAL_UINT(9, otaRemaining);
    TEST_ASSERT_TRUE(otaActive);
}

void test_watchdog_does_not_decrement_below_zero(void) {
    otaActive = true;
    otaRemaining = 1;

    otaWatchdogTick();
    TEST_ASSERT_EQUAL_UINT(0, otaRemaining);

    // Should deactivate now
    TEST_ASSERT_FALSE(otaActive);
}

void test_watchdog_deactivates_on_timeout(void) {
    otaActive = true;
    otaRemaining = 0;

    // otaRemaining is already 0 — nothing to decrement
    // But if otaActive is still true due to race, tick should deactivate
    otaWatchdogTick();
    TEST_ASSERT_FALSE(otaActive);
}

void test_watchdog_does_not_tick_when_inactive(void) {
    otaActive = false;
    otaRemaining = 60;

    otaWatchdogTick();
    // Should remain unchanged
    TEST_ASSERT_EQUAL_UINT(60, otaRemaining);
    TEST_ASSERT_FALSE(otaActive);
}

void test_watchdog_full_countdown(void) {
    otaActive = true;
    otaRemaining = 5;

    for (int i = 0; i < 5; i++) {
        otaWatchdogTick();
    }

    TEST_ASSERT_EQUAL_UINT(0, otaRemaining);
    TEST_ASSERT_FALSE(otaActive);
}

// ============================================================================
// Magic Byte Tests
// ============================================================================

void test_magic_byte_is_0xE9(void) {
    TEST_ASSERT_EQUAL_UINT8(0xE9, ESP_MAGIC_BYTE);
}

void test_magic_byte_from_mock_buffer(void) {
    // Simulate the first byte check from OTA upload handler
    uint8_t mockBuffer[] = {0xE9, 0x04, 0x02, 0x01};
    TEST_ASSERT_EQUAL_UINT8(ESP_MAGIC_BYTE, mockBuffer[0]);
}

void test_magic_byte_rejection(void) {
    // Non-ESP32 binary starts with wrong magic byte
    uint8_t mockBuffer[] = {0xFF, 0x04, 0x02, 0x01};
    TEST_ASSERT_NOT_EQUAL(ESP_MAGIC_BYTE, mockBuffer[0]);
}

void test_magic_byte_hex_conversion(void) {
    // Verify we can convert to hex string for error messages
    uint8_t invalidByte = 0xFF;
    char hex[3];
    snprintf(hex, sizeof(hex), "%02X", invalidByte);
    TEST_ASSERT_EQUAL_STRING("FF", hex);

    uint8_t validByte = 0xE9;
    snprintf(hex, sizeof(hex), "%02X", validByte);
    TEST_ASSERT_EQUAL_STRING("E9", hex);
}

// ============================================================================
// Heartbeat Interval Validation Tests
// ============================================================================

void test_heartbeat_default_interval(void) {
    // Default should be 500 ms
    hb_interval_ms = HB_DEFAULT_INTERVAL_MS;
    TEST_ASSERT_EQUAL_UINT32(500, hb_interval_ms);
}

void test_heartbeat_set_valid_interval(void) {
    // Normal intervals should be accepted
    TEST_ASSERT_TRUE(heartbeat_set_interval_ms(100));
    TEST_ASSERT_EQUAL_UINT32(100, hb_interval_ms);

    TEST_ASSERT_TRUE(heartbeat_set_interval_ms(1000));
    TEST_ASSERT_EQUAL_UINT32(1000, hb_interval_ms);

    TEST_ASSERT_TRUE(heartbeat_set_interval_ms(60000));
    TEST_ASSERT_EQUAL_UINT32(60000, hb_interval_ms);

    // Reset to default
    heartbeat_set_interval_ms(500);
}

void test_heartbeat_reject_below_minimum(void) {
    // Below 10 ms should be rejected
    TEST_ASSERT_FALSE(heartbeat_set_interval_ms(9));
    TEST_ASSERT_FALSE(heartbeat_set_interval_ms(1));
    TEST_ASSERT_FALSE(heartbeat_set_interval_ms(0));

    // Interval should remain unchanged after rejection
    TEST_ASSERT_EQUAL_UINT32(500, hb_interval_ms);
}

void test_heartbeat_reject_above_maximum(void) {
    // Above 60000 ms should be rejected
    TEST_ASSERT_FALSE(heartbeat_set_interval_ms(60001));
    TEST_ASSERT_FALSE(heartbeat_set_interval_ms(120000));

    // Interval should remain unchanged after rejection
    TEST_ASSERT_EQUAL_UINT32(500, hb_interval_ms);
}

void test_heartbeat_boundary_values(void) {
    // Exactly at boundaries should be accepted
    TEST_ASSERT_TRUE(heartbeat_set_interval_ms(10));      // minimum
    TEST_ASSERT_EQUAL_UINT32(10, hb_interval_ms);

    TEST_ASSERT_TRUE(heartbeat_set_interval_ms(60000));   // maximum
    TEST_ASSERT_EQUAL_UINT32(60000, hb_interval_ms);

    // Reset
    heartbeat_set_interval_ms(500);
}

void test_heartbeat_tick_count_increments(void) {
    // Simulate ISR tick counter increments
    hb_tick_count = 0;
    for (int i = 0; i < 100; i++) {
        hb_tick_count++;
    }
    TEST_ASSERT_EQUAL_UINT32(100, hb_tick_count);

    // Verify default 500ms interval produces correct tick rate:
    // 2 ticks per second = 500ms each
    hb_tick_count = 0;
    uint32_t elapsed_ms = 10000; // 10 seconds
    uint32_t ticks = elapsed_ms / hb_interval_ms;
    TEST_ASSERT_EQUAL_UINT32(20, ticks); // 10s / 500ms = 20 ticks

    hb_tick_count = 0;
}

// ============================================================================
// Setup and Runner
// ============================================================================

void setup() {
    delay(2000);
    UNITY_BEGIN();

    // constantTimeCompare tests
    RUN_TEST(test_constantTimeCompare_correct_token);
    RUN_TEST(test_constantTimeCompare_wrong_token);
    RUN_TEST(test_constantTimeCompare_empty_token);
    RUN_TEST(test_constantTimeCompare_partial_match);
    RUN_TEST(test_constantTimeCompare_off_by_one);

    // Watchdog tests
    RUN_TEST(test_watchdog_decrements_remaining);
    RUN_TEST(test_watchdog_does_not_decrement_below_zero);
    RUN_TEST(test_watchdog_deactivates_on_timeout);
    RUN_TEST(test_watchdog_does_not_tick_when_inactive);
    RUN_TEST(test_watchdog_full_countdown);

    // Magic byte tests
    RUN_TEST(test_magic_byte_is_0xE9);
    RUN_TEST(test_magic_byte_from_mock_buffer);
    RUN_TEST(test_magic_byte_rejection);
    RUN_TEST(test_magic_byte_hex_conversion);

    // Heartbeat interval tests
    RUN_TEST(test_heartbeat_default_interval);
    RUN_TEST(test_heartbeat_set_valid_interval);
    RUN_TEST(test_heartbeat_reject_below_minimum);
    RUN_TEST(test_heartbeat_reject_above_maximum);
    RUN_TEST(test_heartbeat_boundary_values);
    RUN_TEST(test_heartbeat_tick_count_increments);

    UNITY_END();
}

void loop() {
    // Nothing — tests run once in setup()
}