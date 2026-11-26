/* esp_timer_drv.c — see esp_timer.h.
 * TIMG_T0CONFIG: EN bit31, divider bits 29:16 (value+1 -> 80 for 1MHz
 * from 80MHz APB). TIMG_T0UPDATE: writing any value latches the counter
 * into T0LO/T0HI atomically — read only after update. */
#include <xc.h>

#include "esp_timer.h"

#define T0CONFIG_EN  (1UL << 31)

void esp_timer_drv_init(void)
{
    TIMG_T0CONFIG = (80UL << 16);      /* 80MHz/80 = 1MHz counter */
    TIMG_T0LO = 0U;
    TIMG_T0HI = 0U;
    TIMG_T0CONFIG |= T0CONFIG_EN;
}

uint64_t esp_timer_now_us(void)
{
    uint32_t lo, hi;
    TIMG_T0UPDATE = 1U;                /* latch both halves atomically */
    lo = TIMG_T0LO;
    hi = TIMG_T0HI;
    return ((uint64_t)hi << 32) | lo;
}

void esp_timer_delay_us(uint32_t us)
{
    const uint64_t start = esp_timer_now_us();
    while ((esp_timer_now_us() - start) < us) {
        /* busy wait — bitbang timing */
    }
}
