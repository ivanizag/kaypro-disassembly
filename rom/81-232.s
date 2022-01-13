;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Analysis of the Kaypro II ROM
;
; Based on 81-232.rom
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; NOTES:
;
;   The code if similar to the 81-149c ROM with the following
; differences:
;   - The welcome message says "Kaypro" instead of "Kaypro II"
;   - Support for double sided doble density disks (DSDD)
;   - The code goes 144 bytes beyong the 2KB limit and needs a 4KB
; ROM. All the reamining spce is filled with FF.
;   - The PIO-2A bit 6 is configured as output.
;
;   To support the DSDD disks, a new disk parameter block. This
; block is not copied to upper RAM as the SSSD and SSDD blocks were.
; Instead the upper RAM copy of SSDD is replaced by the disk
; parameter block for DSDD when needed. Also, the previously unused
; system bit 2 is used to select single side or double side mode.
;
;   On the ROM 81.149c, the current track of both drives is stored
; on two variables. Also, the density detected for the current disk
; on each drive is stored as an aditional 16th byte of the disk
; parameter header. On this ROM, there is a need to store as well if
; the disk is double sided. Current track, density and sides are now
; stored per drive in the variables disk_active_info_drive_a and
; disk_active_info_drive_b. It is copied back an forth to
; disk_active_info as A: or B: is selected. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; I/O Ports
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
io_00_serial_baud_rate:     EQU 0x00
io_04_serial_data:          EQU 0x04
io_05_keyboard_data:        EQU 0x05
io_06_serial_control:       EQU 0x06
io_07_keyboard_control:     EQU 0x07
io_08_parallel_data:        EQU 0x08
io_09_parallel_control:     EQU 0x09
io_0b_parallel_b_control:   EQU 0x0b
io_0c_keyboad_baud_rate:    EQU 0x0c
io_10_fdc_status:           EQU 0x10 ; as IN it is a get status
io_10_fdc_command:          EQU 0x10 ; as OUT it is a command
io_11_fdc_track:            EQU 0x11
io_12_fdc_sector:           EQU 0x12
io_13_fdc_data:             EQU 0x13
io_14_scroll_register:      EQU 0x14
io_1c_system_bits:          EQU 0x1c
io_1d_system_bits_control:  EQU 0x1d


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System bits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
system_bit_drive_a:                 EQU 0
system_bit_drive_b:                 EQU 1
system_bit_side_2:                  EQU 2
system_bit_centronicsReady:         EQU 3
system_bit_centronicsStrobe:        EQU 4
system_bit_double_density_neg:      EQU 5
system_bit_motors_neg:              EQU 6
system_bit_bank:                    EQU 7

system_bit_drive_a_mask:            EQU 0x01
system_bit_drive_b_mask:            EQU 0x02
system_bit_side_2_mask:             EQU 0x04
system_bit_centronicsReady_mask:    EQU 0x08
system_bit_centronicsStrobe_mask:   EQU 0x10
system_bit_double_density_neg_mask: EQU 0x20
system_bit_motors_meg_mask:         EQU 0x40
system_bit_bank_mask:               EQU 0x80


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Console constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
address_vram:                    EQU 0x3000
console_lines:                   EQU 24
console_columns:                 EQU 80
console_line_length:             EQU 0x80 ; There are 80 cols, but 128 bytes reserved for each line
console_line_mask:               EQU 0x7f

address_vram_end:                EQU address_vram + console_lines * console_line_length -1 ; 0x3bff
address_vram_start_of_last_line: EQU address_vram_end - console_line_length + 1            ; 0x3b80


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Disk constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
logical_sector_size:                EQU 128 ; See NOTES
double_density_sector_size:         EQU 1024 ; See NOTES
sectors_per_track_double_density:   EQU 40 ; See NOTES
tracks_per_side:                    EQU 10 ; See NOTES
disk_count:                         EQU 2 ; 0 is A: and 1 is B:

fdc_command_restore:                EQU 0x00
fdc_command_read_address:           EQU 0xc4
fdc_command_seek:                   EQU 0x10
fdc_command_read_sector:            EQU 0x88
fdc_command_write_sector:           EQU 0xac
fdc_command_force_interrupt:        EQU 0xd0

rw_mode_single_density: EQU 1 ; We read or write 128 bytes directly to/from DMA
rw_mode_double_density: EQU 4 ; We read or write the full 512 bytes buffer

fdc_status_record_busy_bit:         EQU 0
fdc_status_record_not_found_bit:    EQU 4
fdc_status_read_error_bitmask:      EQU 0x9c ; Not ready, record not found, crc error or lost data
fdc_status_write_error_bitmask:     EQU 0xfc ; Not ready, write_protect, write fault, record not found, crc error or lost data

; RET, used to set the NMI_ISR when the ROM is disabled
RET_opcode:	       EQU 0xC9


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The first boot sector has the info about
; the rest of the boot sector loading
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
first_sector_load_address:     EQU 0xfa00
address_to_load_second_sector: EQU 0xfa02
address_to_exec_boot:          EQU 0xfa04
count_of_boot_sectors_needed:  EQU 0xfa06


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Disk related variables
; Sector address is given by the DTS (Drive, Track and Sector)
; For double density the sector is divided by 4 to account for 512
; bytes sector.
; See "Uninitialized RAM data areas" in Appendix G
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; DTS with the user requested data. Uses losgical sectors of 128 bytes
drive_selected:                 EQU 0xfc00
track_selected:                 EQU 0xfc01 ; 2 bytes
sector_selected:                EQU 0xfc03

; DTS as understood by the floppy disk controller. Sectors are 512 bytes
drive_in_fdc:                   EQU 0xfc04
track_in_fdc:                   EQU 0xfc05 ; 2 bytes
sector_in_fdc:                  EQU 0xfc07

dd_sector_selected:             EQU 0xfc08 ; the double density sector is sector_selected / 4
fdc_set_flag:                   EQU 0xfc09 ; 'hstact'
pending_write_flag:             EQU 0xfc0a ; 'hstwrt'

pending_count:                  EQU 0xfc0b
drive_unallocated:              EQU 0xfc0c
track_unallocated:              EQU 0xfc0d ; 2 bytes
sector_unallocated:             EQU 0xfc0f

rw_result:                      EQU 0xfc10

read_needed_flag:               EQU 0xfc11
read_not_needed:                EQU 0
read_needed:                    EQU 1

; See CP/M 2.2 System alteration guide appendix G
operation_type:                 EQU 0xfc12 ; 'readop' in appendix G
operation_type_write:           EQU 0
operation_type_read:            EQU 1

; See CP/M 2.2 System alteration guide, section 12 and appendix G
rw_type:                        EQU 0xfc13 ; 'wrtype' in appendix G
rw_type_normal_write:              EQU 0 ; write to allocated
rw_type_directory_write:           EQU 1
rw_type_read_or_unallocated_write: EQU 2 ; write to unallocated
disk_DMA_address:               EQU 0xfc14 ; 2 bytes

