/* test_esp_uart.c — fractional divisor math + frame assembly bit-exact. */
#include "unity.h"
#include "xc.h"
#include "../../peripherals/uart/esp_uart.h"

void setUp(void) { mock_sfr_reset(); }
void tearDown(void) {}

static esp_uart_config_t cfg115200(void)
{
    esp_uart_config_t c;
    c.apb_hz = 80000000UL;
    c.baud = 115200UL;
    c.parity = ESP_UART_PARITY_NONE;
    c.stop_bits = 1U;
    return c;
}

static void test_divisor_math_115200(void)
{
    uint32_t div, frag;
    esp_uart_divisor(80000000UL, 115200UL, &div, &frag);
    /* 80e6*16/115200 = 11111.1 sixteenths -> div 694 frag 7 */
    TEST_ASSERT_EQUAL_UINT32(694U, div);
    TEST_ASSERT_EQUAL_UINT32(7U, frag);
}

static void test_init_programs_clkdiv_and_conf0(void)
{
    esp_uart_config_t c = cfg115200();
    TEST_ASSERT_EQUAL(ESP_UART_STATUS_OK, esp_uart_init(ESP_UART0, &c));
    TEST_ASSERT_EQUAL_HEX32(694U | (7UL << 20), U0CLKDIV);
    /* 8N1: bitnum=3<<2, stop1=1<<4, no parity */
    TEST_ASSERT_EQUAL_HEX32((3UL << 2) | (1UL << 4), U0CONF0);
}

static void test_init_even_parity_two_stop(void)
{
    esp_uart_config_t c = cfg115200();
    c.parity = ESP_UART_PARITY_EVEN;
    c.stop_bits = 2U;
    TEST_ASSERT_EQUAL(ESP_UART_STATUS_OK, esp_uart_init(ESP_UART2, &c));
    TEST_ASSERT_EQUAL_HEX32((3UL << 2) | (3UL << 4) | (1UL << 1), U2CONF0);
}

static void test_zero_baud_rejected(void)
{
    esp_uart_config_t c = cfg115200();
    c.baud = 0U;
    TEST_ASSERT_EQUAL(ESP_UART_STATUS_INVALID_PARAM, esp_uart_init(ESP_UART0, &c));
    TEST_ASSERT_EQUAL_HEX32(0U, U0CLKDIV);
}

static void test_write_blocked_when_fifo_full(void)
{
    esp_uart_config_t c = cfg115200();
    esp_uart_init(ESP_UART0, &c);
    U0STATUS = 127UL << 8;   /* TXFIFO_CNT at capacity-1 boundary */
    TEST_ASSERT_FALSE(esp_uart_write_byte(ESP_UART0, 0x55U));
    TEST_ASSERT_EQUAL_HEX32(0U, U0FIFO);
    U0STATUS = 0U;
    TEST_ASSERT_TRUE(esp_uart_write_byte(ESP_UART0, 0x55U));
    TEST_ASSERT_EQUAL_HEX32(0x55U, U0FIFO);
}

static void test_read_gated_by_rxfifo_count(void)
{
    uint8_t out = 0U;
    TEST_ASSERT_FALSE(esp_uart_read_byte(ESP_UART1, &out));
    U1STATUS = 1U;      /* one byte in rx fifo */
    U1FIFO = 0xA5U;
    TEST_ASSERT_TRUE(esp_uart_read_byte(ESP_UART1, &out));
    TEST_ASSERT_EQUAL_HEX8(0xA5U, out);
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_divisor_math_115200);
    RUN_TEST(test_init_programs_clkdiv_and_conf0);
    RUN_TEST(test_init_even_parity_two_stop);
    RUN_TEST(test_zero_baud_rejected);
    RUN_TEST(test_write_blocked_when_fifo_full);
    RUN_TEST(test_read_gated_by_rxfifo_count);
    return UNITY_END();
}
#endif
