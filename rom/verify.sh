name=$(basename "$1" .s)
echo Verifying $name.s
z80asm -l$name.prn $name.s
z80dasm -a -l -t a.bin | tail -n+3 > source_assembled_and_disassembled
z80dasm -a -l -t $name.rom | tail -n+3 > original_disassembled
echo
diff a.bin $name.rom -s
diff original_disassembled source_assembled_and_disassembled -s