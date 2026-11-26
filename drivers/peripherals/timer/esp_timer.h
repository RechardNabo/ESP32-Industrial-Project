/* esp_timer_drv.h — microsecond timing for ESP32 classic.
 * Uses the 64-bit free-running timer group counter (TIMG T0), 1 MHz
 * after the divider is set. Same 64-bit composition discipline as the
 * RP2040 driver: the low read latches the high register — on ESP32 the
 * UPDATE bit must be written first to latch both halves. */
#ifndef ESP_TIMER_DRV_H
#define ESP_TIMER_DRV_H

#include <stdint.h>

void esp_timer_drv_init(void);
uint64_t esp_timer_now_us(void);
void esp_timer_delay_us(uint32_t us);

#endif
