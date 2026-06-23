/**
 * @file nvs_storage.cpp
 * @brief NVS storage wrappers implementation.
 *
 * Extracted from heartbeat.cpp's direct Preferences usage.
 */

#include "src/infrastructure/nvs_storage.h"
#include <Preferences.h>

uint32_t nvsReadUInt(const char* namespace_, const char* key, uint32_t defaultValue) {
    Preferences nvs;
    nvs.begin(namespace_, true);  // read-only
    uint32_t val = nvs.getUInt(key, defaultValue);
    nvs.end();
    return val;
}

bool nvsWriteUInt(const char* namespace_, const char* key, uint32_t value) {
    Preferences nvs;
    nvs.begin(namespace_, false);  // read-write
    size_t written = nvs.putUInt(key, value);
    nvs.end();
    return written > 0;
}