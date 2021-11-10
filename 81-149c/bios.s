;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Analysis of the Kaypro II ROM
;
; Based on 81-149c.rom
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; I/O Ports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
io_04_serial_data:        EQU 0x04
io_05_keyboard_data:      EQU 0x05
io_06_serial_control:     EQU 0x06
io_07_keyboard_control:   EQU 0x07
io_08_parallel_data:      EQU 0x08
io_10_fdc_command_status: EQU 0x10
io_11_fdc_track:          EQU 0x11
io_12_fdc_sector:         EQU 0x12
io_13_fdc_data:           EQU 0x13
io_14_scroll_register:    EQU 0x14
io_1c_system_bits:        EQU 0x1c


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System bits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
system_bit_drive_a:               EQU 0
system_bit_drive_b:               EQU 1
system_bit_unused:                EQU 2
system_bit_centronicsReady:       EQU 3
system_bit_centronicsStrobe:      EQU 4
system_bit_double_density:        EQU 5
system_bit_motors:                EQU 6
system_bit_bank:                  EQU 7

system_bit_drive_a_mask:          EQU 0x01
system_bit_drive_b_mask:          EQU 0x02
system_bit_unused_mask:           EQU 0x04
system_bit_centronicsReady_mask:  EQU 0x08
system_bit_centronicsStrobe_mask: EQU 0x10
system_bit_double_density_mask:   EQU 0x20
system_bit_motors_mask:           EQU 0x40
system_bit_bank_mask:             EQU 0x80


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Console constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
address_vram:        EQU 0x3000
console_lines:       EQU 24
console_columns:     EQU 80
console_line_length: EQU 0x80                    ; There are 80 cols, but 128 bytes reserved for each line
console_line_mask:   EQU 0x7f

address_vram_end:                EQU address_vram + console_lines * console_line_length -1 ; 0x3bff
address_vram_start_of_last_line: EQU address_vram_end - console_line_length + 1            ; 0x3b80


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Disk constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
sectors_per_track: EQU 40                        ; pysical sectors. CP/M sees only 10 bigger sectors
sector_size:	   EQU 128                       ; physical sector size. Logical will be 512 for CP/M

RET_opcode:	       EQU 0xC9                      ; RET, used to set the NMI_ISR when the ROM is disabled


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The first boot sector has the info about
; the rest of the boot sector loadind
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
first_sector_load_address:     EQU 0xfa00
address_to_load_second_sector: EQU 0xfa02
address_to_exec_boot:          EQU 0xfa04
count_of_boot_sectors_needed:  EQU 0xfa06


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Disk related variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ram_fc00_disk_for_next_access:   EQU 0xfc00
ram_fc01_track_for_next_access:  EQU 0xfc01
ram_fc03_sector_for_next_access: EQU 0xfc03

ram_fc04_disk_xx:                EQU 0xfc04
ram_fc05_track_xx:               EQU 0xfc05
ram_fc07_sector_xx:              EQU 0xfc07

DAT_ram_fc08:                    EQU 0xfc08
DAT_ram_fc09:                    EQU 0xfc09
DAT_ram_fc0a:                    EQU 0xfc0a
DAT_ram_fc0b:                    EQU 0xfc0b
DAT_ram_fc0c:                    EQU 0xfc0c
DAT_ram_fc0d:                    EQU 0xfc0d
DAT_ram_fc0f:                    EQU 0xfc0f
DAT_ram_fc10:                    EQU 0xfc10
DAT_ram_fc11:                    EQU 0xfc11
DAT_ram_fc12:                    EQU 0xfc12
DAT_ram_fc13:                    EQU 0xfc13
ram_fc14_DMA_address:            EQU 0xfc14
DAT_ram_fc16:                    EQU 0xfc16
DAT_ram_fc17:                    EQU 0xfc17
DAT_ram_fc18:                    EQU 0xfc18
DAT_ram_fc19:                    EQU 0xfc19

mem_fe16_active_disk:            EQU 0xfe16
DAT_ram_fe17:                    EQU 0xfe17      ; Disk related flags?
mem_fe18_active_track:           EQU 0xfe18
mem_fe19_track:                  EQU 0xfe19


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Console related variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
console_esc_mode:            EQU 0xfe6c
console_esc_mode_clear:      EQU 0               ; No ESC pending
console_esc_mode_enabled:    EQU 1               ; Next char is the ESC command
console_esc_mode_arg_1:      EQU 2               ; Next char is the first arg of the = command
console_esc_mode_arg_2:      EQU 3               ; Next char is the second arg of the = command
console_esc_equal_first_arg:   EQU 0xfe6d          ; First arg of the esc= command
console_cursor_position:     EQU 0xfe6e          ; 2 bytes

