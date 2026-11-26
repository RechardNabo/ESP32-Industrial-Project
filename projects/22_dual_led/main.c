/* main.c — kit module #22 Dual Red/Green LED — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  500000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    dig_out_t red, green;
    dig_out_config_t rcfg = {{ 25U, DIG_OUT_ACTIVE_HIGH }};
    dig_out_config_t gcfg = {{ 26U, DIG_OUT_ACTIVE_HIGH }};
    dig_out_init(&red, &rcfg);
    dig_out_init(&green, &gcfg);
    bool phase = false;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        phase = !phase;
        dig_out_set(&red, phase);
        dig_out_set(&green, !phase);
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
