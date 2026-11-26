/* main.c — kit module #12 RGB LED — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  20000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    rgb_led_t rgb;
    rgb_led_init(&rgb, 0U, 0U, 0U, 1U, 0U, 2U, 80000000UL, 1000UL);
    uint16_t hue = 0U;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        const uint16_t h = hue % 768U;
        uint8_t r, g, b;
        if (h < 256U)       {{ r = (uint8_t)(255U - h); g = (uint8_t)h; b = 0U; }}
        else if (h < 512U)  {{ r = 0U; g = (uint8_t)(511U - h); b = (uint8_t)(h - 256U); }}
        else                {{ r = (uint8_t)(h - 512U); g = 0U; b = (uint8_t)(767U - h); }}
        rgb_led_set(&rgb, r, g, b);
        hue++;
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
