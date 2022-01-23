;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CP/M BIOS for the KAYPRO CP/M 2.2 {SPv2.72}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

io_00_serial_baud_rate:     EQU 0x00
io_07_keyboard_control:     EQU 0x07
io_1c_system_bits:          EQU 0x1c
system_bit_motors_neg:        EQU 6
system_bit_bank:              EQU 7

reset:                      EQU 0x0000
iobyte:                     EQU 0x0003
user_drive:                 EQU 0x0004
bdos_ep:                    EQU 0x0005
cpm_boot:                   EQU 0xe000
cpm_warm_boot:              EQU 0xe003
bdos_entrypoint:            EQU 0xe806

sector_size:                EQU 128
sectors_per_track:          EQU 40
; See CP/M 2.2 System alteration guide appendix G
rw_type_directory_write:    EQU 1

; Values for PENDING_ACCENT
pending_accent_none:        EQU 0
pending_accent_acute:       EQU 1
pending_accent_diaeresis:   EQU 2

; Bits used on the BIOS_CONFIG
bios_config_1:              EQU 0
    ; 0: disk write mode as requested
    ; 1: disk writes to be "directory write"
bios_config_5:              EQU 5 ; Modified when using CAMBIO.COM
    ; 0: "caracteres españoles (EUR/USASCII)"
    ; 1: "caracteres europeos (E-ASCII)"
bios_config_6:              EQU 6 ; Modified when using CAMBIO8.COM: 7 or 8 bits mode
    ; 0: 7 bits mode
    ; 1: 8 bits mode
bios_config_7:              EQU 7
    ; 0: do the arrows and keypad mappings as set in CONFIG.COM
    ; 1: skip the arrows and keypad mappings

ROM_INITDSK:   EQU 0x03
ROM_HOME:      EQU 0x0c
ROM_SELDSK:    EQU 0x0f
ROM_SETTRK:    EQU 0x12
ROM_SETSEC:    EQU 0x15
ROM_SETDMA:    EQU 0x18
ROM_READ:      EQU 0x1b
ROM_WRITE:     EQU 0x1e
ROM_SECTRAN:   EQU 0x21
;ROM_KBDSTAT:   EQU 0x2a ; There is more complete code than in the ROM
ROM_KBDIN:     EQU 0x2d
ROM_SIOSTI:    EQU 0x33
ROM_SIOIN:     EQU 0x36
ROM_SIOOUT:    EQU 0x39
ROM_LISTST:    EQU 0x3c
ROM_LIST:      EQU 0x3f
ROM_SERSTO:    EQU 0x42
ROM_VIDOUT:    EQU 0x45

; IOBYTE CP/M mappings and Kaypro application
;
; Bits      Bits 6,7      Bits 4,5    Bits 2,3    Bits 0,1
; Device    LIST          PUNCH       READER      CONSOLE
; Value
;   00      TTY:Serial    TTY:Serial  TTY:Serial  TTY:Serial
;   01      CRT:Console   PTP:Serial  PTR:Serial  CRT:Console
;   10      LPT:Parallel  UP1:Serial  UR1:Serial  BAT:Console
;   11      UL1:Custom    UP2:Serial  UR2:Serial  UC1:Console
;
iobyte_console_mask:          EQU 0x03
iobyte_list_mask:             EQU 0xc0
iobyte_list_CRT:              EQU 0x40
iobyte_list_PRT:              EQU 0x80


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS ENTRY POINTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG 0f600h
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
; BIOS FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

READ:
    LD L, ROM_READ
READ_WRITE:
    ; Reset the CONST counter
    XOR A
    LD (CONST_COUNTER), A
    ; Read
    CALL ROM_JUMP
    ; Let's pool from the keyboard on disk usage
    ; Needed as on the Kaypro the keyboard doesn't generate interrupts
    JP POOL_KEYBOARD

WRITE:
    ; Write
    LD L,ROM_WRITE
    ; Check bios_config_1
    LD A,(bios_config)
    RRCA
    ; Is's false, write as requested
    JR NC, READ_WRITE
    ; It's true, force the write type
    LD C, rw_type_directory_write
    JR READ_WRITE

