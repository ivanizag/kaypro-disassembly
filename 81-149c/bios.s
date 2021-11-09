;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Analysis of the Kaypro II ROM
;
; Based on 81-149c.rom
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

io_04_serial_data:          EQU 0x04
io_05_keyboard_data:        EQU 0x05
io_06_serial_control:       EQU 0x06
io_07_keyboard_control:     EQU 0x07
DAT_io_0008:                EQU 0x08
io_10_fdc_command_status:   EQU 0x10
io_11_fdc_track:            EQU 0x11
io_12_fdc_sector:           EQU 0x12
io_13_fdc_data:             EQU 0x13
io_14_scroll_register:      EQU 0x14
io_1c_system_bits:          EQU 0x1c

address_vram:               EQU 0x3000

ram_fa02_address_to_load_boot_sector:  EQU 0xfa02
ram_fa04_address_to_exec_boot:         EQU 0xfa04
ram_fa06_count_of_boot_sectors:        EQU 0xfa06

ram_fc00_disk_for_next_access:         EQU 0xfc00
ram_fc01_track_for_next_access:        EQU 0xfc01
ram_fc03_sector_for_next_access:       EQU 0xfc03

ram_fc04_disk_xx:        EQU 0xfc04
ram_fc05_track_xx:       EQU 0xfc05
ram_fc07_sector_xx:      EQU 0xfc07
DAT_ram_fc08:            EQU 0xfc08
DAT_ram_fc09:            EQU 0xfc09
DAT_ram_fc0a:            EQU 0xfc0a
DAT_ram_fc0b:            EQU 0xfc0b
DAT_ram_fc0c:            EQU 0xfc0c
DAT_ram_fc0d:            EQU 0xfc0d
DAT_ram_fc0f:            EQU 0xfc0f
DAT_ram_fc10:            EQU 0xfc10
DAT_ram_fc11:            EQU 0xfc11
DAT_ram_fc12:            EQU 0xfc12
DAT_ram_fc13:            EQU 0xfc13
ram_fc14_DMA_address:    EQU 0xfc14
DAT_ram_fc16:            EQU 0xfc16
DAT_ram_fc17:            EQU 0xfc17
DAT_ram_fc18:            EQU 0xfc18
DAT_ram_fc19:            EQU 0xfc19

mem_fe16_active_disk:    EQU 0xfe16
DAT_ram_fe17:            EQU 0xfe17
mem_fe18_active_track:   EQU 0xfe18
mem_fe19_track:          EQU 0xfe19

DAT_ram_fe6c:            EQU 0xfe6c
DAT_ram_fe6d:            EQU 0xfe6d
RAM_fe6e_cursor:         EQU 0xfe6e
SUB_ram_fef4:            EQU 0xfef4
DAT_ram_fe70:            EQU 0xfe70
LAB_ram_feed:            EQU 0xfeed

; Some code is relocated to upper memory
relocation_destination:  EQU 0xfecd
relocation_offset:       EQU 0xfecd - 0x04a8    ; relocation_destination - block_to_relocate_to_fecd
read_in_DMA_relocated:   EQU 0xfedc             ; reloc_read_in_DMA + relocation_offset
move_RAM_relocated:      EQU 0xfecd             ; reloc_move_RAM + relocation_offset 
read_to_upper_relocated: EQU 0xfee3             ; reloc_read_to_upper + relocation_offset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS ENTRY POINTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG	0h
	JP          cold_boot
	JP          init_upper_RAM                          
	JP          init_screen 
	JP          init_ports  
	JP          fdc_restore_and_mem                     
	JP          set_disk_for_next_access                
	JP          set_track_for_next_access               
	JP          set_sector_for_next_access              
	JP          set_DMA_address_for_next_access         
	JP          read_sector 
	JP          write_sector
	JP          sector_translation                      
	JP          turn_on_motor                           
	JP          turn_off_motor                          
	JP          is_key_pressed                          
	JP          get_key     
	JP          console_bell
	JP          is_serial_byte_ready                    
	JP          get_byte_from_serial                    
	JP          serial_out  
	JP          lpt_status  
	JP          lpt_output  
	JP          serial_get_control                      
	JP          console_write_c                         
	JP          wait_B      


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INITIALIZATION AND BOOT FROM DISK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cold_boot:
	DI                       
	LD          SP, 0xffff   
	LD          B, 0xa       
	CALL        wait_B      
	CALL        init_ports  
	CALL        init_screen 
	CALL        init_upper_RAM                          
	JR          cold_boot_continue
	DB          0x3D, 0, 0, 0, 0, 0, 0
nmi_isr:
	RET

