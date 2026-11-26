# Makefile — native gcc mirror of the Ceedling suite. No Ruby needed.
CC      := gcc
CFLAGS  := -Wall -Wextra -Werror -std=c99 -g -DUNIT_TEST_HOST
UNITY   := vendor/unity/unity.c
SUPPORT := unit/support/mock_sfr.c
INC     := -Ivendor/unity -Iunit/support -I..

MODULES := gpio uart spi i2c ledc
BINS    := $(MODULES:%=build/test_esp_%) build/test_adc build/test_timer build/test_dig_in build/test_analog_in build/test_dig_out build/test_pwm_out build/test_quad_enc build/test_onewire build/test_kit build/test_climate_station build/test_security_alarm

all: $(BINS) run

build:
	mkdir -p build

build/test_esp_gpio: unit/test_esp_gpio.c ../peripherals/gpio/esp_gpio.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $^

build/test_esp_uart: unit/test_esp_uart.c ../peripherals/uart/esp_uart.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $^

build/test_esp_spi: unit/test_esp_spi.c ../peripherals/spi/esp_spi.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $^

build/test_esp_i2c: unit/test_esp_i2c.c ../peripherals/i2c/esp_i2c.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $^

build/test_esp_ledc: unit/test_esp_ledc.c ../peripherals/ledc/esp_ledc.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $^


# device + app layer
DEVPERIPH := ../peripherals/gpio/esp_gpio.c ../peripherals/adc/esp_adc.c ../peripherals/ledc/esp_ledc.c ../peripherals/timer/esp_timer.c
DEVSRC := ../devices/dig_in/dig_in.c ../devices/analog_in/analog_in.c ../devices/dig_out/dig_out.c ../devices/pwm_out/pwm_out.c ../devices/quad_enc/quad_enc.c ../devices/onewire/onewire.c

build/test_adc: unit/test_adc.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../peripherals/adc/esp_adc.c $(UNITY) $(SUPPORT)

build/test_timer: unit/test_timer.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../peripherals/timer/esp_timer.c $(UNITY) $(SUPPORT)

build/test_dig_in: unit/test_dig_in.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/dig_in/dig_in.c ../peripherals/gpio/esp_gpio.c $(UNITY) $(SUPPORT)

build/test_analog_in: unit/test_analog_in.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/analog_in/analog_in.c ../peripherals/adc/esp_adc.c $(UNITY) $(SUPPORT)

build/test_dig_out: unit/test_dig_out.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/dig_out/dig_out.c ../peripherals/gpio/esp_gpio.c $(UNITY) $(SUPPORT)

build/test_pwm_out: unit/test_pwm_out.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/pwm_out/pwm_out.c ../peripherals/ledc/esp_ledc.c ../peripherals/timer/esp_timer.c $(UNITY) $(SUPPORT)

build/test_quad_enc: unit/test_quad_enc.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/quad_enc/quad_enc.c ../peripherals/gpio/esp_gpio.c $(UNITY) $(SUPPORT)

build/test_onewire: unit/test_onewire.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/onewire/onewire.c ../peripherals/gpio/esp_gpio.c ../peripherals/timer/esp_timer.c $(UNITY) $(SUPPORT)

build/test_kit: unit/test_kit.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../devices/kit/kit.c $(DEVSRC) $(DEVPERIPH) $(UNITY) $(SUPPORT)

build/test_climate_station: unit/test_climate_station.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../apps/climate_station/climate_station.c ../devices/kit/kit.c $(DEVSRC) $(DEVPERIPH) $(UNITY) $(SUPPORT)

build/test_security_alarm: unit/test_security_alarm.c $(UNITY) $(SUPPORT) | build
	$(CC) $(CFLAGS) $(INC) -o $@ $< ../apps/security_alarm/security_alarm.c $(UNITY) $(SUPPORT)

run: $(BINS)
	@total=0; fail=0; \
	for b in $(BINS); do \
		out=$$(./$$b); echo "$$out" | tail -1; \
		n=$$(echo "$$out" | grep -oE '^[0-9]+ Tests' | grep -oE '^[0-9]+'); \
		f=$$(echo "$$out" | grep -oE '[0-9]+ Failures' | grep -oE '^[0-9]+'); \
		total=$$((total+n)); fail=$$((fail+f)); \
	done; \
	echo "== mirror total: $$total tests, $$fail failures =="; \
	test $$fail -eq 0

clean:
	rm -rf build

.PHONY: all run clean