; On greek mode, the char is converted to a control char that is printed as a greek letter
console_alphabet_mask:       EQU 0xfe70
console_alphabet_ascii_mask: EQU 0x7f
console_alphabet_greek_mask: EQU 0x1f


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Entry points of code relocated to upper RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disk_params_destination:    EQU 0xfe71
relocation_destination:     EQU 0xfecd
relocation_offset:          EQU 0xfecd - 0x04a8  ; relocation_destination - block_to_relocate_to_fecd
read_in_DMA_relocated:      EQU 0xfedc           ; reloc_read_in_DMA + relocation_offset
move_RAM_relocated:         EQU 0xfecd           ; reloc_move_RAM + relocation_offset
read_to_upper_relocated:    EQU 0xfee3           ; reloc_read_to_upper + relocation_offset
write_from_upper_relocated: EQU 0xfef4           ; reloc_write_from_upper + relocation_offset
write_to_DMA_relocated:     EQU 0xfeed           ; reloc_write_to_DMA + relocation_offset


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS ENTRY POINTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG	0h
    JP cold_boot
    JP init_upper_RAM
    JP init_screen
    JP init_ports
    JP fdc_restore_and_mem
    JP set_disk_for_next_access
    JP set_track_for_next_access
    JP set_sector_for_next_access
    JP set_DMA_address_for_next_access
    JP read_sector
    JP write_sector
    JP sector_translation
    JP turn_on_motor
    JP turn_off_motor
    JP is_key_pressed
    JP get_key
    JP keyboard_out
    JP is_serial_byte_ready
    JP get_byte_from_serial
    JP serial_out
    JP lpt_status
    JP lpt_output
    JP serial_get_control
    JP console_write_c
    JP wait_b


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INITIALIZATION AND BOOT FROM DISK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cold_boot:
    DI
    LD SP, 0xffff
    LD B, 0xa
    CALL wait_b
    CALL init_ports
    CALL init_screen
    CALL init_upper_RAM
    JR cold_boot_continue                        ; Avoid the NMI entry point at 0x0066
    DB 0x3D, 0, 0, 0, 0, 0, 0
nmi_isr:
    RET                                          ; Just return from the interrupts generated
                                                 ; by the floppy controller

cold_boot_continue:
    CALL console_write_string                    ; console_write_string gets the zero terminated
                                                 ; string after the CALL
    DB 1Bh,"=", 0x20 + 0xa, 0x20 + 0x1f          ; ESC code, move to line 10, column 31
    DB "*    KAYPRO II    *"
    DB 1Bh,"=", 0x20 + 0xd, 0x20 + 0x14          ; ESC code, move to line 13, column 20
    DB " Please place your diskette into Drive A"
    DB 0x8                                       ; Cursor
    DB 0                                         ; End NUL terminated string

    LD C,0x0
    CALL set_disk_for_next_access
    LD BC,0x0
    CALL set_track_for_next_access
    LD C,0x0
    CALL set_sector_for_next_access
    LD BC, first_sector_load_address
    CALL set_DMA_address_for_next_access
    CALL read_sector                             ; Read the first sector
    DI
    OR A
    JR NZ,error_bad_disk
    LD BC,(address_to_load_second_sector)        ; Use the info from the first sector to continue
    LD (ram_fc14_DMA_address),BC
    LD BC,(address_to_exec_boot)                 ; Store the boot exec addres on the stack. A RET will jump there
    PUSH BC
    LD BC,(count_of_boot_sectors_needed)
    LD B,C
    LD C,0x1                                     ; Continue reading from sector 1
read_another_boot_sector:
    PUSH BC                                      ; B has the count of sectors remaining
                                                 ; C has the current sector number
    CALL set_sector_for_next_access
    CALL read_sector
    DI
    POP BC
    OR A
    JR NZ,error_bad_disk
    LD HL,(ram_fc14_DMA_address)
    LD DE, sector_size
    ADD HL,DE                                    ; Increase by 128 the load address (sector size is 128 bytes)??
    LD (ram_fc14_DMA_address),HL
    DEC B
    RET Z                                        ; Done. Jump to the boot exec address previously pushed
    INC C
    LD A, sectors_per_track
    CP C                                         ; Check if we have to go to the next track
    JR NZ,read_another_boot_sector
    LD C,0x10                                    ; Track 0 completed. Continue with sector 1, track 10
    PUSH BC
    LD BC,0x0001                                 ; Sector 1
    CALL set_track_for_next_access
    POP BC
    JR read_another_boot_sector
error_bad_disk:
    CALL console_write_string
    DB "\n\r\n\r\aI cannot read your diskette.",0
    CALL turn_off_motor
wait_forever:
    JR wait_forever                              ; Lock the CPU

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COPY CODE AND DATA TO UPPER RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

disk_params:                                     ; This data will be copied to 0xfe71
init_data_drive_0:
    DB 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    DB 0x73, 0xFF, 0xA2, 0xFE, 0x1A, 0xFE, 0x2A, 0xFE
    DB 0x00
init_data_drive_1:
    DB 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    DB 0x73, 0xFF, 0xA2, 0xFE, 0x43, 0xFE, 0x53, 0xFE
    DB 0x00
init_data_rest:                                  ; Purpose?
    DB 0x12, 0x00, 0x03, 0x07, 0x00, 0x52, 0x00, 0x1F
    DB 0x00, 0x80, 0x00, 0x08, 0x00, 0x03, 0x00, 0x28
    DB 0x00, 0x03, 0x07, 0x00, 0xC2, 0x00, 0x3F, 0x00
    DB 0xF0, 0x00, 0x10, 0x00, 0x01, 0x00, 0x01, 0x06
    DB 0x0B, 0x10, 0x03, 0x08, 0x0D, 0x12, 0x05, 0x0A
    DB 0x0F, 0x02, 0x07, 0x0C, 0x11, 0x04, 0x09, 0x0E

init_upper_RAM:
    LD HL,block_to_relocate_to_fecd
    LD DE,relocation_destination
    LD BC,0x87
    LDIR

    LD HL, disk_params
    LD DE, disk_params_destination
    LD BC,0x52
    LDIR

    XOR A                                        ; Init some variables
    LD (DAT_ram_fc09),A
    LD (DAT_ram_fc0b),A
    LD A,0x0
    LD (DAT_ram_fe17),A
    LD A,0xff
    LD (mem_fe16_active_disk),A
    LD (mem_fe18_active_track),A
    LD (mem_fe19_track),A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set_disk_for_next_access:
    LD A,C
    LD (ram_fc00_disk_for_next_access),A
    JP fdc_set_disk
