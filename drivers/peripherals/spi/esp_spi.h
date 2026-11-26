/* esp_spi.h — SPI master driver for ESP32 classic (SPI2/HSPI, SPI3/VSPI).
 * Clock: CLKCNT_N/H/L in SPI_CLOCK — the divider is N+1 per half period;
 * CLK_EQU_SYSCLK bit31 bypasses for full-speed. cmd/addr/data phases are
 * device-driver policy; this layer owns clock + byte shifting. */
#ifndef ESP_SPI_H
#define ESP_SPI_H

#include <stdint.h>
#include <stdbool.h>

typedef enum { ESP_SPI2 = 0, ESP_SPI3, ESP_SPI_CHANNEL_COUNT } esp_spi_channel_t;
typedef enum {
    ESP_SPI_STATUS_OK = 0, ESP_SPI_STATUS_INVALID_CHANNEL,
    ESP_SPI_STATUS_INVALID_PARAM, ESP_SPI_STATUS_INVALID_CLOCK
} esp_spi_status_t;
typedef enum { ESP_SPI_MODE_0 = 0, ESP_SPI_MODE_1, ESP_SPI_MODE_2, ESP_SPI_MODE_3 } esp_spi_mode_t;

typedef struct { uint32_t apb_hz; uint32_t clock_hz; esp_spi_mode_t mode; } esp_spi_config_t;

esp_spi_status_t esp_spi_init(esp_spi_channel_t ch, const esp_spi_config_t *config);
esp_spi_status_t esp_spi_exchange_byte(esp_spi_channel_t ch, uint8_t tx, uint8_t *rx_out);
uint32_t esp_spi_divisor_n(uint32_t apb_hz, uint32_t clock_hz);

#endif
