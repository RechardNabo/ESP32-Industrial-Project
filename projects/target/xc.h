/* xc.h — TARGET register mapping for ESP32 (classic, ESP32-D0WD).
 * Flat mock names mapped to silicon addresses per the ESP32 TRM and
 * esp-idf soc register headers. Translation notes:
 *  - SENS_MEAS1_CTRL/_CTRL2/_DATA are ONE silicon register (0x54):
 *    control fields, done-flag and result share SENS_SAR_MEAS_START1_REG.
 *  - LEDC channel arrays use the silicon 5-word (0x14 byte) stride; all
 *    16 channels are contiguous because 8 HS x 0x14 lands exactly on the
 *    LS channel base (+0xA0).
 *  - GPIO bank 0 = pins 0-31, bank 1 = pins 32-39. */
#ifndef XC_H
#define XC_H

#include <stdint.h>
#include <stdbool.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

/* GPIO — IO_MUX-less simple pad control, base 0x3FF44000 */
#define GPIO_OUT        REG32(0x3FF44004UL)
#define GPIO_OUT_W1TS   REG32(0x3FF44008UL)
#define GPIO_OUT_W1TC   REG32(0x3FF4400CUL)
#define GPIO_OUT1       REG32(0x3FF44010UL)
#define GPIO_OUT1_W1TS  REG32(0x3FF44014UL)
#define GPIO_OUT1_W1TC  REG32(0x3FF44018UL)
#define GPIO_ENABLE     REG32(0x3FF44020UL)
#define GPIO_ENABLE_W1TS  REG32(0x3FF44024UL)
#define GPIO_ENABLE_W1TC  REG32(0x3FF44028UL)
#define GPIO_ENABLE1    REG32(0x3FF4402CUL)
#define GPIO_ENABLE1_W1TS  REG32(0x3FF44030UL)
#define GPIO_ENABLE1_W1TC  REG32(0x3FF44034UL)
#define GPIO_IN         REG32(0x3FF4403CUL)
#define GPIO_IN1        REG32(0x3FF44040UL)

/* SENS — SAR ADC1, base 0x3FF48800. CTRL/CTRL2/DATA all map to the
 * measurement register at +0x54: driver writes channel one-hot into
 * EN_PAD[30:19], start bits [18:17], reads DONE[16] and DATA[15:0]. */
#define SENS_MEAS1_CTRL   REG32(0x3FF48854UL)
#define SENS_MEAS1_CTRL2  REG32(0x3FF48854UL)
#define SENS_MEAS1_DATA   REG32(0x3FF48854UL)
#define SENS_ATTEN1       REG32(0x3FF48834UL)   /* SAR_ATTEN1: 2 bits per channel */
#define SENS_START_FORCE  REG32(0x3FF48800UL)   /* SAR_READ_CTRL: width/clock config */

/* LEDC — base 0x3FF59000. Channel blocks stride 0x14 (5 words):
 * +0x00 conf0, +0x08 duty within each block. Arrays indexed [ch*5]. */
#define LEDC_BASE_WORDS   ((volatile uint32_t *)0x3FF59000UL)
#define LEDC_CH0CONF0     ((volatile uint32_t *)0x3FF59000UL)         /* +0x00, stride 5 words */
#define LEDC_CH0DUTY      ((volatile uint32_t *)(0x3FF59000UL + 0x08UL))
#define LEDC_LSTIMER0CONF REG32(0x3FF590A0UL + 0xC0UL)   /* +0x160 */
#define LEDC_LSTIMER1CONF REG32(0x3FF590A0UL + 0xC4UL)   /* +0x164 */
#define LEDC_HSTIMER0CONF REG32(0x3FF59000UL + 0x140UL)
#define LEDC_HSTIMER1CONF REG32(0x3FF59000UL + 0x144UL)

/* TIMG0 — watchdog-capable general timer, base 0x3FF5F000 */
#define TIMG_T0CONFIG  REG32(0x3FF5F000UL)
#define TIMG_T0LO      REG32(0x3FF5F004UL)
#define TIMG_T0HI      REG32(0x3FF5F008UL)
#define TIMG_T0UPDATE  REG32(0x3FF5F00CUL)

#endif
