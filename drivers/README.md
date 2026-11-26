# ESP32 Classic Peripheral Driver Library

Register-level peripheral drivers for ESP32 classic (ESP32-WROOM-32 class
modules), host-verified bit-exact against a mock SFR layer. Same modular
architecture as the PIC32MX795/dsPIC30F6014 libraries in the sibling repos.

## Modules (27 host tests green — gcc mirror)

| Peripheral | Channels | Tests | What the tests pin down |
|---|---|---|---|
| GPIO (2 banks) | pins 0-39 | 6 | flash pins 6-11 rejected, input-only 34-39 rejected, W1TS/W1TC atomic set/clear, bank boundary at pin 32 |
| UART | 3 | 6 | fractional divisor (1/16 steps) — exact baud for any rate, FIFO count gating |
| SPI master | 2 | 5 | divider never overclocks, mode edge-bit encoding, instant-transfer completion model |
| I2C master | 2 | 4 | even low/high split, silicon minimum enforcement, minus-one registers |
| LEDC PWM | 16ch/4timers | 6 | the frequency x resolution interlock — impossible combinations rejected, fixed-point divider math |

## The ESP32-specific traps this library absorbs

1. **Pins 6-11 are the internal SPI flash** — driving them crashes the chip.
   The BSP layer makes them invalid at the boundary, not after the fact.
2. **Pins 34-39 have no output driver** — input-only enforcement is a
   distinct status code, not silent failure.
3. **UART has a fractional baud divisor** — unlike PIC/dsPIC integer-only
   dividers, ESP32 divides in 1/16 steps, making most baud rates exact.
   The driver computes in fixed point and still verifies error bounds.
4. **LEDC frequency x resolution interlock** — you cannot have high
   resolution AND high frequency: `cycles = APB/freq` must be >= 2^bits.
   Asking for both produces garbage on silicon; here it is a status code.
5. **I2C is command-sequence silicon** — not a shift-register peripheral
   like the PIC family. This layer owns clock + primitives; transaction
   composition belongs to the device driver layer.
6. **W1TS/W1TC atomic registers** — the correct idiom on a dual-core chip;
   no RMW races even when both cores touch GPIO.

## Test pyramid

- `tests/project.yml` — Ceedling canonical runner
- `tests/Makefile` — native gcc mirror, `make` runs the same suite
- `tests/hil/` — python physical verification (skips cleanly without board)

## Honest scope

- Host-verified only: target compilation with ESP-IDF toolchain headers
  not yet proven; HIL loopback firmware not yet written
- Register bit layouts follow the ESP32 TRM v4.x; the LEDC timer-conf
  layout in particular is documented as owed target verification
- Out of scope this pass: ADC (legacy atten/noise-plagued peripheral —
  recommended next), RMT, MCPWM, SDIO, TWAI/CAN
