/* startup_esp32.c — minimal ESP32 app entry.
 * The second-stage bootloader has already configured flash cache and
 * copied all loadable segments to their final addresses; this entry
 * only zeroes .bss and calls main. Entry point is carried in the
 * image header produced by esptool elf2image. */
#include <stdint.h>

extern uint32_t __bss_start__, __bss_end__;
extern int main(void);

void call_start_cpu0(void)
{
    uint32_t *dst = &__bss_start__;
    while (dst < &__bss_end__) *dst++ = 0U;
    (void)main();
    for (;;) { }
}

/* esptool uses the ELF entry point — alias it */
void _start(void) __attribute__((alias("call_start_cpu0")));
