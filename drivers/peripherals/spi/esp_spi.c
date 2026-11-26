/* esp_spi.c — see esp_spi.h.
 * SPI_CLOCK: CLKCNT_N bits 5:0, CLKCNT_H bits 11:6, CLKCNT_L bits 17:12,
 * CLK_EQU_SYSCLK bit 31. SPI_USER: USR_MOSI bit27, USR_MISO bit28,
 * CK_OUT_EDGE bit 7 (edge select), CK_I_EDGE bit 6? — mode via edge bits.
 * SPI_CMD: USR bit18 starts transfer. Data buffer W0 at offset 0x80. */
#include <xc.h>

#include "esp_spi.h"
#include "../../bsp/esp_board.h"

#define CLOCK_EQU_SYS   (1UL << 31)
#define CLOCK_N_SHIFT   0U
#define CLOCK_H_SHIFT   6U
#define CLOCK_L_SHIFT   12U
#define USER_USR_MOSI   (1UL << 27)
#define USER_USR_MISO   (1UL << 28)
#define USER_DOUTDIN    (1UL << 0)
#define USER_CK_OUT_EDGE (1UL << 7)
#define USER_CK_I_EDGE  (1UL << 6)
#define CMD_USR         (1UL << 18)
#define MISO_DLEN_SHIFT  8U   /* SPI_MISO_DLEN bits — byte len in bits-1 */
#define MOSI_DLEN_SHIFT  0U   /* hmm: both use their own regs on esp32 */

typedef struct {
    volatile uint32_t *cmd, *user, *clock, *w0, *mosi_dlen, *miso_dlen;
} esp_spi_regs_t;

static esp_spi_regs_t tbl[ESP_SPI_CHANNEL_COUNT];
static int tbl_ready = 0;

static const esp_spi_regs_t *regmap(esp_spi_channel_t ch)
{
    if ((unsigned int)ch >= (unsigned int)ESP_SPI_CHANNEL_COUNT) return 0;
    if (!tbl_ready) {
        tbl[ESP_SPI2].cmd = &SPI2CMD;
        tbl[ESP_SPI2].user = &SPI2USER;
        tbl[ESP_SPI2].clock = &SPI2CLOCK;
        tbl[ESP_SPI2].w0 = &SPI2W0;
        tbl[ESP_SPI2].mosi_dlen = &SPI2MOSIDLEN;
        tbl[ESP_SPI2].miso_dlen = &SPI2MISODLEN;
        tbl[ESP_SPI3].cmd = &SPI3CMD;
        tbl[ESP_SPI3].user = &SPI3USER;
        tbl[ESP_SPI3].clock = &SPI3CLOCK;
        tbl[ESP_SPI3].w0 = &SPI3W0;
        tbl[ESP_SPI3].mosi_dlen = &SPI3MOSIDLEN;
        tbl[ESP_SPI3].miso_dlen = &SPI3MISODLEN;
        tbl_ready = 1;
    }
    return &tbl[ch];
}

uint32_t esp_spi_divisor_n(uint32_t apb_hz, uint32_t clock_hz)
{
    /* N+1 divider: smallest N meeting ≤ target — never overclock */
    uint32_t n = (apb_hz + clock_hz - 1UL) / clock_hz;
    return (n == 0U) ? 0U : n - 1U;
}

esp_spi_status_t esp_spi_init(esp_spi_channel_t ch, const esp_spi_config_t *config)
{
    const esp_spi_regs_t *regs = regmap(ch);
    uint32_t n, user;
    if (regs == 0) return ESP_SPI_STATUS_INVALID_CHANNEL;
    if (config == 0 || config->clock_hz == 0U || config->apb_hz == 0U)
        return ESP_SPI_STATUS_INVALID_PARAM;
    n = esp_spi_divisor_n(config->apb_hz, config->clock_hz);
    if (n > 63UL) return ESP_SPI_STATUS_INVALID_CLOCK;

    *regs->clock = (n << CLOCK_N_SHIFT) | (n << CLOCK_H_SHIFT) | ((n + 1UL) << CLOCK_L_SHIFT);
    user = USER_USR_MOSI | USER_USR_MISO;
    /* mode mapping: modes 0/3 use inverse edge relationship — encoded via
     * CK_OUT_EDGE/CK_I_EDGE per TRM */
    if (config->mode == ESP_SPI_MODE_0) user |= USER_CK_OUT_EDGE;
    else if (config->mode == ESP_SPI_MODE_3) user |= USER_CK_OUT_EDGE | USER_CK_I_EDGE;
    else if (config->mode == ESP_SPI_MODE_1) user |= USER_CK_I_EDGE;
    *regs->user = user;
    return ESP_SPI_STATUS_OK;
}

esp_spi_status_t esp_spi_exchange_byte(esp_spi_channel_t ch, uint8_t tx, uint8_t *rx_out)
{
    const esp_spi_regs_t *regs = regmap(ch);
    uint32_t spin = 100000UL;
    if (regs == 0) return ESP_SPI_STATUS_INVALID_CHANNEL;
    *regs->mosi_dlen = 7UL;   /* bits-1: 8-bit frame */
    *regs->miso_dlen = 7UL;
    *regs->w0 = tx;
    /* the command register is resolved per access, not latched: on target
     * this is the same memory-mapped address; in the host model the
     * resolution itself is what advances the transfer-completion model */
    *(ch == ESP_SPI2 ? &SPI2CMD : &SPI3CMD) = CMD_USR;
    while ((*(ch == ESP_SPI2 ? &SPI2CMD : &SPI3CMD) & CMD_USR) != 0U) {
        if (--spin == 0U) return ESP_SPI_STATUS_INVALID_CLOCK;
    }
    if (rx_out != 0) *rx_out = (uint8_t)(*regs->w0 & 0xFFU);
    return ESP_SPI_STATUS_OK;
}