; There are 4 sector buffers. To select the buffer we get the sector modulo 4
sector_buffer_base:             EQU 0xfc16
sector_buffer_0:                EQU 0xfc16
sector_buffer_1:                EQU 0xfc16 + logical_sector_size
sector_buffer_2:                EQU 0xfc16 + logical_sector_size * 2
sector_buffer_3:                EQU 0xfc16 + logical_sector_size * 3

disk_active_drive:              EQU 0xfe16
; There are three bytes with the disk info: track, density, sides support
disk_active_info:               EQU 0xfe17
disk_active_info_undefined:     EQU 0xff
disk_active_track:              EQU disk_active_info + 0
disk_density:                   EQU disk_active_info + 1
disk_density_double:            EQU 0x00 ; FM encoding
disk_density_single:            EQU 0x20 ; MFM encoding
disk_active_has_sides:          EQU disk_active_info + 2
disk_active_has_sides_no:       EQU 0x00
disk_active_has_sides_yes:      EQU 0xff

; Copy of the disk info for the drive A: (3 bytes)
disk_active_info_drive_a:       EQU 0xfe1a ; 3 bytes copy of 0xfe17, 8 and 9
; Copy of the disk info for the drive B: (3 bytes)
disk_active_info_drive_b:       EQU 0xfe1d ; 3 bytes copy of 0xfe17, 8 and 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Console related variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
console_esc_mode:               EQU 0xfe74
console_esc_mode_clear:         EQU 0 ; No ESC pending
console_esc_mode_enabled:       EQU 1 ; Next char is the ESC command
console_esc_mode_arg_1:         EQU 2 ; Next char is the first arg of the = command
console_esc_mode_arg_2:         EQU 3 ; Next char is the second arg of the = command
console_esc_equal_first_arg:    EQU 0xfe75 ; First arg of the esc= command
console_cursor_position:        EQU 0xfe76 ; 2 bytes

; On greek mode, the char is converted to a control char that is printed as a greek letter
console_alphabet_mask:          EQU 0xfe78
console_alphabet_ascii_mask:    EQU 0x7f
console_alphabet_greek_mask:    EQU 0x1f


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Entry points of code relocated to upper RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disk_params_destination:        EQU 0xfe79
disk_parameter_header_0:        EQU 0xfe79
disk_parameter_header_1:        EQU 0xfe8a
disk_parameter_block_single_density:    EQU 0xfe9b
disk_parameter_block_double_density:    EQU 0xfeaa
disk_sector_translation_table:  EQU 0xfeb9
disk_parameter_block_size:      EQU 15
disk_read_address_buffer:       EQU 0xfecb
disk_read_address_sector:       EQU 0xfecd
disk_read_address_buffer_size:  EQU 6

relocation_destination:         EQU 0xfed1
relocation_offset:              EQU 0xfed1 - 0x03b   ; relocation_destination - block_to_relocate
read_single_density_relocated:  EQU 0xfee0           ; reloc_single_density + relocation_offset
move_RAM_relocated:             EQU 0xfed1           ; reloc_move_RAM + relocation_offset
read_to_buffer_relocated:       EQU 0xfee7           ; reloc_read_to_buffer + relocation_offset
write_from_buffer_relocated:    EQU 0xfef8           ; reloc_write_from_buffer + relocation_offset
write_single_density_relocated: EQU 0xfef1           ; reloc_write_single_density + relocation_offset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Other addresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CSV_0:      EQU 0xfe20 ; Scrathpad for change disk check, drive 0
ALV_0:      EQU 0xfe30 ; Scrathpad for BDOS disk allocation, drive 0
CSV_1:      EQU 0xfe4a ; Scrathpad for change disk check, drive 1
ALV_1:      EQU 0xfe5a ; Scrathpad for BDOS disk allocation, drive 1
DIRBUF:     EQU 0xff6d ; Address of a 128 byte scratchpad for BDOS dir ops


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS ENTRY POINTS
;
; Description of the entry points adapted from the KayPLUS manual.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG	0h
    ; COLD: Resets entire computer system and is ALMOST like
    ; pressing the RESET button.
    ; Corresponds to CP/M BIOS function BOOT
    JP EP_COLD

    ; INITDSK: Resets the disk input/output buffer status to empty.
    ; Any pending write is lost. Useful to perform a "soft" disk reset.
    JP EP_INITDSK

    ; INITVID: Resets the video system. Video hardware is configured
    ; and screen is cleared
    JP EP_INITVID

    ; INITDEV: Initializes tall I/O ports.
    JP EP_INITDEV

    ; HOME: Sets track number to 0
    ; Corresponds to CP/M BIOS function HOME
    JP EP_HOME

    ; SELDSK: Selects logical drive in register C (value of 0 through 1),
    ; corresponding to drives A or B). SELDSK determines what type of
    ; disk (density) is present in the drive.
    ; Corresponds to CP/M BIOS function SELDSK
    JP EP_SELDSK

    ; SETTRK: Sets the track number to the value in register BC. No seek
    ; is actually performed until a disk read/write occurs.
    ; Corresponds to CP/M BIOS function SETTRK
    JP EP_SETTRK

    ; SETSEC: Sets the logical sector number to the value in register C.
    ; Corresponds to CP/M BIOS function SETSEC
    JP EP_SETSEC

    ; SETDMA: Specifies the DMA address where disk read/write occurs in
    ; memory. The address in register pair BC is used until another DMA
    ; address is specified.
    ; Corresponds to CP/M BIOS function SETDMA
    JP EP_SETDMA

    ; READ: Reads the previously-specified logical sector from specified
    ; track and disk into memory at the DMA address. Note that on
    ; double-density disks and the hard drive, one physical sector may be
    ; composed of up to eight logical sectors, so a physical disk read
    ; may not actually occur. Returns disk status in A with zero
    ; indicating no error occurred and a non-zero value indicating an
    ; error.
    ; Corresponds to CP/M BIOS function READ
    JP EP_READ

    ; WRITE: Same as above, but writes from memory to disk.
    ; Corresponds to CP/M BIOS function WRITE
    JP EP_WRITE

    ; SECTRAN: Translates logical sector number to physical sector number
    ; Corresponds to CP/M BIOS function SECTRAN
    JP EP_SECTRAN

    ; DISKON: Turns on the disk drive.
    JP EP_DISKON

    ; DISKOFF: Turns off the disk drive.
    JP EP_DISKOFF

    ; KBDSTAT: Simply returns status of keyboard queue. Returns 0FFH if
    ; a key is available, or 00H otherwise.
    ; Corresponds to CP/M BIOS function CONST
    JP EP_KBDSTAT

    ; KBDIN: Gets character from keyboard buffer or waits for one, if
    ; none ready. 
    ; Corresponds to CP/M BIOS function CONIN
    JP EP_KBDIN

    ; KBDOUT: Sends the character in register A to the keyboard port.
    JP EP_KBDOUT

    ; SIOSTI: Returns status of SIO-B input port. Returns 00H if no
    ; character is ready, or 0FFH otherwise.
    JP EP_SIOSTI

    ; SIOIN: Gets character from SIO-B input port, or waits for one if
    ; none is ready.
    JP EP_SIOIN

    ; SIOOUT: Sends character to SIO-B output port.
    JP EP_SIOOUT

    ; LISTST: Returns the list status of the Centronics port: 00H is
    ; returned if the printer is busy, 0FFH if ready.
    JP EP_LISTST

    ; LIST: Sends the character in register C to the Centronics port.
    JP EP_LIST

    ; SERSTO: Returns status of SIO-B output port. Returns 0FFH if SIO-B
    ; is ready to accept a character for output, and 00H otherwise.
    JP EP_SERSTO

    ; VIDOUT: Sends character in register C to video screen. All characters
    ; 20H (blank) to 7FH are directly displayed and screen scroll is done,
    ; if required. Characters below 20H are defined as control characters.
    JP EP_VIDOUT

    ; DELAY: This entry point performs a "B times 10 mSec" delay. The
    ; 10 mSec delay is preset for 4 MHz. "B" is the value in the B-register
    ; and ranges from 1 to 256 decimal (0 is treated as 256).
    JP EP_DELAY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INITIALIZATION AND BOOT FROM DISK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_COLD:
    DI
    LD SP, 0xffff
    LD B, 0xa ; 100ms delay
    CALL EP_DELAY
    ; Init the system, io ports, screen and memory
    CALL EP_INITDEV
    CALL EP_INITVID
    CALL EP_INITDSK
    ; Avoid the NMI entry point at 0x0066
    JR EP_COLD_continue                        
    DB 0x3D, 0xC3, 0x3B, 0x2B, 0xAF, 0x32, 0x13

