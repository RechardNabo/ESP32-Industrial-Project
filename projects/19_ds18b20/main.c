/* main.c — kit module #19 DS18B20 Precision Temp — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  1000000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    ds18b20_t ds;
    ds18b20_init(&ds, 22U);
    uint8_t scratch[9];

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        if (ds18b20_start_conversion(&ds) == ONEWIRE_STATUS_OK) {{
        }}
        if (ds18b20_read_scratchpad(&ds, scratch) == ONEWIRE_STATUS_OK) {{
            const int32_t millic = ds18b20_raw_to_millic((int16_t)(scratch[0] | ((uint16_t)scratch[1] << 8)));
            (void)millic;
        }}
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
