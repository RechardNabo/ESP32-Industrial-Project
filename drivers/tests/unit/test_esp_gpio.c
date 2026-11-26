/* test_esp_gpio.c — bit-exact verification of the ESP32 GPIO driver. */
#include "unity.h"
#include "xc.h"
#include "../../peripherals/gpio/esp_gpio.h"

void setUp(void) { mock_sfr_reset(); }
void tearDown(void) {}

static void test_output_enable_sets_w1ts_bank0(void)
{
    esp_gpio_status_t st = esp_gpio_set_output(2U);
    TEST_ASSERT_EQUAL(ESP_GPIO_STATUS_OK, st);
    TEST_ASSERT_EQUAL_HEX32(1UL << 2, GPIO_ENABLE_W1TS);
    /* parent applies pending set on access */
    TEST_ASSERT_EQUAL_HEX32(1UL << 2, GPIO_ENABLE);
}

static void test_output_enable_high_bank_uses_reg1(void)
{
    TEST_ASSERT_EQUAL(ESP_GPIO_STATUS_OK, esp_gpio_set_output(33U));
    TEST_ASSERT_EQUAL_HEX32(1UL << 1, GPIO_ENABLE1_W1TS);
    TEST_ASSERT_EQUAL_HEX32(0U, GPIO_ENABLE_W1TS);
}

static void test_input_only_pin_34_rejected_for_output(void)
{
    TEST_ASSERT_EQUAL(ESP_GPIO_STATUS_NOT_OUTPUT_CAPABLE, esp_gpio_set_output(34U));
    TEST_ASSERT_EQUAL_HEX32(0U, GPIO_ENABLE1_W1TS);
}

static void test_flash_pin_6_rejected(void)
{
    TEST_ASSERT_EQUAL(ESP_GPIO_STATUS_INVALID_PIN, esp_gpio_set_output(6U));
    TEST_ASSERT_EQUAL(ESP_GPIO_STATUS_INVALID_PIN, esp_gpio_write(6U, true));
}

static void test_write_high_low_roundtrip(void)
{
    esp_gpio_set_output(4U);
    esp_gpio_write(4U, true);
    TEST_ASSERT_EQUAL_HEX32(1UL << 4, GPIO_OUT);
    esp_gpio_write(4U, false);
    TEST_ASSERT_EQUAL_HEX32(0U, GPIO_OUT);
}

static void test_read_reflects_input_register(void)
{
    GPIO_IN = 1UL << 5;
    TEST_ASSERT_TRUE(esp_gpio_read(5U));
    TEST_ASSERT_FALSE(esp_gpio_read(6U));
    GPIO_IN1 = 1UL << (35U - 32U);
    TEST_ASSERT_TRUE(esp_gpio_read(35U));
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_output_enable_sets_w1ts_bank0);
    RUN_TEST(test_output_enable_high_bank_uses_reg1);
    RUN_TEST(test_input_only_pin_34_rejected_for_output);
    RUN_TEST(test_flash_pin_6_rejected);
    RUN_TEST(test_write_high_low_roundtrip);
    RUN_TEST(test_read_reflects_input_register);
    return UNITY_END();
}
#endif