nmi_isr:
    ; Just return from the interrupts generated
    ; by the floppy controller
    RET

EP_COLD_continue:
    ; Show the wellcome message
    CALL console_write_string                    ; console_write_string uses the zero terminated
                                                 ; string after the CALL
    DB 1Bh,"=", 0x20 + 0xa, 0x20 + 0x1f          ; ESC code, move to line 10, column 31
    DB "*     KAYPRO      *"
    DB 1Bh,"=", 0x20 + 0xd, 0x20 + 0x14          ; ESC code, move to line 13, column 20
    DB " Please place your diskette into Drive A"
    DB 0x8                                       ; Cursor
    DB 0                                         ; End NUL terminated string

    ; Read the first sector of the boot disk
    LD C,0x0
    CALL EP_SELDSK
    LD BC,0x0
    CALL EP_SETTRK
    LD C,0x0
    CALL EP_SETSEC
    LD BC, first_sector_load_address
    CALL EP_SETDMA
    CALL EP_READ
    DI
    ; Verify the result
    OR A
    JR NZ, error_bad_disk
    ; Set the DMA destination as instructed by the info
    ; on the first boot sector
    LD BC, (address_to_load_second_sector)
    LD (disk_DMA_address), BC
    ; Store the boot exec addres on the stack. A RET will
    ; use this address and start executionthere
    LD BC, (address_to_exec_boot)
    PUSH BC
    ; Prepare the loading of the rest of the sectors
    LD BC, (count_of_boot_sectors_needed)
    LD B,C
    ; Continue reading from sector 1
    LD C,0x1
read_another_boot_sector:
    ; B has the count of sectors remaining
    ; C has the current sector number
    PUSH BC
    ; Load sector C
    CALL EP_SETSEC
    CALL EP_READ
    DI
    ; Verify the result
    POP BC
    OR A
    JR NZ, error_bad_disk
    ; Increase by 128 the load address (logical sector size is 128 bytes)
    LD HL, (disk_DMA_address)
    LD DE, logical_sector_size
    ADD HL,DE                                    
    LD (disk_DMA_address), HL
    ; Decrease the count of sectors remaining
    DEC B
    ; If done , jump to the boot exec address previously pushed to the stack
    RET Z
    ; Not finished, calculate the next sector and track
    INC C
    LD A, sectors_per_track_double_density
    ; Are we on the last sector of the track?
    CP C
    ; No, continue reading sector + 1
    JR NZ,read_another_boot_sector
    ; Yes, track 0 completed. Continue with track 1, sector 16
    LD C,0x10                                    
    PUSH BC
    ; Move to track 1
    LD BC,0x0001
    CALL EP_SETTRK
    POP BC
    ; Loop
    JR read_another_boot_sector

error_bad_disk:
    ; Error, write the error message and stop
    CALL console_write_string
    DB "\n\r\n\r\aI cannot read your diskette.",0
    CALL EP_DISKOFF
wait_forever:
    ; Lock the CPU forever
    JR wait_forever

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INIT DISK. COPY CODE AND DISK PARAMS TO UPPER RAM. RESET VARIABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; See CP/M 2.2 System alteration guide, section 10

; This data will be copied starting 0xfe79
disk_params:
init_disk_parameter_header_0: ; to 0xfe79
    DW 0x0000 ; XLT, logical translation table
    DW 0x0000, 0x0000, 0x0000 ; Scrathpad for BDOS
    DW DIRBUF ; Address of additional scratchpad for BDOS,
    DW disk_parameter_block_double_density ; DPB
    DW CSV_0
    DW ALV_0
    DB 0x00 ; Used by the BIOS to store the disk density

init_disk_parameter_header_1: ; to 0xfe8a
    DW 0x0000 ; XLT, logical translation table
    DW 0x0000, 0x0000, 0x0000 ; Scrathpad for BDOS
    DW DIRBUF ; Address of additional scratchpad for BDOS,
    DW disk_parameter_block_double_density ; DPB
    DW CSV_1
    DW ALV_1
    DB 0x00 ; Used by the BIOS to store the disk density

; Single density disk
;   18 sectors (of 128 bytes) per track
;   1024 bytes per allocation block
;   83 kb total disk space
;   40 tracks, 3 reserved
init_disk_parameter_block_single_density: ; to 0xfe9b
    DW 18   ; SPT, sectors per track
    DB 3    ; BSH, data alloc shift factor
    DB 7    ; BLM
    ; As BSH=3 and BLM=7, then BLS (data alocation size) is 1024.
    DB 0    ; EXM, extent mask
    DW 82   ; DSM, total storage in allocation blocks - 1
    DW 31   ; DRM, number of directory entries - 1
    DB 0x80 ; AL0
    DB 0x00 ; AL1
    DW 8    ; CKS, directory check vector size
    DW 3    ; OFF, number of reserved tracks

; Single density disk
;   40 sectors (128 bytes) per track
;   1024 bytes per allocation block
;   195 kb total disk space
;   40 tracks, 1 reserved
init_disk_parameter_block_double_density: ; to 0xfeaa
    DW 40   ; SPT, sectors per track
    DB 3    ; BSH, data alloc shift factor
    DB 7    ; BLM
    ; As BSH=3 and BLM=7, then BLS (data alocation size) is 1024.
    DB 0    ; EXM, extent mask
    DW 194  ; DSM, total storage in allocation blocks - 1
    DW 63   ; DRM, number of directory entries - 1
    DB 0xF0 ; AL0
    DB 0x00 ; AL1
    DW 16   ; CKS, directory check vector size
    DW 1    ; OFF, number of reserved tracks

