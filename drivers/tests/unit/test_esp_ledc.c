/* test_esp_ledc.c — the frequency x resolution interlock, bit-exact. */
#include "unity.h"
#include "xc.h"
#include "../../peripherals/ledc/esp_ledc.h"

void setUp(void) { mock_sfr_reset(); }
void tearDown(void) {}

static esp_ledc_timer_config_t cfg5k13(void)
{
    esp_ledc_timer_config_t c;
    c.apb_hz = 80000000UL;
    c.frequency = 5000UL;
    c.resolution_bits = 13U;
    return c;
}

static void test_legal_combination_accepted(void)
{
    TEST_ASSERT_TRUE(esp_ledc_freq_resolution_legal(80000000UL, 5000UL, 13U));
}

static void test_impossible_combination_rejected(void)
{
    /* 80e6/5000 = 16000 cycles < 2^20 — cannot resolve 20 bits at 5kHz */
    TEST_ASSERT_FALSE(esp_ledc_freq_resolution_legal(80000000UL, 5000UL, 20U));
}

static void test_timer_init_programs_fixed_point_divider(void)
{
    esp_ledc_timer_config_t c = cfg5k13();
    TEST_ASSERT_EQUAL(ESP_LEDC_STATUS_OK, esp_ledc_timer_init(0U, &c));
    /* cycles 16000, divider fp = (16000<<8)/8192 = 500 */
    TEST_ASSERT_EQUAL_HEX32((13UL << 20) | 500U, LEDC_LSTIMER0CONF);
}

static void test_timer_init_impossible_rejected_clean(void)
{
    esp_ledc_timer_config_t c = cfg5k13();
    c.resolution_bits = 20U;
    TEST_ASSERT_EQUAL(ESP_LEDC_STATUS_FREQ_RESOLUTION_IMPOSSIBLE,
                      esp_ledc_timer_init(0U, &c));
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_LSTIMER0CONF);
}

static void test_channel_binds_timer_and_enables_output(void)
{
    TEST_ASSERT_EQUAL(ESP_LEDC_STATUS_OK, esp_ledc_channel_init(3U, 1U));
    TEST_ASSERT_EQUAL_HEX32(1U | (1UL << 2), LEDC_CH0CONF0[3]);
}

static void test_duty_permille_programmed_fixed_point(void)
{
    esp_ledc_channel_init(3U, 1U);
    TEST_ASSERT_EQUAL(ESP_LEDC_STATUS_OK, esp_ledc_set_duty(3U, 500U));
    TEST_ASSERT_EQUAL_HEX32(500UL << 4, LEDC_CH0DUTY[3]);
    TEST_ASSERT_EQUAL(ESP_LEDC_STATUS_INVALID_PARAM, esp_ledc_set_duty(3U, 1001U));
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_legal_combination_accepted);
    RUN_TEST(test_impossible_combination_rejected);
    RUN_TEST(test_timer_init_programs_fixed_point_divider);
    RUN_TEST(test_timer_init_impossible_rejected_clean);
    RUN_TEST(test_channel_binds_timer_and_enables_output);
    RUN_TEST(test_duty_permille_programmed_fixed_point);
    return UNITY_END();
}
#endif