CONST:
    ; Make sure the disk is off once every 256 calls
    LD HL, CONST_COUNTER
    DEC (HL) ; TODO: review, was a INC
    CALL Z, DISKOFF
    ; What is the console assigned device?
    LD A, (iobyte)
    AND iobyte_console_mask
    LD L, ROM_SIOSTI
    ; It's the serial port, query the serial port
    JR Z,ROM_JUMP
    ; It's the CRT, query the keyboard
    CALL POOL_KEYBOARD
    ; Return the result
ERROR_CODE_INSTRUCTION:
    ; This is self modifying code, the error code
    ; is stored on the LD A, operand
    LD A,0x0 ; This 0x0 is changed elsewhere
    OR A
    RET

DISKOFF:
    IN A, (io_1c_system_bits)
    SET system_bit_motors_neg, A
    OUT (io_1c_system_bits), A
    RET

CONIN:
    CALL DISKOFF
CONIN_BLOCK:
    ; Wait until a character is ready
    CALL CONST
    JR Z, CONIN_BLOCK
    ; What is the console assigned device?
    LD A, (iobyte)
    AND iobyte_console_mask
    LD L, ROM_SIOIN
    ; It's the TTY, query the serial port
    JR Z, ROM_JUMP
    ; It's the CRT, query the keyboard
    ; Get the char on the buffer
    LD HL,(INPUT_BUFFER_GET_CURSOR)
    LD C,(HL)
    ; Increase the get cursor
    CALL NEXT_L
    LD (INPUT_BUFFER_GET_CURSOR),HL
    ; Get the error code from the insertion point on the buffer
    LD A,(INPUT_BUFFER_INSERT_CURSOR)
    ; Has the get cursor has reached the insert cursor?
    SUB L
    ; No, continue
    JR NZ, PROCESS_CHAR_IN_BUFFER
    ; Yes, store the error code thar is returned later
    LD (ERROR_CODE_INSTRUCTION+1),A
PROCESS_CHAR_IN_BUFFER:
    LD A,C
    ; Get bios_config_7
    LD HL,bios_config
    BIT bios_config_7,(HL)
    ; It's set, no more processing needed
    RET NZ
    ; It's clear
    OR A
    ; If < 0x80, return it
    RET P
    ; Let's check the config to map the arrow keys and the numeric keypad
    ; The ROM returns 80-83 for the arrows and 84-91 for the keypad
    ; Is the key < 0x92?
    CP 0x92
    ; No, return it
    RET NC
    ; Yes, apply the mapping
    AND 0x1f
    LD HL, key_maps
    LD C, A
    LD B, 0x0
    ADD HL, BC
    LD A, (HL)
    RET

READER:
    ; Only the TTY is supported
    LD L,ROM_SIOIN

ROM_JUMP:
    DI
    ; Activate the ROM bank
    IN A, (io_1c_system_bits)
    SET system_bit_bank, A
    OUT (io_1c_system_bits), A
    ; Switch to the ROM stack
    ; Note: the stack is not really changed. On other versions there
    ; is an LD SP, 0xfc00
    LD (STACK_SAVE), SP
    LD SP, STACK_SAVE
    ; Push the ROM cleanup code to RET there
    LD A,L
    LD HL,ROM_JUMP_CLEANUP
    PUSH HL
    LD L,A
    ; Jump to the ROM address in L, page 0
    LD H,0x0
    JP (HL)

LIST:
    ; What is the list assigned device?
    LD A,(iobyte)
    AND iobyte_list_mask
    ; It's the TTY, write to the serial port
    JP Z, OUT_SERIAL
    CP iobyte_list_PRT
    ; It's the PRT, write to the parallel port
    JP Z, OUT_LPT
    CP iobyte_list_CRT
    ; It's the CRT, write to video memory
    JP Z, OUT_CRT
    ; It's the UL1, use the user providded code
    JP OUT_UL1