init_sector_translation_table: ; 0xfeb9
    ; Only used for single density
    ; There is translation for 18 sectors.
    DB 1, 6, 11, 16, 3, 8, 13, 18
    DB 5, 10, 15, 2, 7, 12, 17, 4
    DB 9, 14
disk_params_end:

init_disk_parameter_block_double_density_double_side:
    DW 40   ; SPT, sectors per track 
    DB 4    ; BSH, data alloc shift factor 
    DB 15   ; BLM
    ; As BSH=4 and BLM=15, then BLS (data alocation size) is 2048.
    DB 1    ; EXM, extent mask 
    DW 196  ; DSM, total storage in allocation blocks - 1
    DW 63   ; DRM, number of directory entries - 1
    DB 0xC0 ; AL0
    DB 0x00 ; AL1 
    DW 16   ; CKS, directory check vector size
    DW 1    ; OFF, number of reserved tracks

EP_INITDSK:
    ; Copy relocatable disk access to upper RAM to
    ; be accessible even when the ROM is swapped out
    LD HL, block_to_relocate
    LD DE, relocation_destination
    LD BC, block_to_relocate_end - block_to_relocate ;0x87
    LDIR

    ; Copy the disk parameters to upper RAM
    LD HL, disk_params
    LD DE, disk_params_destination
    LD BC, disk_params_end - disk_params ;0x52
    LDIR

    ; Init some variables
    XOR A
    LD (fdc_set_flag), A ; = No
    LD (pending_count), A ; = 0
    LD A, disk_density_double
    LD (disk_density), A
    LD A, disk_active_info_undefined
    LD (disk_active_drive), A
    LD (disk_active_info_drive_a), A
    LD (disk_active_info_drive_b), A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK ENTRY POINTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_SELDSK:
    ; C: disk number
    LD A,C
    LD (drive_selected), A
    JP init_drive

EP_SETSEC:
    ; BC: sector number
    LD A,C
    LD (sector_selected), A
    ; Is the disk double density?
    LD A, (disk_density)
    OR A
    ; No, send the sector to the controller
    JP NZ, fdc_set_sector
    ; Yes, we just store the sector number
    RET

EP_SETDMA:
    ; BC: DMA address
    LD (disk_DMA_address), BC
    RET

EP_SETTRK:
    ; C: track number
    LD (track_selected), BC
    ; Is the disk double density?
    LD A, (disk_density)
    OR A
    ; No, send the track to the controller
    JP NZ, fdc_seek_track
    ; Yes, we just store the track number
    RET

EP_HOME:
    ;Is the disk double density?
    LD A, (disk_density)
    OR A
    ; No, go to track 0 and return
    JP NZ, fdc_seek_track_0
    ; Yes.
    ; Is a write pending?
    LD A,(pending_write_flag)
    OR A
    ; Yes, skip update
    JP NZ, skip_buffer_discard
    ; No, discard the buffer
    LD (fdc_set_flag),A ; = No
skip_buffer_discard:
    JP fdc_seek_track_0

EP_READ:
    ; Is disk double density?
    LD A,(disk_density)
    OR A
    ; No, go directly to the read routine
    JP NZ, read_single_density_relocated
    ; Yes, some preparation is needed as the calls to EP_SETSEC and
    ; EP_SETTRK did not send the info to the fdc for double density.
    ; Init variables
    XOR A
    LD (pending_count),A ; = 0
    ; Starting from here it is equal to read in Appendix G
    LD A, operation_type_read
    LD (operation_type), A; = operation_type_read
    LD (read_needed_flag), A ; = read_needed
    LD A, rw_type_read_or_unallocated_write
    LD (rw_type),A
    JP read_write_double_density

EP_WRITE:
    ; C indicates the rw_type
    ; Is disk double density?
    LD A,(disk_density)
    OR A
    ; No, go directly to the write routine
    JP NZ, write_single_density_relocated
    ; Yes, some preparation is needed as the calls to EP_SETSEC and
    ; set_track did not send the info to the fdc on double density.
    ; Starting from here it is equal to read in Appendix G
    XOR A
    LD (operation_type), A ; = operation_type_write
    LD A,C
    LD (rw_type),A ; = C
    CP rw_type_read_or_unallocated_write
    ; It's an allocated write, we can skip reset the
    ; unallocated params to check if a read is needed.
    JP NZ, write_check_read_needed
    LD A, double_density_sector_size / logical_sector_size ; 8
    LD (pending_count),A ; = 8
    ; Initialize the unallocated params
    LD A, (drive_selected)
    LD (drive_unallocated), A
    LD HL, (track_selected)
    LD (track_unallocated), HL
    LD A, (sector_selected)
    LD (sector_unallocated), A
write_check_read_needed:
    ; Do we have pending logical sectors?
    LD A,(pending_count)
    OR A
    ; No, skip
    JP Z, write_with_read_needed
    ; Yes, there are more unallocated records remaining
    DEC A
    LD (pending_count),A ; pending_count-1
    ; Is drive requested different to the unallocated?
    LD A, (drive_selected)
    LD HL, drive_unallocated
    CP (HL)
    ; Yes, the drive is different
    JP NZ, write_with_read_needed
    ; The drives are the same
    ; Is track requested different to the unallocated?
    LD HL, track_unallocated
    CALL is_track_equal_to_track_selected
    ; Yes, the track is different
    JP NZ, write_with_read_needed
    ; The tracks are the same
    ; Is sector requested different to the unallocated?
    LD A, (sector_selected)
    LD HL, sector_unallocated
    CP (HL)
    ; Yes, the sector is different
    JP NZ, write_with_read_needed
    ; The sectors are the same
    ; DTS on the unallocated variables match the requested DTS
    ; Advance to the next sector to check if the next write will
    ; be of the next sector.
    INC (HL)
    ; Are we at the end of the track?
    LD A,(HL)
    CP sectors_per_track_double_density
    ; No
    JP C, write_with_read_not_needed
    ; Yes, increase track and set sector to zero
    LD (HL),0x0
    LD HL, (track_unallocated)
    INC HL
    LD (track_unallocated),HL
write_with_read_not_needed:
    XOR A
    LD (read_needed_flag),A ; = read_not_needed
    JP read_write_double_density
write_with_read_needed:
    XOR A
    LD (pending_count),A ; = 0
    INC A
    LD (read_needed_flag),A ; = read_needed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK INTERNAL IMPLEMENTATION READ AND WRITE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
