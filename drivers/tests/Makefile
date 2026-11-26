# Makefile — native gcc mirror of the Ceedling suite. No Ruby needed.
CC      := gcc
CFLAGS  := -Wall -Wextra -Werror -std=c99 -g -DUNIT_TEST_HOST
UNITY   := vendor/unity/unity.c
SUPPORT := unit/support/mock_sfr.c
INC     := -Ivendor/unity -Iunit/support -I..

MODULES := gpio uart spi i2c ledc
BINS    := $(MODULES:%=build/test_esp_%)

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