LISTST:
    ; What is the list assigned device?
    LD A,(iobyte)
    AND iobyte_list_mask
    LD L,ROM_SERSTO
    ; It's the TTY, query the serial port
    JR Z,ROM_JUMP
    LD L,ROM_LISTST
    CP iobyte_list_PRT
    ; It's the PRT, query the parallel port
    JR Z,ROM_JUMP
    CP iobyte_list_CRT
    ; It's the CRT, return always 0xff
    LD A,0xff
    RET Z
    ; It's the UL1, use the user providded code
    JP STATUS_UL1

INITDSK:
    LD L, ROM_INITDSK
    JR ROM_JUMP

HOME:
    LD L, ROM_HOME
    JR ROM_JUMP

SETTRK:
    LD L, ROM_SETTRK
    JR ROM_JUMP

SETSEC:
    LD L, ROM_SETSEC
    JR ROM_JUMP

SELDSK:
    LD L, ROM_SELDSK
    JR ROM_JUMP

SETDMA:
    LD L, ROM_SETDMA
    JR ROM_JUMP

SECTRAN:
    LD L, ROM_SECTRAN
    JR ROM_JUMP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BOOT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BOOT:
    CALL INITDSK
    ; Reset the stack
    LD SP, 0x100
    ; Reset iobyte
    LD A,(iobyte_default)
    LD (iobyte),A
    ; Reset serial baud rate
    LD A, (baud_rate_default)
    OUT (io_00_serial_baud_rate), A
    CALL SETUP_ENTRYPOINTS
    ; Displat the welcome message
    CALL WRITE_STRING_INLINE
    DB 1Ah,"KAYPRO CP/M 2.2 {SPv2.72}\r\n",0
    LD HL, PRINTER_MESSAGE
    CALL WRITE_STRING_HL
    ; Select drive 0, track 0
    XOR A
    LD (user_drive),A
    ; Continue boot to CP/M
    LD C,A
    JP cpm_boot

WBOOT:
    ; Reset the stack
    LD SP, 0x100
    CALL INITDSK
    LD HL, bios_config
    ; Rest the bits 6 anf 7 of the bios config
    LD A, (HL)
    AND 0x3f
    LD (HL), A
    ; Select drive 0, track 0
    LD C,0x0
    CALL SELDSK
    LD BC, 0x0
    CALL SETTRK
    ; Set DMA address to where CP/M is
    LD BC, cpm_boot
    CALL SETDMA
    LD (DISK_DMA_ADDRESS),BC
    ; Read 44 sectors, start on sector 1
    LD BC, 0x2c01
WBOOT_LOOP:
    PUSH BC
    CALL SETSEC
    CALL READ
    POP BC
    ; Read error?
    OR A
    ; Yes, restart at track 0, sector 1
    JR NZ, WBOOT
    ; No, increase DMA by 128 bytes for the next sector
    PUSH BC
    LD HL, (DISK_DMA_ADDRESS)
    LD DE, sector_size
    ADD HL, DE
    LD (DISK_DMA_ADDRESS), HL
    PUSH HL
    POP BC
    CALL SETDMA
    POP BC
    ; Are we done?
    DEC B
    ; Yes, exec CP/M
    JP Z, WBOOT_SHOW_MESSAGE_LANGUAGE
    ; No, next sector
    INC C
    ; Are we past the last sector of track 0
    LD A, sectors_per_track
    CP C
    ; No, read the next sector
    JR NZ, WBOOT_LOOP
    ; Yes, go to track 1, sector 16
    LD C, 0x10
    PUSH BC
    LD C, 0x1
    CALL SETTRK
    POP BC
    ; Read the next sector
    JR WBOOT_LOOP

WBOOT_SHOW_MESSAGE_LANGUAGE:
    CALL SETUP_ENTRYPOINTS
    ; Select the message language
    LD A, (bios_config)
    BIT bios_config_5, A
    LD HL, WARM_BOOT_MESSAGE_ES
    JR NZ, WBOOT_SHOW_MESSAGE
    LD HL, WARM_BOOT_MESSAGE_US