read_write_double_density:
    ; Reset the result variable
    XOR A
    LD (rw_result),A ; = 0
    ; Translate the sector logical address to the double density
    ; address. As sector in DD are four times the size of sector
    ; in SD, we divide by 4 (or shift right twice).
    ; Sure? Ono some places its 8 times ???
    LD A, (sector_selected)
    OR A ; Clear carry
    RRA ; /2
    OR A ; Clear carry
    RRA ; /2
    LD (dd_sector_selected),A ; sector_selected / 4
    ; Is fcd_position set
    LD HL, fdc_set_flag
    LD A,(HL)
    LD (HL),0x1 ; fdc_set_flag = Yes
    OR A
    ; No, continue after updating the DTS_in_fdc variables
    JP Z, rw_fdc_not_set
    ; Yes
    ; Are the fdc variables different from the selected?
    LD A,(drive_selected)
    LD HL, drive_in_fdc
    CP (HL)
    ; Yes, the drive is different
    JP NZ, rw_fdc_mismatch
    ; Is track requested different to the xx?
    LD HL, track_in_fdc
    CALL is_track_equal_to_track_selected
    ; Yes, the track is different
    JP NZ, rw_fdc_mismatch
    ; Is sector requested equals to the xx?
    LD A, (dd_sector_selected)
    LD HL, sector_in_fdc
    CP (HL)
    ; Yes, the sector is equal
    JP Z, rw_fdc_set
rw_fdc_mismatch:
    ; Is there a pending write on the buffer
    LD A, (pending_write_flag)
    OR A
    ; Yes, write the buffer before continuing
    CALL NZ, write_from_buffer_with_retries
    ; Now we can init the _in_fdc variables
rw_fdc_not_set:
    ; DTS_in_fdc = DTS_selected
    LD A, (drive_selected)
    LD (drive_in_fdc),A
    LD HL, (track_selected)
    LD (track_in_fdc),HL
    LD A,(dd_sector_selected)
    LD (sector_in_fdc),A
    ; Is a read needed
    LD A,(read_needed_flag)
    OR A
    ; Yes, read to fill the buffer
    CALL NZ, read_to_buffer_with_retries
    XOR A
    LD (pending_write_flag),A ; = no pending write
rw_fdc_set:
    ; Calculate the sector buffer to use for this sector   
    LD A, (sector_selected)
    AND 0x3 ; mod 4
    LD L,A
    LD H,0x0
    ADD HL,HL ; *2
    ADD HL,HL ; *2
    ADD HL,HL ; *2
    ADD HL,HL ; *2
    ADD HL,HL ; *2
    ADD HL,HL ; *2
    ADD HL,HL ; *2. Combined *128
    LD DE, sector_buffer_base
    ADD HL,DE
    ; HL = sector_buffer_base + (sector mod 4) * logical_sector_size
    LD DE,(disk_DMA_address)
    LD BC,logical_sector_size
    ;
    LD A,(operation_type)
    OR A
    ; Yes, it's a read, skip write related coe
    JR NZ, copy_block_to_or_from_buffer
    LD A,0x1
    LD (pending_write_flag),A ; = 1
    ; Reverse the block copy direction
    EX DE,HL
copy_block_to_or_from_buffer:
    ; Copy a sector from the buffer to the DMA
    CALL move_RAM_relocated
    LD A, (rw_type)
    CP rw_type_directory_write
    LD A, (rw_result)
    ; Return if it is a read or a normal write
    RET NZ
    OR A
    ; Return if last read/write had an error
    RET NZ
    ; It is a directory write. Le's not wait and
    ; save to disk now. (to be more reliable?)
    XOR A
    LD (pending_write_flag),A ; = 0
    CALL write_from_buffer_with_retries
    LD A,(rw_result)
    RET

is_track_equal_to_track_selected:
    ; HL = address to a variable with the track
    ; Returns flag Z set if they are equal.
    ; This is not inline as the drive and sector comparison because
    ; the track is two bytes.
    EX DE,HL
    LD HL, track_selected
    LD A,(DE) ; = track
    CP (HL)
    RET NZ
    INC DE
    INC HL
    LD A,(DE)
    CP (HL)
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK INTERNAL INIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_drive:
    ; Change current drive, update the disk info and check density
    ; C: drive number 
    LD HL,0x0
    LD A,C
    CP disk_count
    ; Ignore if the drive number is out of range
    RET NC
    ; Point HL to the disk info for disk A or B
    OR A
    LD HL, disk_parameter_header_0
    JR Z, disk_params_skip_for_drive_a
    LD HL, disk_parameter_header_1
disk_params_skip_for_drive_a:
    ; The current drive is the requested one?
    LD A,(disk_active_drive)
    CP C
    ; Yes, nothing to do
    RET Z
    ; No, change the drive
    ; Store the new drive number
    LD A,C
    LD (disk_active_drive),A
    OR A
    ; If the disk info for the drive is defined,
    ; restore that as the active info
    PUSH HL
    LD HL, disk_active_info
    LD DE, disk_active_info_drive_b
    JR Z, save_previous_disk_info
    LD DE, disk_active_info_drive_a
save_previous_disk_info:
    LD A, (DE)
    ; Is the active info undefined?
    CP disk_active_info_undefined
    ; Yes, no need to save the info
    JR Z, skip_save_disk_info
    PUSH BC
    ; Save the current disk info for the drive
    LD BC, 0x3
    LDIR
    POP BC
    LD DE, disk_active_info
skip_save_disk_info:
    ; C is the disk number
    LD A,C
    OR A
    ; Load active info for disk a or b
    LD HL, disk_active_info_drive_a
    JR Z, load_previous_info
    LD HL, disk_active_info_drive_b
load_previous_info:
    LD A,(HL)
    ; Is the stored info undefined?
    CP disk_active_info_undefined
    ; Yes, the info is not cached, we need to analyze the disk
    JR Z, analyze_inserted_disk
    ; Restore the disk info
    LD BC, 0x3
    LDIR
    ; Copy the required disk parameter block DDSD or DDDD
    LD BC, disk_parameter_block_size
    LD DE, disk_parameter_block_double_density
    LD HL, init_disk_parameter_block_double_density
    LD A, (disk_active_has_sides)
    OR A
    JR Z, skip_for_single_side
    LD HL, init_disk_parameter_block_double_density_double_side
skip_for_single_side:
    LDIR ; Copy the parameter block
    ; Restore the track position
    LD A, (disk_active_track)
    OUT (io_11_fdc_track), A
    POP HL
    RET

analyze_inserted_disk:
    POP HL
    ; Try reading as double density disk
    LD A, disk_density_double
    LD (disk_density), A
    CALL prepare_drive
    CALL EP_HOME
    CALL fdc_read_address
    ; If it reads the track, it is a double density disk
    JR Z, set_double_density_disk
    ; No, try reading as single density disk
    LD A, disk_density_single
    LD (disk_density), A
    CALL prepare_drive
    CALL fdc_read_address
    RET NZ ; Return if it fails as single and double density disk
    JR set_single_density_disk

