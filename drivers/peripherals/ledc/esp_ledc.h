/* esp_ledc.h — LEDC PWM driver for ESP32 classic — 16 channels.
 * The ESP32 signature PWM peripheral: independent of the CPU cores,
 * hardware fade support. Frequency×resolution interlock is THE trap:
 * bits × frequency ≤ clock — init validates instead of producing garbage. */
#ifndef ESP_LEDC_H
#define ESP_LEDC_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
    ESP_LEDC_STATUS_OK = 0, ESP_LEDC_STATUS_INVALID_CHANNEL,
    ESP_LEDC_STATUS_INVALID_PARAM, ESP_LEDC_STATUS_FREQ_RESOLUTION_IMPOSSIBLE
} esp_ledc_status_t;

#define ESP_LEDC_CHANNEL_COUNT  16U

typedef struct {
    uint32_t apb_hz;
    uint32_t frequency;
    uint8_t  resolution_bits;   /* 1-20 */
} esp_ledc_timer_config_t;

esp_ledc_status_t esp_ledc_timer_init(uint8_t timer, const esp_ledc_timer_config_t *config);
esp_ledc_status_t esp_ledc_channel_init(uint8_t channel, uint8_t timer);
esp_ledc_status_t esp_ledc_set_duty(uint8_t channel, uint32_t permille);
/* validation exposed for tests */
bool esp_ledc_freq_resolution_legal(uint32_t apb_hz, uint32_t frequency, uint8_t bits);

#endif
