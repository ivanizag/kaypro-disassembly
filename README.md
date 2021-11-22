# Kaypro ROM disassembled and commented

See [81-149c/bios.s](81-149c/bios.s) disassembly of the ROM 81-149c for the Kaypro II.
The ROM has these main sections:
- entry points (DONE)
- initialization (DONE)
- loading the OS from disk (DONE)
- disk read and write (DONE)
- keyboard, serial and parallel ports usage (DONE)
- formatted output to the screen (DONE)

The file bios.s can be assembled with z80asm to generate a binary identical to the initial ROM. See verify.sh

## Entry points

They are very similar but not identical to the CP/M BIOS entrypoints. Probably the CP/M BIOS
entry points have to enable the ROM and not need to do much more that can the proper Kaypro BIOS
entry points.

The names have been taken from the KayPLUS manual.

## Initialization

On initialization the system is configured:
- the serial, keyboard, parallel and system bits are configured accessing
the ports of the Z80-SIO and Z80-PIO
- the screen is cleared, the cursor moved home, esc mode is terminated and greek alphabet is disabled
- the floppy disk variables are reset
- the disk parameter header and blocks and the single density translation table is moved to upper memory to be accessible by the CP/M BDOS when the ROM is paged out.
- routines to move blocks of memory or read and write block to or from disk is move to upper memory to be able to move, load and save blocks of RAM that share addresses with the ROM area 
- the welcome string is shown

After that, the disk can be booted

## Loading the OS from disk

To load the OS, the first sector 0 of track 0 of disk A is loaded. That sector has the
information of how many more sectors have to be read, where they have to be loaded and where to jump execution to start the OS.

## Floppy disk read and write

The entry points comply with the CP/M BIOS specification. Kaypro supports single
density (FM) and double density (MFM) disks. When a disk is selected, the ROM tries to
read in double density first; if this fails, it tries single density. It stores the
density for next use of the disk.

The code for single density is similar to the Appendix B of the CP/M 2.2 Alteration Guide

For double density, the ROM has to do sector blocking and deblocking with code similar to Appendix G of the CP/M 2.2 Alteration Guide

## Keyboard, serial and parallel usage

Basic entrypoint to input, output and status on the ports

## Formatted output

Code to output characters to the screen by writting to the video memory.
It does cursor management, process of control chars and escape sequences.

The control chars processed are: 0xa, 0xd, 0x8, 0xc, 0xb, 0x18, 0x17, 0x1a and 0x1e.
The escape commands processed are: G, A, R, E and =.

If greek mode is set (with ESC-G), lowercase characters are shown as greek letters.

## Memory map

```
- 0x0000-0x07ff: ROM

- 0xfa00-0xfa7f: First boot sector

- 0xfc00-0xfc15: Work variables for the floopy R/W
- 0xfc16-0xfe15: 512 bytes to buffer double density sectors
- 0xfe16-0xfe19: More work variables for the floopy R/W
- 0xfe1a-0xfe29: CSV_0 Scrathpad for change disk check, drive 0
- 0xfe2a-0xfe42: ALV_0 Scrathpad for BDOS disk allocation, drive 0
- 0xfe43-0xfe52: CSV_1 Scrathpad for change disk check, drive 1
- 0xfe53-0xfe6b: ALV_1 Scrathpad for BDOS disk allocation, drive 1
- 0xfe6c-0xfe70: Work variables for the console output
- 0xfe71-0xfe81: Drive A disk parameter header
- 0xfe82-0xfe92: Drive B disk parameter header
- 0xfe93-0xfea1: Single density disk parameter block 
- 0xfea2-0xfeb0: Double density disk parameter block 
- 0xfeb1-0xfecc: Single density sector translation table
- 0xfecd-0xff53: Disk R/W code relocated to upper memory
- 0xff54-0xff72: BLANK?
- 0xff73-0xfff3: Scratchpad for BDOS directory operations
```
