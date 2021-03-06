# Kaypro disassembled and commented

## Elements analysed

[ROMS](rom):

- [81-149c](rom/81-149c.s): `*    KAYPRO II    *` downloaded from [Retroarchive](http://www.retroarchive.org/maslin/disks/roms/index.html)
- [81-232](rom/81-232.s): `*     KAYPRO      *` dumped from my Kaypro, support for double side disks.
- [omni2](rom/omni2.s): `*     Omni  II    *` like the 81-232 with changes on the character handling. 

[CP/M BIOS](bios):

- [CP/M 2.2 F for ROM 81-149](bios/bios_22.s): `KAYPRO II 64k CP/M vers 2.2` From [kpii-149 in retroarchive](http://www.retroarchive.org/maslin/disks/kaypro/kpii-149.td0). Identical to CP/M 2.2 for ROM 81-232A (kpro-ii.td0).
- [CP/M 2.2 F for Kaypro IV](bios/bios_22f_IV.s): `KAYPRO IV 64k CP/M vers 2.2` From [K4836765 in retroarchive](http://www.retroarchive.org/maslin/disks/kaypro/k4836765.td0). It only changes a byte on the welcome string.
- [CP/M 2.2 Spanish for ROM 81-232](bios/bios_22sp.s): `KAYPRO CP/M 2.2 {SPv2.72}` From my collection. Has translated versions of the warm boot message and does the character translation for the Spanish keyboard
- [CP/M 2.2 German for ROM 81-232](bios/bios_22sp.s): `KAYPRO CP/M 2.2 {GMv2.72}` From [kayiiger in in z80.eu](http://www.z80.eu/downloads/KayIIger.zip). Has translated versions of the warm boot message and does the character translation for the German keyboard

[Executables](executables)

- [config.com 11-July-1982](executables/config_1982.s): for BIOS `KAYPRO II \r\n64k CP/M v 2.2`
- [config.com v1.1](executables/config_v1.1.s): for BIOS `KAYPRO II 64k CP/M vers 2.2`. Adds persistant baud rate changes
- [cambio.com](executables/cambio.s): Provided by the CP/M in Spanish to select how the BIOS behaves
- [cambio8.com](executables/cambio8.s): Provided by the CP/M in Spanish to select how the BIOS behaves

[Character generators](chars)

- 81-146a: Kapyro II/83, downloaded from [Retroarchive](http://www.retroarchive.org/maslin/disks/roms/index.html)
- 81-234: Kaypro II/83 International version, dumped from my Kaypro with Spanish keyboard. Replaces the Greek chars with the extra European latin chars
- Omni2: Omni II Logic Analyzer
- 81-187: Kaypro 10, higher resolution
- 81-235: Kaypro 2/84, higher resolution, identical to 81-187

![81-234 character generator](chars/81-234.png)



## References

- [Kaypro II Theory of Operation](documentation/Kaypro%20II%20Theory%20of%20Operation%201983.pdf)
- [CP/M 2.2 Alteration Guide](documentation/CPM_2.2_Alteration_Guide_1979.pdf)
- [FD179X-02 Datasheet](documentation/FD179X-02_Data_Sheet_May1980.pdf)
- [Zilog Z80-PIO Technical Manual](documentation/Zilog%20Z80-PIO%20Technical%20Manual.pdf)
- [Zilog Z80-SIO Technical Manual](documentation/Zilog%20Z80-SIO%20Technical%20Manual.pdf)

