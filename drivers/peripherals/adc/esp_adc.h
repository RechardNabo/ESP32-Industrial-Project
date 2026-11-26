/* esp_adc.h — ADC1 driver for ESP32 classic (legacy RTC controller).
 * ADC1 channels 0-7 on GPIO32-39. 12-bit width, attenuation selects the
 * input range — the trap: 0dB attenuation only reads to ~800mV; the full
 * 3.3V range needs 11dB (12dB in later docs). Driver makes attenuation
 * explicit instead of defaulting to a clipped range. */
#ifndef ESP_ADC_H
#define ESP_ADC_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
    ESP_ADC_STATUS_OK = 0,
    ESP_ADC_STATUS_INVALID_CHANNEL,
    ESP_ADC_STATUS_INVALID_PARAM,
    ESP_ADC_STATUS_TIMEOUT
} esp_adc_status_t;

typedef enum {
    ESP_ADC_ATTEN_0DB = 0,    /* ~0-800mV */
    ESP_ADC_ATTEN_2_5DB,      /* ~0-1.1V */
    ESP_ADC_ATTEN_6DB,        /* ~0-1.5V */
    ESP_ADC_ATTEN_11DB        /* ~0-3.1V — full range */
} esp_adc_atten_t;

esp_adc_status_t esp_adc_init(esp_adc_atten_t atten);
esp_adc_status_t esp_adc_read(uint8_t channel, uint16_t *raw_out);
/* millivolts — atten-dependent scale, integer math */
uint16_t esp_adc_to_mv(uint16_t raw, esp_adc_atten_t atten);

#endif
