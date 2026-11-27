# ESP32 flashing — complete layout

One-time per board (or when blank), then only the app line per project:

```
esptool.exe --chip esp32 --port COMx write_flash \
  0x1000  bootloader.bin \
  0x8000  partitions.bin \
  0x10000 build-target/NN_module-app.bin
```

- bootloader.bin / partitions.bin: prebuilt here (shared, board-level)
- NN_module-app.bin: per-project, from `cd projects/NN_module && make`
- RAM-resident app images: no flash-XIP config needed beyond dio/40m
