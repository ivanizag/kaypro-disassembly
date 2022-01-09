z80asm -lcambio8.prn cambio8.s
z80dasm -a -l -t a.bin | tail -n+3 > source_assembled_and_disassembled
z80dasm -a -l -t cambio8.com | tail -n+3 > original_disassembled
echo
diff a.bin cambio8.com -s
diff original_disassembled source_assembled_and_disassembled -s