set_double_density_disk:
    ; HL is disk_parameter_header
    PUSH HL
    PUSH DE
    ; Set no sector tran on the disk params $0 and $1
    LD DE,0x0000
    LD (HL),E
    INC HL
    LD (HL),D
    ; Set DPB for double density on the disk params $a and $b
    LD DE,0x0009
    ADD HL,DE
    LD DE, disk_parameter_block_double_density
    LD (HL),E
    INC HL
    LD (HL),D
    ; Select disk side 2, will be change to side 1 later.
    IN A,(io_1c_system_bits)
    OR system_bit_side_2_mask
    OUT (io_1c_system_bits),A
    ; Try reading on the side 2
    CALL fdc_read_address
    LD BC, disk_parameter_block_size
    LD DE, disk_parameter_block_double_density
    LD HL, init_disk_parameter_block_double_density
    LD A, disk_active_has_sides_no
    ; If it fails, side 2 is not readable we are for sure on a single side disk
    JR NZ, second_side_analysis_completed
    ; The previous fdc_read_address has not failed: there is valid
    ; info on the side 2. 
    ; We will see if the sector number to check if it is a single side disk
    ; reversed or if it is the side 2 of a double sided disk.
    ; As we have loaded the sector info, on the 3rd byte  we have the 
    ; sector number. On a second side the sector goes from 10 to 29.
    LD A, (disk_read_address_sector)
    ; Is the sector number less than 10?
    CP tracks_per_side
    LD A, disk_active_has_sides_no
    ; Yes it is less than 10, it's is not a two sided disk
    JR C, second_side_analysis_completed
    LD HL, init_disk_parameter_block_double_density_double_side
    LD A, disk_active_has_sides_yes
second_side_analysis_completed:
    ; Store the result of the side analyis
    LD (disk_active_has_sides), A
    ; Copy the disk param block required DDSD or DDDD
    LDIR
    ; Go back to side 1
    IN A,(io_1c_system_bits)
    AND ~system_bit_side_2_mask
    OUT (io_1c_system_bits),A
    JR finish_set_single_or_double_density_disk

set_single_density_disk:
    ; HL is disk_parameter_header
    PUSH HL
    PUSH DE
    ; Set the sector translation table on the disk params $0 and $1
    LD DE, disk_sector_translation_table
    LD (HL),E
    INC HL
    LD (HL),D
    ; Set the DPB on the disk params $a and $b
    LD DE,0x0009
    ADD HL,DE
    LD DE, disk_parameter_block_single_density
    LD (HL),E
    INC HL
    LD (HL),D

finish_set_single_or_double_density_disk:
    ; Copy 
    LD HL, disk_active_info
    LD DE, disk_active_info_drive_a
    LD A, (disk_active_drive)
    OR A
    JR Z, skip_for_drive_a_bis
    LD DE, disk_active_info_drive_b
skip_for_drive_a_bis:
    PUSH BC
    LD BC, 0x3
    LDIR
    POP BC
    POP DE
    POP HL
    RET

fdc_read_address:
    ; This is used to confirm that the disk is readable as configured
    ; for single or double density. 
    PUSH HL
    PUSH BC
    LD HL, disk_read_address_buffer
    LD BC, disk_read_address_buffer_size*0x100 + io_13_fdc_data
    LD A, fdc_command_read_address
    OUT (io_10_fdc_command), A
wait_for_data:
    HALT
    INI
    JR NZ, wait_for_data
    CALL wait_for_result
    ; Is record not found?
    BIT fdc_status_record_not_found_bit, A
    POP BC
    POP HL
    RET

fdc_seek_track_0:
    CALL prepare_drive
    ; Go to the first side of the disk
    IN A,(io_1c_system_bits)
    AND ~system_bit_side_2_mask
    OUT (io_1c_system_bits),A
    ; Set active track to 0
    XOR A
    LD (disk_active_track), A
    LD A, fdc_command_restore
    OUT (io_10_fdc_command), A
    JR wait_for_result

fdc_seek_track:
    ; C: track number
    CALL prepare_drive
    LD A, (disk_active_has_sides)
    OR A
    JR Z, skip_disk_side_change
    LD A , C
    RRA
    LD C, A
    IN A,(io_1c_system_bits)
    JR C, select_disk_side_2
    ; Selet disk side 1
    AND  ~system_bit_side_2_mask
    JR update_disk_side
select_disk_side_2:
    ; Select disk side 2
    OR system_bit_side_2_mask
update_disk_side:
    OUT (io_1c_system_bits),A
skip_disk_side_change:
    LD A, C
    LD (disk_active_track), A
    OUT (io_13_fdc_data),A
    LD A, fdc_command_seek
    OUT (io_10_fdc_command),A
    JR wait_for_result

fdc_set_sector:
    ; C = sector
    IN A,(io_1c_system_bits)
    BIT system_bit_side_2, A
    LD A,C
    JR Z, skip_for_side_1
    ADD A, tracks_per_side ; For tracks on the other side of the disk we add 10 
skip_for_side_1:
    OUT (io_12_fdc_sector),A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK MORE ENTRYPOINTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_SECTRAN:
    ; BC = sector
    ; DE = pointer to the translation table
    ; Returns in HL the translated sector
    LD A,D
    OR E
    LD H,B
    LD L,C ; HL = BC; Why is this needed?
    ; Return if there is no translation table (DE=0x0000)
    RET Z
    EX DE,HL ; HL <> DE
    ADD HL,BC ; HL = sector + BC
    LD L,(HL)
    LD H,0x0
    RET

prepare_drive:
    ; 1: Interrupt any pending floppy disk controller command.
    PUSH HL
    PUSH DE
    PUSH BC
    ; 1: Interrupt any pending floppy disk controller command.
    LD A, fdc_command_force_interrupt
    OUT (io_10_fdc_command), A
    ; 2: Start the motor
    CALL EP_DISKON
    ; 3; Update the systems bits for the proper selected drive and density.
    LD A, (disk_active_drive)
    LD E,A
    IN A,(io_1c_system_bits)
    ; Clear drive select bits
    AND ~ (system_bit_double_density_neg_mask|system_bit_drive_a_mask|system_bit_drive_b_mask)
    ; Add the bit of the drive selected
    OR E
    INC A ; disk A(0) to mask 0x1, disk B(1) to mask 0x2
    ; Reflect the disk density variable on the system bits.
    LD HL, disk_density
    OR (HL)
    ; Store the modified system bits
    OUT (io_1c_system_bits), A
    POP BC
    POP DE
    POP HL
    RET

EP_DISKON:
    ; Turns the motor on, if it is already on it can return immediately.
    ; It was off, it is started and there is a delay yo let the motors
    ; get some speed.
    ;
    ; Is it already on?
    IN A,(io_1c_system_bits)
    BIT system_bit_motors_neg,A
    ; Yes, return
    RET Z
    ; No, turn on
    RES system_bit_motors_neg,A
    OUT (io_1c_system_bits),A
    ; Wait for the motor to get some speed
    LD B,0x32; 500ms delay
    CALL EP_DELAY
    RET

EP_DISKOFF:
    ; Turn off in any case
    IN A,(io_1c_system_bits)
    SET system_bit_motors_neg,A
    OUT (io_1c_system_bits),A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WAIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_DELAY:
    ; wait time in B
    LD DE,0x686
