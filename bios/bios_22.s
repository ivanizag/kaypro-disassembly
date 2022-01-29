;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

io_00_serial_baud_rate:     EQU 0x00
io_1c_system_bits:          EQU 0x1c
system_bit_motors_neg:        EQU 6
system_bit_bank:              EQU 7


reset:                      EQU 0x0000
iobyte:                     EQU 0x0003
user_drive:                 EQU 0x0004
bdos_ep:                    EQU 0x0005
cpm_boot:                   EQU 0xe400
bdos_entrypoint:            EQU 0xec06
rom_stack:                  EQU 0xfc00
disk_DMA_address:           EQU 0xfc14 ; 2 bytes
ram_e407:                   EQU 0xe407
; See CP/M 2.2 System alteration guide appendix G
rw_type_directory_write:    EQU 1


; Info to reload CP/M from disk
; Like on the ROM, it only works with double density disks
logical_sector_size:                  EQU 128
double_density_sectors_per_track:     EQU 40
double_density_sectors_for_directory: EQU 16
boot_sectors:                         EQU 44
    ; On the actual CP/M 2.2 disks this number is higher
    ;   - 48 sectors on CPM 2.2f
    ;   - 55 sectors on CPM 2.2 SP or DE


ROM_INITDSK:   EQU 0x03
ROM_HOME:      EQU 0x0c
ROM_SELDSK:    EQU 0x0f
ROM_SETTRK:    EQU 0x12
ROM_SETSEC:    EQU 0x15
ROM_SETDMA:    EQU 0x18
ROM_READ:      EQU 0x1b
ROM_WRITE:     EQU 0x1e
ROM_SECTRAN:   EQU 0x21
ROM_KBDSTAT:   EQU 0x2a
ROM_KBDIN:     EQU 0x2d
ROM_SIOSTI:    EQU 0x33
ROM_SIOIN:     EQU 0x36
ROM_SIOOUT:    EQU 0x39
ROM_LISTST:    EQU 0x3c
ROM_LIST:      EQU 0x3f
ROM_SERSTO:    EQU 0x42
ROM_VIDOUT:    EQU 0x45

; IOBYTE Mappings:
;
; Bits      Bits 6,7    Bits 4,5    Bits 2,3    Bits 0,1
; Device    LIST        PUNCH       READER      CONSOLE
;
; Value
;   00      TTY:        TTY:        TTY:        TTY:
;   01      CRT:        PTP:        PTR:        CRT:
;   10      LPT:        UP1:        UR1:        BAT:
;   11      UL1:        UP2:        UR2:        UC1:
iobyte_console_mask:          EQU 0x03
iobyte_list_mask:             EQU 0xc0
iobyte_list_CRT:              EQU 0x40
iobyte_list_PRT:              EQU 0x80

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS ENTRY POINTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG 0fa00h
    JP BOOT
EP_WBOOT:
    JP WBOOT
    JP CONST
    JP CONIN
    JP CONOUT
    JP LIST
    JP PUNCH
    JP READER
    JP HOME
    JP SELDSK
    JP SETTRK
    JP SETSEC
    JP SETDMA
    JP READ
    JP WRITE
    JP LISTST
    JP SECTRAN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS CONFIGURATION
;
; Using CONFIG.COM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

iobyte_default:
    DB 81h ; Console to CRT and List to parallel port
bios_config:
    DB 00h
key_maps:
arrow_key_map: ; Mapping for the arrow keys
    DB 0Bh, 0Ah, 08h, 0Ch
keypad_map: ; Mapping for the keypad
    DB "0123"
    DB "4567"
    DB "89-,"
    DB "\r."
baud_rate_default:
    DB 05h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BOOT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BOOT:
    CALL INITDSK
    ; User 0, drive 0
    XOR A
    LD (user_drive), A
    ; Reset iobyte
    LD A, (iobyte_default)
    LD (iobyte), A
    ; Reset serial baud rate
    LD A, (baud_rate_default)
    OUT (io_00_serial_baud_rate), A
    CALL WRITE_STRING_INLINE
    DB 1Ah,"\r\nKAYPRO II 64k CP/M vers 2.2\r\n",0