WBOOT_SHOW_MESSAGE:
    CALL WRITE_STRING_HL
    ; Proceed with the CP/M warm boot
    LD A,(user_drive)
    LD C,A
    JP cpm_warm_boot

SETUP_ENTRYPOINTS:
    LD A,0xc3 ; JP opcode
    ; Set the WBOOT jump at address 0
    LD (reset), A
    LD HL, EP_WBOOT
    LD (reset+1), HL
    ; Set BDOS entry point at address 5
    LD (bdos_ep), A
    LD HL, bdos_entrypoint
    LD (bdos_ep+1), HL
    ; Reset any pending accent. Why 2 bytes?
    LD HL,0x0000
    LD (PENDING_ACCENT),HL
    RET

ROM_JUMP_CLEANUP:
    PUSH AF
    ; Deactivate the ROM bank
    IN A, (io_1c_system_bits)
    RES system_bit_bank, A
    OUT (io_1c_system_bits), A
    POP AF
    ; Restore the stack
    LD SP,(STACK_SAVE)
    EI
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSOLE OUTPUT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CONOUT:
    ; What is the console assigned device?
    LD A, (iobyte)
    AND iobyte_console_mask
    ; It's the TTY, write to the serial port (punch does that)
    JP Z,PUNCH
    ; If not use CRT

OUT_CRT:
    LD A, (bios_config)
    BIT bios_config_5, A
    ; If bit 5 is clear, ignore translations
    JR Z, OUT_CRT_FILTER
    LD A, C
    ; Last char was a escape
    LD HL, OUTPUT_ESCAPE_STATE
    BIT 0x7, (HL)
    ; Yes, process that
    JR NZ, OUT_HAD_ESCAPE
    ; Is the char a escape?
    CP 0x1b ; ESC
    ; Yes, store the escape
    JR Z,OUT_CRT_ESCAPE
    ; Are we processing an ESC=XY sequence?
    BIT 0x6,(HL)
    ; No, process the char
    JR Z, OUT_CRT_ESC_TRANSLATE
    ; Yes, continue processing the ESC=XY sequence
    ; Reduce one the pending sequence chars
    INC HL ; HL points to OUTPUT_ESCAPE_COUNT
    DEC (HL)
    DEC HL ; HL points back to OUTPUT_ESCAPE_STATE
    ; If the are more chars pendind, continue
    JR NZ, OUT_CRT_FILTER
    ; If not, reset the escape state and continue
    LD (HL),0x0
    JR OUT_CRT_FILTER

OUT_HAD_ESCAPE:
    ; Clear the escape flag
    RES 0x7,(HL)
    ; If ESC =, then process it
    CP '='
    JR Z,OUT_CRT_EQUAL
    ; Is ESC ESC?
    CP 0x1b ; ESC
    ; No, apply a possible char translation
    JR NZ,OUT_CRT_ESC_TRANSLATE
    ; Yes, ignore the second ESC

OUT_CRT_ESCAPE:
    ; Set the escape state
    LD (HL),0x80
    JR OUT_CRT_FILTER

OUT_CRT_EQUAL:
    ; Advance the escape state
    LD (HL),0x40
    ; Set 2 pending escape chars
    INC HL ; HL points to OUTPUT_ESCAPE_COUNT
    LD (HL), 0x2
    JR OUT_CRT_FILTER

OUT_CRT_ESC_TRANSLATE:
    ; ESC plus some symbols is translated to special chars
    LD HL, VIDEO_OUT_ESC_ORIG
    LD DE, VIDEO_OUT_ESC_DEST
    LD BC, 0x8
    CALL REPLACE_BYTE
    LD C, A

OUT_CRT_FILTER:
    ; Apply AND 0x9F to the chars >= 0x80, collapsing then
    ; on the 0x80 to 0x9F, that will be 0x00 to 0x1F for the
    ; character generator as it ignores the high bit
    LD A, C
    AND 0x9f
    JP P, FILTER_NON_PRINTABLE_CONTROL_CHARS
    LD C, A