cold_boot_continue:           
	CALL        console_write_string                    
	DB          1Bh,"=*?"
	DB          "*    KAYPRO II    *"
	DB          1Bh,"=-4"
	DB          " Please place your diskette into Drive A",8h
	DB          0
	LD          C,0x0       
	CALL        set_disk_for_next_access                
	LD          BC,0x0      
	CALL        set_track_for_next_access               
	LD          C,0x0       
	CALL        set_sector_for_next_access              
	LD          BC,0xfa00   
	CALL        set_DMA_address_for_next_access         
	CALL        read_sector 
	DI                       
	OR          A           
	JR          NZ,error_bad_disk                       
	LD          BC,(ram_fa02_address_to_load_boot_sector)
	LD          (ram_fc14_DMA_address),BC               
	LD          BC,(ram_fa04_address_to_exec_boot)      
	PUSH        BC          
	LD          BC,(ram_fa06_count_of_boot_sectors)     
	LD          B,C         
	LD          C,0x1       
read_another_boot_sector:     
	PUSH        BC          
	CALL        set_sector_for_next_access              
	CALL        read_sector 
	DI                       
	POP         BC          
	OR          A           
	JR          NZ,error_bad_disk            
	LD          HL,(ram_fc14_DMA_address)               
	LD          DE,0x80     
	ADD         HL,DE       
	LD          (ram_fc14_DMA_address),HL               
	DEC         B           
	RET         Z           
	INC         C           
	LD          A,0x28      
	CP          C           
	JR          NZ,read_another_boot_sector  
	LD          C,0x10      
	PUSH        BC          
	LD          BC,0x1      
	CALL        set_track_for_next_access               
	POP         BC          
	JR          read_another_boot_sector                
error_bad_disk:               
	CALL        console_write_string                    
	DB          "\n\r\n\r\aI cannot read your diskette.",0
	CALL        turn_off_motor                          
wait_forever:                 
	JR          wait_forever

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COPY CODE AND DATA TO UPPER RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_data_drive_0:
	DB          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    DB          0x73, 0xFF, 0xA2, 0xFE, 0x1A, 0xFE, 0x2A, 0xFE
	DB          0x00
init_data_drive_1:
    DB          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	DB          0x73, 0xFF, 0xA2, 0xFE, 0x43, 0xFE, 0x53, 0xFE
	DB          0x00 
init_data_rest:
    DB          0x12, 0x00, 0x03, 0x07, 0x00, 0x52, 0x00, 0x1F
    DB          0x00, 0x80, 0x00, 0x08, 0x00, 0x03, 0x00, 0x28
    DB          0x00, 0x03, 0x07, 0x00, 0xC2, 0x00, 0x3F, 0x00
    DB          0xF0, 0x00, 0x10, 0x00, 0x01, 0x00, 0x01, 0x06
    DB          0x0B, 0x10, 0x03, 0x08, 0x0D, 0x12, 0x05, 0x0A
    DB          0x0F, 0x02, 0x07, 0x0C, 0x11, 0x04, 0x09, 0x0E 

init_upper_RAM:
	LD          HL,block_to_relocate_to_fecd                       
	LD          DE,relocation_destination   
	LD          BC,0x87     
	LDIR                     
	LD          HL,init_data_drive_0                       
	LD          DE,0xfe71   
	LD          BC,0x52     
	LDIR                     
	XOR         A           
	LD          (DAT_ram_fc09),A                        
	LD          (DAT_ram_fc0b),A                        
	LD          A,0x0       
	LD          (DAT_ram_fe17),A                        
	LD          A,0xff      
	LD          (mem_fe16_active_disk),A                
	LD          (mem_fe18_active_track),A               
	LD          (mem_fe19_track),A                      
	RET     

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FLOPPY DISK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set_disk_for_next_access:
	LD          A,C         
	LD          (ram_fc00_disk_for_next_access),A       
	JP          fdc_set_disk
set_sector_for_next_access:
	LD          A,C         
	LD          (ram_fc03_sector_for_next_access),A     
	LD          A,(DAT_ram_fe17)                        
	OR          A           
	JP          NZ,fdc_set_sector_C                     
	RET                      
set_DMA_address_for_next_access:
	LD          (ram_fc14_DMA_address),BC               
	RET                      
set_track_for_next_access:
	LD          (ram_fc01_track_for_next_access),BC     
	LD          A,(DAT_ram_fe17)                        
	OR          A           
	JP          NZ,fdc_seek_track_C                     
	RET                      
fdc_restore_and_mem:
	LD          A,(DAT_ram_fe17)                        
	OR          A           
	JP          NZ,fdc_restore                          
	LD          A,(DAT_ram_fc0a)                        
	OR          A           
	JP          NZ,LAB_ram_01e9                         
	LD          (DAT_ram_fc09),A                        
LAB_ram_01e9:                 
	JP          fdc_restore 

read_sector:
	LD          A,(DAT_ram_fe17)                        
	OR          A           
	JP          NZ,read_in_DMA_relocated                    
	XOR         A           
	LD          (DAT_ram_fc0b),A                        
	LD          A,0x1       
	LD          (DAT_ram_fc12),A                        
	LD          (DAT_ram_fc11),A                        
	LD          A,0x2       
	LD          (DAT_ram_fc13),A                        
	JP          LAB_ram_0279
