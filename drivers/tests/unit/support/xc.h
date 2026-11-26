/* xc.h — host-test register model for ESP32 classic peripherals in scope.
 * Behavioral models (documented simplifications):
 *  - W1TS/W1TC write-1-set/clear registers are flat memory; the modelled
 *    parent register (GPIO_OUT etc.) applies pending set/clear on access.
 *  - SPI CMD USR bit self-clears on the access after write — instant
 *    transfer completion. */
#ifndef XC_H
#define XC_H

#include <stdint.h>

/* GPIO — parent registers modelled, W1TS/W1TC flat */
volatile uint32_t *mock_gpio_out_model(void);
volatile uint32_t *mock_gpio_out1_model(void);
volatile uint32_t *mock_gpio_enable_model(void);
volatile uint32_t *mock_gpio_enable1_model(void);
#define GPIO_OUT     (*mock_gpio_out_model())
#define GPIO_OUT1    (*mock_gpio_out1_model())
#define GPIO_ENABLE  (*mock_gpio_enable_model())
#define GPIO_ENABLE1 (*mock_gpio_enable1_model())
extern volatile uint32_t GPIO_OUT_W1TS, GPIO_OUT_W1TC, GPIO_OUT1_W1TS, GPIO_OUT1_W1TC;
extern volatile uint32_t GPIO_ENABLE_W1TS, GPIO_ENABLE_W1TC, GPIO_ENABLE1_W1TS, GPIO_ENABLE1_W1TC;
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

void mock_sfr_reset(void);

#endif