BOOT_SILENT:
    LD A,0xc3 ; JP opcode
    ; Set the WBOOT jump at address 0
    LD HL, EP_WBOOT
    LD (reset), A
    LD (reset+1), HL
    ; Set BDOS entry point at address 5
    LD HL, bdos_entrypoint
    LD (bdos_ep), A
    LD (bdos_ep+1), HL
    ; Continue boot to CP/M
    LD A, (user_drive)
    LD C, A
    JP cpm_boot

WBOOT:
    CALL INITDSK
    CALL WRITE_STRING_INLINE
    DB "\r\nWarm Boot\r\n",0

WBOOT_SILENT:
    ; Reset the stack
    LD SP, 0x100
    ; Select drive 0, track 0
    LD C, 0x0
    CALL SELDSK
    LD BC, 0x0
    CALL SETTRK
    ; Set DMA address to where CP/M must be is
    LD HL, cpm_boot
    LD (disk_DMA_address), HL
    ; Read 44 sectors, start on sector 1
    LD BC, (boot_sectors * 256) + 1
WBOOT_LOOP:
    PUSH BC
    CALL SETSEC
    CALL READ
    POP BC
    ; Read error?
    OR A
    ; Yes, restart at track 0, sector 1
    JR NZ, WBOOT_SILENT
    ; No, increase DMA by 128 bytes for the next sector
    LD HL, (disk_DMA_address)
    LD DE, logical_sector_size
    ADD HL, DE
    LD (disk_DMA_address), HL
    ; Store 0 in e407. Why?
    XOR A
    LD (ram_e407), A
    ; Are we done?
    DEC B
    ; Yes, boot CP/M
    JP Z, BOOT_SILENT
    ; No, next sector
    INC C
    ; Are we past the last sector of track 0
    LD A, double_density_sectors_per_track
    CP C
    ; No, read the next sector
    JP NZ, WBOOT_LOOP
    ; Yes, track 0 completed. Continue with track 1
    ; Skip the 16 sectors used for the directory
    LD C, double_density_sectors_for_directory                                
    PUSH BC
    LD C, 0x1
    CALL SETTRK
    POP BC
    ; Read the next sector
    JR WBOOT_LOOP

CONST:
    ; Make sure the disk is off once every 256 calls
    LD HL, CONST_COUNTER
    INC (HL)
    CALL Z, DISKOFF
    ; What is the console assigned device?
    LD A, (iobyte)
    AND iobyte_console_mask
    LD L, ROM_SIOSTI
    ; It's the serial port, query the serial port
    JP Z, ROM_JUMP
    ; It's the CRT, query the keyboard
    LD L, ROM_KBDSTAT
    JP ROM_JUMP

CONIN:
    CALL DISKOFF
    ; What is the console assigned device?
    LD A, (iobyte)
    AND iobyte_console_mask
    LD L, ROM_SIOIN
    ; It's the TTY, query the serial port
    JP Z, ROM_JUMP
    ; It's the CRT, query the keyboard
    LD L, ROM_KBDIN
    CALL ROM_JUMP
    ; Process the keyboard output
    OR A
    ; If < 0x80, return it
    RET P
    ; Let's check the config to map the arrow keys and the numeric keypad
    ; The ROM returns 80-83 for the arrows and 84-91 for the keypad
    ; Apply the mapping
    AND 0x1f
    LD HL, key_maps
    LD C, A
    LD B, 0x0
    ADD HL, BC
    LD A, (HL)
    RET

DISKOFF:
    IN A, (io_1c_system_bits)
    SET system_bit_motors_neg, A
    OUT (io_1c_system_bits), A
    RET

CONOUT:
    ; What is the console assigned device?
    LD A, (iobyte)
    AND iobyte_console_mask
    LD L, ROM_SIOOUT
    ; It's the TTY, write to the serial port
    JP Z, ROM_JUMP
    ; It's the CRT, write to video memory
    LD L, ROM_VIDOUT
    JP ROM_JUMP

READER:
    ; Only the TTY is supported
    LD L, ROM_SIOIN
    JP ROM_JUMP

