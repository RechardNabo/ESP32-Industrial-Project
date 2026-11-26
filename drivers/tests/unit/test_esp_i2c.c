/* test_esp_i2c.c — period decomposition + master enable bit-exact. */
#include "unity.h"
#include "xc.h"
#include "../../peripherals/i2c/esp_i2c.h"

void setUp(void) { mock_sfr_reset(); }
void tearDown(void) {}

static void test_periods_split_evenly_400k(void)
{
    uint32_t low, high;
    esp_i2c_periods(80000000UL, 400000UL, &low, &high);
    TEST_ASSERT_EQUAL_UINT32(100U, low);
    TEST_ASSERT_EQUAL_UINT32(100U, high);
}

static void test_periods_enforce_silicon_minimums(void)
{
    uint32_t low, high;
    /* very fast clock demand: total = 80e6/5e6 = 16 -> l 8 h 8, both >= mins */
    esp_i2c_periods(80000000UL, 5000000UL, &low, &high);
    TEST_ASSERT_TRUE(low >= 7U);
    TEST_ASSERT_TRUE(high >= 6U);
}

static void test_init_programs_minus_one_registers(void)
{
    esp_i2c_config_t c;
    c.apb_hz = 80000000UL;
    c.clock_hz = 400000UL;
    TEST_ASSERT_EQUAL(ESP_I2C_STATUS_OK, esp_i2c_init(ESP_I2C0, &c));
    TEST_ASSERT_EQUAL_HEX32(99U, I2C0SCLLOW);
    TEST_ASSERT_EQUAL_HEX32(99U, I2C0SCLHIGH);
    TEST_ASSERT_EQUAL_HEX32(1UL << 4, I2C0CTR);
}

static void test_invalid_clock_rejected(void)
{
    esp_i2c_config_t c;
    c.apb_hz = 80000000UL;
    c.clock_hz = 0U;
    TEST_ASSERT_EQUAL(ESP_I2C_STATUS_INVALID_PARAM, esp_i2c_init(ESP_I2C1, &c));
    TEST_ASSERT_EQUAL_HEX32(0U, I2C1CTR);
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_periods_split_evenly_400k);
    RUN_TEST(test_periods_enforce_silicon_minimums);
    RUN_TEST(test_init_programs_minus_one_registers);
    RUN_TEST(test_invalid_clock_rejected);
    return UNITY_END();
}
#endif
