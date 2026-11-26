# 03 — Laser Diode (ESP32)

Standalone firmware for kit module #3 from the 37-in-1 sensor kit.

## Wiring (ESP32 devkit)

| Module pin | ESP32 pin |
|---|---|
| VCC | 3V3 |
| GND | GND |
| signal | GPIO18=S |

> ESP32 GPIO are 3.3V native — 5V module outputs need a divider or
> 3.3V module Vcc. ADC inputs are ADC1 (GPIO32-39); pins 34-39 input-only.
> ESP32 ADC is noisy and nonlinear at the rails — the driver uses 11dB
> attenuation for full range; precision work belongs on the DS18B20.

## Behavior

Blinks the laser at 1Hz 50% duty.

## Verification

Laser dot visibly pulses.

## Implementation

Device class driver in `drivers/devices/`; host-verified bit-exact in
`drivers/tests/` (80 tests). Composition in `main.c`.
