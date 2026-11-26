/* esp_board.h — board facts, ESP32 classic (ESP32-WROOM-32 class module).
 * 32-bit registers throughout; GPIO blocks carry atomic W1TS/W1TC
 * write-1-set/write-1-clear aliases. APB clock 80 MHz is the time base. */
#ifndef ESP_BOARD_H
#define ESP_BOARD_H

#include <stdint.h>
#include <stdbool.h>

#define ESP_APB_CLK_HZ  80000000UL

/* pins 6-11 are internal SPI flash — never user GPIO; 34-39 input-only */
static inline bool esp_gpio_usable(uint8_t pin)
{
    if (pin >= 6U && pin <= 11U) return false;
    if (pin > 39U) return false;
    return true;
}
static inline bool esp_gpio_output_capable(uint8_t pin)
{
    return esp_gpio_usable(pin) && !(pin >= 34U);
}

#define ESP_UART_PRESENT_MASK  0x7U   /* UART0 console + UART1/2 user */

#endif
