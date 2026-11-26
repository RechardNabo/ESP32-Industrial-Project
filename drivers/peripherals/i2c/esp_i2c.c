/* esp_i2c.c — see esp_i2c.h.
 * I2C_SCL_LOW_PERIOD/I2C_SCL_HIGH_PERIOD: value+1 APB clocks each.
 * I2C_CTR: MS_MODE bit4 master enable, bit0 trans start. */
#include <xc.h>

#include "esp_i2c.h"
#include "../../bsp/esp_board.h"

#define CTR_MS_MODE  (1UL << 4)

typedef struct {
    volatile uint32_t *ctr, *scl_low, *scl_high;
} esp_i2c_regs_t;

static const esp_i2c_regs_t tbl[ESP_I2C_CHANNEL_COUNT] = {
    { &I2C0CTR, &I2C0SCLLOW, &I2C0SCLHIGH },
    { &I2C1CTR, &I2C1SCLLOW, &I2C1SCLHIGH },
};

static const esp_i2c_regs_t *regmap(esp_i2c_channel_t ch)
{
    return ((unsigned int)ch >= (unsigned int)ESP_I2C_CHANNEL_COUNT) ? 0 : &tbl[ch];
}

void esp_i2c_periods(uint32_t apb_hz, uint32_t clock_hz, uint32_t *low, uint32_t *high)
{
    /* total APB clocks per bit, split evenly; both must meet silicon mins
     * (low ≥ 6+1, high ≥ 5+1 on ESP32 classic) */
    const uint32_t total = apb_hz / clock_hz;
    uint32_t l = total / 2U, h = total - l;
    if (l < 7U) { l = 7U; }
    if (h < 6U) { h = 6U; }
    *low = l; *high = h;
}

esp_i2c_status_t esp_i2c_init(esp_i2c_channel_t ch, const esp_i2c_config_t *config)
{
    const esp_i2c_regs_t *regs = regmap(ch);
    uint32_t low, high;
    if (regs == 0) return ESP_I2C_STATUS_INVALID_CHANNEL;
    if (config == 0 || config->clock_hz == 0U || config->apb_hz == 0U)
        return ESP_I2C_STATUS_INVALID_PARAM;
    esp_i2c_periods(config->apb_hz, config->clock_hz, &low, &high);
    if (low > 1024UL || high > 1024UL) return ESP_I2C_STATUS_INVALID_CLOCK;
    *regs->scl_low = low - 1U;
    *regs->scl_high = high - 1U;
    *regs->ctr |= CTR_MS_MODE;
    return ESP_I2C_STATUS_OK;
}
