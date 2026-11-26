# 29 — LDR Light Sensor (ESP32)

Standalone firmware for kit module #29 from the 37-in-1 sensor kit.

## Wiring (ESP32 devkit)

| Module pin | ESP32 pin |
|---|---|
| VCC | 3V3 |
| GND | GND |
| signal | GPIO36=ADC1ch0 |

> ESP32 GPIO are 3.3V native — 5V module outputs need a divider or
> 3.3V module Vcc. ADC inputs are ADC1 (GPIO32-39); pins 34-39 input-only.
> ESP32 ADC is noisy and nonlinear at the rails — the driver uses 11dB
> attenuation for full range; precision work belongs on the DS18B20.

## Behavior

Reads the analog channel and reports scaled engineering units at 10Hz.

## Verification

Physical stimulus tracks the reported values.

## Implementation

Device class driver in `drivers/devices/`; host-verified bit-exact in
`drivers/tests/` (80 tests). Composition in `main.c`.
