/* xc.h — host-test register model for ESP32 classic peripherals in scope.
 * Behavioral models (documented simplifications):
 *  - W1TS/W1TC write-1-set/clear registers are flat memory; the modelled
 *    parent register (GPIO_OUT etc.) applies pending set/clear on access.
 *  - SPI CMD USR bit self-clears on the access after write — instant
 *    transfer completion. */
#ifndef XC_H
#define XC_H

#include <stdint.h>
#include <stdbool.h>

/* GPIO — parent registers modelled, W1TS/W1TC flat */
volatile uint32_t *mock_gpio_out_model(void);
volatile uint32_t *mock_gpio_out1_model(void);
volatile uint32_t *mock_gpio_enable_model(void);
volatile uint32_t *mock_gpio_enable1_model(void);
#define GPIO_OUT     (*mock_gpio_out_model())
#define GPIO_OUT1    (*mock_gpio_out1_model())
#define GPIO_ENABLE  (*mock_gpio_enable_model())
#define GPIO_ENABLE1 (*mock_gpio_enable1_model())
/* W1TS/W1TC are write-models: every write first flushes pending writes to
 * the parent IN ORDER � silicon write ordering preserved (write-only on hw) */
volatile uint32_t *mock_out_w1ts_w(void);
volatile uint32_t *mock_out_w1tc_w(void);
volatile uint32_t *mock_out1_w1ts_w(void);
volatile uint32_t *mock_out1_w1tc_w(void);
volatile uint32_t *mock_en_w1ts_w(void);
volatile uint32_t *mock_en_w1tc_w(void);
volatile uint32_t *mock_en1_w1ts_w(void);
volatile uint32_t *mock_en1_w1tc_w(void);
#define GPIO_OUT_W1TS     (*mock_out_w1ts_w())
#define GPIO_OUT_W1TC     (*mock_out_w1tc_w())
#define GPIO_OUT1_W1TS    (*mock_out1_w1ts_w())
#define GPIO_OUT1_W1TC    (*mock_out1_w1tc_w())
#define GPIO_ENABLE_W1TS  (*mock_en_w1ts_w())
#define GPIO_ENABLE_W1TC  (*mock_en_w1tc_w())
#define GPIO_ENABLE1_W1TS (*mock_en1_w1ts_w())
#define GPIO_ENABLE1_W1TC (*mock_en1_w1tc_w())
extern volatile uint32_t GPIO_IN, GPIO_IN1;

/* UART0-2 — flat */
extern volatile uint32_t U0FIFO, U0CLKDIV, U0STATUS, U0CONF0;
extern volatile uint32_t U1FIFO, U1CLKDIV, U1STATUS, U1CONF0;
extern volatile uint32_t U2FIFO, U2CLKDIV, U2STATUS, U2CONF0;

/* SPI2/SPI3 — CMD modelled, rest flat */
extern volatile uint32_t SPI2USER, SPI2CLOCK, SPI2W0, SPI2MOSIDLEN, SPI2MISODLEN;
extern volatile uint32_t SPI3USER, SPI3CLOCK, SPI3W0, SPI3MOSIDLEN, SPI3MISODLEN;
volatile uint32_t *mock_spi2cmd_model(void);
volatile uint32_t *mock_spi3cmd_model(void);
#define SPI2CMD (*mock_spi2cmd_model())
#define SPI3CMD (*mock_spi3cmd_model())

/* I2C0/I2C1 — flat */
extern volatile uint32_t I2C0CTR, I2C0SCLLOW, I2C0SCLHIGH;
extern volatile uint32_t I2C1CTR, I2C1SCLLOW, I2C1SCLHIGH;

/* LEDC — flat */
extern volatile uint32_t LEDC_LSTIMER0CONF, LEDC_LSTIMER1CONF;
extern volatile uint32_t LEDC_HSTIMER0CONF, LEDC_HSTIMER1CONF;
extern volatile uint32_t LEDC_CH0CONF0[16];
extern volatile uint32_t LEDC_CH0DUTY[16];

/* ADC legacy controller */
extern volatile uint32_t SENS_ATTEN1, SENS_START_FORCE;
extern volatile uint32_t SENS_MEAS1_CTRL, SENS_MEAS1_DATA;
volatile uint32_t *mock_meas1ctrl2_model(void);
#define SENS_MEAS1_CTRL2 (*mock_meas1ctrl2_model())

/* timer group 0 � T0 at 1MHz; UPDATE latches both halves on silicon,
 * the mock advances virtual time per read so busy-waits terminate */
extern volatile uint32_t TIMG_T0CONFIG, TIMG_T0UPDATE;
volatile uint32_t *mock_t0lo_model(void);
volatile uint32_t *mock_t0hi_model(void);
#define TIMG_T0LO (*mock_t0lo_model())
#define TIMG_T0HI (*mock_t0hi_model())
void mock_time_reset(void);
void mock_time_schedule(uint32_t offset_us, uint8_t pin, bool level);
uint64_t mock_time_now(void);

void mock_sfr_reset(void);

#endif