PUNCH:
    ; Only the TTY is supported
    LD L, ROM_SIOOUT
    JP ROM_JUMP

LIST:
    ; What is the list assigned device?
    LD A,(iobyte)
    AND iobyte_list_mask
    ; It's the TTY, write to the serial port
    LD L, ROM_SIOOUT
    JP Z, ROM_JUMP
    LD L, ROM_LIST
    CP iobyte_list_PRT
    ; It's the PRT, write to the parallel port
    JP Z, ROM_JUMP
    LD L, ROM_VIDOUT
    CP iobyte_list_CRT
    ; It's the CRT, write to video memory
    JP Z, ROM_JUMP
    LD L, ROM_SIOOUT
    ; It's the UL1, write to the serial port
    JP ROM_JUMP

LISTST:
    ; What is the list assigned device?
    LD A,(iobyte)
    AND iobyte_list_mask
    ; It's the TTY, query the serial port
    LD L, ROM_SERSTO
    JP Z, ROM_JUMP
    LD L, ROM_LISTST
    CP iobyte_list_PRT
    ; It's the PRT, write to the parallel port
    JP Z, ROM_JUMP
    ; It's the CRT or UL1, return always 0
    XOR A
    RET

INITDSK:
    LD L, ROM_INITDSK
    JR ROM_JUMP

HOME:
    LD L, ROM_HOME
    JR ROM_JUMP

SELDSK:
    LD L, ROM_SELDSK
    JR ROM_JUMP

SETTRK:
    LD L, ROM_SETTRK
    JR ROM_JUMP

SETSEC:
    LD L, ROM_SETSEC
    JR ROM_JUMP

SETDMA:
    LD L, ROM_SETDMA
    JR ROM_JUMP

READ:
    ; Reset the CONST counter
    XOR A
    LD (CONST_COUNTER), A
    ; Read
    LD L, ROM_READ
    JR ROM_JUMP

WRITE:
    ; Reset the CONST counter
    XOR A
    LD (CONST_COUNTER), A
    ; Write
    LD L,ROM_WRITE
    ; Is the bios_config 0?
    LD A,(bios_config)
    OR A
    ; Yes, write normally
    JR Z, ROM_JUMP
    ; No, force the write type
    LD C, rw_type_directory_write
    JR ROM_JUMP

SECTRAN:
    LD L, ROM_SECTRAN
    JR ROM_JUMP

ROM_JUMP:
    EXX
    ; Activate the ROM bank
    IN A, (io_1c_system_bits)
    SET system_bit_bank, A
    OUT (io_1c_system_bits), A
    ; Switch to the ROM stack
    LD (STACK_SAVE), SP
    LD SP, rom_stack
    ; Push the ROM cleanup code to RET there
    LD DE, ROM_JUMP_CLEANUP
    PUSH DE
    EXX
    ; Jump to the ROM address in L, page 0
    LD H,0x0
    JP (HL)

ROM_JUMP_CLEANUP:
    EX AF, AF' ;'
    ; Restore the stack
    LD SP, (STACK_SAVE)
    ; Deactivate the ROM bank
    IN A, (io_1c_system_bits)
    RES system_bit_bank, A
    OUT (io_1c_system_bits), A
    EX AF, AF' ; '
    ; Return to the caller
    RET

WRITE_STRING_INLINE:
    ; Retrieve the char at the return address in the stack
    EX (SP), HL
    LD A, (HL)
    ; Increase the return address
    INC HL
    EX (SP), HL
    ; Is the char a null?
    OR A
    ; Yes, return
    RET Z
    ; No, write it
    LD C, A
    CALL CONOUT
    ; Process the next char
    JR WRITE_STRING_INLINE

CONST_COUNTER:
    DB $04
STACK_SAVE:
    DW $EF35
FILLER:
    DS 14, $00
    DB $8E, $04, $8E, $04
    DB $03, $04, $88, $9C
    DB $C5, $04, $53, $FF
    DB $14, $05, $0F, $04
    DB $13, $06
    DW ROM_JUMP_CLEANUP ; not used

