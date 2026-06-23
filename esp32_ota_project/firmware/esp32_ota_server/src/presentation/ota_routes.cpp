/**
 * @file ota_routes.cpp
 * @brief OTA HTTP route handler implementations (presentation layer).
 *
 * Migrated from ota_handlers.cpp — identical HTTP handler logic, but state
 * management delegated to domain layer (ota_state). All HTTP I/O stays here.
 *
 * Endpoints:
 *   GET /version         — firmware version, hostname, uptime
 *   GET /status          — OTA state, heap, flash, chip info
 *   GET /unlock-ota      — token validation, starts OTA session window
 *   POST /push-firmware  — receives and flashes binary image
 */

#include "src/presentation/ota_routes.h"
#include "src/domain/ota_state.h"
#include "ota_config.h"

#include <WiFi.h>
#include <WebServer.h>
#include <Update.h>
#include <ESPmDNS.h>

// ============================================================================
// Module-level Upload State (needed for multipart callback)
// ============================================================================

/** Pointer to the global server, needed by the upload callback */
static WebServer* gServer = nullptr;

/** Total bytes written during OTA upload (accumulated across chunks) */
static size_t totalWritten = 0;

/** True if the first byte has been validated (magic byte check) */
static bool firstByteValidated = false;

/** True if the update has been aborted due to an error */
static bool updateErrored = false;

// ============================================================================
// JSON Response Helper
// ============================================================================

/**
 * Send a JSON response with the given status code.
 */
static void sendJson(WebServer* server, int code, const String& json) {
    server->sendHeader("Access-Control-Allow-Origin", "*");
    server->send(code, "application/json", json);
}

// ============================================================================
// HTTP Route Handlers
// ============================================================================

/**
 * GET /version
 * Returns JSON with firmware version, hostname, and uptime in seconds.
 */
static void handleVersion(WebServer* server) {
    String json = "{";
    json += "\"version\":\"" + String(FIRMWARE_VERSION) + "\",";
    json += "\"hostname\":\"" + String(MDNS_HOSTNAME) + "\",";
    json += "\"uptime_s\":" + String(millis() / 1000UL);
    json += "}";
    sendJson(server, 200, json);
}

/**
 * GET /status
 * Returns JSON with OTA state, free heap, flash size, chip model, and MAC.
 */
static void handleStatus(WebServer* server) {
    String json = "{";
    json += "\"ota_unlocked\":" + String(otaStateIsActive() ? "true" : "false") + ",";
    json += "\"ota_remaining_s\":" + String(otaStateRemainingSeconds()) + ",";
    json += "\"free_heap\":" + String(ESP.getFreeHeap()) + ",";
    json += "\"flash_size\":" + String(ESP.getFlashChipSize()) + ",";
    json += "\"chip_model\":\"" + String(ESP.getChipModel()) + "\",";
    json += "\"mac\":\"" + WiFi.macAddress() + "\"";
    json += "}";
    sendJson(server, 200, json);
}

/**
 * GET /unlock-ota?token=<TOKEN>
 *
 * Validates the token using constant-time comparison. On success, starts
 * the OTA session window (watchdog countdown of OTA_TIMEOUT_SECONDS).
 *
 * Rate-limited: after OTA_MAX_FAILED_ATTEMPTS from the same IP, the IP is
 * locked out for OTA_LOCKOUT_DURATION_S seconds (429 Too Many Requests).
 */
