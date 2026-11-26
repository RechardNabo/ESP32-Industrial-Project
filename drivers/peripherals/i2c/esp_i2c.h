/* esp_i2c.h — I2C master for ESP32 classic. This peripheral is command-
 * sequence driven (the silicon executes a command list), unlike anything
 * in the PIC/dsPIC world. This layer owns clock config + command FIFO
 * primitives; full transaction composition is the device driver's job.
 * SCL: period = (I2C_SCL_LOW+1) + (I2C_SCL_HIGH+1) APB clocks. */
#ifndef ESP_I2C_H
#define ESP_I2C_H

#include <stdint.h>
#include <stdbool.h>

typedef enum { ESP_I2C0 = 0, ESP_I2C1, ESP_I2C_CHANNEL_COUNT } esp_i2c_channel_t;
typedef enum {
    ESP_I2C_STATUS_OK = 0, ESP_I2C_STATUS_INVALID_CHANNEL,
    ESP_I2C_STATUS_INVALID_PARAM, ESP_I2C_STATUS_INVALID_CLOCK
} esp_i2c_status_t;

typedef struct { uint32_t apb_hz; uint32_t clock_hz; } esp_i2c_config_t;

esp_i2c_status_t esp_i2c_init(esp_i2c_channel_t ch, const esp_i2c_config_t *config);
/* period decomposition: total APB clocks split into low/high phases,
 * meeting the minimums the silicon requires — exposed for tests */
void esp_i2c_periods(uint32_t apb_hz, uint32_t clock_hz, uint32_t *low, uint32_t *high);

#endif
