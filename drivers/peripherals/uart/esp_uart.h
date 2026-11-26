/* esp_uart.h — UART driver for ESP32 classic (UART0-2).
 * Fractional baud divisor: CLKDIV = integer part in bits 19:0, fraction
 * in 1/16 steps bits 23:20 — baud = APB/(div + frag/16). The fraction
 * makes exact baud possible for any rate; init still validates error. */
#ifndef ESP_UART_H
#define ESP_UART_H

#include <stdint.h>
#include <stdbool.h>

typedef enum { ESP_UART0 = 0, ESP_UART1, ESP_UART2, ESP_UART_CHANNEL_COUNT } esp_uart_channel_t;

typedef enum {
    ESP_UART_STATUS_OK = 0,
    ESP_UART_STATUS_INVALID_CHANNEL,
    ESP_UART_STATUS_INVALID_PARAM,
    ESP_UART_STATUS_INVALID_BAUD
} esp_uart_status_t;

typedef enum { ESP_UART_PARITY_NONE = 0, ESP_UART_PARITY_EVEN, ESP_UART_PARITY_ODD } esp_uart_parity_t;

typedef struct {
    uint32_t apb_hz;
    uint32_t baud;
    esp_uart_parity_t parity;
    uint8_t stop_bits;   /* 1 or 2 */
} esp_uart_config_t;

#define ESP_UART_ERR_LIMIT_X1000  20   /* 2.0% in per-mille */

esp_uart_status_t esp_uart_init(esp_uart_channel_t ch, const esp_uart_config_t *config);
bool esp_uart_write_byte(esp_uart_channel_t ch, uint8_t byte);
bool esp_uart_read_byte(esp_uart_channel_t ch, uint8_t *byte_out);
/* divisor computation in fixed point — exposed for tests */
void esp_uart_divisor(uint32_t apb_hz, uint32_t baud, uint32_t *div, uint32_t *frag16);

#endif