EP_DELAY_inner_loop:
    DEC DE
    LD A,D
    OR E
    JP NZ, EP_DELAY_inner_loop
    ; Do DELAY again with B-1
    DJNZ EP_DELAY
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK INTERNAL MORE IMPLEMENTATION READ AND WRITE
;
; Actual read and write used by the Appendix G algorithm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

wait_for_result:
    ; The fdc generates a NMI when it requires attention. The NMI handler
    ; is just a RET that will stop the HALT and execute the next instruction.
    HALT
wait_while_busy:
    IN A,(io_10_fdc_status)
    BIT fdc_status_record_busy_bit, A
    JR NZ,wait_while_busy
    RET

write_from_buffer_with_retries:
    LD L, 3 ; retry 3 times if verification fails
write_full_retry:
    LD DE,0x040f ; retry 15 times without seek. Repeat all up to 4 times with seek0
write_retry:
    PUSH HL
    PUSH DE
    CALL fcd_seek_sector
    CALL write_from_buffer_relocated
    POP DE
    POP HL
    ; If write success, verify the write
    JR Z, verify_write
    DEC E
    ; Retry without moving the head home
    JR NZ, write_retry
    DEC D
    ; Do not retry anymore
    JR Z, process_result
    ; Mode the head to track 0 to retry making sure the head is moved.
    CALL fdc_seek_track_0
    LD E,0xf
    JR write_retry

verify_write:
    LD B,0x0 ; loop for 256 bytes
    LD A, fdc_command_read_sector
    OUT (io_10_fdc_command),A
read_first_256_bytes_loop:
    ; Test read 256 bytes (B from 0 and back to 0)
    HALT
    IN A,(io_13_fdc_data)
    DJNZ read_first_256_bytes_loop
read_second_256_bytes_loop:
    ; Test read 256 bytes (B from 0 and back to 0)
    HALT
    IN A,(io_13_fdc_data)
    DJNZ read_second_256_bytes_loop
    CALL wait_for_result
    ; Use only the error related bits
    AND fdc_status_read_error_bitmask
process_result:
    LD (rw_result),A
    ; No errors, return
    RET Z
    ; If we have retries lett, retry
    DEC L
    JR NZ, write_full_retry
    ; No more retries, exit with error ff
    LD A,0xff
    JR process_result

read_to_buffer_with_retries:
    ; Load a full 512 bytes double density sector in the buffer.
    ; It is retried 15*4 times. Every 15 tries the head is fully moved
    ; to track 0 and moved to the requested track.
    LD DE,0x040f ; retry 15 times without seek. Repeat all up to 4 times with seek0
read_retry:
    PUSH DE
    CALL fcd_seek_sector
    ; Read 512 bytes
    CALL read_to_buffer_relocated
    LD (rw_result), A
    POP DE
    ; Read success, exit
    RET Z
    DEC E
    ; Retry without moving the head home
    JR NZ,read_retry
    DEC D
    ; Do not retry anymore
    RET Z
    ; Mode the head to track 0 to retry making sure the head is moved.
    CALL fdc_seek_track_0
    LD E,0xf
    JR read_retry

fcd_seek_sector:
    ; Put the disk to the requested position
    LD A,(drive_in_fdc)
    LD C,A
    CALL init_drive
    LD BC,(track_in_fdc)
    CALL fdc_seek_track
    LD A,(sector_in_fdc)
    LD C,A
    CALL fdc_set_sector
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE RELOCATED TO UPPER RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

block_to_relocate:
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

reloc_read_single_density:
    ; Read 128 bytes into DMA
    LD HL,(disk_DMA_address)
    LD B, rw_mode_single_density
    JR reloc_read_internal
reloc_read_to_buffer:
    ; Read 512 bytes into buffer
    LD HL, sector_buffer_base
    LD B, rw_mode_double_density
reloc_read_internal:
    ; Configure RW for read
    LD DE, fdc_status_read_error_bitmask * 0x100 + fdc_command_read_sector
    JR reloc_RW_internal

reloc_write_single_density:
    ; Write 128 bytes from DMA
    LD HL, (disk_DMA_address)
    LD B, rw_mode_single_density
    JR reloc_write_internal
reloc_write_from_buffer:
    ; Write 512 bytes from buffer
    LD HL, sector_buffer_base
    LD B, rw_mode_double_density
reloc_write_internal:
    ; Configure RW for write
    LD DE, fdc_status_write_error_bitmask * 0x100 + fdc_command_write_sector

reloc_RW_internal:
    CALL prepare_drive; Call in the ROM area
    DI
    ; Hide the ROM. No more calls to the ROM passed this instruction
    IN A,(io_1c_system_bits)
    RES system_bit_bank,A
    OUT (io_1c_system_bits),A
    ; Setup RET as the handler of NMI
    ; As the ROM is paged out, there is no handler.
    PUSH HL
    ; Store in A' the current first byte on 0x66
    LD HL, nmi_isr
    LD A,(HL)
    EX AF,AF' ; '
    ; Set RET as the handler of NMI
    LD (HL), RET_opcode
    POP HL
    ;
    LD A,B ; A = rw_mode
    LD BC, logical_sector_size * 0x100 + io_13_fdc_data  ; Setup of the INI command
    BIT 0x0,A 
    JR NZ, read_rw_internal_cont
    ; For rw_mode_double_density let's set B to zero
    LD B,0x0
read_rw_internal_cont:
    ; Is mode single density?
    CP rw_mode_single_density
    PUSH AF
    LD A,E
    ; Is the command a write?
    CP fdc_command_write_sector
    ; Yes, go to write
    JR Z, reloc_write_sector
    ; No, let's read
    OUT (io_10_fdc_command),A
    POP AF
    ; If the mode is single density, let's read the 128 bytes
    JR Z, reloc_read_the_rest
reloc_read_first_256_bytes:
    HALT
    INI ; IN from io_13_fdc_data
    JR NZ, reloc_read_first_256_bytes
reloc_read_the_rest:
    ; The rest will be 256 bytes on buffer mode and 128 bytes in single density mode
    HALT
    INI ; IN from io_13_fdc_data
    JR NZ, reloc_read_the_rest
    ; We are done
    JR read_write_sector_completed

reloc_write_sector:
    OUT (io_10_fdc_command),A ; A = fdc_command_write_sector
    POP AF
    ; if the mode is single density, let's write the 128 bytes
    JR Z, reloc_write_the_rest
reloc_write_first_256_bytes:
    HALT
    OUTI ; OUT to io_13_fdc_data
    JR NZ,reloc_write_first_256_bytes
reloc_write_the_rest:
    ; The rest will be 256 bytes on buffer mode and 128 bytes in single density mode
    HALT
    OUTI ; OUT to io_13_fdc_data
    JR NZ, reloc_write_the_rest

read_write_sector_completed:
    ; Restore the byte that was on the NMI handler
    EX AF,AF' ; ' 
    LD (nmi_isr),A
    ; Restore the ROM
    IN A,(io_1c_system_bits)
    SET system_bit_bank,A
    OUT (io_1c_system_bits),A
    EI
    ; Wait for the disk access result code
    CALL wait_for_result
    ; Return the result code: 0 or 1
    AND D ; fdc_status_read_error_bitmask or fdc_status_write_error_bitmask
    ; If no error return with A = 0
    RET Z
    ; If error return with A = 1
    LD A,0x1
    RET