set_sector_for_next_access:
    LD A,C
    LD (ram_fc03_sector_for_next_access),A
    LD A,(DAT_ram_fe17)
    OR A
    JP NZ,fdc_set_sector_C
    RET
set_DMA_address_for_next_access:
    LD (ram_fc14_DMA_address),BC
    RET
set_track_for_next_access:
    LD (ram_fc01_track_for_next_access),BC
    LD A,(DAT_ram_fe17)
    OR A
    JP NZ,fdc_seek_track_C
    RET
fdc_restore_and_mem:
    LD A,(DAT_ram_fe17)
    OR A
    JP NZ,fdc_restore
    LD A,(DAT_ram_fc0a)
    OR A
    JP NZ,LAB_ram_01e9
    LD (DAT_ram_fc09),A
LAB_ram_01e9:
    JP fdc_restore

read_sector:
    LD A,(DAT_ram_fe17)
    OR A
    JP NZ,read_in_DMA_relocated
    XOR A
    LD (DAT_ram_fc0b),A
    LD A,0x1
    LD (DAT_ram_fc12),A
    LD (DAT_ram_fc11),A
    LD A,0x2
    LD (DAT_ram_fc13),A
    JP LAB_ram_0279
write_sector:
    LD A,(DAT_ram_fe17)
    OR A
    JP NZ,write_to_DMA_relocated
    XOR A
    LD (DAT_ram_fc12),A
    LD A,C
    LD (DAT_ram_fc13),A
    CP 0x2
    JP NZ,LAB_ram_0232
    LD A,0x8
    LD (DAT_ram_fc0b),A
    LD A,(ram_fc00_disk_for_next_access)
    LD (DAT_ram_fc0c),A
    LD HL,(ram_fc01_track_for_next_access)
    LD (DAT_ram_fc0d),HL
    LD A,(ram_fc03_sector_for_next_access)
    LD (DAT_ram_fc0f),A
LAB_ram_0232:
    LD A,(DAT_ram_fc0b)
    OR A
    JP Z,LAB_ram_0271
    DEC A
    LD (DAT_ram_fc0b),A
    LD A,(ram_fc00_disk_for_next_access)
    LD HL,0xfc0c
    CP (HL)
    JP NZ,LAB_ram_0271
    LD HL,0xfc0d
    CALL FUN_ram_0311
    JP NZ,LAB_ram_0271
    LD A,(ram_fc03_sector_for_next_access)
    LD HL,0xfc0f
    CP (HL)
    JP NZ,LAB_ram_0271
    INC (HL)
    LD A,(HL)
    CP 0x28
    JP C,LAB_ram_026a
    LD (HL),0x0
    LD HL,(DAT_ram_fc0d)
    INC HL
    LD (DAT_ram_fc0d),HL
LAB_ram_026a:
    XOR A
    LD (DAT_ram_fc11),A
    JP LAB_ram_0279
LAB_ram_0271:
    XOR A
    LD (DAT_ram_fc0b),A
    INC A
    LD (DAT_ram_fc11),A
LAB_ram_0279:
    XOR A
    LD (DAT_ram_fc10),A
    LD A,(ram_fc03_sector_for_next_access)
    OR A
    RRA
    OR A
    RRA
    LD (DAT_ram_fc08),A
    LD HL,0xfc09
    LD A,(HL)
    LD (HL),0x1
    OR A
    JP Z,LAB_ram_02b5
    LD A,(ram_fc00_disk_for_next_access)
    LD HL,0xfc04
    CP (HL)
    JP NZ,LAB_ram_02ae
    LD HL,0xfc05
    CALL FUN_ram_0311
    JP NZ,LAB_ram_02ae
    LD A,(DAT_ram_fc08)
    LD HL,0xfc07
    CP (HL)
    JP Z,LAB_ram_02d2
LAB_ram_02ae:
    LD A,(DAT_ram_fc0a)
    OR A
    CALL NZ,read_sector_yy
LAB_ram_02b5:
    LD A,(ram_fc00_disk_for_next_access)
    LD (ram_fc04_disk_xx),A
    LD HL,(ram_fc01_track_for_next_access)
    LD (ram_fc05_track_xx),HL
    LD A,(DAT_ram_fc08)
    LD (ram_fc07_sector_xx),A
    LD A,(DAT_ram_fc11)
    OR A
    CALL NZ,read_sector_xx
    XOR A
    LD (DAT_ram_fc0a),A
LAB_ram_02d2:
    LD A,(ram_fc03_sector_for_next_access)
    AND 0x3
    LD L,A
    LD H,0x0
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    LD DE,0xfc16
    ADD HL,DE
    LD DE,(ram_fc14_DMA_address)
    LD BC,0x80
    LD A,(DAT_ram_fc12)
    OR A
    JR NZ,LAB_ram_02f8
    LD A,0x1
    LD (DAT_ram_fc0a),A
    EX DE,HL
LAB_ram_02f8:
    CALL move_RAM_relocated
    LD A,(DAT_ram_fc13)
    CP 0x1
    LD A,(DAT_ram_fc10)
    RET NZ
    OR A
    RET NZ
    XOR A
    LD (DAT_ram_fc0a),A
    CALL read_sector_yy
    LD A,(DAT_ram_fc10)
    RET
FUN_ram_0311:
    EX DE,HL
    LD HL,0xfc01
    LD A,(DE)
    CP (HL)
    RET NZ
    INC DE
    INC HL
    LD A,(DE)
    CP (HL)
    RET
