/* esp32_app.ld — RAM-resident application image for ESP32-D0WD.
 * .text in IRAM (0x40080000, 128K), .rodata/.data/.bss in DRAM
 * (0x3FFB0000 up). The bootloader copies segments per the image header,
 * so no .data copy loop is needed. */
ENTRY(call_start_cpu0)

MEMORY {
    IRAM(x)  : ORIGIN = 0x40080000, LENGTH = 128K
    DRAM(rw) : ORIGIN = 0x3FFB0000, LENGTH = 160K
}

SECTIONS {
    .text : {
        . = ALIGN(4);
        *(.literal*) *(.text*)
        . = ALIGN(4);
    } > IRAM

    .rodata : {
        . = ALIGN(4);
        *(.rodata*) *(.srodata*)
        . = ALIGN(4);
    } > DRAM

    .data : {
        . = ALIGN(4);
        *(.data*) *(.sdata*)
        . = ALIGN(4);
    } > DRAM

    .bss : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
        end = .;
        _end = .;
    } > DRAM
}
