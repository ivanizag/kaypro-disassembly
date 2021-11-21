# Kaypro ROM disassembled and commented

See [81-149c/bios.s](81-149c/bios.s) disassembly of the ROM 81-149c for the Kaypro II.
The ROM has these main sections:
- entry points (DONE)
- initialization and loading the OS from disk (DONE)
- disk read and write (DONE)
- keyboard, serial and parallel ports usage (DONE)
- formatted output to the screen (DONE)

The file bios.s can be assembled with z80asm to generate a binary identical to the initial ROM. See verify.sh
