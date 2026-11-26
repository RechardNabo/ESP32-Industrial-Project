/* main.c — kit module #35 Large Reed Switch — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  10000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    dig_in_t sensor;
    dig_in_config_t cfg = kit_dig_in_config(KIT_REED_BIG, 21U);
    dig_in_init(&sensor, &cfg);
    esp_gpio_set_output(LED_PIN);
    uint32_t events = 0U;
    bool was_active = false;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        dig_in_sample(&sensor);
        const bool active = dig_in_state(&sensor);
        esp_gpio_write(LED_PIN, active);
        if (active && !was_active) {{
            events++;
        }}
        was_active = active;
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