write_sector:                 
	LD          A,(DAT_ram_fe17)                        
	OR          A           
	JP          NZ,LAB_ram_feed                         
	XOR         A           
	LD          (DAT_ram_fc12),A                        
	LD          A,C         
	LD          (DAT_ram_fc13),A                        
	CP          0x2         
	JP          NZ,LAB_ram_0232                         
	LD          A,0x8       
	LD          (DAT_ram_fc0b),A                        
	LD          A,(ram_fc00_disk_for_next_access)       
	LD          (DAT_ram_fc0c),A                        
	LD          HL,(ram_fc01_track_for_next_access)     
	LD          (DAT_ram_fc0d),HL                       
	LD          A,(ram_fc03_sector_for_next_access)     
	LD          (DAT_ram_fc0f),A                        
LAB_ram_0232:                 
	LD          A,(DAT_ram_fc0b)                        
	OR          A           
	JP          Z,LAB_ram_0271                          
	DEC         A           
	LD          (DAT_ram_fc0b),A                        
	LD          A,(ram_fc00_disk_for_next_access)       
	LD          HL,0xfc0c   
	CP          (HL)                       
	JP          NZ,LAB_ram_0271                         
	LD          HL,0xfc0d   
	CALL        FUN_ram_0311
	JP          NZ,LAB_ram_0271                         
	LD          A,(ram_fc03_sector_for_next_access)     
	LD          HL,0xfc0f   
	CP          (HL)                        
	JP          NZ,LAB_ram_0271                         
	INC         (HL)                        
	LD          A,(HL)                      
	CP          0x28        
	JP          C,LAB_ram_026a                          
	LD          (HL),0x0                    
	LD          HL,(DAT_ram_fc0d)                       
	INC         HL          
	LD          (DAT_ram_fc0d),HL                       
LAB_ram_026a:                 
	XOR         A           
	LD          (DAT_ram_fc11),A                        
	JP          LAB_ram_0279
LAB_ram_0271:                 
	XOR         A           
	LD          (DAT_ram_fc0b),A                        
	INC         A           
	LD          (DAT_ram_fc11),A                        
LAB_ram_0279:                 
	XOR         A           
	LD          (DAT_ram_fc10),A                        
	LD          A,(ram_fc03_sector_for_next_access)     
	OR          A           
	RRA                      
	OR          A           
	RRA                      
	LD          (DAT_ram_fc08),A                        
	LD          HL,0xfc09   
	LD          A,(HL)                      
	LD          (HL),0x1                    
	OR          A           
	JP          Z,LAB_ram_02b5                          
	LD          A,(ram_fc00_disk_for_next_access)       
	LD          HL,0xfc04   
	CP          (HL)                    
	JP          NZ,LAB_ram_02ae                         
	LD          HL,0xfc05   
	CALL        FUN_ram_0311
	JP          NZ,LAB_ram_02ae                         
	LD          A,(DAT_ram_fc08)                        
	LD          HL,0xfc07   
	CP          (HL)                  
	JP          Z,LAB_ram_02d2                          
LAB_ram_02ae:                 
	LD          A,(DAT_ram_fc0a)                        
	OR          A           
	CALL        NZ,read_sector_yy                       
LAB_ram_02b5:                 
	LD          A,(ram_fc00_disk_for_next_access)       
	LD          (ram_fc04_disk_xx),A                    
	LD          HL,(ram_fc01_track_for_next_access)     
	LD          (ram_fc05_track_xx),HL                  
	LD          A,(DAT_ram_fc08)                        
	LD          (ram_fc07_sector_xx),A                  
	LD          A,(DAT_ram_fc11)                        
	OR          A           
	CALL        NZ,read_sector_xx                       
	XOR         A           
	LD          (DAT_ram_fc0a),A                        
LAB_ram_02d2:                 
	LD          A,(ram_fc03_sector_for_next_access)     
	AND         0x3         
	LD          L,A         
	LD          H,0x0       
	ADD         HL,HL       
	ADD         HL,HL       
	ADD         HL,HL       
	ADD         HL,HL       
	ADD         HL,HL       
	ADD         HL,HL       
	ADD         HL,HL       
	LD          DE,0xfc16   
	ADD         HL,DE       
	LD          DE,(ram_fc14_DMA_address)               
	LD          BC,0x80     
	LD          A,(DAT_ram_fc12)                        
	OR          A           
	JR          NZ,LAB_ram_02f8                         
	LD          A,0x1       
	LD          (DAT_ram_fc0a),A                        
	EX          DE,HL       
LAB_ram_02f8:                 
	CALL        move_RAM_relocated                   
	LD          A,(DAT_ram_fc13)                        
	CP          0x1         
	LD          A,(DAT_ram_fc10)                        
	RET         NZ          
	OR          A           
	RET         NZ          
	XOR         A           
	LD          (DAT_ram_fc0a),A                        
	CALL        read_sector_yy                          
	LD          A,(DAT_ram_fc10)                        
	RET                      
