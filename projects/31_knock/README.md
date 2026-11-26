# 31 — Piezo Knock (ESP32)

Standalone firmware for kit module #31 from the 37-in-1 sensor kit.

## Wiring (ESP32 devkit)

| Module pin | ESP32 pin |
|---|---|
| VCC | 3V3 |
| GND | GND |
| signal | GPIO13=OUT |

> ESP32 GPIO are 3.3V native — 5V module outputs need a divider or
> 3.3V module Vcc. ADC inputs are ADC1 (GPIO32-39); pins 34-39 input-only.
> ESP32 ADC is noisy and nonlinear at the rails — the driver uses 11dB
> attenuation for full range; precision work belongs on the DS18B20.

## Behavior

Onboard LED mirrors the sensor state; edge events counted over UART.

## Verification

Physical stimulus toggles the LED and increments the count.

## Implementation

Device class driver in `drivers/devices/`; host-verified bit-exact in
`drivers/tests/` (80 tests). Composition in `main.c`.
