/* esp_uart.c — see esp_uart.h.
 * Registers per port: FIFO(0x0) CLKDIV(0x14) STATUS(0x1C) CONF0(0x20).
 * STATUS: RXFIFO_CNT bits 7:0, TXFIFO_CNT bits 15:8 (128-deep FIFOs).
 * CONF0: bit0 PARITY(0 even 1 odd), bit1 PARITY_EN, bits 3:2 BIT_NUM
 * (3=8bit), bits 5:4 STOP_BIT_NUM (1=1bit, 3=2bit). */
#include <xc.h>

#include "esp_uart.h"
#include "../../bsp/esp_board.h"

#define CONF0_PARITY      (1UL << 0)
#define CONF0_PARITY_EN   (1UL << 1)
#define CONF0_BITNUM_8    (3UL << 2)
#define CONF0_STOP1       (1UL << 4)
#define CONF0_STOP2       (3UL << 4)
#define STATUS_RXCNT_MASK  0xFFUL
#define STATUS_TXCNT_SHIFT 8UL
#define TXFIFO_CAPACITY    128UL

typedef struct {
    volatile uint32_t *fifo;
    volatile uint32_t *clkdiv;
    volatile uint32_t *status;
    volatile uint32_t *conf0;
} esp_uart_regs_t;

static const esp_uart_regs_t tbl[ESP_UART_CHANNEL_COUNT] = {
    { &U0FIFO, &U0CLKDIV, &U0STATUS, &U0CONF0 },
    { &U1FIFO, &U1CLKDIV, &U1STATUS, &U1CONF0 },
    { &U2FIFO, &U2CLKDIV, &U2STATUS, &U2CONF0 },
};

static const esp_uart_regs_t *regmap(esp_uart_channel_t ch)
{
    return ((unsigned int)ch >= (unsigned int)ESP_UART_CHANNEL_COUNT) ? 0 : &tbl[ch];
}

void esp_uart_divisor(uint32_t apb_hz, uint32_t baud, uint32_t *div, uint32_t *frag16)
{
    /* fixed point: total divisor in sixteenths = apb×16/baud, rounded */
    const uint64_t sixteenths = ((uint64_t)apb_hz * 16UL + baud / 2U) / baud;
    *div = (uint32_t)(sixteenths / 16U);
    *frag16 = (uint32_t)(sixteenths % 16U);
}

esp_uart_status_t esp_uart_init(esp_uart_channel_t ch, const esp_uart_config_t *config)
{
    const esp_uart_regs_t *regs = regmap(ch);
    uint32_t div, frag, conf;
    uint64_t actual_x1000, err_x1000;

    if (regs == 0) return ESP_UART_STATUS_INVALID_CHANNEL;
    if (config == 0 || config->baud == 0U || config->apb_hz == 0U)
        return ESP_UART_STATUS_INVALID_PARAM;

    esp_uart_divisor(config->apb_hz, config->baud, &div, &frag);
    if (div == 0U || div > 0xFFFFFUL) return ESP_UART_STATUS_INVALID_BAUD;

    /* verify: actual×1000/baud within 2.0% */
    actual_x1000 = ((uint64_t)config->apb_hz * 1000UL * 16UL)
                 / ((uint64_t)div * 16UL + frag);
    err_x1000 = (actual_x1000 > config->baud * 1000UL)
        ? actual_x1000 - config->baud * 1000UL : config->baud * 1000UL - actual_x1000;
    if ((err_x1000 / config->baud) > ESP_UART_ERR_LIMIT_X1000)
        return ESP_UART_STATUS_INVALID_BAUD;

    conf = CONF0_BITNUM_8;
    if (config->parity != ESP_UART_PARITY_NONE) {
        conf |= CONF0_PARITY_EN;
        if (config->parity == ESP_UART_PARITY_ODD) conf |= CONF0_PARITY;
    }
    conf |= (config->stop_bits == 2U) ? CONF0_STOP2 : CONF0_STOP1;

    *regs->clkdiv = (div & 0xFFFFFUL) | ((frag & 0xFUL) << 20U);
    *regs->conf0 = conf;
    return ESP_UART_STATUS_OK;
}

bool esp_uart_write_byte(esp_uart_channel_t ch, uint8_t byte)
{
    const esp_uart_regs_t *regs = regmap(ch);
    uint32_t txcnt;
    if (regs == 0) return false;
    txcnt = (*regs->status >> STATUS_TXCNT_SHIFT) & 0xFFUL;
    if (txcnt >= TXFIFO_CAPACITY - 1UL) return false;
    *regs->fifo = byte;
    return true;
}

bool esp_uart_read_byte(esp_uart_channel_t ch, uint8_t *byte_out)
{
    const esp_uart_regs_t *regs = regmap(ch);
    if (regs == 0 || byte_out == 0) return false;
    if ((*regs->status & STATUS_RXCNT_MASK) == 0U) return false;
    *byte_out = (uint8_t)(*regs->fifo & 0xFFU);
    return true;
}