FUN_ram_0311:
	EX          DE,HL       
	LD          HL,0xfc01   
	LD          A,(DE)        
	CP          (HL)      
	RET         NZ          
	INC         DE          
	INC         HL          
	LD          A,(DE)        
	CP          (HL)                        
	RET                      
fdc_set_disk:
	LD          HL,0x0      
	LD          A,C         
	CP          0x2         
	RET         NC          
	OR          A           
	LD          HL,0xfe71   
	JR          Z,skip_for_disk_0                       
	LD          HL,0xfe82   
skip_for_disk_0:              
	LD          A,(mem_fe16_active_disk)                
	CP          C           
	RET         Z           
	LD          A,C         
	LD          (mem_fe16_active_disk),A                
	OR          A           
	PUSH        HL          
	LD          DE,0x10     
	ADD         HL,DE       
	LD          A,(HL)               
	LD          (DAT_ram_fe17),A                        
	LD          HL,0xfe19   
	JR          Z,LAB_ram_0346                          
	DEC         HL          
LAB_ram_0346:                 
	LD          A,(HL)             
	CP          0xff        
	JR          Z,LAB_ram_034e                          
	IN          A,(io_11_fdc_track)                
	LD          (HL),A             
LAB_ram_034e:                 
	LD          A,C         
	OR          A           
	LD          HL,0xfe18   
	JR          Z,LAB_ram_0356                          
	INC         HL          
LAB_ram_0356:                 
	LD          A,(HL)                    
	OUT         (io_11_fdc_track),A                
	EX          DE,HL       
	POP         HL          
	CP          0xff        
	RET         NZ          
	CALL        fdc_ensure_ready                        
	CALL        fdc_restore_and_mem                     
	IN          A,(io_1c_system_bits)                   
	AND         0xdf        
	OR          0x0         
	OUT         (io_1c_system_bits),A                   
	CALL        fdc_read_address                        
	JR          Z,local_read_address_ok                 
	IN          A,(io_1c_system_bits)                   
	AND         0xdf        
	OR          0x20        
	OUT         (io_1c_system_bits),A                   
	CALL        fdc_read_address                        
	RET         NZ          
	JR          local_read_address_second_ok            
local_read_address_ok:        
	PUSH        HL                        
	PUSH        DE                      
	LD          DE,0x0000      
	LD          (HL),E                      
	INC         HL          
	LD          (HL),D                      
	LD          DE,0x0009      
	ADD         HL,DE       
	LD          DE,0xfea2   
	LD          (HL),E                      
	INC         HL          
	LD          (HL),D                      
	LD          DE,0x0005      
	ADD         HL,DE       
	LD          A,0x0       
	LD          (HL),A               
	LD          (DAT_ram_fe17),A                        
	JR          local_read_address_end                  
local_read_address_second_ok: 
	PUSH        HL          
	PUSH        DE                      
	LD          DE,0xfeb1   
	LD          (HL),E                      
	INC         HL          
	LD          (HL),D                      
	LD          DE,0x0009      
	ADD         HL,DE       
	LD          DE,0xfe93   
	LD          (HL),E                      
	INC         HL          
	LD          (HL),D                      
	LD          DE,0x5      
	ADD         HL,DE       
	LD          A,0x20      
	LD          (HL),A               
	LD          (DAT_ram_fe17),A                        
local_read_address_end:       
	POP         DE          
	POP         HL          
	IN          A,(io_12_fdc_sector)               
	OUT         (io_11_fdc_track),A                
	LD          (DE),A                    
	RET                      
fdc_read_address:
	LD          A,0xc4      
	OUT         (io_10_fdc_command_status),A       
	CALL        fdc_halt    
	BIT         0x4,A       
	RET                      
fdc_restore:
	CALL        fdc_ensure_ready                        
	LD          A,0x0       
	OUT         (io_10_fdc_command_status),A       
	JR          fdc_halt    
fdc_seek_track_C:
	CALL        fdc_ensure_ready                        
	LD          A,C         
	OUT         (io_13_fdc_data),A                 
	LD          A,0x10      
	OUT         (io_10_fdc_command_status),A       
	JR          fdc_halt    
fdc_set_sector_C:
	LD          A,C         
	OUT         (io_12_fdc_sector),A               
	RET                      
sector_translation:           
	LD          A,D         
	OR          E           
	LD          H,B         
	LD          L,C         
	RET         Z           
	EX          DE,HL       
	ADD         HL,BC       
	LD          L,(HL)                    
	LD          H,0x0       
	RET                      
fdc_ensure_ready:
	PUSH        HL          
	PUSH        DE          
	PUSH        BC          
	LD          A,0xd0      
	OUT         (io_10_fdc_command_status),A       
	CALL        turn_on_motor                           
	LD          A,(mem_fe16_active_disk)                
	LD          E,A         
	IN          A,(io_1c_system_bits)                   
	AND         0xfc        
	OR          E           
	INC         A           
	AND         0xdf        
	LD          HL,0xfe17   
	OR          (HL)                        
	OUT         (io_1c_system_bits),A                   
	POP         BC          
	POP         DE          
	POP         HL          
	RET                      