FILTER_NON_PRINTABLE_CONTROL_CHARS:
    LD A, C
    ; Is the char a control char?
    CP 0x20
    ; No, output it
    JR NC, VIDOUT
    ; Yes, it is printable?
    PUSH BC
    LD HL, PRINTABLE_CONTROL_CHARS
    LD BC, 0xb
    CPIR
    POP BC
    ; No, do not output it
    RET NZ
    ; Yes, output it

VIDOUT:
    LD L,ROM_VIDOUT
    JP ROM_JUMP

PRINTABLE_CONTROL_CHARS:
    DB 0x07, 0x08, 0x0a, 0x0b
    DB 0x0c, 0x0d, 0x17, 0x18
    DB 0x1a, 0x1b, 0x1e

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; KKEYBOARD POLLING AND INPUT BUFFER
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
POOL_KEYBOARD:
    PUSH AF ; TODO: where is the POP AF?
KBDIN_CHECK:
    ; Query the keyboard status, bit 0 is 1 on key pending
    IN A, (io_07_keyboard_control)
    RRCA
    ; No key pending, we are done.
    JR NC, FINISH_POOL_KEYBOARD
    ; Set SIO register to WR1
    LD A, 0x1; WR1
    DI
    OUT (io_07_keyboard_control), A
    ; Query WR1
    IN A, (io_07_keyboard_control)
    EI
    AND 0x60
    ; If bit 6 and 5 are clear, get the key
    JR Z, KBDIN
    ; If not, send an error reset to keyboard
    ; control, beep and return
    LD A, 0x30 ; Error reset
    OUT (io_07_keyboard_control), A
    JR PLAY_BELL

KBDIN:
    LD L,ROM_KBDIN
    CALL ROM_JUMP
    OR A
    ; if the key is above 0x7f, we don't process it
    JP M, STORE_KEY_IN_BUFFER
    CALL PROCESS_KEY
    ; The key was invalid, beep and return
    JR C, PLAY_BELL
    ; They key was consumed, check for another
    JR Z, KBDIN_CHECK
STORE_KEY_IN_BUFFER:
    ; Store the key in the input buffer
    LD HL,(INPUT_BUFFER_INSERT_CURSOR)
    LD (HL),A
    ; Store that there is a key avaialable
    LD A,0xff
    LD (ERROR_CODE_INSTRUCTION+1),A
    ; Advance the insert cursor
    CALL NEXT_L
    ; Has the insert cursor reached the get cursor=
    LD A,(INPUT_BUFFER_GET_CURSOR)
    CP L
    ; Yes, the buffer is full, play bell and return
    JR Z,PLAY_BELL
    ; Store the increased cursor
    LD (INPUT_BUFFER_INSERT_CURSOR),HL
    ; Check for another key
    JR KBDIN_CHECK


PLAY_BELL:
    ; Seng a ^G to the keyboard
    LD C,0x7
    CALL OUT_CRT
FINISH_POOL_KEYBOARD:
    ; Counterpart of the PUSH AF at the start of POOL_KEYBOARD
    POP AF
    RET

NEXT_L:
    ; Increments L, when 0, go back to 0xa3
    INC L
    LD A,L
    OR A
    RET NZ
    LD L,0xa3
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ???
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PUNCH:
OUT_SERIAL:
    LD L, ROM_SIOOUT

OUT_EXTERNAL:
    LD A, C
    ; Is char >= 0xc0?
    SBC A, 0xc0
    ; No, continue
    JR C, TRANSLATE_LOW_CHAR
    ; Yes, translate the values chars from 0xc0 to 0xff
    ; Note that the tables onle have 0x20 values not 0x40
    PUSH HL
    LD HL, bios_config
    BIT bios_config_5, (HL)
    LD HL, PRINTER_OUT_HIGH_CHAR_ALT
    JR Z, ADD_OFFSET
    LD HL, PRINTER_OUT_HIGH_CHAR_ES
ADD_OFFSET:
    ; Apply the offset HL = HL + char - 0xc0
    ADD A, L
    LD L, A
    JR NC, GET_TRANSLATED_HIGH_CHAR
    INC H ; Carry on 16 bit addition