fdc_set_disk:
    LD HL,0x0
    LD A,C
    CP 0x2
    RET NC
    OR A
    LD HL,0xfe71
    JR Z,skip_for_disk_0
    LD HL,0xfe82
skip_for_disk_0:
    LD A,(mem_fe16_active_disk)
    CP C
    RET Z
    LD A,C
    LD (mem_fe16_active_disk),A
    OR A
    PUSH HL
    LD DE,0x10
    ADD HL,DE
    LD A,(HL)
    LD (DAT_ram_fe17),A
    LD HL,0xfe19
    JR Z,LAB_ram_0346
    DEC HL
LAB_ram_0346:
    LD A,(HL)
    CP 0xff
    JR Z,LAB_ram_034e
    IN A,(io_11_fdc_track)
    LD (HL),A
LAB_ram_034e:
    LD A,C
    OR A
    LD HL,0xfe18
    JR Z,LAB_ram_0356
    INC HL
LAB_ram_0356:
    LD A,(HL)
    OUT (io_11_fdc_track),A
    EX DE,HL
    POP HL
    CP 0xff
    RET NZ
    CALL fdc_ensure_ready
    CALL fdc_restore_and_mem
    ; Read address in single density
    IN A,(io_1c_system_bits)
    AND ~system_bit_double_density_mask          ; Disable double density
    OR 0x0
    OUT (io_1c_system_bits),A
    CALL fdc_read_address
    JR Z,local_read_address_ok
    ; Retry read address with double density
    IN A,(io_1c_system_bits)
    AND ~system_bit_double_density_mask
    OR system_bit_double_density_mask            ; Enable double density
    OUT (io_1c_system_bits),A
    CALL fdc_read_address
    RET NZ
    JR local_read_address_second_ok
local_read_address_ok:
    PUSH HL
    PUSH DE
    LD DE,0x0000
    LD (HL),E
    INC HL
    LD (HL),D
    LD DE,0x0009
    ADD HL,DE
    LD DE,0xfea2
    LD (HL),E
    INC HL
    LD (HL),D
    LD DE,0x0005
    ADD HL,DE
    LD A,0x0
    LD (HL),A
    LD (DAT_ram_fe17),A
    JR local_read_address_end
local_read_address_second_ok:
    PUSH HL
    PUSH DE
    LD DE,0xfeb1
    LD (HL),E
    INC HL
    LD (HL),D
    LD DE,0x0009
    ADD HL,DE
    LD DE,0xfe93
    LD (HL),E
    INC HL
    LD (HL),D
    LD DE,0x5
    ADD HL,DE
    LD A,0x20
    LD (HL),A
    LD (DAT_ram_fe17),A
local_read_address_end:
    POP DE
    POP HL
    IN A,(io_12_fdc_sector)
    OUT (io_11_fdc_track),A
    LD (DE),A
    RET
fdc_read_address:
    LD A,0xc4
    OUT (io_10_fdc_command_status),A
    CALL fdc_halt
    BIT 0x4,A
    RET
fdc_restore:
    CALL fdc_ensure_ready
    LD A,0x0
    OUT (io_10_fdc_command_status),A
    JR fdc_halt
fdc_seek_track_C:
    CALL fdc_ensure_ready
    LD A,C
    OUT (io_13_fdc_data),A
    LD A,0x10
    OUT (io_10_fdc_command_status),A
    JR fdc_halt
fdc_set_sector_C:
    LD A,C
    OUT (io_12_fdc_sector),A
    RET
sector_translation:
    LD A,D
    OR E
    LD H,B
    LD L,C
    RET Z
    EX DE,HL
    ADD HL,BC
    LD L,(HL)
    LD H,0x0
    RET
fdc_ensure_ready:
    PUSH HL
    PUSH DE
    PUSH BC
    LD A,0xd0
    OUT (io_10_fdc_command_status),A
    CALL turn_on_motor

    LD A,(mem_fe16_active_disk)
    LD E,A
    IN A,(io_1c_system_bits)
    AND ~(system_bit_drive_a_mask|system_bit_drive_b_mask) ; Clear drive select bits
    OR E
    INC A                                          ; disk A(0) to mask 0x1, disk B(1) to mask 0x2
    AND ~system_bit_double_density_mask            ; Disable double density
    LD HL,DAT_ram_fe17
    OR (HL)
    OUT (io_1c_system_bits),A
    POP BC
    POP DE
    POP HL
    RET

turn_on_motor:
    ; Is it already on?
    IN A,(io_1c_system_bits)
    BIT system_bit_motors,A
    ; Return if it is
    RET Z
    ; Turn on
    RES system_bit_motors,A
    OUT (io_1c_system_bits),A
    ; Wait for motor to get some speed
    LD B,0x32
    CALL wait_b
    RET

turn_off_motor:
    ; Turn off in any case
    IN A,(io_1c_system_bits)
    SET system_bit_motors,A
    OUT (io_1c_system_bits),A
    RET

wait_b:
    ; wait time in B
    LD DE,0x686
wait_b_inner_loop:
    DEC DE
    LD A,D
    OR E
    JP NZ,wait_b_inner_loop
    DJNZ wait_b                                  ; Do wait_b again with B-1
    RET

fdc_halt:
    ; The fdc generates a NMI when it requires attention. The NMI handler
    ; is just a RET that will stop the HALT and execute the next instruction.
    HALT
wait_while_busy:
    IN A,(io_10_fdc_command_status)
    BIT 0x0,A
    JR NZ,wait_while_busy
    RET

read_sector_yy:
    LD L,0x3
