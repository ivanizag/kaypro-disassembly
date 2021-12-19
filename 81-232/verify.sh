z80asm -lbios.prn bios.s
z80dasm -a -l -t a.bin | tail -n+3 > source_assembled_and_disassembled
z80dasm -a -l -t 81-232.rom | tail -n+3 > original_bios_disassembled
echo
diff a.bin 81-232.rom -s
diff original_bios_disassembled source_assembled_and_disassembled -s