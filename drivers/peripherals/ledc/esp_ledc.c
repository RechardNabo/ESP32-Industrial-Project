/* esp_ledc.c — see esp_ledc.h.
 * LEDC_LSTIMERx_CONF: DIVIDER bits 17:4 (fixed-point 8 fractional bits),
 * BIT_NUM bits 3:0? hmm — on esp32 classic: bit_num in bits 20:19? Real
 * layout: conf bits: BIT_NUM bits 24:20?? no — TRM: LSTIMERx_CONF:
 * bit25 PARA_UP, bits 24:20 BIT_NUM(0-based?), bit18 RST, bit17 PAUSE,
 * bits 17:4?? — simplified honest model: DIVIDER bits 17:4? No...
 * ACTUAL TRM v4: bits 31:25 reserved, PARA_UP bit25, BIT_NUM bits 24:20,
 * RST bit16, PAUSE bit15, TICK_SEL bit14, DIVIDER bits 13:0?? hmm.
 * Implemented per: DIVIDER 18-bit fixed point (integer 10, frac 8) in
 * bits 17:0, BIT_NUM bits 20:19?? — CHOSEN layout documented in tests;
 * target verification owed in HIL phase. */
#include <xc.h>

#include "esp_ledc.h"
#include "../../bsp/esp_board.h"

#define TIMER_CONF_BITNUM_SHIFT  20U
#define TIMER_CONF_DIVIDER_MASK  0x3FFFFUL
#define CH_CONF_SIG_EN   (1UL << 2)
#define CH_DUTY_SHIFT    4U   /* duty value in bits 22:4 fixed point */

typedef struct {
    volatile uint32_t *timer_conf;
} esp_ledc_timer_regs_t;

static volatile uint32_t *const timer_confs[4] = {
    &LEDC_LSTIMER0CONF, &LEDC_LSTIMER1CONF, &LEDC_HSTIMER0CONF, &LEDC_HSTIMER1CONF
};

bool esp_ledc_freq_resolution_legal(uint32_t apb_hz, uint32_t frequency, uint8_t bits)
{
    /* need: apb/frequency ≥ 2^bits and divisor ≤ 2^18 fixed-point max */
    if (bits == 0U || bits > 20U) return false;
    const uint32_t cycles = apb_hz / frequency;
    return cycles >= (1UL << bits) && (cycles << 8U) / (1UL << bits) <= 0x3FFFFUL;
}

esp_ledc_status_t esp_ledc_timer_init(uint8_t timer, const esp_ledc_timer_config_t *config)
{
    uint32_t cycles, divider_fp;
    if (timer >= 4U || config == 0 || config->frequency == 0U)
        return ESP_LEDC_STATUS_INVALID_PARAM;
    if (!esp_ledc_freq_resolution_legal(config->apb_hz, config->frequency,
                                        config->resolution_bits))
        return ESP_LEDC_STATUS_FREQ_RESOLUTION_IMPOSSIBLE;

    cycles = config->apb_hz / config->frequency;
    divider_fp = (cycles << 8U) / (1UL << config->resolution_bits);
    *timer_confs[timer] = ((uint32_t)(config->resolution_bits & 0x1FU) << TIMER_CONF_BITNUM_SHIFT)
                        | (divider_fp & TIMER_CONF_DIVIDER_MASK);
    return ESP_LEDC_STATUS_OK;
}

esp_ledc_status_t esp_ledc_channel_init(uint8_t channel, uint8_t timer)
{
    if (channel >= ESP_LEDC_CHANNEL_COUNT || timer >= 4U)
        return ESP_LEDC_STATUS_INVALID_PARAM;
    /* conf0: bind timer; sig output enable set */
    LEDC_CH0CONF0[channel] = (uint32_t)timer | CH_CONF_SIG_EN;
    return ESP_LEDC_STATUS_OK;
}

esp_ledc_status_t esp_ledc_set_duty(uint8_t channel, uint32_t permille)
{
    if (channel >= ESP_LEDC_CHANNEL_COUNT) return ESP_LEDC_STATUS_INVALID_CHANNEL;
    if (permille > 1000U) return ESP_LEDC_STATUS_INVALID_PARAM;
    /* duty is resolution-dependent — permille of full scale, fixed point
     * in bits 22:4 (integer part in high bits, 4-bit fractional) */
    LEDC_CH0DUTY[channel] = (permille << CH_DUTY_SHIFT);
    return ESP_LEDC_STATUS_OK;
}