LAB_ram_043b:
    LD DE,0x040f
LAB_ram_043e:
    PUSH HL
    PUSH DE
    CALL go_to_track_sector
    CALL write_from_upper_relocated
    POP DE
    POP HL
    JR Z,LAB_ram_0457
    DEC E
    JR NZ,LAB_ram_043e
    DEC D
    JR Z,LAB_ram_046c
    CALL fdc_restore
    LD E,0xf
    JR LAB_ram_043e
LAB_ram_0457:
    LD B,0x0
    LD A,0x88
    OUT (io_10_fdc_command_status),A
LAB_ram_045d:
    HALT
    IN A,(io_13_fdc_data)
    DJNZ LAB_ram_045d
LAB_ram_0462:
    HALT
    IN A,(io_13_fdc_data)
    DJNZ LAB_ram_0462
    CALL fdc_halt
    AND 0x9c
LAB_ram_046c:
    LD (DAT_ram_fc10),A
    RET Z
    DEC L
    JR NZ,LAB_ram_043b
    LD A,0xff
    JR LAB_ram_046c
read_sector_xx:
    LD DE,0x40f
LAB_ram_047a:
    PUSH DE
    CALL go_to_track_sector
    CALL read_to_upper_relocated
    LD (DAT_ram_fc10),A
    POP DE
    RET Z
    DEC E
    JR NZ,LAB_ram_047a
    DEC D
    RET Z
    CALL fdc_restore
    LD E,0xf
    JR LAB_ram_047a
go_to_track_sector:
    LD A,(ram_fc04_disk_xx)
    LD C,A
    CALL fdc_set_disk
    LD BC,(ram_fc05_track_xx)
    CALL fdc_seek_track_C
    LD A,(ram_fc07_sector_xx)
    LD C,A
    CALL fdc_set_sector_C
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE RELOCATED TO UPPER RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

block_to_relocate_to_fecd:
reloc_move_RAM:
    ; Hide the ROM
    IN A,(io_1c_system_bits)
    RES system_bit_bank,A
    OUT (io_1c_system_bits),A
    ; Copy the bytes
    LDIR
    ; Show the ROM
    IN A,(io_1c_system_bits)
    SET system_bit_bank,A
    OUT (io_1c_system_bits),A
    RET
reloc_read_in_DMA:
    LD HL,(ram_fc14_DMA_address)
    LD B,0x1
    JR reloc_read_internal
reloc_read_to_upper:
    LD HL,0xfc16
    LD B,0x4
reloc_read_internal:
    LD DE,0x9c88
    JR reloc_RW_internal
reloc_write_to_DMA:
    LD HL,(ram_fc14_DMA_address)
    LD B,0x1
    JR reloc_write_internal
reloc_write_from_upper:
    LD HL,0xfc16
    LD B,0x4
reloc_write_internal:
    LD DE,0xfcac
reloc_RW_internal:
    CALL fdc_ensure_ready
    DI
    ; Hide the ROM
    IN A,(io_1c_system_bits)
    RES system_bit_bank,A
    OUT (io_1c_system_bits),A
    ; Setup RET as the handler of NMI
    ; as the ROM is paged out, there is no handler
    ; Store the previous value to restore it later
    PUSH HL
    LD HL, nmi_isr
    LD A,(HL)
    EX AF,AF'
    LD (HL), RET_opcode
    POP HL

    LD A,B
    LD BC, sector_size * 0x100 + io_13_fdc_data  ; Setup of the INI command
    BIT 0x0,A
    JR NZ,LAB_ram_04f4
    LD B,0x0
LAB_ram_04f4:
    CP 0x1
    PUSH AF
    LD A,E
    CP 0xac
    JR Z,reloc_write_sector
    OUT (io_10_fdc_command_status),A
    POP AF
    JR Z,reloc_read_second_half_of_sector
reloc_read_first_half_of_sector:
    HALT
    INI                                          ; IN from io_13_fdc_data
    JR NZ,reloc_read_first_half_of_sector
reloc_read_second_half_of_sector:
    HALT
    INI                                          ; IN from io_13_fdc_data
    JR NZ,reloc_read_second_half_of_sector
    JR read_sector_completed
reloc_write_sector:
    OUT (io_10_fdc_command_status),A
    POP AF
    JR Z,reloc_write_second_half_of_sector
reloc_write_first_half_of_sector:
    HALT
    OUTI                                         ; OUT to io_13_fdc_data
    JR NZ,reloc_write_first_half_of_sector
reloc_write_second_half_of_sector:
    HALT
    OUTI                                         ; OUT to io_13_fdc_data
    JR NZ,reloc_write_second_half_of_sector
read_sector_completed:
    ; Restore the byte that was on the NMI handler
    EX AF,AF'
    LD (nmi_isr),A
    ; Restore the ROM
    IN A,(io_1c_system_bits)
    SET system_bit_bank,A
    OUT (io_1c_system_bits),A
    EI
    ; Wait for the disk access result code
    CALL fdc_halt
    ; Return the result code: 0 or 1
    AND D
    RET Z
    LD A,0x1
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; IO PORTS INITIALIZATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


init_ports_count:
    DB 0x1C
init_ports_data:
    ; The first byte is the value to OUT on the port given by the second byte
    DW 0x1807
    DW 0x050C
    DW 0x0407
    DW 0x4407
    DW 0x0307
    DW 0xC107
    DW 0x0507
    DW 0xE807
    DW 0x0107
    DW 0x0007
    DW 0x1806
    DW 0x0500
    DW 0x0406
    DW 0x4406
    DW 0x0306
    DW 0xE106
    DW 0x0506
    DW 0xE806
    DW 0x0106
    DW 0x0006
    DW 0x031D
    DW 0x811C
    DW 0xCF1D
    DW 0x0C1D
    DW 0x0309
    DW 0x0F09
    DW 0x030B
    DW 0x4F0B
