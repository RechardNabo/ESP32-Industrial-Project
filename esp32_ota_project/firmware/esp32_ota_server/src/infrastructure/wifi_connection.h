/**
 * @file wifi_connection.h
 * @brief Wi-Fi connection management (infrastructure layer).
 *
 * Provides blocking Wi-Fi connection with static IP configuration
 * and deep-sleep fallback on failure.
 */

#ifndef WIFI_CONNECTION_H
#define WIFI_CONNECTION_H

/**
 * Connect to Wi-Fi using the credentials from ota_config.h.
 *
 * Blocks for up to WIFI_CONNECT_TIMEOUT_S seconds. If connection fails,
 * enters deep sleep for WIFI_RETRY_SLEEP_S seconds, then reboots to retry.
 * This ensures the device eventually connects and does not hang indefinitely.
 */
void connectWifi();

#endif // WIFI_CONNECTION_H