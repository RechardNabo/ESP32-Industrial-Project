/**
 * @file ota_config.h
 * @brief Centralised configuration constants for the ESP32 OTA update system.
 *
 * All tuneable parameters are defined here. No magic strings or numbers
 * should appear anywhere else in the codebase.
 */

#ifndef OTA_CONFIG_H
#define OTA_CONFIG_H

// ============================================================================
// Network Identity
// ============================================================================

/** mDNS hostname advertised on the local network. Accessible as my-esp32.local */
#define MDNS_HOSTNAME        "my-esp32"

/** Wi-Fi SSID — must be updated for your deployment environment */
#define WIFI_SSID            "Server-Network"

/** Wi-Fi password — must be updated for your deployment environment */
#define WIFI_PASSWORD        "extremehacktivist"

// ============================================================================
// Static IP Configuration
// ============================================================================

/** Static IP address for the ESP32 on the local network */
#define DEVICE_IP_ADDR       IPAddress(192, 168, 0, 195)

/** Gateway IP address (typically the router) */
#define GATEWAY_IP_ADDR      IPAddress(192, 168, 0, 1)

/** Subnet mask */
#define SUBNET_MASK          IPAddress(255, 255, 255, 0)

/** Primary DNS server (use gateway as DNS for local resolution) */
#define PRIMARY_DNS_ADDR     IPAddress(192, 168, 0, 1)

// ============================================================================
// Wi-Fi Connection Parameters
// ============================================================================

/** Maximum seconds to attempt Wi-Fi connection before deep-sleep retry */
#define WIFI_CONNECT_TIMEOUT_S     30

/** Deep-sleep duration (seconds) after Wi-Fi connection failure before retry */
#define WIFI_RETRY_SLEEP_S         5

// ============================================================================
// Firmware Identity
// ============================================================================

/** Current firmware version string — increment before each build and OTA push */
#define FIRMWARE_VERSION     "1.0.0"

// ============================================================================
// HTTP Server
// ============================================================================

/** TCP port for the OTA web server */
#define HTTP_PORT             80

// ============================================================================
// Security
// ============================================================================

/** Pre-shared token required to unlock the OTA session */
#define OTA_SECRET_TOKEN      "SecretFlash2026"

/** HTTP endpoint to unlock OTA with token query parameter */
#define OTA_UNLOCK_PATH       "/unlock-ota"

/** HTTP endpoint to push firmware binary (POST, multipart/form-data) */
#define OTA_PUSH_PATH         "/push-firmware"

/** HTTP endpoint to read current firmware version (GET) */
#define OTA_VERSION_PATH      "/version"

/** HTTP endpoint to read device status (GET) */
#define OTA_STATUS_PATH       "/status"

// ============================================================================
// Watchdog Timer
// ============================================================================

/** Seconds before an unlocked OTA session expires and is locked again */
#define OTA_TIMEOUT_SECONDS   60

// ============================================================================
// Rate Limiting
// ============================================================================

/** Maximum failed unlock attempts from a single IP before lockout */
#define OTA_MAX_FAILED_ATTEMPTS      3

/** Lockout duration in seconds after exceeding max failed attempts */
#define OTA_LOCKOUT_DURATION_S       300

/** Window in seconds for counting consecutive failed attempts */
#define OTA_ATTEMPT_WINDOW_S         60

// ============================================================================
// Binary Validation
// ============================================================================

/** ESP32 binary images always start with this magic byte (0xE9) */
#define ESP_MAGIC_BYTE        0xE9

// ============================================================================
// Heartbeat Tick Configuration
// ============================================================================

/**
 * Heartbeat tick interval in milliseconds.
 * The hardware timer ISR fires at exactly this interval, toggling the onboard
 * LED and publishing a /heartbeat endpoint. This interval is also persisted
 * to NVS so it survives OTA updates — a new firmware reads the stored value
 * on boot and applies it, guaranteeing the tick period never changes across
 * upgrades unless explicitly overridden via the /heartbeat endpoint.
 */
#define HEARTBEAT_INTERVAL_MS          500

/** GPIO pin for the heartbeat LED. Onboard LED on most ESP32 devboards. */
#define HEARTBEAT_LED_PIN              2

/** NVS namespace for heartbeat configuration (survives OTA) */
#define HEARTBEAT_NVS_NAMESPACE        "hb_cfg"

/** NVS key for the heartbeat interval (milliseconds, uint32) */
#define HEARTBEAT_NVS_KEY_INTERVAL     "interval"

/** Hardware timer number used for the heartbeat ISR (0 or 1) */
#define HEARTBEAT_TIMER_NUM            0

/** Timer clock prescaler — 80 divides APB_CLK (80 MHz) to 1 MHz (1 µs tick) */
#define HEARTBEAT_TIMER_PRESCALER      80

// ============================================================================
// Logging
// ============================================================================

/**
 * If defined, LOG macros produce output on Serial.
 * Comment this out to disable all logging at compile time.
 */
// #define OTA_DISABLE_LOGS

/** Log levels */
#define LOG_LEVEL_INFO    0
#define LOG_LEVEL_WARN    1
#define LOG_LEVEL_ERROR   2

#ifdef OTA_DISABLE_LOGS
  #define LOG(level, msg)                  ((void)0)
  #define LOG_FMT(level, fmt, ...)         ((void)0)
#else
  #define _LOG_LEVEL_STR(lvl) \
    ((lvl) == LOG_LEVEL_INFO  ? "INFO" : \
     (lvl) == LOG_LEVEL_WARN  ? "WARN" : \
     (lvl) == LOG_LEVEL_ERROR ? "ERROR" : "UNKNOWN")

  #define LOG(level, msg) \
    Serial.printf("[%s][%lu] %s\n", _LOG_LEVEL_STR(level), millis(), msg)

  #define LOG_FMT(level, fmt, ...) \
    Serial.printf("[%s][%lu] " fmt "\n", _LOG_LEVEL_STR(level), millis(), ##__VA_ARGS__)
#endif

#endif // OTA_CONFIG_H