init_ports:
    LD HL,init_ports_count
    LD B,(HL)
init_port_loop:
    INC HL
    LD C,(HL)
    INC HL
    LD A,(HL)
    ; An out for each pair of bytes in init_ports_data
    OUT (C),A
    DJNZ init_port_loop
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; KEYBOARD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

is_key_pressed:
    ; return 0 or FF in A
    IN A,(io_07_keyboard_control)
    AND 0x1
    RET Z
    LD A,0xff
    RET

get_key:
    ; return char in A
    CALL is_key_pressed
    JR Z,get_key
    IN A,(io_05_keyboard_data)
    CALL translate_keyboard_in_a
    RET

keyboard_out:
    ; char in C. C=4 for the bell.
    IN A,(io_07_keyboard_control)
    AND 0x4
     ; Loop until a key is pressed
    JR Z,keyboard_out
    LD A,C
    OUT (io_05_keyboard_data),A
    RET

translate_keyboard_in_a:
    LD HL,translate_keyboard_keys
    LD BC,translate_keyboard_size
    CPIR
    ; Key not found, return the key not translated
    RET NZ
    ; Key found, replace with the corresponding char
    LD DE,translate_keyboard_keys
    OR A
    SBC HL,DE
    LD DE,translate_keyboard_values
    ADD HL,DE
    LD A,(HL)
    RET
translate_keyboard_size: EQU 0x13
translate_keyboard_keys:
    DB 0xF1, 0xF2, 0xF3, 0xF4, 0xB1, 0xC0, 0xC1, 0xC2
    DB 0xD0, 0xD1, 0xD2, 0xE1, 0xE2, 0xE3, 0xE4, 0xD3
    DB 0xC3, 0xB2 ; The 0xff from the values table is used as the last key
translate_keyboard_values:
    DB 0xFF, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86
    DB 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E
    DB 0x8F, 0x90, 0x91

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERIAL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

is_serial_byte_ready:
    ; return 0 or FF in A
    IN A,(io_06_serial_control)
    AND 0x1
    JR force_0_or_ff

get_byte_from_serial:
    ; return char in A
    CALL is_serial_byte_ready
    JR Z,get_byte_from_serial
    IN A,(io_04_serial_data)
    RET

serial_out:
    ; char in C
    IN A,(io_06_serial_control)
    AND 0x4
    ; Loop until a byte is ready
    JR Z,serial_out
    LD A,C
    OUT (io_04_serial_data),A
    RET
serial_get_control:
    IN A,(io_06_serial_control)
    AND 0x4
    JR force_0_or_ff

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PARALLEL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lpt_status:
    ; return 0 or FF in A
    IN A,(io_1c_system_bits)
    BIT system_bit_centronicsReady,A
force_0_or_ff:
    RET Z
    LD A,0xff
    RET
lpt_output:
    ; char in C
    ; Loop until the printer is ready
    CALL lpt_status
    JR Z,lpt_output
    ; Ouput the byte in C
    LD A,C
    OUT (io_08_parallel_data),A
    ; Pulse the strobe signal
    IN A,(io_1c_system_bits)
    SET system_bit_centronicsStrobe,A
    OUT (io_1c_system_bits),A
    RES system_bit_centronicsStrobe,A
    OUT (io_1c_system_bits),A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSOLE OUTPUT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_screen:
    ; Clear stored ESC command argument
    LD A, ' '
    LD (console_esc_equal_first_arg),A
    ; clear screen and put the cursor at the top left
    CALL console_clear_screen
    LD (console_cursor_position),HL
    ; Disable esc mode
    XOR A
    LD (console_esc_mode),A
    ; ??
    LD A,0x17
    OUT (io_14_scroll_register),A
    ; Set ASCII mode
    LD A,console_alphabet_ascii_mask
    LD (console_alphabet_mask),A
    RET

console_write_c:
    ; char in C
    ; Are we processing an escape sequence?
    LD A,(console_esc_mode)
    OR A ; Clear carry
    JP NZ,process_esc_command
    ; Is it a BELL?
    LD A,0x7 ; ^G BELL
    CP C
    JR NZ,console_write_c_cont
    ; BELL sends a 4 to the keyboard to beep
    LD C,0x4
    JP keyboard_out
console_write_c_cont:
    CALL remove_blink_and_get_cursor_position
    ; Push console_write_end to the stack to execute on any RET
    LD DE,console_write_end
    PUSH DE
    ; Test all special chars
    LD A,C
    CP 0xa
    JR Z,console_line_feed
    CP 0xd
    JP Z,console_carriage_return
    CP 0x8
    JR Z,console_backspace
    CP 0xc
    JR Z,console_right
    CP 0xb
    JR Z,console_up
    CP 0x1b
    JP Z,enable_esc_mode
    CP 0x18
    JP Z,console_erase_to_end_of_line
    CP 0x17
    JR Z,console_erase_to_end_of_screen
    CP 0x1a
    JR Z,console_clear_screen
    CP 0x1e
    JR Z,console_home_cursor
    CP 0x60
    JR C,LAB_ram_066a
    ; Apply the alphabet mask
    LD A,(console_alphabet_mask)
    AND C
