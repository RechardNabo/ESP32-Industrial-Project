/* main.c — kit module #32 LM35 #32 — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  100000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    analog_in_t sensor;
    analog_in_config_t cfg = kit_analog_config(KIT_LM35_B, 2U);
    esp_adc_init(ESP_ADC_ATTEN_11DB);   /* full-range — see attenuation note */
    analog_in_init(&sensor, &cfg);
    int32_t eng = 0;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        if (analog_in_read_scaled(&sensor, &eng) == ANALOG_IN_STATUS_OK) {
            /* report eng over UART console */
        }
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
