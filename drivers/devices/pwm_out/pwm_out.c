/* pwm_out.c — ESP32 LEDC adaptation. The RP2040 original uses slices;
 * here channel ids are LEDC channels and one shared timer per frequency
 * group. buzzer retune = re-init the LEDC timer with the new frequency. */
#include "pwm_out.h"
#include "../../peripherals/ledc/esp_ledc.h"

pwm_out_status_t pwm_out_init_channel(pwm_out_channel_t *ch, uint8_t slice, uint8_t channel,
                                      uint32_t clk_hz, uint32_t frequency)
{
    esp_ledc_timer_config_t tcfg;
    if (ch == 0 || slice >= 4U || channel >= 16U) return PWM_OUT_STATUS_INVALID_CONFIG;
    tcfg.apb_hz = clk_hz;
    tcfg.frequency = frequency;
    tcfg.resolution_bits = 13U;
    if (esp_ledc_timer_init(slice, &tcfg) != ESP_LEDC_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    if (esp_ledc_channel_init(channel, slice) != ESP_LEDC_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    ch->slice = slice;      /* reinterpreted: slice = LEDC timer, channel = LEDC channel */
    ch->channel = channel;
    return PWM_OUT_STATUS_OK;
}

pwm_out_status_t pwm_out_set_permille(const pwm_out_channel_t *ch, uint32_t permille)
{
    if (ch == 0 || permille > 1000U) return PWM_OUT_STATUS_INVALID_PARAM;
    if (esp_ledc_set_duty(ch->channel, permille) != ESP_LEDC_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    return PWM_OUT_STATUS_OK;
}

pwm_out_status_t rgb_led_init(rgb_led_t *dev, uint8_t r_slice, uint8_t r_chan,
                              uint8_t g_slice, uint8_t g_chan,
                              uint8_t b_slice, uint8_t b_chan,
                              uint32_t clk_hz, uint32_t frequency)
{
    if (dev == 0) return PWM_OUT_STATUS_INVALID_CONFIG;
    if (pwm_out_init_channel(&dev->r, r_slice, r_chan, clk_hz, frequency) != PWM_OUT_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    if (pwm_out_init_channel(&dev->g, g_slice, g_chan, clk_hz, frequency) != PWM_OUT_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    if (pwm_out_init_channel(&dev->b, b_slice, b_chan, clk_hz, frequency) != PWM_OUT_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    return rgb_led_off(dev);
}

pwm_out_status_t rgb_led_set(rgb_led_t *dev, uint8_t red, uint8_t green, uint8_t blue)
{
    if (dev == 0) return PWM_OUT_STATUS_INVALID_CONFIG;
    pwm_out_set_permille(&dev->r, ((uint32_t)red * 1000UL) / 255UL);
    pwm_out_set_permille(&dev->g, ((uint32_t)green * 1000UL) / 255UL);
    pwm_out_set_permille(&dev->b, ((uint32_t)blue * 1000UL) / 255UL);
    return PWM_OUT_STATUS_OK;
}

pwm_out_status_t rgb_led_off(rgb_led_t *dev)
{
    return rgb_led_set(dev, 0U, 0U, 0U);
}

pwm_out_status_t buzzer_init(buzzer_t *dev, uint8_t slice, uint8_t channel, uint32_t clk_hz)
{
    pwm_out_channel_t tmp;
    if (dev == 0) return PWM_OUT_STATUS_INVALID_CONFIG;
    if (pwm_out_init_channel(&tmp, slice, channel, clk_hz, 2000UL) != PWM_OUT_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_CONFIG;
    dev->slice = slice;
    dev->channel = channel;
    dev->clk_hz = clk_hz;
    dev->sounding = false;
    esp_ledc_set_duty(channel, 0U);
    return PWM_OUT_STATUS_OK;
}

pwm_out_status_t buzzer_tone(buzzer_t *dev, uint32_t frequency)
{
    esp_ledc_timer_config_t tcfg;
    if (dev == 0 || frequency == 0U) return PWM_OUT_STATUS_INVALID_PARAM;
    tcfg.apb_hz = dev->clk_hz;
    tcfg.frequency = frequency;
    tcfg.resolution_bits = 13U;
    if (esp_ledc_timer_init((uint8_t)dev->slice, &tcfg) != ESP_LEDC_STATUS_OK)
        return PWM_OUT_STATUS_INVALID_PARAM;
    esp_ledc_set_duty((uint8_t)dev->channel, 500U);
    dev->sounding = true;
    return PWM_OUT_STATUS_OK;
}

pwm_out_status_t buzzer_off(buzzer_t *dev)
{
    if (dev == 0) return PWM_OUT_STATUS_INVALID_CONFIG;
    esp_ledc_set_duty((uint8_t)dev->channel, 0U);
    dev->sounding = false;
    return PWM_OUT_STATUS_OK;
}