turn_on_motor:
	IN          A,(io_1c_system_bits)                   
	BIT         0x6,A       
	RET         Z           
	RES         0x6,A       
	OUT         (io_1c_system_bits),A                   
	LD          B,0x32      
	CALL        wait_B      
	RET                      
turn_off_motor:
	IN          A,(io_1c_system_bits)                   
	SET         0x6,A       
	OUT         (io_1c_system_bits),A                   
	RET                      
wait_B:
	LD          DE,0x686    
wait_B_loop:                  
	DEC         DE          
	LD          A,D         
	OR          E           
	JP          NZ,wait_B_loop                          
	DJNZ        wait_B      
	RET                      
fdc_halt:
	HALT                     
wait_while_busy:              
	IN          A,(io_10_fdc_command_status)       
	BIT         0x0,A       
	JR          NZ,wait_while_busy                      
	RET                      
read_sector_yy:
	LD          L,0x3       
LAB_ram_043b:                 
	LD          DE,0x40f    
LAB_ram_043e:                 
	PUSH        HL          
	PUSH        DE                       
	CALL        go_to_track_sector                      
	CALL        SUB_ram_fef4
	POP         DE          
	POP         HL          
	JR          Z,LAB_ram_0457                          
	DEC         E           
	JR          NZ,LAB_ram_043e                         
	DEC         D           
	JR          Z,LAB_ram_046c                          
	CALL        fdc_restore 
	LD          E,0xf       
	JR          LAB_ram_043e
LAB_ram_0457:                 
	LD          B,0x0       
	LD          A,0x88      
	OUT         (io_10_fdc_command_status),A       
LAB_ram_045d:                 
	HALT                     
	IN          A,(io_13_fdc_data)                 
	DJNZ        LAB_ram_045d
LAB_ram_0462:                 
	HALT                     
	IN          A,(io_13_fdc_data)                 
	DJNZ        LAB_ram_0462
	CALL        fdc_halt    
	AND         0x9c        
LAB_ram_046c:                 
	LD          (DAT_ram_fc10),A                        
	RET         Z           
	DEC         L           
	JR          NZ,LAB_ram_043b                         
	LD          A,0xff      
	JR          LAB_ram_046c
read_sector_xx:
	LD          DE,0x40f    
LAB_ram_047a:                 
	PUSH        DE                       
	CALL        go_to_track_sector                      
	CALL        read_to_upper_relocated               
	LD          (DAT_ram_fc10),A                        
	POP         DE          
	RET         Z           
	DEC         E           
	JR          NZ,LAB_ram_047a                         
	DEC         D           
	RET         Z           
	CALL        fdc_restore 
	LD          E,0xf       
	JR          LAB_ram_047a
go_to_track_sector:
	LD          A,(ram_fc04_disk_xx)                    
	LD          C,A         
	CALL        fdc_set_disk
	LD          BC,(ram_fc05_track_xx)                  
	CALL        fdc_seek_track_C                        
	LD          A,(ram_fc07_sector_xx)                  
	LD          C,A         
	CALL        fdc_set_sector_C                        
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE RELOCATED TO UPPER RAM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

block_to_relocate_to_fecd:
reloc_move_RAM:               
	IN          A,(io_1c_system_bits)                   
	RES         0x7,A       
	OUT         (io_1c_system_bits),A                   
	LDIR                     
	IN          A,(io_1c_system_bits)                   
	SET         0x7,A       
	OUT         (io_1c_system_bits),A                   
	RET                      
reloc_read_in_DMA:            
	LD          HL,(ram_fc14_DMA_address)               
	LD          B,0x1       
	JR          reloc_read_internal                     
reloc_read_to_upper:          
	LD          HL,0xfc16   
	LD          B,0x4       
reloc_read_internal:          
	LD          DE,0x9c88   
	JR          reloc_RW_internal                       
reloc_write_to_DMA:           
	LD          HL,(ram_fc14_DMA_address)               
	LD          B,0x1       
	JR          reloc_write_internal                    
reloc_write_from_upper:       
	LD          HL,0xfc16   
	LD          B,0x4       
reloc_write_internal:         
	LD          DE,0xfcac   
reloc_RW_internal:            
	CALL        fdc_ensure_ready                        
	DI                       
	IN          A,(io_1c_system_bits)                   
	RES         0x7,A       
	OUT         (io_1c_system_bits),A                   
	PUSH        HL                        
	LD          HL,0x0066  ;nmi_isr     
	LD          A,(HL)                           
	EX          AF,AF'      
	LD          (HL),0xc9                        
	POP         HL          
	LD          A,B         
	LD          BC,0x8013   
	BIT         0x0,A       
	JR          NZ,LAB_ram_04f4                         
	LD          B,0x0       