LAB_ram_066a:
    ; Write the char at the cursor position
    LD (HL),A
    ; Advance the cursor
    INC HL
    LD A,L
    ; Return if we are not at the and of the line
    AND 0x7f
    CP console_columns
    RET C
    ; We are at the end of the line CR + LF
    CALL console_carriage_return
    JR console_line_feed

console_line_feed_cont:
    ; Let's check if the cursor is past the end of the screen
    LD DE, address_vram_end
    LD A,D
    CP H
    JR C,console_line_feed_scroll
    RET NZ
    LD A,E
    CP L
    RET NC

console_line_feed_scroll:
    ; We are at the end of the screen, scroll the screen
    ; Move all lines except the first up
    LD B, console_lines - 1
    ; Copy 80 chars from each line to the prev one
    ; Starting by the second line
    LD HL, address_vram + console_line_length
    LD DE, address_vram
console_line_feed_scroll_loop:
    PUSH BC
    ; Copy 80 chars
    LD BC, console_columns
    LDIR
    ; Skip the 128 - 80 chars not used
    LD BC,console_line_length - console_columns
    ADD HL,BC
    EX DE,HL
    ADD HL,BC
    EX DE,HL
    POP BC
    ; Repeat for each line
    DJNZ console_line_feed_scroll_loop
    ; Place the cursor at the bottom left
    LD HL, address_vram_start_of_last_line
    JR console_erase_to_end_of_line

console_line_feed:
    ; Advance the cursor to the next line
    LD DE, console_line_length
    ADD HL,DE
    ; Scroll up if needed
    JR console_line_feed_cont

console_backspace:
    LD A,L
    AND console_line_mask
    ; Ignore if we are already at the beginning of the line
    RET Z
    ; Move the cursor to the previous char
    DEC HL
    RET

console_right:
    LD A,L
    AND console_line_mask
    ; Ignore if we are already at the end of the line
    CP console_columns-1
    RET NC
    ; Move the cursor to the next char
    INC HL
    RET

console_up:
    PUSH HL
    ; Move one line up
    LD DE, -console_line_length
    ADD HL,DE
    PUSH HL
    ; Are we moved too far up?
    OR A ; Clear carry
    LD DE,address_vram
    SBC HL,DE
    POP HL ; Updated position
    POP DE ; Original position
    ; No, we re ok
    RET NC
    ; Yes, restore the original position
    EX DE,HL
    RET

console_clear_screen:
    ; Put a space at the beginning of the screen
    ; and for the rest of the screen, copy the previous char (a space)
    LD HL, address_vram
    LD DE, address_vram + 1
    LD BC, console_lines * console_line_length - 1
    LD (HL), ' '
    LDIR
    ; Set the cursor to the beginning of the screen
    LD HL,address_vram
    RET

console_home_cursor:
    ; Set the cursor to the beginning of the screen
    LD HL,address_vram
    RET

console_erase_to_end_of_screen:
    PUSH HL
    CALL console_erase_to_end_of_line
    LD DE, console_line_length
    ; Move cursor to the beggining of the current line
    LD A,L
    AND console_line_length
    LD L,A
    ; Move cursor the the next line
    ADD HL,DE
    ; Did we move past the end the the screen?
    LD A,0x3c ; MSB byte of the position past the end of the screen
    CP H
    ; If yes, restore cursor and return
    JR Z,console_restore_cursor_position
    ; Write spaces until the end of the screen
    ; Set in CB the count of spaces to write
    LD E,L
    LD D,H
    OR A ; Clear carry
    LD HL, address_vram_end
    SBC HL,DE
    LD C,L
    LD B,H
    ; Set DE as the next char
    LD H,D
    LD L,E
    INC DE
    ; Fill with spaces copying the previous char until the end of the screen
    LD (HL), ' '
    LDIR
console_restore_cursor_position:
    POP HL
    RET

console_erase_to_end_of_line:
    LD A,L
    AND console_line_mask
    ; Are we at the last position of the line?
    CP console_columns-1
    ; No
    JR C,console_erase_to_end_of_line_cont
    ; Yes, write a space and return
    LD (HL), ' '
    RET
console_erase_to_end_of_line_cont:
    PUSH HL
    PUSH HL
    ; Move to the start of the line
    LD A,L
    AND console_line_length
    LD L,A
    ; Move to the end of the line
    LD DE, console_columns - 1
    ADD HL,DE
    POP DE ; Original position
    PUSH DE
    ; Set CB to the count of spaces to write from cursor to the end of the line
    OR A ; Clear carry
    SBC HL,DE
    LD C,L
    LD B,H
    ; Set DE as the next char
    POP HL
    LD E,L
    LD D,H
    INC DE
    ; Fill with spaces copying the previous char until the end of the line
    LD (HL), ' '
    LDIR
    POP HL
    RET

remove_blink_and_get_cursor_position:
    ; Get the cursor position
    LD HL,(console_cursor_position)
    LD A,(HL)
    ; Is the char at the cursor a blinking '_'
    CP '_' + 0x80
    LD A, ' '
    ; No, continue
    JR NZ,remove_blink_and_get_cursor_position_cont
    ; Yes, put back a space
    LD (HL),A
remove_blink_and_get_cursor_position_cont:
    ; Remove the blink bit
    RES 0x7,(HL)
    RET

console_carriage_return:
    ; Set column to 0 by clearing the 7 LS bits on the cursor position
    LD A,L
    AND console_line_length
    LD L,A
    RET

enable_esc_mode:
    ; Enable esc mode, next char will be an ESC command
    LD A,console_esc_mode_enabled
    LD (console_esc_mode),A
    RET

