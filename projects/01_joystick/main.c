/* main.c — kit module #1 PS2 Joystick — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  50000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    analog_in_t vrx, vry;
    analog_in_config_t xcfg = kit_analog_config(KIT_JOYSTICK, 0U);
    analog_in_config_t ycfg = kit_analog_config(KIT_JOYSTICK, 1U);
    esp_adc_init(ESP_ADC_ATTEN_11DB);
    analog_in_init(&vrx, &xcfg);
    analog_in_init(&vry, &ycfg);
    dig_in_t btn;
    dig_in_config_t bcfg = kit_dig_in_config(KIT_JOYSTICK_BTN, 23U);
    dig_in_init(&btn, &bcfg);
    int32_t x = 0, y = 0;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        analog_in_read_scaled(&vrx, &x);
        analog_in_read_scaled(&vry, &y);
        dig_in_sample(&btn);
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