LAB_ram_04f4:                 
	CP          0x1         
	PUSH        AF          
	LD          A,E         
	CP          0xac        
	JR          Z,reloc_write_sector                    
	OUT         (io_10_fdc_command_status),A       
	POP         AF          
	JR          Z,reloc_read_second_half_of_sector      
reloc_read_first_half_of_sector:
	HALT                     
	INI                      
	JR          NZ,reloc_read_first_half_of_sector      
reloc_read_second_half_of_sector:
	HALT                     
	INI                      
	JR          NZ,reloc_read_second_half_of_sector     
	JR          read_sector_completed                   
reloc_write_sector:           
	OUT         (io_10_fdc_command_status),A       
	POP         AF          
	JR          Z,reloc_write_second_half_of_sector     
reloc_write_first_half_of_sector:
	HALT                     
	OUTI                     
	JR          NZ,reloc_write_first_half_of_sector     
reloc_write_second_half_of_sector:
	HALT                     
	OUTI                     
	JR          NZ,reloc_write_second_half_of_sector    
read_sector_completed:        
	EX          AF,AF'      
	LD          (nmi_isr),A 
	IN          A,(io_1c_system_bits)                   
	SET         0x7,A       
	OUT         (io_1c_system_bits),A                   
	EI                       
	CALL        fdc_halt    
	AND         D           
	RET         Z           
	LD          A,0x1       
	RET                      

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; IO PORTS INITIALIZATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


init_ports_count:             
	DB         0x1C         
init_ports_data:              
	DW          0x1807       
	DW          0x050C        
	DW          0x0407        
	DW          0x4407       
	DW          0x0307        
	DW          0xC107       
	DW          0x0507        
	DW          0xE807       
	DW          0x0107        
	DW          0x0007          
	DW          0x1806       
	DW          0x0500        
	DW          0x0406        
	DW          0x4406       
	DW          0x0306        
	DW          0xE106       
	DW          0x0506        
	DW          0xE806       
	DW          0x0106        
	DW          0x0006          
	DW          0x031D        
	DW          0x811C       
	DW          0xCF1D       
	DW          0x0C1D        
	DW          0x0309        
	DW          0x0F09        
	DW          0x030B        
	DW          0x4F0B       
init_ports:
	LD          HL,init_ports_count    
	LD          B,(HL)                  
init_port_loop:               
	INC         HL          
	LD          C,(HL)                   
	INC         HL          
	LD          A,(HL)                 
	OUT         (C),A           
	DJNZ        init_port_loop                          
	RET                      

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; KEYBOARD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

is_key_pressed:
	IN          A,(io_07_keyboard_control)              
	AND         0x1         
	RET         Z           
	LD          A,0xff      
	RET                      
get_key:                      
	CALL        is_key_pressed                          
	JR          Z,get_key   
	IN          A,(io_05_keyboard_data)                 
	CALL        translate_keyboard_in_a                 
	RET                      
console_bell:
	IN          A,(io_07_keyboard_control)              
	AND         0x4         
	JR          Z,console_bell                          
	LD          A,C         
	OUT         (io_05_keyboard_data),A                 
	RET                      
translate_keyboard_in_a:
	LD          HL,0x5a7    
	LD          BC,0x13     
	CPIR                     
	RET         NZ          
	LD          DE,0x5a7    
	OR          A           
	SBC         HL,DE       
	LD          DE,0x5b9    
	ADD         HL,DE       
	LD          A,(HL)         
	RET                      
translate_keyboard_keys:      
	DB          0xF1, 0xF2, 0xF3, 0xF4, 0xB1, 0xC0, 0xC1, 0xC2
	DB          0xD0, 0xD1, 0xD2, 0xE1, 0xE2, 0xE3, 0xE4, 0xD3
	DB          0xC3, 0xB2
translate_keyboard_values:
	DB          0xFF, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86
	DB          0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E
	DB          0x8F, 0x90, 0x91 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERIAL AND PARALLEL 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

is_serial_byte_ready:
	IN          A,(io_06_serial_control)                
	AND         0x1         
	JR          force_0_or_ff                           
get_byte_from_serial:         
	CALL        is_serial_byte_ready                    
	JR          Z,get_byte_from_serial                  
	IN          A,(io_04_serial_data)                   
	RET                      
serial_out:                   
	IN          A,(io_06_serial_control)                
	AND         0x4         
	JR          Z,serial_out
	LD          A,C         
	OUT         (io_04_serial_data),A                   
	RET                      
serial_get_control:           
	IN          A,(io_06_serial_control)                
	AND         0x4         
	JR          force_0_or_ff     
lpt_status:
	IN          A,(io_1c_system_bits)                   
	BIT         0x3,A       
force_0_or_ff:                
	RET         Z           
	LD          A,0xff      
	RET                      
