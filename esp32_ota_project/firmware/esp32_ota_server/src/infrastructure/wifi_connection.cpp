/**
 * @file wifi_connection.cpp
 * @brief Wi-Fi connection management implementation.
 *
 * Migrated from esp32_ota_server.ino — identical logic, now in infrastructure layer.
 */

#include "src/infrastructure/wifi_connection.h"
#include <WiFi.h>
#include <ESPmDNS.h>
#include "ota_config.h"

void connectWifi() {
    LOG_FMT(LOG_LEVEL_INFO, "Connecting to Wi-Fi SSID: %s", WIFI_SSID);

    WiFi.mode(WIFI_STA);

    // Configure static IP before connecting
    if (!WiFi.config(DEVICE_IP_ADDR, GATEWAY_IP_ADDR, SUBNET_MASK, PRIMARY_DNS_ADDR)) {
        LOG(LOG_LEVEL_ERROR, "Static IP configuration failed — falling back to DHCP");
        // Continue anyway — WiFi.begin will use DHCP
    }
    LOG_FMT(LOG_LEVEL_INFO, "Static IP configured: 192.168.0.195");

    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    unsigned long startAttempt = millis();
    unsigned long timeoutMs = WIFI_CONNECT_TIMEOUT_S * 1000UL;

    while (WiFi.status() != WL_CONNECTED) {
        if (millis() - startAttempt > timeoutMs) {
            LOG(LOG_LEVEL_ERROR, "Wi-Fi connection timeout — entering deep sleep");
            delay(100);
            // ESP32 Arduino core v3: esp_deep_sleep_start() takes no arguments.
            // Configure the wake-up timer BEFORE entering deep sleep.
            esp_sleep_enable_timer_wakeup(WIFI_RETRY_SLEEP_S * 1000000ULL);
            esp_deep_sleep_start();
            // After deep sleep, device reboots and this function runs again
        }
        delay(500);
        Serial.print(".");
    }

    Serial.println();
    LOG_FMT(LOG_LEVEL_INFO, "Wi-Fi connected — IP: %s", WiFi.localIP().toString().c_str());
    Serial.print("  MAC Address: ");
    Serial.println(WiFi.macAddress());
    Serial.print("  IP Address:   ");
    Serial.println(WiFi.localIP());
}