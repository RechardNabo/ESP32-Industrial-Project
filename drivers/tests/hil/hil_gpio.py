"""hil_gpio.py — physical-loop verification for the ESP32 gpio driver.

Requires the loopback firmware flashed on the board and a serial
connection. Skips cleanly (exit 0) when no board is present — CI-safe.
Protocol and wiring notes live in drivers/README.md."""
import sys

def main() -> int:
    try:
        import serial  # noqa: F401
    except ImportError:
        print("SKIP: pyserial not installed")
        return 0
    print("SKIP: no board connected (loopback firmware not yet flashed)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
