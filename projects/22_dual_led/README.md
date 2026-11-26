# 22 — Dual Red/Green LED (ESP32)

Standalone firmware for kit module #22 from the 37-in-1 sensor kit.

## Wiring (ESP32 devkit)

| Module pin | ESP32 pin |
|---|---|
| VCC | 3V3 |
| GND | GND |
| signal | GPIO25=red GPIO26=green |

> ESP32 GPIO are 3.3V native — 5V module outputs need a divider or
> 3.3V module Vcc. ADC inputs are ADC1 (GPIO32-39); pins 34-39 input-only.
> ESP32 ADC is noisy and nonlinear at the rails — the driver uses 11dB
> attenuation for full range; precision work belongs on the DS18B20.

## Behavior

Alternates red/green at 1Hz.

## Verification

Clean alternation, never both.

## Implementation

Device class driver in `drivers/devices/`; host-verified bit-exact in
`drivers/tests/` (80 tests). Composition in `main.c`.
