/* esp_adc.c — see esp_adc.h.
 * SENS_SAR1: MEAS_START bit, channel in SAR1 channel-select field.
 * On ESP32 classic the RTC-domain controller: SENS_SAR_MEAS1_CTRL carries
 * channel (bits 22:19) + start (bit 18), done status bit in MEAS1_CTRL2.
 * Layout per TRM v4.x — target verification owed, documented in README. */
#include <xc.h>

#include "esp_adc.h"
#include "../../bsp/esp_board.h"

#define MEAS1_START      ((1UL << 18) | (1UL << 17))   /* start_force + start_sar */
#define MEAS1_DONE       (1UL << 0)   /* in CTRL2 status */
#define WIDTH_12BIT      3UL          /* SAR1_BIT_WIDTH bits [1:0] = 12-bit */

static esp_adc_atten_t active_atten;

esp_adc_status_t esp_adc_init(esp_adc_atten_t atten)
{
    if (atten > ESP_ADC_ATTEN_11DB) return ESP_ADC_STATUS_INVALID_PARAM;
    active_atten = atten;
    /* attenuation applies per-channel in hardware — host model stores the
     * global selection; per-channel refinement is target-phase work */
    SENS_ATTEN1 = ((uint32_t)atten & 3UL) * 0x55555555UL;   /* 2 bits per channel, all 8 */
    SENS_START_FORCE = WIDTH_12BIT;
    return ESP_ADC_STATUS_OK;
}

esp_adc_status_t esp_adc_read(uint8_t channel, uint16_t *raw_out)
{
    uint32_t spin = 100000UL;
    if (channel > 7U || raw_out == 0) return ESP_ADC_STATUS_INVALID_CHANNEL;
    SENS_MEAS1_CTRL = ((uint32_t)channel << 19) | MEAS1_START;
    while ((SENS_MEAS1_CTRL2 & MEAS1_DONE) == 0U) {
        if (--spin == 0U) return ESP_ADC_STATUS_TIMEOUT;
    }
    *raw_out = (uint16_t)(SENS_MEAS1_DATA & 0xFFFU);
    return ESP_ADC_STATUS_OK;
}

uint16_t esp_adc_to_mv(uint16_t raw, esp_adc_atten_t atten)
{
    /* full-scale millivolts per attenuation (approximate, chip-variant —
     * real accuracy needs per-chip eFuse calibration, noted in README) */
    static const uint32_t fs_mv[4] = { 800UL, 1100UL, 1500UL, 3100UL };
    return (uint16_t)(((uint32_t)raw * fs_mv[atten & 3U]) / 4095UL);
}