block_to_relocate_end:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; IO PORTS INITIALIZATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_ports_count:
    DB 0x1C
init_ports_data:
    ; Keyboard, SIO-B. See Z80-SIO Technical Manual
    DB io_07_keyboard_control, 0x18 ; Reset
    DB io_0c_keyboad_baud_rate, 0x05 ; Set 8816 clock generator to 300 baud
    DB io_07_keyboard_control, 0x04 ; WR4
    DB io_07_keyboard_control, 0x44 ;   = 0x44, CLK/32, 1 Stop bit, no parity
    DB io_07_keyboard_control, 0x03 ; WR3
    DB io_07_keyboard_control, 0xC1 ;   = 0xc1, 8bits, RX enable
    DB io_07_keyboard_control, 0x05 ; WR5
    DB io_07_keyboard_control, 0xE8 ;   = 0xe8, 8bits TX, TX enable, DTR
    DB io_07_keyboard_control, 0x01 ; WR1
    DB io_07_keyboard_control, 0x00 ;   = 0x00, disable interrupts

    ; Serial port, SIO-A. See Z80-SIO Technical Manual
    DB io_06_serial_control, 0x18 ; Reset
    DB io_00_serial_baud_rate, 0x05 ; Set 8816 clock generator to 300 baud
    DB io_06_serial_control, 0x04 ; WR4
    DB io_06_serial_control, 0x44 ;   = 0x44, CLK/32, 1 Stop bit, no parity
    DB io_06_serial_control, 0x03 ; WR3
    DB io_06_serial_control, 0xE1 ;   = 0xe1, 8bits, auto-enable, RX enable
    DB io_06_serial_control, 0x05 ; WR5
    DB io_06_serial_control, 0xE8 ;   = 0xe8, 8bits TX, TX enable, DTR
    DB io_06_serial_control, 0x01 ; WR1
    DB io_06_serial_control, 0x00 ;   = 0x00, disable interrupts

    ; System bits, PIO-2A. See Z80-PIO Technical Manual
    DB io_1d_system_bits_control, 0x03 ; Enable interrupts with AND
    DB io_1c_system_bits, 0x81 ;  system_bits = 0x81, drive A, ROM enabled
    DB io_1d_system_bits_control, 0xCF ; set mode 3-control
    DB io_1d_system_bits_control, 0x08 ; direction = IOOO_OOOO
    
    ; Parallel port, PIO-1A. See Z80-PIO Technical Manual
    DB io_09_parallel_control, 0x03 ; Enable interrupts with AND
    DB io_09_parallel_control, 0x0F ; set mode 0-output

    ; Parallel port, PIO-1B. See Z80-PIO Technical Manual
    DB io_0b_parallel_b_control, 0x03 ; Enable interrupts with AND
    DB io_0b_parallel_b_control, 0x4F ; set mode 1-input
EP_INITDEV:
    LD HL,init_ports_count
    LD B,(HL)
init_ports_loop:
    INC HL
    LD C,(HL)
    INC HL
    LD A,(HL)
    ; An out for each pair of bytes in init_ports_data
    OUT (C),A
    DJNZ init_ports_loop
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; KEYBOARD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_KBDSTAT:
    ; return 0 or FF in A
    IN A, (io_07_keyboard_control)
    AND 0x1
    RET Z
    LD A,0xff
    RET

EP_KBDIN:
    ; return char in A
    CALL EP_KBDSTAT
    JR Z, EP_KBDIN
    IN A, (io_05_keyboard_data)
    CALL translate_keyboard_in_a
    RET

EP_KBDOUT:
    ; char in C. C=4 for the bell.
    IN A, (io_07_keyboard_control)
    AND 0x4
     ; Loop until a key is pressed
    JR Z, EP_KBDOUT
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERIAL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_SIOSTI:
    ; return 0 or FF in A
    IN A, (io_06_serial_control)
    AND 0x1
    JR force_0_or_ff

EP_SIOIN:
    ; return char in A
    CALL EP_SIOSTI
    JR Z, EP_SIOIN
    IN A, (io_04_serial_data)
    RET

EP_SIOOUT:
    ; char in C
    IN A, (io_06_serial_control)
    AND 0x4
    ; Loop until a byte is ready
    JR Z, EP_SIOOUT
    LD A,C
    OUT (io_04_serial_data), A
    RET

EP_SERSTO:
    IN A, (io_06_serial_control)
    AND 0x4
    JR force_0_or_ff

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PARALLEL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_LISTST:
    ; return 0 or FF in A
    IN A, (io_1c_system_bits)
    BIT system_bit_centronicsReady, A
force_0_or_ff:
    RET Z
    LD A,0xff
    RET

EP_LIST:
    ; char in C
    ; Loop until the printer is ready
    CALL EP_LISTST
    JR Z, EP_LIST
    ; Ouput the byte in C
    LD A,C
    OUT (io_08_parallel_data), A
    ; Pulse the strobe signal
    IN A, (io_1c_system_bits)
    SET system_bit_centronicsStrobe, A
    OUT (io_1c_system_bits), A
    RES system_bit_centronicsStrobe, A
    OUT (io_1c_system_bits), A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSOLE OUTPUT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

EP_INITVID:
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

EP_VIDOUT:
    ; char in C
    ; Are we processing an escape sequence?
    LD A, (console_esc_mode)
    OR A ; Clear carry
    JP NZ, process_esc_command
    ; Is it a BELL?
    LD A,0x7 ; ^G BELL
    CP C
    JR NZ, EP_VIDOUT_cont
    ; BELL sends a 4 to the keyboard to beep
    LD C,0x4
    JP EP_KBDOUT
EP_VIDOUT_cont:
    CALL remove_blink_and_get_cursor_position
    ; Push console_write_end to the stack to execute on any RET
    LD DE, console_write_end
    PUSH DE
    ; Test all special chars
    LD A,C
    CP 0xa
    JR Z, console_line_feed
    CP 0xd
    JP Z, console_carriage_return
    CP 0x8
    JR Z, console_backspace
    CP 0xc
    JR Z, console_right
    CP 0xb
    JR Z, console_up
    CP 0x1b
    JP Z, enable_esc_mode
    CP 0x18
    JP Z, console_erase_to_end_of_line
    CP 0x17
    JR Z,console_erase_to_end_of_screen
    CP 0x1a
    JR Z,console_clear_screen
    CP 0x1e
    JR Z,console_home_cursor
    ; For lowercase chars we may apply a conversion to greek
    ; letters. 
    CP 'a'-1
    JR C,skip_greek_conversion
    ; Apply the alphabet mask
    LD A,(console_alphabet_mask)
    AND C
skip_greek_conversion:
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
    LD HL, ret_opcode_address
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
ret_opcode_address:
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
    CALL EP_VIDOUT
    JR console_write_string

filler:
    DS 0x76f, 0xff
