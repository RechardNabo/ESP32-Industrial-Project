/* test_hall_switch_app.c — 3 tests pinning the project's event-counting contract. */
#include "unity.h"
#include "xc.h"
#include "hall_switch_app.h"
#include "../../drivers/devices/kit/kit.h"

static hall_switch_app_t app;
static dig_in_config_t cfg;
static uint8_t pin;

void setUp(void)
{
    mock_sfr_reset();
    pin = kit_default_pin(KIT_HALL_SWITCH);
    cfg = kit_dig_in_config(KIT_HALL_SWITCH, pin);
    hall_switch_app_init(&app, pin);
}
void tearDown(void) {}

static void drive_active(bool on)
{
    /* ESP32 GPIO banks: GPIO_IN covers 0-31, GPIO_IN1 covers 32-39 */
    const bool high = (cfg.active == DIG_IN_ACTIVE_HIGH) ? on : !on;
    if (pin >= 32U) {
        const uint32_t bit = 1UL << (pin - 32U);
        if (high) GPIO_IN1 |= bit; else GPIO_IN1 &= ~bit;
    } else {
        const uint32_t bit = 1UL << pin;
        if (high) GPIO_IN |= bit; else GPIO_IN &= ~bit;
    }
}

static void settle(int ticks)
{
    int i;
    for (i = 0; i < ticks; i++) (void)hall_switch_app_step(&app);
}

static void test_init_is_clean(void)
{
    TEST_ASSERT_EQUAL_UINT32(0U, hall_switch_app_events(&app));
    if (pin < 32U) TEST_ASSERT_EQUAL_HEX32(0U, GPIO_ENABLE & (1UL << pin));
    else          TEST_ASSERT_EQUAL_HEX32(0U, GPIO_ENABLE1 & (1UL << (pin - 32U)));
}

static void test_one_activation_counts_once_even_when_held(void)
{
    drive_active(true);
    settle(12);
    TEST_ASSERT_EQUAL_UINT32(1U, hall_switch_app_events(&app));
    settle(20);   /* still held — must NOT recount */
    TEST_ASSERT_EQUAL_UINT32(1U, hall_switch_app_events(&app));
}

static void test_release_and_reactivation_counts_again(void)
{
    drive_active(true);
    settle(12);
    drive_active(false);
    settle(12);
    drive_active(true);
    settle(12);
    TEST_ASSERT_EQUAL_UINT32(2U, hall_switch_app_events(&app));
}

#ifndef UNIT_TEST_NO_MAIN
int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_init_is_clean);
    RUN_TEST(test_one_activation_counts_once_even_when_held);
    RUN_TEST(test_release_and_reactivation_counts_again);
    return UNITY_END();
}
#endif
