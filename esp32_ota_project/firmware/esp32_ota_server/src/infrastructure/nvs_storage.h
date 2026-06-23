/**
 * @file nvs_storage.h
 * @brief NVS (Non-Volatile Storage) wrappers (infrastructure layer).
 *
 * Provides typed read/write for heartbeat configuration persistence.
 */

#ifndef NVS_STORAGE_H
#define NVS_STORAGE_H

#include <stdint.h>

/**
 * Read a uint32 value from NVS.
 *
 * @param namespace_  NVS namespace (e.g., HEARTBEAT_NVS_NAMESPACE)
 * @param key         NVS key (e.g., HEARTBEAT_NVS_KEY_INTERVAL)
 * @param defaultValue Default value if the key does not exist
 * @return            The stored value, or defaultValue if absent
 */
uint32_t nvsReadUInt(const char* namespace_, const char* key, uint32_t defaultValue);

/**
 * Write a uint32 value to NVS.
 *
 * @param namespace_  NVS namespace
 * @param key         NVS key
 * @param value       Value to store
 * @return            true on success
 */
bool nvsWriteUInt(const char* namespace_, const char* key, uint32_t value);

#endif // NVS_STORAGE_H