/* esp_gpio.h — GPIO driver for ESP32 classic.
 * Atomic W1TS/W1TC used for output set/clear — no RMW race across cores.
 * Input-only and flash-pin facts enforced at the boundary. */
#ifndef ESP_GPIO_H
#define ESP_GPIO_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
    ESP_GPIO_STATUS_OK = 0,
    ESP_GPIO_STATUS_INVALID_PIN,
    ESP_GPIO_STATUS_NOT_OUTPUT_CAPABLE
} esp_gpio_status_t;

esp_gpio_status_t esp_gpio_set_output(uint8_t pin);
esp_gpio_status_t esp_gpio_set_input(uint8_t pin);
esp_gpio_status_t esp_gpio_write(uint8_t pin, bool high);
esp_gpio_status_t esp_gpio_toggle(uint8_t pin);
bool esp_gpio_read(uint8_t pin);

#endif