GET_TRANSLATED_HIGH_CHAR:
    LD C,(HL)
    LD A,C
    ; If translated char is 0xff, put a space
    INC A
    POP HL
    JR NZ, TRANSLATE_LOW_CHAR
    LD C, ' '
TRANSLATE_LOW_CHAR:
    LD A, (bios_config)
    BIT bios_config_5, A
    JP Z, ROM_JUMP
    LD A,C
    ; Is char <= 0x20
    CP 0x20
    ; No, output it
    JP C, ROM_JUMP
    ; Yes, translate the values chars from 0x20 to 0x7f
    PUSH HL
    LD HL, PRINTER_OUT_LOW_CHAR_TABLE - 0x20
    ; Apply the offset HL = HL + C
    LD A,L
    ADD A,C
    JR NC,GET_TRANSLATED_LOW_CHAR
    INC H ; Carry on 16 bit addition
GET_TRANSLATED_LOW_CHAR:
    LD L,A
    LD C,(HL)
    POP HL
    ; Output it
    JP ROM_JUMP

OUT_LPT:
    LD L, ROM_LIST
    JR OUT_EXTERNAL

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INPUT KEY PROCESSING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

REGISTER_ACUTE_ACCENT:
    LD A, pending_accent_acute
    JR REGISTER_PENDING_ACCENT
REGISTER_DIAERESIS_ACCENT:
    LD A, pending_accent_diaeresis
REGISTER_PENDING_ACCENT:
    LD HL, PENDING_ACCENT
    LD (HL), A
    ; Return 0, meaning that the key is consumed and another one is needed
    XOR A
    RET

PROCESS_KEY:
    ; Transform the key press to the corresponding character
    ; using the bios config for the keyboard layout selected.
    ; Carry is set for invalid keys.
    ;
    ; Check accent. Is there is one, store it and return 0.
    CP '['
    JR Z, REGISTER_ACUTE_ACCENT
    CP '{'
    JR Z, REGISTER_DIAERESIS_ACCENT
    PUSH AF
    ; Is there a pending accent?
    LD HL, PENDING_ACCENT
    LD A, (HL)
    AND pending_accent_acute+pending_accent_diaeresis
    ; Yes process the key adding accent
    JR NZ, HAD_PENDING_ACCENT
    ; No, continue
    POP AF
    ; Replace symbols (8 cases)
    LD HL,bios_config
    BIT bios_config_5, (HL)
    LD HL, LOOKUP_KEY_US
    LD BC,0x8
    LD DE, LOOKUP_KEY_ALT
    JR Z, REPLACE_KEY
    LD DE, LOOKUP_KEY_ES
REPLACE_KEY:
    CALL REPLACE_BYTE
    ; If a match is found, do not continue replacing
    JR Z, KEY_TRANSLATION_DONE
    ; Replace symbols (7 cases)
    LD HL, LOOKUP_KEY2_US
    LD DE, LOOKUP_KEY2_INTL
    LD BC, 0x7
    CALL REPLACE_BYTE
KEY_TRANSLATION_DONE:
    ; Reset the pending accent
    LD HL, PENDING_ACCENT
    LD (HL), pending_accent_none
    ; Copy the most sgnificant bit on the carry flag
    RLCA
    RRA
    ; Is the mode set to 7 or to 8 bits?
    LD HL, bios_config
    BIT bios_config_6, (HL)
    ; If valid (<=7f), make sure ff is marked as invalid. Not needed.
    JR NC, MARK_FF_AS_INVALID
    ; It's 7 bit mode, we are done all >80 are invalid
    RET Z
    ; It's 8 bit mode, only ff is invalid
MARK_FF_AS_INVALID:
    LD C,A
    INC C
    SCF
    ; If 0 (was ff) return as invalid (with the carry set)
    RET Z
    ; For the rest, crear the carry (the key is valid)
    CCF
    RET