lpt_output:                   
	CALL        lpt_status  
	JR          Z,lpt_output
	LD          A,C         
	OUT         (DAT_io_0008),A                         
	IN          A,(io_1c_system_bits)                   
	SET         0x4,A       
	OUT         (io_1c_system_bits),A                   
	RES         0x4,A       
	OUT         (io_1c_system_bits),A                   
	RET            

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSOLE OUTPUT	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_screen:
	LD          A,0x20      
	LD          (DAT_ram_fe6d),A                        
	CALL        console_clear_screen                    
	LD          (RAM_fe6e_cursor),HL                    
	XOR         A           
	LD          (DAT_ram_fe6c),A                        
	LD          A,0x17      
	OUT         (io_14_scroll_register),A               
	LD          A,0x7f      
	LD          (DAT_ram_fe70),A                        
	RET                      

console_write_c:
	LD          A,(DAT_ram_fe6c)                        
	OR          A           
	JP          NZ,LAB_ram_073b                         
	LD          A,0x7       
	CP          C           
	JR          NZ,console_write_c_cont                 
	LD          C,0x4       
	JP          console_bell
console_write_c_cont:         
	CALL        set_hl_to_cursor_a_to_char_cleaned      
	LD          DE,0x795    
	PUSH        DE          
	LD          A,C         
	CP          0xa         
	JR          Z,console_line_feed                     
	CP          0xd         
	JP          Z,console_carriage_return               
	CP          0x8         
	JR          Z,console_backspace                     
	CP          0xc         
	JR          Z,console_right                         
	CP          0xb         
	JR          Z,console_up
	CP          0x1b        
	JP          Z,store_1_in_fe6c                       
	CP          0x18        
	JP          Z,console_erase_to_end_of_line          
	CP          0x17        
	JR          Z,console_erase_to_end_of_screen        
	CP          0x1a        
	JR          Z,console_clear_screen                  
	CP          0x1e        
	JR          Z,console_home_cursor                   
	CP          0x60        
	JR          C,LAB_ram_066a                          
	LD          A,(DAT_ram_fe70)                        
	AND         C           
LAB_ram_066a:                 
	LD          (HL),A        
	INC         HL          
	LD          A,L         
	AND         0x7f        
	CP          0x50        
	RET         C           
	CALL        console_carriage_return                 
	JR          console_line_feed                       
LAB_ram_0677:                 
	LD          DE,0x3bff   
	LD          A,D         
	CP          H           
	JR          C,LAB_ram_0682                          
	RET         NZ          
	LD          A,E         
	CP          L           
	RET         NC          
LAB_ram_0682:                 
	LD          B,0x17      
	LD          HL,0x3080   
	LD          DE,address_vram                         
LAB_ram_068a:                 
	PUSH        BC          
	LD          BC,0x50     
	LDIR                     
	LD          BC,0x30     
	ADD         HL,BC       
	EX          DE,HL       
	ADD         HL,BC       
	EX          DE,HL       
	POP         BC          
	DJNZ        LAB_ram_068a
	LD          HL,0x3b80   
	JR          console_erase_to_end_of_line            

console_line_feed:            
	LD          DE,0x80     
	ADD         HL,DE       
	JR          LAB_ram_0677

console_backspace:            
	LD          A,L         
	AND         0x7f        
	RET         Z           
	DEC         HL          
	RET                      

console_right:                
	LD          A,L         
	AND         0x7f        
	CP          0x4f        
	RET         NC          
	INC         HL          
	RET                      

console_up:                   
	PUSH        HL          
	LD          DE,0xff80   
	ADD         HL,DE       
	PUSH        HL          
	OR          A           
	LD          DE,address_vram                         
	SBC         HL,DE       
	POP         HL          
	POP         DE          
	RET         NC          
	EX          DE,HL       
	RET                      

console_clear_screen:
	LD          HL,address_vram                         
	LD          DE,address_vram+1                       
	LD          BC,0xbff    
	LD          (HL),0x20                   
	LDIR                     
	LD          HL,address_vram                         
	RET                      

console_home_cursor:          
	LD          HL,address_vram                         
	RET                      

console_erase_to_end_of_screen:
	PUSH        HL          
	CALL        console_erase_to_end_of_line            
	LD          DE,0x80     
	LD          A,L         
	AND         0x80        
	LD          L,A         
	ADD         HL,DE       
	LD          A,0x3c      
	CP          H           
	JR          Z,LAB_ram_06fb                          
	LD          E,L         
	LD          D,H         
	OR          A           
	LD          HL,0x3bff   
	SBC         HL,DE       
	LD          C,L         
	LD          B,H         
	LD          H,D         
	LD          L,E         
	INC         DE          
	LD          (HL),0x20     
	LDIR                     
LAB_ram_06fb:                 
	POP         HL          
	RET                      

console_erase_to_end_of_line:
	LD          A,L         
	AND         0x7f        
	CP          0x4f        
	JR          C,console_erase_to_end_of_line_cont                          
	LD          (HL),0x20     
	RET                      
