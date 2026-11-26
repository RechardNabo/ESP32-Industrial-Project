/* test_esp_spi.c — clock divider + mode edge bits + instant-transfer model. */
#include "unity.h"
#include "xc.h"
#include "../../peripherals/spi/esp_spi.h"

void setUp(void) { mock_sfr_reset(); }
void tearDown(void) {}

static esp_spi_config_t cfg10m(void)
{
    esp_spi_config_t c;
    c.apb_hz = 80000000UL;
    c.clock_hz = 10000000UL;
    c.mode = ESP_SPI_MODE_0;
    return c;
}

static void test_divisor_never_overclocks(void)
{
    TEST_ASSERT_EQUAL_UINT32(7U, esp_spi_divisor_n(80000000UL, 10000000UL));
    /* 80e6/3e6 = 26.67 -> ceil 27 -> n 26, actual 2.963MHz <= 3MHz */
    TEST_ASSERT_EQUAL_UINT32(26U, esp_spi_divisor_n(80000000UL, 3000000UL));
}

static void test_init_programs_clock_register(void)
{
    esp_spi_config_t c = cfg10m();
    TEST_ASSERT_EQUAL(ESP_SPI_STATUS_OK, esp_spi_init(ESP_SPI2, &c));
    TEST_ASSERT_EQUAL_HEX32(7U | (7UL << 6) | (8UL << 12), SPI2CLOCK);
}

static void test_mode0_sets_out_edge_bit(void)
{
    esp_spi_config_t c = cfg10m();
    esp_spi_init(ESP_SPI2, &c);
    TEST_ASSERT_EQUAL_HEX32((1UL << 27) | (1UL << 28) | (1UL << 7), SPI2USER);
}

static void test_mode3_sets_both_edge_bits(void)
{
    esp_spi_config_t c = cfg10m();
    c.mode = ESP_SPI_MODE_3;
    esp_spi_init(ESP_SPI3, &c);
    TEST_ASSERT_EQUAL_HEX32((1UL << 27) | (1UL << 28) | (1UL << 7) | (1UL << 6), SPI3USER);
}

static void test_exchange_frame_lengths_and_echo(void)
{
    esp_spi_config_t c = cfg10m();
    uint8_t rx = 0U;
    esp_spi_init(ESP_SPI2, &c);
    TEST_ASSERT_EQUAL(ESP_SPI_STATUS_OK, esp_spi_exchange_byte(ESP_SPI2, 0xA5U, &rx));
    TEST_ASSERT_EQUAL_HEX32(7U, SPI2MOSIDLEN);
    TEST_ASSERT_EQUAL_HEX32(7U, SPI2MISODLEN);
    TEST_ASSERT_EQUAL_HEX8(0xA5U, rx);   /* looped back through W0 in the model */
    TEST_ASSERT_EQUAL_HEX32(0U, SPI2CMD);  /* USR self-cleared after completion */
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_divisor_never_overclocks);
    RUN_TEST(test_init_programs_clock_register);
    RUN_TEST(test_mode0_sets_out_edge_bit);
    RUN_TEST(test_mode3_sets_both_edge_bits);
    RUN_TEST(test_exchange_frame_lengths_and_echo);
    return UNITY_END();
}
#endif
