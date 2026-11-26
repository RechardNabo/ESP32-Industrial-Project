/* esp_gpio.c — bank 0 pins 0-31, bank 1 pins 32-39. */
#include <xc.h>

#include "esp_gpio.h"
#include "../../bsp/esp_board.h"

static bool high_bank(uint8_t pin) { return pin >= 32U; }
static uint32_t pinbit(uint8_t pin) { return 1UL << (pin & 31U); }

esp_gpio_status_t esp_gpio_set_output(uint8_t pin)
{
    if (!esp_gpio_usable(pin)) return ESP_GPIO_STATUS_INVALID_PIN;
    if (!esp_gpio_output_capable(pin)) return ESP_GPIO_STATUS_NOT_OUTPUT_CAPABLE;
    if (high_bank(pin)) GPIO_ENABLE1_W1TS = pinbit(pin);
    else                GPIO_ENABLE_W1TS  = pinbit(pin);
    return ESP_GPIO_STATUS_OK;
}

esp_gpio_status_t esp_gpio_set_input(uint8_t pin)
{
    if (!esp_gpio_usable(pin)) return ESP_GPIO_STATUS_INVALID_PIN;
    if (high_bank(pin)) GPIO_ENABLE1_W1TC = pinbit(pin);
    else                GPIO_ENABLE_W1TC  = pinbit(pin);
    return ESP_GPIO_STATUS_OK;
}

esp_gpio_status_t esp_gpio_write(uint8_t pin, bool high)
{
    if (!esp_gpio_output_capable(pin)) return ESP_GPIO_STATUS_INVALID_PIN;
    if (high_bank(pin)) {
        if (high) GPIO_OUT1_W1TS = pinbit(pin); else GPIO_OUT1_W1TC = pinbit(pin);
    } else {
        if (high) GPIO_OUT_W1TS = pinbit(pin); else GPIO_OUT_W1TC = pinbit(pin);
    }
    return ESP_GPIO_STATUS_OK;
}

esp_gpio_status_t esp_gpio_toggle(uint8_t pin)
{
    if (!esp_gpio_output_capable(pin)) return ESP_GPIO_STATUS_INVALID_PIN;
    if (high_bank(pin)) GPIO_OUT1 ^= pinbit(pin);
    else                GPIO_OUT  ^= pinbit(pin);
    return ESP_GPIO_STATUS_OK;
}

bool esp_gpio_read(uint8_t pin)
{
    if (!esp_gpio_usable(pin)) return false;
    if (high_bank(pin)) return (GPIO_IN1 & pinbit(pin)) != 0U;
    return (GPIO_IN & pinbit(pin)) != 0U;
}
