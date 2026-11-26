/* mock_sfr.c — backing memory + behavioral models, see xc.h. */
#include <string.h>

#include "xc.h"

static volatile uint32_t gpio_out_store, gpio_out1_store;
static volatile uint32_t gpio_enable_store, gpio_enable1_store;
volatile uint32_t GPIO_OUT_W1TS, GPIO_OUT_W1TC, GPIO_OUT1_W1TS, GPIO_OUT1_W1TC;
volatile uint32_t GPIO_ENABLE_W1TS, GPIO_ENABLE_W1TC, GPIO_ENABLE1_W1TS, GPIO_ENABLE1_W1TC;
volatile uint32_t GPIO_IN, GPIO_IN1;

volatile uint32_t U0FIFO, U0CLKDIV, U0STATUS, U0CONF0;
volatile uint32_t U1FIFO, U1CLKDIV, U1STATUS, U1CONF0;
volatile uint32_t U2FIFO, U2CLKDIV, U2STATUS, U2CONF0;

volatile uint32_t SPI2USER, SPI2CLOCK, SPI2W0, SPI2MOSIDLEN, SPI2MISODLEN;
volatile uint32_t SPI3USER, SPI3CLOCK, SPI3W0, SPI3MOSIDLEN, SPI3MISODLEN;

volatile uint32_t I2C0CTR, I2C0SCLLOW, I2C0SCLHIGH;
volatile uint32_t I2C1CTR, I2C1SCLLOW, I2C1SCLHIGH;

volatile uint32_t LEDC_LSTIMER0CONF, LEDC_LSTIMER1CONF;
volatile uint32_t LEDC_HSTIMER0CONF, LEDC_HSTIMER1CONF;
volatile uint32_t LEDC_CH0CONF0[16];
volatile uint32_t LEDC_CH0DUTY[16];

static volatile uint32_t spi2cmd_store, spi3cmd_store;

static volatile uint32_t *w1x_model(volatile uint32_t *parent,
                                    volatile uint32_t *w1ts, volatile uint32_t *w1tc)
{
    *parent |= *w1ts;
    *parent &= ~*w1tc;
    *w1ts = 0U;
    *w1tc = 0U;
    return parent;
}

volatile uint32_t *mock_gpio_out_model(void)
{
    return w1x_model(&gpio_out_store, &GPIO_OUT_W1TS, &GPIO_OUT_W1TC);
}
volatile uint32_t *mock_gpio_out1_model(void)
{
    return w1x_model(&gpio_out1_store, &GPIO_OUT1_W1TS, &GPIO_OUT1_W1TC);
}
volatile uint32_t *mock_gpio_enable_model(void)
{
    return w1x_model(&gpio_enable_store, &GPIO_ENABLE_W1TS, &GPIO_ENABLE_W1TC);
}
volatile uint32_t *mock_gpio_enable1_model(void)
{
    return w1x_model(&gpio_enable1_store, &GPIO_ENABLE1_W1TS, &GPIO_ENABLE1_W1TC);
}

static volatile uint32_t *cmd_model(volatile uint32_t *store)
{
    *store &= ~(1UL << 18);
    return store;
}

volatile uint32_t *mock_spi2cmd_model(void) { return cmd_model(&spi2cmd_store); }
volatile uint32_t *mock_spi3cmd_model(void) { return cmd_model(&spi3cmd_store); }

void mock_sfr_reset(void)
{
    gpio_out_store = gpio_out1_store = 0U;
    gpio_enable_store = gpio_enable1_store = 0U;
    GPIO_OUT_W1TS = GPIO_OUT_W1TC = GPIO_OUT1_W1TS = GPIO_OUT1_W1TC = 0U;
    GPIO_ENABLE_W1TS = GPIO_ENABLE_W1TC = GPIO_ENABLE1_W1TS = GPIO_ENABLE1_W1TC = 0U;
    GPIO_IN = GPIO_IN1 = 0U;
    U0FIFO = U0CLKDIV = U0STATUS = U0CONF0 = 0U;
    U1FIFO = U1CLKDIV = U1STATUS = U1CONF0 = 0U;
    U2FIFO = U2CLKDIV = U2STATUS = U2CONF0 = 0U;
    SPI2USER = SPI2CLOCK = SPI2W0 = SPI2MOSIDLEN = SPI2MISODLEN = 0U;
    SPI3USER = SPI3CLOCK = SPI3W0 = SPI3MOSIDLEN = SPI3MISODLEN = 0U;
    spi2cmd_store = spi3cmd_store = 0U;
    I2C0CTR = I2C0SCLLOW = I2C0SCLHIGH = 0U;
    I2C1CTR = I2C1SCLLOW = I2C1SCLHIGH = 0U;
    LEDC_LSTIMER0CONF = LEDC_LSTIMER1CONF = 0U;
    LEDC_HSTIMER0CONF = LEDC_HSTIMER1CONF = 0U;
    memset((void *)LEDC_CH0CONF0, 0, sizeof(LEDC_CH0CONF0));
    memset((void *)LEDC_CH0DUTY, 0, sizeof(LEDC_CH0DUTY));
}
