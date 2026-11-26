/* main.c — kit module #3 Laser Diode — standalone firmware, ESP32 classic.
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
    dig_out_t dev;
    dig_out_config_t cfg = kit_dig_out_config(KIT_LASER, 18U);
    dig_out_init(&dev, &cfg);
    bool phase = false;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        phase = !phase;
        dig_out_set(&dev, phase);
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