HAD_PENDING_ACCENT:
    POP AF
    LD HL, bios_config
    BIT bios_config_5, (HL)
    LD HL, LOOKUP_ACCENT_SYMBOLS_US
    LD BC, 0xe
    LD DE, LOOKUP_ACCENT_SYMBOLS_ALT
    JR Z, REPLACE_ACCENT_SYMBOLS
    LD DE, LOOKUP_ACCENT_SYMBOLS_ES
REPLACE_ACCENT_SYMBOLS:
    CALL REPLACE_BYTE
    ; If a match is found, do not continue replacing
    JR Z,KEY_TRANSLATION_DONE
    ; Prepare acute or diaeresis accentuation
    LD HL, PENDING_ACCENT
    BIT 0x0,(HL)
    LD HL, VOWELS_NAKED
    LD BC, 0x5
    LD DE, VOWELS_ACUTE
    JR NZ, ADD_ACCENT_TO_VOCALS
    LD DE, VOWELS_DIAERESIS
ADD_ACCENT_TO_VOCALS:
    CALL REPLACE_BYTE
    JR Z, KEY_TRANSLATION_DONE
    ; If no match is found, it's an illegal key press
    LD A,0xff
    JR KEY_TRANSLATION_DONE

REPLACE_BYTE:
    ; Search the byte on the HL table
    PUSH BC
    CPIR
    POP HL
    ; If nothing found, return
    RET NZ
    ; Found, replace the byte
    INC BC
    OR  A
    SBC HL,BC
    ADD HL,DE
    XOR A
    LD A,(HL)
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WRITE STRINGS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WRITE_STRING_INLINE:
    ; Retrieve the string char at the return address in the stack
    EX (SP),HL
    CALL WRITE_STRING_HL
    ; Advance the return address past the string
    EX (SP),HL
    RET

WRITE_STRING_HL:
    LD A,(HL)
    ; Is the char a null?
    OR A
    ; Yes, return
    RET Z
    ; No, write it
    LD C,A
    PUSH HL
    CALL CONOUT
    POP HL
    ; Process the next char
    INC HL
    JR WRITE_STRING_HL

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VARIABLES AND CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Keyboard layout changes
LOOKUP_KEY_US:
    ; US keyboard layout
    DB "!@#]};:|" ; From the US keys: 1! 2@ 3# ]} ;: \|
LOOKUP_KEY_ES:
    ; Spanish keyboard layout
    DB "[]#",0xFF,0xFF,"|\\{"
LOOKUP_KEY_ALT:
    ; Alt keyboard layout
    DB 0xCF,0xDF,0xCB,"[]",0xC0,0xD0,0xDB
    ;  ¡    ¿    £     []  Ñ    ñ    º
LOOKUP_KEY2_US:
    ; US keyboard layout
    DB "/'\"<>?\\" ; From the US keys: /? \| '" ,< ->
LOOKUP_KEY2_INTL:
    ; International keyboard layout
    DB "';:?!\"/"

; Transformation of chars for printing
PRINTER_OUT_HIGH_CHAR_ALT:
    ; Translations of chars 0xc0 to 0xfd for TTY or LPT output
    DB "|aeiouaeiou#AOU["
    DB "\\aeiouaeiou{@}",0xFF,"]"
PRINTER_OUT_HIGH_CHAR_ES:
    ; Translations of chars 0xc0 to 0xfd for TTY or LPT output
    DB "naeiouaeiou",0xFF,"AOU",0xFF
    DB "Naeiouaeiou",0xFF,0xFF,"c",0xFF,0xFF

; Modified chars with accents on the international keyboards
LOOKUP_ACCENT_SYMBOLS_US:
    ; Key that can be modfied with an accent on the US keyboard layout
    DB "2@3#6^]}\\|,<.>"
LOOKUP_ACCENT_SYMBOLS_ALT:
    ; Modifed keys on the Alt keyboard layout
    DB "@@##",0xDD,0xDD,"{}\\|<<>>"
LOOKUP_ACCENT_SYMBOLS_ES:
    ; Modifed keys on the Spanish keyboard layout
    DB 0xFF,0xFF,0xFF,0xFF,"}}",0xFF,0xFF,0xFF,0xFF,"<<>>"

