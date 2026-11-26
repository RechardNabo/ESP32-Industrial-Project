/* test_adc.c — attenuation range honesty + conversion model, bit-exact. */
#include "unity.h"
#include "xc.h"
#include "../../peripherals/adc/esp_adc.h"

void setUp(void) { mock_sfr_reset(); }
void tearDown(void) {}

static void test_init_programs_attenuation_all_channels(void)
{
    TEST_ASSERT_EQUAL(ESP_ADC_STATUS_OK, esp_adc_init(ESP_ADC_ATTEN_11DB));
    /* 2 bits per channel x 8 channels, value 3 each */
    TEST_ASSERT_EQUAL_HEX32(3UL * 0x55555555UL, SENS_ATTEN1);
}

static void test_read_channel_select_encoding(void)
{
    uint16_t raw = 0U;
    esp_adc_init(ESP_ADC_ATTEN_11DB);
    SENS_MEAS1_DATA = 2048U;
    TEST_ASSERT_EQUAL(ESP_ADC_STATUS_OK, esp_adc_read(3U, &raw));
    TEST_ASSERT_EQUAL_UINT16(2048U, raw);
    /* DONE consumed in conversion model */
    TEST_ASSERT_EQUAL_HEX32(1U, SENS_MEAS1_CTRL2 & 1U);
}

static void test_invalid_channel_rejected(void)
{
    uint16_t raw;
    TEST_ASSERT_EQUAL(ESP_ADC_STATUS_INVALID_CHANNEL, esp_adc_read(8U, &raw));
}

static void test_millivolt_scaling_per_attenuation(void)
{
    /* THE trap this encodes: 0dB reads only ~800mV full-scale — using it
     * for a 3.3V signal clips silently. 11dB reaches ~3.1V. */
    TEST_ASSERT_EQUAL_UINT16(800U, esp_adc_to_mv(4095U, ESP_ADC_ATTEN_0DB));
    TEST_ASSERT_EQUAL_UINT16(3100U, esp_adc_to_mv(4095U, ESP_ADC_ATTEN_11DB));
    TEST_ASSERT_EQUAL_UINT16(1550U, esp_adc_to_mv(2048U, ESP_ADC_ATTEN_11DB));
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_init_programs_attenuation_all_channels);
    RUN_TEST(test_read_channel_select_encoding);
    RUN_TEST(test_invalid_channel_rejected);
    RUN_TEST(test_millivolt_scaling_per_attenuation);
    return UNITY_END();
}
#endif
