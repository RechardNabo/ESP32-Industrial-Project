/* test_pwm_out.c — ESP32 LEDC adaptation: duty is permille<<4 fixed point,
 * frequency retuning reprograms the timer divider, not a TOP register. */
#include "unity.h"
#include "xc.h"
#include "../../devices/pwm_out/pwm_out.h"
#include "../../peripherals/timer/esp_timer.h"

void setUp(void) { mock_sfr_reset(); esp_timer_drv_init(); }
void tearDown(void) {}

static void test_rgb_init_silences_all_channels(void)
{
    rgb_led_t dev;
    TEST_ASSERT_EQUAL(PWM_OUT_STATUS_OK,
        rgb_led_init(&dev, 0U, 0U, 0U, 1U, 0U, 2U, 80000000UL, 1000UL));
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[0]);
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[1]);
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[2]);
}

static void test_rgb_full_red_max_duty(void)
{
    rgb_led_t dev;
    rgb_led_init(&dev, 0U, 0U, 0U, 1U, 0U, 2U, 80000000UL, 1000UL);
    rgb_led_set(&dev, 255U, 0U, 0U);
    /* 255 -> 1000 permille -> LEDC duty register 1000 << 4 */
    TEST_ASSERT_EQUAL_HEX32(1000UL << 4, LEDC_CH0DUTY[0]);
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[1]);
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[2]);
}

static void test_rgb_half_green_scales(void)
{
    rgb_led_t dev;
    rgb_led_init(&dev, 0U, 0U, 0U, 1U, 0U, 2U, 80000000UL, 1000UL);
    rgb_led_set(&dev, 0U, 128U, 0U);
    /* 128x1000/255 = 501 permille -> 501 << 4 */
    TEST_ASSERT_EQUAL_HEX32(501UL << 4, LEDC_CH0DUTY[1]);
}

static void test_buzzer_tone_retunes_timer(void)
{
    buzzer_t dev;
    TEST_ASSERT_EQUAL(PWM_OUT_STATUS_OK, buzzer_init(&dev, 1U, 5U, 80000000UL));
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[5]);
    TEST_ASSERT_EQUAL(PWM_OUT_STATUS_OK, buzzer_tone(&dev, 2000UL));
    /* 80e6/2000 = 40000 cycles; fp div = (40000<<8)/8192 = 1250; res 13 */
    TEST_ASSERT_EQUAL_HEX32((13UL << 20) | 1250U, LEDC_LSTIMER1CONF);
    TEST_ASSERT_EQUAL_HEX32(500UL << 4, LEDC_CH0DUTY[5]);
    TEST_ASSERT_TRUE(dev.sounding);
}

static void test_buzzer_off_silences(void)
{
    buzzer_t dev;
    buzzer_init(&dev, 1U, 5U, 80000000UL);
    buzzer_tone(&dev, 2000UL);
    buzzer_off(&dev);
    TEST_ASSERT_EQUAL_HEX32(0U, LEDC_CH0DUTY[5]);
    TEST_ASSERT_FALSE(dev.sounding);
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_rgb_init_silences_all_channels);
    RUN_TEST(test_rgb_full_red_max_duty);
    RUN_TEST(test_rgb_half_green_scales);
    RUN_TEST(test_buzzer_tone_retunes_timer);
    RUN_TEST(test_buzzer_off_silences);
    return UNITY_END();
}
#endif
