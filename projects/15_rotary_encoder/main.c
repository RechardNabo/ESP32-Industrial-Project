/* main.c — kit module #15 KY-040 Rotary Encoder — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  2000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    quad_enc_t enc;
    quad_enc_config_t ecfg = {{ 34U, 35U, 1 }};
    quad_enc_init(&enc, &ecfg);
    dig_in_t btn;
    dig_in_config_t bcfg = {{ 23U, DIG_IN_ACTIVE_LOW, 5U }};
    dig_in_init(&btn, &bcfg);
    int32_t last_detents = 0;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        quad_enc_sample(&enc);
        dig_in_sample(&btn);
        if (dig_in_state(&btn)) {{
            quad_enc_reset(&enc);
        }}
        if (quad_enc_detents(&enc) != last_detents) {{
            last_detents = quad_enc_detents(&enc);
        }}
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
