/* mock_sfr.c â€” backing memory + behavioral models, see xc.h. */
#include <string.h>

#include "xc.h"

void mock_time_reset(void);

#define MOCK_TIME_QUANTUM_US  2ULL
#define MOCK_SCHED_MAX        8

static uint64_t vtime_us;
static volatile uint32_t t0lo_cell, t0hi_cell, meas1ctrl_store, meas1ctrl2_store;
static struct { uint64_t at_us; uint8_t pin; bool level; } sched[MOCK_SCHED_MAX];
static int sched_count;

static volatile uint32_t gpio_out_store, gpio_out1_store;
static volatile uint32_t gpio_enable_store, gpio_enable1_store;
static volatile uint32_t out_w1ts, out_w1tc, out1_w1ts, out1_w1tc;
static volatile uint32_t en_w1ts, en_w1tc, en1_w1ts, en1_w1tc;
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
volatile uint32_t LEDC_CH0CONF0[80];
volatile uint32_t LEDC_CH0DUTY[80];

static volatile uint32_t spi2cmd_store, spi3cmd_store;

static void flush_out(void)
{
    gpio_out_store |= out_w1ts;
    gpio_out_store &= ~out_w1tc;
    out_w1ts = out_w1tc = 0U;
}
static void flush_out1(void)
{
    gpio_out1_store |= out1_w1ts;
    gpio_out1_store &= ~out1_w1tc;
    out1_w1ts = out1_w1tc = 0U;
}
static void flush_en(void)
{
    gpio_enable_store |= en_w1ts;
    gpio_enable_store &= ~en_w1tc;
    en_w1ts = en_w1tc = 0U;
}
static void flush_en1(void)
{
    gpio_enable1_store |= en1_w1ts;
    gpio_enable1_store &= ~en1_w1tc;
    en1_w1ts = en1_w1tc = 0U;
}

volatile uint32_t *mock_out_w1ts_w(void) { flush_out(); return &out_w1ts; }
volatile uint32_t *mock_out_w1tc_w(void) { flush_out(); return &out_w1tc; }
volatile uint32_t *mock_out1_w1ts_w(void) { flush_out1(); return &out1_w1ts; }
volatile uint32_t *mock_out1_w1tc_w(void) { flush_out1(); return &out1_w1tc; }
volatile uint32_t *mock_en_w1ts_w(void) { flush_en(); return &en_w1ts; }
volatile uint32_t *mock_en_w1tc_w(void) { flush_en(); return &en_w1tc; }
volatile uint32_t *mock_en1_w1ts_w(void) { flush_en1(); return &en1_w1ts; }
volatile uint32_t *mock_en1_w1tc_w(void) { flush_en1(); return &en1_w1tc; }

volatile uint32_t *mock_gpio_out_model(void) { flush_out(); return &gpio_out_store; }
volatile uint32_t *mock_gpio_out1_model(void) { flush_out1(); return &gpio_out1_store; }
volatile uint32_t *mock_gpio_enable_model(void) { flush_en(); return &gpio_enable_store; }
volatile uint32_t *mock_gpio_enable1_model(void) { flush_en1(); return &gpio_enable1_store; }

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
    out_w1ts = out_w1tc = out1_w1ts = out1_w1tc = 0U;
    en_w1ts = en_w1tc = en1_w1ts = en1_w1tc = 0U;
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
    SENS_ATTEN1 = SENS_START_FORCE = 0U;
    SENS_MEAS1_CTRL = SENS_MEAS1_DATA = 0U;
    meas1ctrl2_store = 0U;
    TIMG_T0CONFIG = TIMG_T0UPDATE = 0U;
    meas1ctrl_store = 0U;
    mock_time_reset();
}

/* ---- ADC + timer backing + time engine (same model as RP2040 port) ---- */
#include <stdbool.h>

volatile uint32_t SENS_ATTEN1, SENS_START_FORCE;
volatile uint32_t SENS_MEAS1_CTRL, SENS_MEAS1_DATA;
volatile uint32_t TIMG_T0CONFIG, TIMG_T0UPDATE;


void mock_time_reset(void)
{
    int i;
    vtime_us = 0ULL;
    sched_count = 0;
    for (i = 0; i < MOCK_SCHED_MAX; i++) sched[i].at_us = 0ULL;
}

uint64_t mock_time_now(void) { return vtime_us; }

void mock_time_schedule(uint32_t offset_us, uint8_t pin, bool level)
{
    if (sched_count >= MOCK_SCHED_MAX) return;
    sched[sched_count].at_us = vtime_us + offset_us;
    sched[sched_count].pin = pin;
    sched[sched_count].level = level;
    sched_count++;
}

static void time_tick(void)
{
    int i;
    vtime_us += MOCK_TIME_QUANTUM_US;
    for (i = 0; i < sched_count; i++) {
        if (sched[i].at_us != 0ULL && vtime_us >= sched[i].at_us) {
            if (sched[i].level) GPIO_IN |= (1UL << sched[i].pin);
            else                GPIO_IN &= ~(1UL << sched[i].pin);
            sched[i].at_us = 0ULL;
        }
    }
}

volatile uint32_t *mock_t0lo_model(void)
{
    time_tick();
    t0lo_cell = (uint32_t)(vtime_us & 0xFFFFFFFFULL);
    return &t0lo_cell;
}

volatile uint32_t *mock_t0hi_model(void)
{
    t0hi_cell = (uint32_t)(vtime_us >> 32);
    return &t0hi_cell;
}

/* ADC conversion model: the conversion completes when the driver polls
 * CTRL2 — instant-completion simplification, documented in xc.h */
volatile uint32_t *mock_meas1ctrl2_model(void)
{
    if ((SENS_MEAS1_CTRL & (1UL << 18)) != 0U) {
        SENS_MEAS1_CTRL &= ~(1UL << 18);   /* START self-clears */
        meas1ctrl2_store |= 1UL;           /* conversion DONE */
    }
    return &meas1ctrl2_store;
}