static void handleUnlock(WebServer* server) {
    IPAddress clientIp = server->client().remoteIP();

    // Rate-limit check before processing
    if (otaIsRateLimited(clientIp)) {
        LOG_FMT(LOG_LEVEL_WARN, "_UNLOCK_RATE_LIMITED %s", clientIp.toString().c_str());
        sendJson(server, 429, "{\"error\":\"Too many failed attempts. Try again later.\"}");
        return;
    }

    // Already unlocked — return remaining time
    if (otaStateIsActive()) {
        String json = "{\"unlocked\":true,\"expires_in_s\":" + String(otaStateRemainingSeconds()) + "}";
        sendJson(server, 200, json);
        return;
    }

    // Extract token from query parameter
    if (!server->hasArg("token")) {
        otaRecordFailedAttempt(clientIp);
        sendJson(server, 401, "{\"unlocked\":false,\"error\":\"Missing token parameter\"}");
        return;
    }

    String token = server->arg("token");

    // Constant-time comparison to prevent timing attacks
    if (constantTimeCompare(token.c_str(), OTA_SECRET_TOKEN)) {
        otaStateUnlock();
        LOG_FMT(LOG_LEVEL_INFO, "OTA session unlocked by %s — expires in %ds",
                clientIp.toString().c_str(), OTA_TIMEOUT_SECONDS);
        String json = "{\"unlocked\":true,\"expires_in_s\":" + String(OTA_TIMEOUT_SECONDS) + "}";
        sendJson(server, 200, json);
    } else {
        otaRecordFailedAttempt(clientIp);
        sendJson(server, 401, "{\"unlocked\":false,\"error\":\"Invalid token\"}");
    }
}

/**
 * POST /push-firmware guard — pre-upload check.
 * Actual upload processing is handled by otaUploadHandler callback
 * and handlePushFirmwarePost() after upload completes.
 */
static void handlePushFirmware(WebServer* server) {
    if (!otaStateIsActive()) {
        sendJson(server, 403, "{\"error\":\"OTA session not unlocked\"}");
        return;
    }
    // Actual upload processing is handled by otaUploadHandler callback
    // and handlePushFirmwarePost() after upload completes
}

// ============================================================================
// Upload Callback — processes each chunk as it arrives
// ============================================================================

/**
 * Multipart upload callback invoked by WebServer for each chunk.
 * Handles chunk-by-chunk processing in three phases:
 *   1. UPLOAD_FILE_START — initialise Update, check magic byte
 *   2. UPLOAD_FILE_WRITE — stream each chunk to flash
 *   3. UPLOAD_FILE_END   — finalise Update, reboot on success
 */
static void otaUploadHandler() {
    HTTPUpload& upload = gServer->upload();

    if (upload.status == UPLOAD_FILE_START) {
        LOG_FMT(LOG_LEVEL_INFO, "OTA upload start: filename=%s size=%d",
                upload.filename.c_str(), upload.totalSize);
        firstByteValidated = false;
        updateErrored = false;
        totalWritten = 0;
        // Begin OTA update with unknown size (streaming mode)
        if (!Update.begin(UPDATE_SIZE_UNKNOWN)) {
            LOG_FMT(LOG_LEVEL_ERROR, "Update.begin() failed: %s", Update.errorString());
            updateErrored = true;
        }
        return;
    }

    if (upload.status == UPLOAD_FILE_WRITE) {
        if (updateErrored) {
            return;
        }

        const uint8_t* data = upload.buf;
        size_t len = upload.currentSize;

        // First chunk: validate magic byte
        if (!firstByteValidated) {
            if (len == 0) {
                LOG(LOG_LEVEL_ERROR, "First chunk is empty — aborting");
                Update.abort();
                updateErrored = true;
                return;
            }

            if (data[0] != ESP_MAGIC_BYTE) {
                String expected = "0xE9";
                String received = "0x" + byteToHex(data[0]);
                LOG_FMT(LOG_LEVEL_ERROR, "Magic byte mismatch: expected=%s received=%s",
                        expected.c_str(), received.c_str());
                Update.abort();
                updateErrored = true;

                // We'll send the error response in the POST handler
                return;
            }

            firstByteValidated = true;
            LOG(LOG_LEVEL_INFO, "Magic byte 0xE9 validated — writing firmware");

            // Write the first chunk (including the validated magic byte)
            // ESP32 Arduino core v3: Update.write() takes uint8_t* (non-const), cast required
            size_t written = Update.write(const_cast<uint8_t*>(data), len);
            if (written != len) {
                LOG_FMT(LOG_LEVEL_ERROR, "Write error: wrote %d of %d bytes",
                        written, len);
                Update.abort();
                updateErrored = true;
                return;
            }
            totalWritten = written;
            return;
        }

        // Subsequent chunks: stream to flash
        size_t written = Update.write(const_cast<uint8_t*>(data), len);
        if (written != len) {
            LOG_FMT(LOG_LEVEL_ERROR, "Write error: wrote %d of %d bytes (total so far: %d)",
                    written, len, totalWritten);
            Update.abort();
            updateErrored = true;
            return;
        }
        totalWritten += written;
        return;
    }

    if (upload.status == UPLOAD_FILE_END) {
        if (updateErrored) {
            return;
        }
        LOG_FMT(LOG_LEVEL_INFO, "OTA upload complete: total bytes=%d", totalWritten);
        return;
    }

    // UPLOAD_FILE_ABORTED
    if (upload.status == UPLOAD_FILE_ABORTED) {
        LOG(LOG_LEVEL_ERROR, "OTA upload aborted by client");
        Update.abort();
        updateErrored = true;
    }
}

