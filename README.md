# Kaypro ROM disassembled and commented

See [81-149c/bios.s](81-149c/bios.s) disassembly of the ROM 81-149c for the Kaypro II.
The ROM has these main sections:
- entry points
- initialization and loading the OS from disk
- disk read and write
- keyboard, serial and parallel ports usage
- formatted output to the screen

The file bios.s can be assembled with z80asm to generate a binary identical to the initial ROM. See verify.sh
