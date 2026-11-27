# target.mk — shared ESP32 (ESP32-D0WD) target build for every module project.
# Produces build-target/$(PROJECT)-app.bin — flash at 0x10000 with esptool,
# alongside the shared bootloader (0x1000) and partition table (0x8000).
TCROOT  := C:/Users/rnabo/AppData/Local/Arduino15/packages/esp32/tools/esp-x32/2601/bin
CC      := "$(TCROOT)/xtensa-esp32-elf-gcc.exe"
ESPTOOL := C:/Users/rnabo/AppData/Local/Arduino15/packages/esp32/tools/esptool_py/5.3.1/esptool.exe

# DEPTH — relative path from the project dir back up to projects/
DEPTH   ?= ../
# ROOT — repo root; TGT — shared target infra dir
ROOT    := $(DEPTH)/..
TGT     := $(DEPTH)/target
CFLAGS  := -O1 -Wall -fno-common -g -mlongcalls \
           -I. -I$(TGT) -I$(ROOT)/drivers -I$(DEPTH)/lib
DEVSRC := $(ROOT)/drivers/devices/dig_in/dig_in.c $(ROOT)/drivers/devices/analog_in/analog_in.c \
          $(ROOT)/drivers/devices/dig_out/dig_out.c $(ROOT)/drivers/devices/pwm_out/pwm_out.c \
          $(ROOT)/drivers/devices/quad_enc/quad_enc.c $(ROOT)/drivers/devices/onewire/onewire.c \
          $(ROOT)/drivers/devices/kit/kit.c \
          $(ROOT)/drivers/peripherals/gpio/esp_gpio.c $(ROOT)/drivers/peripherals/adc/esp_adc.c \
          $(ROOT)/drivers/peripherals/ledc/esp_ledc.c $(ROOT)/drivers/peripherals/timer/esp_timer.c
LIBSRC := $(DEPTH)/lib/blink.c $(DEPTH)/lib/edge_count.c $(DEPTH)/lib/hysteresis.c \
          $(DEPTH)/lib/colorwheel.c $(DEPTH)/lib/sequencer.c $(DEPTH)/lib/peak_detect.c
BOOTSRC := $(TGT)/startup_esp32.c
TDIR    := build-target

all: $(TDIR)/$(PROJECT)-app.bin

$(TDIR):
	mkdir -p $(TDIR)

$(TDIR)/$(PROJECT).elf: main.c $(APP).c $(DEVSRC) $(LIBSRC) $(BOOTSRC) | $(TDIR)
	$(CC) $(CFLAGS) -o $@ main.c $(APP).c $(DEVSRC) $(LIBSRC) $(BOOTSRC) \
	      -T$(TGT)/esp32_app.ld -Wl,-Map=$(TDIR)/$(PROJECT).map -nostdlib -Wl,--gc-sections -lgcc

$(TDIR)/$(PROJECT)-app.bin: $(TDIR)/$(PROJECT).elf
	$(ESPTOOL) --chip esp32 elf2image --flash-mode dio --flash-freq 40m --flash-size 4MB -o $@ $<

clean:
	rm -rf $(TDIR)

.PHONY: all clean
