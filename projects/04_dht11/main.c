/* main.c — kit module #4 DHT11 Temp+Humidity — standalone firmware, ESP32 classic.
 * Non-blocking super-loop over the device layer. Wiring/verification: README.md.
 * Target build: ESP-IDF. Host-verified logic: drivers/tests/unit/. */
#include <stdint.h>
#include <stdbool.h>

#include "../../drivers/devices/kit/kit.h"
#include "../../drivers/peripherals/gpio/esp_gpio.h"
#include "../../drivers/peripherals/timer/esp_timer.h"

#define TICK_US  2000000UL
#define LED_PIN  2U   /* typical devkit onboard LED */

int main(void)
{
    esp_timer_drv_init();
    dht11_t dht;
    dht11_init(&dht, 22U);
    uint8_t rh = 0U, temp = 0U;

    for (;;) {
        const uint64_t tick_start = esp_timer_now_us();
        if (dht11_read(&dht, &rh, &temp) == ONEWIRE_STATUS_OK) {{
            /* report over UART console */
        }}
        while ((esp_timer_now_us() - tick_start) < TICK_US) { }
    }
}