; Transformation of chars for display accorging to the
; codepage 1023 https://en.wikipedia.org/wiki/Code_page_1023
VIDEO_OUT_ESC_ORIG:
    DB "|#[\\{@}]"
VIDEO_OUT_ESC_DEST:
    DB 0xC0,0xCB,0xCF,0xD0,0xDB,0xDC,0xDD,0xDF
    ;  ñ    £    ¡    Ñ    º    §    ß    ¿

; Application of accents on keyboard input
VOWELS_ACUTE:
    ; Acute accentuation on vowels
    DB 0xC1,0xC2,0xC3,0xC4,0xC5
VOWELS_DIAERESIS:
    ; Grave accentuation on vowels
    DB 0xD6,0xD7,0xD8,0xD9,0xDA

WARM_BOOT_MESSAGE_US:
    DB "\r\nWarm Boot",0
WARM_BOOT_MESSAGE_ES:
    DB "\r\nReinicializaci",0xC4,"n de CP/M",0
CONST_COUNTER:
    DB 0x2D
VOWELS_NAKED:
    ; Base for vowel accentuation
    DB "aeiou"
OUTPUT_ESCAPE_STATE:
    ; Bit 7 true if prev was ESC
    ; Bit 6 true if prev was ESC=
    DB 0x00
OUTPUT_ESCAPE_COUNT:
    DB 0x00
PENDING_ACCENT:
    DB pending_accent_none
DISK_DMA_ADDRESS:
    DW 0x0000
INPUT_BUFFER_INSERT_CURSOR:
    DW INPUT_BUFFER
INPUT_BUFFER_GET_CURSOR:
    DW INPUT_BUFFER
FILLER:
    DB "armes Urlade" ; rest from the German version?
    DB 0x8E,0x04,0x8E,0x04,0x03,0x04,0x88,0x9C
    DB 0xC5,0x04,0x53,0xFF,0x14,0x05,0x0F,0x04
    DB 0x28,0x08,0x62,0xDF
STACK_SAVE:
    DW 0xEB3B
INPUT_BUFFER:
    DB 0x41,0x12,0x24,0x80,0x40,0x08,0x00,0x00
    DB 0xaa,0xAA,0xAA,0x00,0x00,0xAA,0x00,0x00
    DB 0x92,0x01,0x24,0x92,0x00,0x00,0x00,0x00
    DB 0x00,0x00,0x90,0x00,0x00,0x04,0x90,0x40
    DB 0x00,0x04,0x48,0x21,0x20,0x08,0x22,0x21
    DB 0x08,0x84,0x00,0x02,0x00,0x24,0x10,0x04
    DB 0x24,0x22,0x10,0x84,0x92,0x04,0x84,0x20
    DB 0x08,0x92,0x40,0x10,0x08,0x42,0x11,0x24
    DB 0x21,0x04,0x21,0x12,0x11,0x01,0x08,0x91
    DB 0x12,0x12,0x21,0x10,0x08,0x08,0x44,0x48
    DB 0x92,0x24,0x02,0x01,0x00,0x81,0x24,0x90
    DB 0x89,0x22,0x48,0x20,0x04

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PRINTER CONFIGURATION
; 128 bytes available at 0xfb00 for the printer message on startup
; and to remap the characters if needed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PRINTER_MESSAGE:
    DB "STANDARD PRINTER",0
PRINTER_MESSAGE_FILLER:
    DB 0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F
PRINTER_OUT_LOW_CHAR_TABLE:
    ; Translations of chars 0x20 to 0x7f for TTY or LPT output
    DB " !\"#$%&'()*+,-./0123456789:;<=>?"
    DB "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
    DB "`abcdefghijklmnopqrstuvwxyz{|}~",0x7F

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; USER LIST DEVICE
; 128 bytes available at 0xfb80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

OUT_UL1:
    ; Not implemented, 3 bytes available
    DS 3, 0x00
STATUS_UL1:
    ; Not implemented, 125 more bytes available
    DS 125, 0x00