process_esc_command:
    ; A has the esc mode
    ; C has the char to process
    ; Push the location of a RET on the stack. A RET will be another RET?
    LD HL,0x07a2
    PUSH HL
    ; Reset ESC mode
    LD HL,console_esc_mode
    LD (HL), console_esc_mode_clear
    ; Are we in a n ESC mode past ebaled?
    CP console_esc_mode_enabled
    ; Yes, process esc argument
    JR NZ,process_esc_arg_1
    ; No, process the command
    ; Load the char in A with the upper bit cleared (no blink)
    LD A,C
    RES 0x7,A
    CP 'G'
    JR Z, esc_set_greek_mode
    CP 'A'
    JR Z,esc_set_ascii_mode
    CP 'R'
    JR Z,esc_line_delete
    CP 'E'
    JR Z,esc_line_insert
    CP '='
    ;  Not a known ESC command, we ignore the char and return
    RET NZ
    ; Command is '=', we set that mode
    LD (HL),console_esc_mode_arg_1
    RET

process_esc_arg_1:
    ; Are we in an ESC mode past arg_1
    CP console_esc_mode_arg_1
    ; Yes
    JR NZ,process_esc_arg_2
    ; No, store the first argmument and return
    LD A,C
    LD (console_esc_equal_first_arg),A
    LD (HL),console_esc_mode_arg_2
    RET

process_esc_arg_2:
    ; Are we in an ESC mode past arg_2
    CP console_esc_mode_arg_2
    ; Yes, just return
    RET NZ
    CALL remove_blink_and_get_cursor_position
    POP HL
    ; Put the cursor at the top right corner
    LD HL,address_vram
    ; Second arg is column + 0x20
    LD A,C
    SUB 0x20
    ; Get the modulo 80
esc_arg_2_mod_80_loop:
    SUB console_columns
    JR NC,esc_arg_2_mod_80_loop
    ADD A,console_columns
    ; Advance to te arg_2 column
    LD L,A
    ; First arg is row + 0x20
    LD A,(console_esc_equal_first_arg)
    SUB 0x20
    ; Get the modulo 24
esc_arg_2_mod_24_loop:
    SUB console_lines
    JR NC,esc_arg_2_mod_24_loop
    ADD A,console_lines
    ; Advance to the arg_1 row by advancing a line per row
    LD DE,console_line_length
move_down_loop:
    JP Z,console_write_end
    ADD HL,DE
    DEC A
    JR move_down_loop

console_write_end:
    ; Finish the console_write and enable blink at the cursor position
    ; HL has the cursor position
    ; Get the char under the cursos
    LD A,(HL)
    ; If it is a space, we write a blinking '_'
    CP 0x20
    JR NZ, console_write_end_cont
    LD A,'_' + 0x80
console_write_end_cont:
    ; Set the upper bit of the char to blink
    SET 0x7,A
    LD (HL),A
    ; Store the cursor position
    LD (console_cursor_position),HL
    RET

esc_set_greek_mode:
    ; Store the mask for chars to write
    ; For greek chars, we map to 0 to 0x1f
    LD A,console_alphabet_greek_mask
    LD (console_alphabet_mask),A
    RET

esc_set_ascii_mode:
    ; Store the mask for chars to write
    ; For ASCII, we just remove the blink bit
    LD A,console_alphabet_ascii_mask
    LD (console_alphabet_mask),A
    RET

esc_line_delete:
    POP HL
    ; Prepare HL, DE, BC and the Z flag
    CALL esc_line_insert_or_delete_prepare
    PUSH DE
    ; Skip copy if there is nothing to copy
    JR Z,esc_line_delete_end
    LDIR
esc_line_delete_end:
    ; Delete the last line, it is always empty after a line delete
    LD HL, address_vram_start_of_last_line
    CALL console_erase_to_end_of_line
    ; Set the cursor to it's original position
    POP HL
    ; Done
    JR console_write_end

esc_line_insert:
    POP HL
    ; Prepare HL, DE, BC and the Z flag
    CALL esc_line_insert_or_delete_prepare
    PUSH DE
    ; Skip copy if there is nothing to copy
    JR Z,esc_line_insert_end
    ; Copy lines down up to the cursor line
    LD DE, address_vram_end
    LD HL, address_vram_start_of_last_line - 1
    LDDR
esc_line_insert_end:
    ; Delete the line as we insert a blank line
    POP HL
    PUSH HL
    CALL console_erase_to_end_of_line
    ; Set the cursor to the start of the line
    POP HL
    ; Done
    JR console_write_end

esc_line_insert_or_delete_prepare:
    CALL remove_blink_and_get_cursor_position
    CALL console_carriage_return
    PUSH HL
    EX DE,HL
    ; Position of the bottom left
    LD HL, address_vram_start_of_last_line
    ; Set BC to the count of bytes until the end of the screen minus one line
    OR A ; Clear carry
    SBC HL,DE
    LD B,H
    LD C,L
    ; Set HL to the start of the next line
    POP HL
    PUSH HL
    LD DE,console_line_length
    ADD HL,DE
    ; Set DE to the start of the current line
    POP DE
    ; Set Z flag if BC is zero. To be used later.
    LD A,B
    OR C
    ; Back to insert or delete line
    RET

console_write_string:
    ; Get return address from the stack
    EX (SP),HL
    ; Read the char pointed there
    LD A,(HL)
    ; Increment by one the return address in the stack
    INC HL
    EX (SP),HL
    ; If the char is a zero, we are done with the string and can
    ; return to the caller on the address past the string
    OR A
    RET Z
    ; Write the char and continue with the string
    LD C,A
    CALL console_write_c
    JR console_write_string

filler:
    DB 0xff, 0x00