// ============================================================================
// POST handler for /push-firmware — called after upload completes
// ============================================================================

/**
 * Post-upload handler for /push-firmware.
 * After the multipart upload callback finishes, this handler checks the
 * result and either finalises the update or returns an error.
 */
static void handlePushFirmwarePost(WebServer* server) {
    // Check if upload was aborted or had errors
    if (updateErrored) {
        otaStateReset();

        // Determine the specific error
        if (!firstByteValidated) {
            // Magic byte check failed
            HTTPUpload& upload = server->upload();
            uint8_t receivedByte = (upload.currentSize > 0) ? upload.buf[0] : 0x00;
            String json = "{\"error\":\"Invalid binary: magic byte mismatch\",";
            json += "\"expected\":\"0xE9\",";
            json += "\"received\":\"0x" + byteToHex(receivedByte) + "\"}";
            sendJson(server, 400, json);
        } else {
            // Write error or other failure
            String err = Update.errorString();
            String json = "{\"error\":\"" + err + "\"}";
            sendJson(server, 500, json);
        }
        return;
    }

    // Finalise the update
    if (!Update.end(true)) {
        String err = Update.errorString();
        LOG_FMT(LOG_LEVEL_ERROR, "Update.end() failed: %s", err.c_str());
        otaStateReset();
        sendJson(server, 500, "{\"error\":\"" + err + "\"}");
        return;
    }

    // Success — reset state and reboot
    LOG_FMT(LOG_LEVEL_INFO, "OTA success: %d bytes written — rebooting", totalWritten);
    otaStateReset();

    String json = "{\"success\":true,\"bytes_written\":" + String(totalWritten) + ",";
    json += "\"message\":\"Rebooting...\"}";
    sendJson(server, 200, json);

    delay(500);
    ESP.restart();
}

// ============================================================================
// Route Registration
// ============================================================================

void registerOtaRoutes(WebServer* server) {
    gServer = server;

    server->on(OTA_VERSION_PATH, HTTP_GET, [server]() {
        handleVersion(server);
    });

    server->on(OTA_STATUS_PATH, HTTP_GET, [server]() {
        handleStatus(server);
    });

    server->on(OTA_UNLOCK_PATH, HTTP_GET, [server]() {
        handleUnlock(server);
    });

    // POST /push-firmware uses the upload callback for multipart handling,
    // then the POST handler for result processing
    server->on(OTA_PUSH_PATH, HTTP_POST,
        [server]() {
            handlePushFirmwarePost(server);
        },
        otaUploadHandler
    );

    LOG(LOG_LEVEL_INFO, "OTA routes registered");
}