console_erase_to_end_of_line_cont:                 
	PUSH        HL          
	PUSH        HL          
	LD          A,L         
	AND         0x80        
	LD          L,A         
	LD          DE,0x004f     
	ADD         HL,DE       
	POP         DE          
	PUSH        DE          
	OR          A           
	SBC         HL,DE       
	LD          C,L         
	LD          B,H         
	POP         HL          
	LD          E,L         
	LD          D,H         
	INC         DE          
	LD          (HL),0x20     
	LDIR                     
	POP         HL          
	RET                      

set_hl_to_cursor_a_to_char_cleaned:
	LD          HL,(RAM_fe6e_cursor)                    
	LD          A,(HL)        
	CP          0xdf        
	LD          A,0x20      
	JR          NZ,LAB_ram_072d                         
	LD          (HL),A        
LAB_ram_072d:                 
	RES         0x7,(HL)      
	RET              

console_carriage_return:
	LD          A,L         
	AND         0x80        
	LD          L,A         
	RET

store_1_in_fe6c:              
	LD          A,0x1       
	LD          (DAT_ram_fe6c),A                        
	RET                      

LAB_ram_073b:                 
	LD          HL,0x7a2    
	PUSH        HL          
	LD          HL,0xfe6c   
	LD          (HL),0x0                    
	CP          0x1         
	JR          NZ,LAB_ram_0761                         
	LD          A,C         
	RES         0x7,A       
	CP          0x47        
	JR          Z,store_1f_in_fe70                      
	CP          0x41        
	JR          Z,store_7f_in_fe70                      
	CP          0x52        
	JR          Z,LAB_ram_07af                          
	CP          0x45        
	JR          Z,LAB_ram_07c1                          
	CP          0x3d        
	RET         NZ          
	LD          (HL),0x2                    
	RET                      

LAB_ram_0761:                 
	CP          0x2         
	JR          NZ,LAB_ram_076c                         
	LD          A,C         
	LD          (DAT_ram_fe6d),A                        
	LD          (HL),0x3                    
	RET                      
LAB_ram_076c:                 
	CP          0x3         
	RET         NZ          
	CALL        set_hl_to_cursor_a_to_char_cleaned      
	POP         HL          
	LD          HL,address_vram                         
	LD          A,C         
	SUB         0x20        

LAB_ram_0779:                 
	SUB         0x50        
	JR          NC,LAB_ram_0779                         
	ADD         A,0x50      
	LD          L,A         
	LD          A,(DAT_ram_fe6d)                        
	SUB         0x20        

LAB_ram_0785:                 
	SUB         0x18        
	JR          NC,LAB_ram_0785                         
	ADD         A,0x18      
	LD          DE,0x80     

LAB_ram_078e:                 
	JP          Z,LAB_ram_0795                          
	ADD         HL,DE       
	DEC         A           
	JR          LAB_ram_078e

LAB_ram_0795:                 
	LD          A,(HL)        
	CP          0x20        
	JR          NZ,LAB_ram_079c                         
	LD          A,0xdf      
LAB_ram_079c:                 
	SET         0x7,A       
	LD          (HL),A        
	LD          (RAM_fe6e_cursor),HL                    
	RET                      

store_1f_in_fe70:             
	LD          A,0x1f      
	LD          (DAT_ram_fe70),A                        
	RET                      

store_7f_in_fe70:             
	LD          A,0x7f      
	LD          (DAT_ram_fe70),A                        
	RET                      

LAB_ram_07af:                 
	POP         HL          
	CALL        FUN_ram_07d8
	PUSH        DE          
	JR          Z,LAB_ram_07b8                          
	LDIR                     
LAB_ram_07b8:                 
	LD          HL,0x3b80   
	CALL        console_erase_to_end_of_line            
	POP         HL          
	JR          LAB_ram_0795

LAB_ram_07c1:                 
	POP         HL          
	CALL        FUN_ram_07d8
	PUSH        DE          
	JR          Z,LAB_ram_07d0                          
	LD          DE,0x3bff   
	LD          HL,0x3b7f   
	LDDR                     
LAB_ram_07d0:                 
	POP         HL          
	PUSH        HL          
	CALL        console_erase_to_end_of_line            
	POP         HL          
	JR          LAB_ram_0795

FUN_ram_07d8:
	CALL        set_hl_to_cursor_a_to_char_cleaned      
	CALL        console_carriage_return                 
	PUSH        HL          
	EX          DE,HL       
	LD          HL,0x3b80   
	OR          A           
	SBC         HL,DE       
	LD          B,H         
	LD          C,L         
	POP         HL          
	PUSH        HL          
	LD          DE,0x80     
	ADD         HL,DE       
	POP         DE          
	LD          A,B         
	OR          C           
	RET                      

console_write_string:
	EX          (SP),HL                       
	LD          A,(HL)        
	INC         HL          
	EX          (SP),HL                       
	OR          A           
	RET         Z           
	LD          C,A         
	CALL        console_write_c                         
	JR          console_write_string              

filler:
	DB          0xff, 0x00


