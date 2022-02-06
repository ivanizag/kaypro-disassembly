
RST0:      EQU 0x0000
BDOS:      EQU 0x0005
    CON_READ:      EQU 0x01
    CON_WRITE:     EQU 0x02
    CON_RAWIO:     EQU 0x06
        CON_RAWIO_PEEK_CHAR: EQU 0xff
    CON_WRITESTR:  EQU 0x09
    DRV_SET:       EQU 0x0E

BIOS_config_byte:       EQU 0xfa34
BIOS_WRITE_fa2a:        EQU 0xfa2a
BIOS_SETSEC_fa21:       EQU 0xfa21
BIOS_SETTRK_fa1e:       EQU 0xfa1e
BIOS_SETDMA_fa24:       EQU 0xfa24

io_port_00_serial_baud_rate: EQU 0x00

bios_config_copy: EQU 0x2b9b ; replace with offset

changes_pending_yes:    EQU 0x00
changes_pending_no:     EQU 0xff

write_safe_yes:         EQU 0xff
write_safe_no:          EQU 0x00

; ASCII codes
no_key:       EQU 0x00
line_feed:    EQU 0x0a
form_feed:    EQU 0x0c
return_key:   EQU 0x0d
clear_screen: EQU 0x1a
escape:       EQU 0x1b
home:         EQU 0x1e

ORG 0x0100
    JP          main_menu_reset

move_cursor:
    ; Output an 0xff terminated string in DE to console
    LD          A, (DE)
    CP          0xff
    RET         Z
    PUSH        DE
    LD          C, CON_WRITE
    LD          E, A
    CALL        BDOS
    POP         DE
    INC         DE
    JR          move_cursor

main_menu_reset:
    ; The config will be stored in B:
    LD          A, 0x1
    LD          (disk_drive_destination), A
    ; Let's mark that there are no changes to save
    LD          A, changes_pending_no
    LD          (changes_pending), A
main_menu:
    ; Show the main menu and select an option
    LD          C,CON_WRITESTR
    LD          DE,msg_menu_header
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_main_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    PUSH        AF
    LD          C,CON_WRITESTR
    LD          DE,msg_new_line
    CALL        BDOS
    POP         AF
    CP          '1'
    JP          Z,menu_1_iobyte
    CP          '2'
    JP          Z,menu_2_write_safe
    CP          '3'
    JP          Z,menu_3_cursor_keys
    CP          '4'
    JP          Z,menu_4_keypad
    CP          '5'
    JP          Z,menu_5_baud_rate
    CP          escape
    JP          Z,menu_exit
    JP          main_menu


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION 5: Configure the serial port baud rate
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_5_baud_rate:
    ; Show the baud rate menu and select an option
    LD          C,CON_WRITESTR
    LD          DE,msg_menu_header
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_baud_rate_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    PUSH        AF
    LD          C,CON_WRITESTR
    LD          DE,msg_new_line
    CALL        BDOS
    POP         AF
    CP          '1'
    JP          Z,menu_5_baud_rate_1_help
    CP          escape
    JP          Z,main_menu
    CP          '2'
    JP          Z,menu_5_baud_rate_2_change
    JP          menu_5_baud_rate

menu_5_baud_rate_2_change:
    ; Show the baud rate change menu
    LD          C,CON_WRITESTR
    LD          DE,msg_baud_rate_change_menu
    CALL        BDOS
baud_rate_selection_reset:
    LD          A,0x0
    LD          (current_selection),A
    LD          C,CON_WRITESTR
    LD          DE,msg_form_feeds
    CALL        BDOS
baud_rate_selection:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,baud_rate_selection
    CP          escape
    JR          Z,menu_5_baud_rate
    CP          line_feed
    JP          Z,baud_rate_selection_next
    CP          return_key
    JR          NZ,baud_rate_selection
    ; We have a selection
    LD          A,(current_selection)
    CP          0x10
    JP          NC,baud_rate_selection
    ; The selection is valid
    ; Update the copy of the BIOS with the baud rate
    LD          (bios_content_baud_rate),A
    ; Configure the serial port
    OUT         (io_port_00_serial_baud_rate),A
    ; Mark that there are changes to save
    XOR         A
    LD          (changes_pending),A
    JP          menu_5_baud_rate

baud_rate_selection_next:
    ; Select the next baud rate
    LD          A,(current_selection)
    INC         A
    LD          (current_selection),A
    ; If we are past the last option, restart
    CP          0x11
    JR          Z,baud_rate_selection_reset
    LD          C,CON_WRITESTR
    LD          DE,msg_line_feed
    CALL        BDOS
    JR          baud_rate_selection

current_selection:
    ; Variable uses on all the sections
    db          0h

msg_baud_rate_change_menu:
    db          clear_screen
    db          "   50\r\n"
    db          "   75\r\n"
    db          "  110\t\tMove the cursor to the baud rate which\r\n"
    db          "  134.5\r\n"
    db          "  150\t\tyou want to use by typing the [LINE FEED] key.\r\n"
    db          "  300\r\n"
    db          "  600\r\n"
    db          " 1200\t\tWhen the cursor is at the rate you want\r\n"
    db          " 1800\r\n"
    db          " 2000\t\ttype the RETURN key and it will be set.\r\n"
    db          " 2400\r\n"
    db          " 3600\t\tThe new baud rate will be effective now.\r\n"
    db          " 4800\r\n"
    db          " 7200\r\n"
    db          " 9600\r\n"
    db          "19200\r\n"
    db          "Type [ESC] key to return to the previous menu (no changes)\r\n\r\n\n$"

msg_form_feeds:
    db          home,form_feed,form_feed,form_feed,form_feed,form_feed,"$"

msg_line_feed: 
    db          "\n$"

menu_5_baud_rate_1_help:
    ; Show the baud rate help screen
    LD          C,CON_WRITESTR
    LD          DE,msg_help_baud_rate
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_press_any_key
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    JP          menu_5_baud_rate

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION 4: Configure the keypad mappings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_4_keypad:
    ; Show the keypad menu and select an option
    LD          C,CON_WRITESTR
    LD          DE,msg_menu_header
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_keypad_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    PUSH        AF
    LD          C,CON_WRITESTR
    LD          DE,msg_new_line
    CALL        BDOS
    POP         AF
    CP          '1'
    JP          Z,menu_4_keypad_1_help
    CP          '2'
    JP          Z,menu_4_keypad_2_change
    CP          escape
    JP          Z,main_menu
    JP          menu_4_keypad

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; HEX INPUT:
; Used on options 3 and 4 to retreive an hex value
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

key_selection_input:
    ; Set the next key to map
    LD          A,(current_selection)
    INC         A
    LD          (current_selection),A
    ; Retrieve the HEX mapping
    CALL        key_edit_H
    ; Store the key if there is data
    JR          NZ,store_key_change
    ; Return to the sequence if we had a line feed
    CP          line_feed
    RET         Z
    ; We are done, back to the previous menu
    POP         HL
    LD          HL,(menu_escape_address)
    JP          (HL)

    ; unused
    db          0xC8

store_key_change:;
    ; Mark that there are changes to save
    LD          A,changes_pending_yes
    LD          (changes_pending),A
    ; Calculate the position on the BIOS copy to store the mapping
    ; HL has the section and we offset with the selection - 1
    LD          DE,0x0
    LD          A,(current_selection)
    DEC         A
    LD          E,A
    LD          HL,(key_config_base_address)
    ADD         HL,DE
    LD          A,C
    ; Store it
    LD          (HL),A
    RET

key_edit_H:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,key_edit_H
    CP          line_feed
    RET         Z
    CP          escape
    RET         Z
    ; If less than '0' ignore the key press
    CP          '0'
    JR          C,key_edit_H
    ; Is it '9' or less?
    CP          '9' + 1
    ; Yes, it is a decimal digit between 0 and 9
    JR          C,key_decimal_digit_H
    ; No, it must be A to F, if not we will ignore the key press
    ; To lowercase
    RES         0x5,A
    CP          'F' + 1
    JR          NC,key_edit_H
    CP          'A'
    JR          C,key_edit_H
    ; It is an hex digit, echo it
    PUSH        AF
    LD          C,CON_WRITE
    LD          E,A
    CALL        BDOS
    POP         AF
    ; substract 7 to have A-F just after 0-9
    SUB         'A' - '9' - 1
    JR          key_process_digit_H

key_decimal_digit_H:
    ; It is a decimal digit, echo it
    PUSH        AF
    LD          C,CON_WRITE
    LD          E,A
    CALL        BDOS
    POP         AF

key_process_digit_H:
    ; Convert the ASCII digit to a number 
    SUB         '0'
    ; Set it as the high nibble
    RLC         A
    RLC         A
    RLC         A
    RLC         A
    AND         0xf0
    PUSH        AF

key_edit_L:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,key_edit_L
    CP          line_feed
    JR          Z,key_edit_L_cancel
    CP          escape
    JR          NZ,key_edit_L_continue
key_edit_L_cancel:
    POP         HL
    RET
key_edit_L_continue:
    ; If less than '0' ignore the key press
    CP          '0'
    JR          C,key_edit_L
    ; Is it '9' or less?
    CP          '9' + 1
    ; Yes, it is a decimal digit between 0 and 9
    JR          C,key_decimal_digit_L
    ; No, it must be A to F, if not we will ignore the key press
    ; To lowercase
    RES         0x5,A
    CP          'F' + 1
    JR          NC,key_edit_L
    CP          'A'
    JR          C,key_edit_L
    PUSH        AF
    ; It is an hex digit, echo it
    LD          C,CON_WRITE
    LD          E,A
    CALL        BDOS
    POP         AF
    ; substract 7 to have A-F just after 0-9
    SUB         'A' - '9' - 1
    JR          key_process_digit_L

key_decimal_digit_L:
    ; It is a decimal digit, echo it
    PUSH        AF
    LD          C,CON_WRITE
    LD          E,A
    CALL        BDOS
    POP         AF

key_process_digit_L:
    ; Convert the ASCII digit to a number
    SUB         '0'
    ; Set it as the low nibble
    AND         0xf
    LD          C,A
    POP         AF
    OR          C
    LD          C,A
    RET         NZ
    INC         A
    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION 4: Configure the keypad mappings (continued)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_4_keypad_2_change:
    ; Set the address of the previous menu
    LD          HL,menu_4_keypad
    LD          (menu_escape_address),HL
    ; Set the address of the key mapping to change
    LD          HL,bios_content_keypad_map
    LD          (key_config_base_address),HL
    ; Show the menu
    LD          C,CON_WRITESTR
    LD          DE,msg_keypad_change_menu
    CALL        BDOS

keypad_sequence:
    ; Move through the keypad sequence
    LD          A,0x0
    LD          (current_selection),A
    LD          DE,keypad_options_positions
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+5
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+10
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+15
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+20
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+25
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+30
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+35
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+40
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+45
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+50
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+55
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+60
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+65
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,keypad_options_positions+70
    CALL        move_cursor
keypad_selection_esc:
    ; The cursor is on the top of the ESC option
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,keypad_selection_esc
    CP          escape
    JP          Z,menu_4_keypad
    CP          line_feed
    JR          NZ,keypad_selection_esc
    ; Restart the sequence
    JP          keypad_sequence

msg_keypad_change_menu:
    db          clear_screen
    db          "-----------------------------\tMove the cursor to the key you wish\r\n"
    db          ":      :      :      :      :\r\n"
    db          ":   7  :   8  :   9  :   -  :\tto change. Use the [LINE FEED] key.\r\n"
    db          ":      :      :      :      :\r\n"
    db          ":  37  :  38  :  39  :  2D  :\tThe default HEXADECIMAL code will be\r\n"
    db          ";------;------;------;------:\r\n"
    db          ":      :      :      :      :\tthe number which is flashing.\r\n"
    db          ":   4  :   5  :   6  :   ,  :\r\n"
    db          ":      :      :      :      :\r\n"
    db          ":  34  :  35  :  36  :  2C  :\tWhen you reach the key you wish to change.\r\n"
    db          ":------:------:------:------:\r\n"
    db          ":      :      :      :      :\tType in the new HEXADECIMAL code.\r\n"
    db          ":   1  :   2  :   3  :      :\r\n"
    db          ":      :      :      :      :\r\n"
    db          ":  31  :  32  :  33  : ENTER:\t(* NOTE: you must enter both digits *)\r\n"
    db          ":------:------:------:      :\r\n"
    db          ":             :      :  0D  :\t(*       to change the code.        *)\r\n"
    db          ":      0      :   .  :      :\r\n"
    db          ":             :      :      :\r\n"
    db          ":     30      :  2E  :      : Type the [ESC] key to return to the previous menu\r\n"
    db          "-----------------------------\r\n$"
keypad_options_positions:
    db          0x1B,"=3&",0xFF
    db          0x1B,"=.#",0xFF
    db          0x1B,"=.*",0xFF
    db          0x1B,"=.1",0xFF
    db          0x1B,"=)#",0xFF
    db          0x1B,"=)*",0xFF
    db          0x1B,"=)1",0xFF
    db          0x1B,"=$#",0xFF
    db          0x1B,"=$*",0xFF
    db          0x1B,"=$1",0xFF
    db          0x1B,"=$8",0xFF
    db          0x1B,"=)8",0xFF
    db          0x1B,"=08",0xFF
    db          0x1B,"=31",0xFF
    db          0x1B,"=3I",0xFF

menu_4_keypad_1_help:
    ; Show the help for keypad configuration
    LD          C,CON_WRITESTR
    LD          DE,msg_help_keypad
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_press_any_key
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    JP          menu_4_keypad

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION 3: Configure the corsor keys mappings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_3_cursor_keys:
    ; Show the cursor keys menu and select the option
    LD          C,CON_WRITESTR
    LD          DE,msg_menu_header
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_cursor_keys_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    PUSH        AF
    LD          C,CON_WRITESTR
    LD          DE,msg_new_line
    CALL        BDOS
    POP         AF
    CP          '1'
    JP          Z,menu_3_cursor_keys_1_help
    CP          escape
    JP          Z,main_menu
    CP          '2'
    JP          Z,menu_3_cursor_keys_2_change
    JR          menu_3_cursor_keys

menu_3_cursor_keys_2_change:
    ; Set the address of the keypad mapping to change
    LD          HL,bios_content_arrow_key_map
    LD          (key_config_base_address),HL
    ; Set the address of the previous menu
    LD          HL,menu_3_cursor_keys
    LD          (menu_escape_address),HL
    ; Show the menu
    LD          C,CON_WRITESTR
    LD          DE,msg_cursor_keys_change_menu
    CALL        BDOS

cursor_keys_sequence:
    ; Move through the cursor keys sequence
    LD          A,0x0
    LD          (current_selection),A
    LD          DE,cursor_keys_options_positions
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,cursor_keys_options_positions+5
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,cursor_keys_options_positions+10
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,cursor_keys_options_positions+15
    CALL        move_cursor
    CALL        key_selection_input
    LD          DE,cursor_keys_options_positions+20
    CALL        move_cursor
cursor_keys_selection_esc:
    ; The cursor is on top of the ESC option
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,cursor_keys_selection_esc
    CP          line_feed
    JP          Z,cursor_keys_sequence
    CP          escape
    JR          NZ,cursor_keys_selection_esc
    JP          menu_3_cursor_keys
    ; Restart the sequence
    JP          cursor_keys_sequence

menu_3_cursor_keys_1_help:
    ; Show the help for cursor keys configuration
    LD          C,CON_WRITESTR
    LD          DE,msg_help_cursor_keys
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_press_any_key
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    JP          menu_3_cursor_keys

msg_cursor_keys_change_menu:
    db          clear_screen
    db          "\r\n"
    db          "\r\n"
    db          "            ---------------------------------\r\n"
    db          "            :       :       :       :       :\r\n"
    db          "            :   ^   :   :   :  <-   :  ->   :\r\n"
    db          "            :   :   :   v   :       :       :\r\n"
    db          "            :       :       :       :       :\r\n"
    db          "            :  0B   :  0A   :  08   :  0C   :\r\n"
    db          "            ---------------------------------\r\n"
    db          "\r\n"
    db          "\r\n"
    db          "       Type the [ESC] key to return to the previous menu.\r\n"
    db          "\r\n"
    db          " Move the cursor to the key which you wish to change by pressing\r\n"
    db          " the [LINE FEED] key. The default HEXADECIMAL code will be the flashing number.\r\n"
    db          " Type the new HEXADECIMAL number you wish to assign to the key.\r\n"
    db          "\r\n"
    db          " You must type both digits to effect the change.\r\n\r\n$"

 cursor_keys_options_positions:
    db          0x1B,"='/",0xFF
    db          0x1B,"='7",0xFF
    db          0x1B,"='?",0xFF
    db          0x1B,"='G",0xFF
    db          0x1B,"=+2",0xFF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION 2: Configure the write safe flag
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_2_write_safe:
    ; Show the menu and select the option
    LD          C,CON_WRITESTR
    LD          DE,msg_menu_header
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_write_safe_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    PUSH        AF
    LD          C,CON_WRITESTR
    LD          DE,msg_new_line
    CALL        BDOS
    POP         AF
    CP          '1'
    JP          Z,menu_2_write_safe_1_help
    CP          '2'
    JP          Z,menu_2_write_safe_2_change
    CP          escape
    JP          Z,main_menu
    JP          menu_2_write_safe

menu_2_write_safe_2_change:
    ; Show the change menu
    LD          C,CON_WRITESTR
    LD          DE,msg_write_safe_change_menu
    CALL        BDOS
    ; There is a sequence of three states: YES, NO and ESC

write_safe_yes_option:
    ; We are on the YES option
    LD          DE,write_safe_options_position_yes
    CALL        move_cursor
write_safe_yes_option_loop:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,write_safe_yes_option_loop
    CP          line_feed
    ; Line feed: go to the NO option
    JR          Z,write_safe_no_option
    CP          escape
    ; Escape: go back to the menu
    JP          Z,menu_2_write_safe
    CP          return_key
    JR          NZ,write_safe_yes_option
    ; Return: select the YES option
    LD          A,write_safe_yes
    LD          (bios_config_copy),A
    LD          A,changes_pending_yes
    LD          (changes_pending),A
    JP          menu_2_write_safe

write_safe_no_option:
    ; We are on the NO option
    LD          DE,write_safe_options_position_no
    CALL        move_cursor
write_safe_no_option_loop:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,write_safe_no_option_loop
    CP          line_feed
    ; Line feed go to the ESC option
    JR          Z,write_safe_esc_option
    CP          escape
    ; Escape: go back to the menu
    JR          Z,menu_2_write_safe
    CP          return_key
    JR          NZ,write_safe_no_option
    ; Return: select the NO option
    LD          A,write_safe_no ; = changes_pending_yes
    LD          (bios_config_copy),A
    LD          (changes_pending),A
    JP          menu_2_write_safe

write_safe_esc_option:
    ; We are on the ESC option
    LD          DE,write_safe_options_position_esc
    CALL        move_cursor
write_safe_esc_option_loop:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,write_safe_esc_option_loop
    CP          escape
    ; Escape: go back to the menu
    JP          Z,menu_2_write_safe
    CP          line_feed
    JP          NZ,write_safe_esc_option
    ; Line feed: go to the YES option
    JP          write_safe_yes_option

menu_2_write_safe_1_help:
    ; Show the help for write safe flag
    LD          C,CON_WRITESTR
    LD          DE,msg_help_write_safe
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_press_any_key
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    JP          menu_2_write_safe

msg_write_safe_change_menu:
    db          clear_screen
    db          "\r\n"
    db          "\r\n"
    db          "\r\n"
    db          "Yes I want Write Safe enabeled.\r\n"
    db          "\r\n"
    db          "No do not enable Write Safe.\tThis is the default mode on your KAYPRO II .\r\n"
    db          "\r\n"
    db          "Type the [ESC] key to return to the previous menu.\r\n"
    db          "\r\n"
    db          "\r\n"
    db          "Use the [LINE FEED] key to move the cursor to the mode\r\n"
    db          "which you wish to use and then type the [RETURN] key to\r\n"
    db          "enter your choice.\r\n"
    db          "\r\n"
    db          "**** PLEASE read the help file before you enable Write Safe. ****\r\n"
    db          "****        If you do not understand it ASK your dealer.     ****\r\n$"

write_safe_options_position_yes:
    db          0x1B,"=# ",0xFF
write_safe_options_position_no:
    db          0x1B,"=% ",0xFF
write_safe_options_position_esc:
    db          0x1B,"='+",0xFF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION 1: Configure the IOBYTE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_1_iobyte:
    ; Show the menu and select the option
    LD          C,CON_WRITESTR
    LD          DE,msg_menu_header
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_iobyte_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    PUSH        AF
    LD          C,CON_WRITESTR
    LD          DE,msg_new_line
    CALL        BDOS
    POP         AF
    CP          '1'
    JP          Z,menu_1_iobyte_1_help
    CP          '2'
    JP          Z,menu_1_iobyte_2_change
    CP          escape
    JP          Z,main_menu
    JP          menu_1_iobyte

menu_1_iobyte_2_change:
    LD          C,CON_WRITESTR
    LD          DE,msg_iobyte_change_menu
    CALL        BDOS
    ; Set to the address of the IOBYTE on the BIOS copy
    LD          HL,bios_content_io_byte
    LD          (key_config_base_address),HL
    ; Set the address of the previous menu
    LD          HL,menu_1_iobyte
    LD          (menu_escape_address),HL
iobyte_sequence_CON:
    LD          A,0x0
    LD          (current_selection),A
    ; Two options to set CON
    LD          DE,iobyte_options_position_CON_CRT
    CALL        move_cursor
    CALL        iobyte_selection_input
    LD          DE,iobyte_options_position_CON_TTY
    CALL        move_cursor
    CALL        iobyte_selection_input
iobyte_sequence_LST:
    ; Two options to set LST
    LD          DE,iobyte_options_position_LST_LPT
    CALL        move_cursor
    CALL        iobyte_selection_input
    LD          DE,iobyte_options_position_LST_TTY
    CALL        move_cursor
    CALL        iobyte_selection_input
iobyte_sequence_esc:
    LD          DE,iobyte_options_position_esc
    CALL        move_cursor

iobyte_selection_esc:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,iobyte_selection_esc
    CP          escape
    ; Escape: go back to the menu
    JP          Z,menu_1_iobyte
    CP          line_feed
    ; Line feed: restart the sequence
    JR          NZ,iobyte_selection_esc
    JP          iobyte_sequence_CON

iobyte_selection_input:
    LD          C,CON_RAWIO
    LD          E,CON_RAWIO_PEEK_CHAR
    CALL        BDOS
    CP          no_key
    JR          Z,iobyte_selection_input
    CP          escape
    ; No escape, process the key press
    JR          NZ,iobyte_process_key
    ; Escape: go back to the menu
    POP         HL
    LD          HL,(menu_escape_address)
    JP          (HL)

iobyte_process_key:
    CP          line_feed
    JR          NZ,iobyte_process_key_continue
    ; Line feed: continue the sequence
    LD          A,(current_selection)
    INC         A
    LD          (current_selection),A
    RET
iobyte_process_key_continue:
    CP          return_key
    JR          NZ,iobyte_selection_input
    ; Return key: select the option
    LD          A,changes_pending_yes
    LD          (changes_pending),A
    ; Calculate the address of the function to call. The
    ; address is in:
    ;      selection_id*2 + iobyte_options_handlers
    LD          A,(current_selection)
    ADD         A,A ; A = A*2
    LD          DE,0x0
    LD          E,A
    LD          HL,iobyte_options_handlers
    ADD         HL,DE
    ; Read low byte
    LD          E,(HL)
    ; Read high byte
    INC         HL
    LD          D,(HL)
    EX          DE,HL
    LD          DE,(key_config_base_address)
    JP          (HL)

iobyte_options_handlers:
    dw          iobyte_option_handler_CON_CRT
    dw          iobyte_option_handler_CON_TTY
    dw          iobyte_option_handler_LST_LPT
    dw          iobyte_option_handler_LST_TTY

iobyte_option_handler_CON_CRT:
    LD          A,(DE)
    ; iobyte CONSOLE = 01-CRT
    RES         0x1,A
    SET         0x0,A
    LD          (DE),A
    ; Continue on the LST options
    LD          HL,iobyte_sequence_LST
    LD          A,0x2
    LD          (current_selection),A
    POP         DE
    JP          (HL)

iobyte_option_handler_CON_TTY:
    LD          A,(DE)
    ; iobyte CONSOLE = 00-TTY
    RES         0x0,A
    RES         0x1,A
    LD          (DE),A
    ; Continue on the LST options (just the next one)
    LD          A,(current_selection)
    INC         A
    LD          (current_selection),A
    RET

iobyte_option_handler_LST_LPT:
    LD          A,(DE)
    ; iobyte LIST = 10-LPT
    RES         0x6,A
    SET         0x7,A
    LD          (DE),A
    ; Continue on the ESC option
    LD          HL,iobyte_sequence_esc
    JP          (HL)

iobyte_option_handler_LST_TTY:
    LD          A,(DE)
    ; iobyte LIST = 00-TTY
    RES         0x7,A
    RES         0x6,A
    LD          (DE),A
    ; Continue on the ESC option
    RET

menu_1_iobyte_1_help:
    ; Display the help
    LD          C,CON_WRITESTR
    LD          DE,msg_help_iobyte
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_press_any_key
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    JP          menu_1_iobyte

msg_iobyte_change_menu:
    db          clear_screen
    db          "\r\n"
    db          "\r\n"
    db          "\tDefault settings\tPosibile changes\r\n"
    db          "\t----------------\t----------------\r\n"
    db          "\r\n"
    db          "\tCON:=CRT:\t\tCON:=TTY:\tType the [LINE FEED] key to \r\n"
    db          "\tLST:=LPT:\t\tLST:=TTY:\tmove the cursor to the mode \r\n"
    db          "\tPUN:=TTY:\t\t- none -\tyou wish to select.\r\n"
    db          "\tRDR:=TTY:\t\t- none -\tThen the RETURN key to enter\r\n"
    db          "\t\t\t\t\t\tyour selection.\r\n"
    db          "\tType the [ESC] key to return to the previous menu.\r\n"
    db          "\r\n"
    db          "* CON: If you chose CON:=TTY: then all input and output  will be through the\r\n"
    db          "\tserial connector on the back of your KAYPRO II instead of through the\r\n"
    db          "\tkeyboard and the CRT.\r\n"
    db          "\r\n"
    db          "\r\n"
    db          "* LST:\tThis setting will decide wether the output directed at a printer\r\n"
    db          "\twill go through the LPT: (parallel connector) or to the\r\n"
    db          "\tTTY: (serial connector).\r\n$"

iobyte_options_position_CON_CRT:
    db          0x1B,"=%,",0xFF
iobyte_options_position_CON_TTY:
    db          0x1B,"=%D",0xFF
iobyte_options_position_LST_LPT:
    db          0x1B,"=&,",0xFF
iobyte_options_position_LST_TTY:
    db          0x1B,"=&D",0xFF
iobyte_options_position_esc:
    db          0x1B,"=*3",0xFF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXIT AND SAVE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menu_exit:
    LD          A,(changes_pending)
    CP          changes_pending_no
    ; If changes are pending, ask the user if he wants to save them
    JP          NZ,save_changes_menu

exit_without_saving_changes:
    ; Reset the BIOS config in memory (not on disk)
    ; Why?
    LD          A,write_safe_no
    LD          (BIOS_config_byte),A
    JP          Z,RST0

save_changes_menu:
    ; Show the YES/NO options
    LD          C,CON_WRITESTR
    LD          DE,msg_save_changes_menu
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    ; To uppercase
    RES         0x5,A
    CP          'N'
    ; If NO, then exit without saving changes
    JP          Z,exit_without_saving_changes
    CP          'Y'
    JR          NZ,save_changes_menu
    ; If YES, then save changes
    ; Set write safe mode in memory to make sure this save is safe
    LD          A,write_safe_yes
    LD          (BIOS_config_byte),A
    ; Set drive (B: per the initialization)
    LD          C,DRV_SET
    LD          A,(disk_drive_destination)
    LD          E,A
    CALL        BDOS
    ; Save the updated BIOS to track 1, sectors 15 to 18
    LD          HL,bios_content
    LD          (data_to_write_address),HL
    LD          BC,0x1 ; Track 1
    LD          (disk_track_destination),BC
    LD          BC,0x15 ; SEctor 15
    LD          (disk_sector_destination),BC
    LD          A,0x4 ; Four sectors, 512 bytes
    LD          (sectors_to_write),A
    LD          HL,0x80 ; Each sector is 128 bytes
    LD          (logical_sector_size),HL
write_sector:
    LD          BC,(disk_track_destination)
    CALL        BIOS_SETTRK_fa1e
    LD          BC,(data_to_write_address)
    CALL        BIOS_SETDMA_fa24
    LD          BC,(disk_sector_destination)
    CALL        BIOS_SETSEC_fa21
    LD          C,0x0
    CALL        BIOS_WRITE_fa2a
    CP          0x0
    ; If successful, proceed with the next sector
    JR          Z,write_sector_next
    ; Error
    ; Tell the user
    LD          C,CON_WRITESTR
    LD          DE,msg_disk_error
    CALL        BDOS
    LD          C,CON_WRITESTR
    LD          DE,msg_press_any_key
    CALL        BDOS
    LD          C,CON_READ
    CALL        BDOS
    ; Revert the write safe in memory
    LD          A,write_safe_no
    LD          (BIOS_config_byte),A
    ; Back to the main menu
    JP          main_menu_reset

write_sector_next:
    ; Point to the next 128 bytes
    LD          HL,(data_to_write_address)
    LD          DE,(logical_sector_size)
    ADD         HL,DE
    ; Point to the next sector
    LD          (data_to_write_address),HL
    LD          A,(disk_sector_destination)
    INC         A
    LD          (disk_sector_destination),A
    ; Reduce by 1 the sectors pending to write
    LD          A,(sectors_to_write)
    DEC         A
    LD          (sectors_to_write),A
    CP          0x0
    ; If there are still sectors to write, cotinue writing
    JP          NZ,write_sector
    ; We are done
    LD          C,CON_WRITESTR
    LD          DE,msg_done
    CALL        BDOS
    ; Revert the write safe in memory
    LD          A,write_safe_no
    LD          (BIOS_config_byte),A
    ; Back to the main menu
    JP          main_menu_reset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VARIABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

changes_pending:
    db          0h
disk_drive_destination:
    db          0h
data_to_write_address:
    dw          0h
key_config_base_address:
    dw          0h
disk_track_destination:
    dw          0h
disk_sector_destination:
    dw          0h
sectors_to_write:
    db          0h
menu_escape_address:
    dw          0h
logical_sector_size:
    dw          0h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MESSAGES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

msg_new_line:
    db          "\r\n$"
msg_done:
    db          "\r\nDONE WITH CONFIGURATION\r\n$"
msg_press_any_key:
    db          "\r\nPlease type any key to continue$"
msg_disk_error:
    db          "\r\n*** I can't write to your disk ***\r\n$"

msg_menu_header:
    db          clear_screen
    db          "\r\n"
    db          "\r\n"
    db          "KAYPRO II  CONFIGURATION PROGRAM   Version 1.1\r\n"
    db          "-----------------------------------------------\r\n"
    db          "\r\n"
    db          "CHOICES\r\n"
    db          "-------\r\n\r\n$"

msg_main_menu:
    db          "1 --------> I/O Byte cold boot defaults\r\n"
    db          "2 --------> Write Safe flag\r\n"
    db          "3 --------> Cursor Keys definitions\r\n"
    db          "4 --------> Numerical keypad definitions\r\n"
    db          "5 --------> Baud rate\r\n"
    db          "\r\n"
    db          "[ESC] key ----> EXIT this program and return to CP/M\r\n"
    db          "\r\n"
    db          "(* NOTE: Anything not changed will contain its default value. *)\r\n"
    db          "\r\n"
    db          "Any changes that this program can make will only affect the disk in drive B.\r\n"
    db          "These changes will not be seen until you move the disk to drive A and\r\n"
    db          "push the RESET switch (Cold Boot) or turn the power off and on,\r\n"
    db          "EXCEPT selection '5' (Baud rate) which will have an immediate effect.\r\n"
    db          "Upon exiting this program you will be asked whether you want to apply\r\n"
    db          "the changes to the disk in drive B.\r\n"
    db          "Please enter '1' or '2' or '3' or '4' or '5' or [ESC] key ====>$"

msg_iobyte_menu:
    db          "1 --------> Help (I/O Byte definitions)\r\n"
    db          "\r\n"
    db          "2 --------> Change the I/O Byte\r\n"
    db          "\r\n"
    db          "[ESC] key ----> Return to main menu\r\n"
    db          "\r\n"
    db          "Please enter '1' or '2' or [ESC] key ==========>$"

msg_write_safe_menu:
    db          "1 --------> Help (Write safe flag definitions)\r\n"
    db          "\r\n"
    db          "2 --------> Change the write safe flag\r\n"
    db          "\r\n"
    db          "[ESC] key ----> Return to main menu\r\n"
    db          "\r\n"
    db          "Please enter '1' or '2' or [ESC] key ==========>$"

msg_cursor_keys_menu:
    db          "1 --------> Help (Cursor key definitions)\r\n"
    db          "\r\n"
    db          "2 --------> Change the Cursor key settings\r\n"
    db          "\r\n"
    db          "[ESC] key ----> Return to main menu\r\n"
    db          "\r\n"
    db          "Please enter '1' or '2' or [ESC] key ==========>$"

msg_keypad_menu:
    db          "1 --------> Help (Numerical keypad definitions)\r\n"
    db          "\r\n"
    db          "2 --------> Change the Numerical keypad settings\r\n"
    db          "\r\n"
    db          "[ESC] key ----> Return to main menu\r\n"
    db          "\r\n"
    db          "Please enter '1' or '2' or [ESC] key ==========>$"

msg_baud_rate_menu:
    db          "1 --------> Help (Baud rate definitions)\r\n"
    db          "\r\n"
    db          "2 --------> Change the Baud rate\r\n"
    db          "\r\n"
    db          "[ESC] key ----> Return to main menu\r\n"
    db          "\r\n"
    db          "Please enter '1' or '2' or [ESC] key ==========>$"

msg_save_changes_menu:
    db          "\r\n"
    db          "Y----------> procede to update the disk in drive B\r\n"
    db          "N----------> not ready, EXIT TO CP/M\r\n"
    db          "\r\n"
    db          "Please type (Y) or (N) ====>$"

msg_help_keypad:
    db          clear_screen
    db          "\r\nOn the right hand side of your KAYPRO II keyboard there is a group of\r\n"
    db          "fourteen keys, labeled:                 7 8 9 -\r\n"
    db          "\t\t\t\t\t4 5 6 ,\r\n"
    db          "\t\t\t\t\t1 2 3 enter\r\n"
    db          "\t\t\t\t\t 0  .\r\n"
    db          "\r\n"
    db          "These fourteen keys each produce a unique code when typed.\r\n"
    db          "In some situations it may be useful to have one or more keys  \r\n"
    db          "provide a special function, such as in an application\r\n"
    db          "program requiring choices from a menu.\r\n"
    db          "\tThis portion of the CONFIGURATION program allows you to set the\r\n"
    db          "codes which will be produced by these fourteen keys.\r\n\r\n\n\n\n$"

msg_help_baud_rate:
    db          clear_screen
    db          "\r\n"
    db          "Your KAYPRO II computer has a serial port with which you may communicate\r\n"
    db          "with the outside world. This serial port is most often referred to as\r\n"
    db          "RS-232. In using RS-232 both the computer and the external device\r\n"
    db          "must be set at the same baud rate (the speed at which data travels)\r\n"
    db          "\r\n"
    db          "\tYour KAYPRO II is capable of the following baud rates:\r\n"
    db          "   50\t\t-not used very often\r\n"
    db          "   75\t\t-not used very often\r\n"
    db          "  110\t\t-used with slower printers\r\n"
    db          "  134.5         -used with some IBM printers\r\n"
    db          "  150\t\t-not used very often\r\n"
    db          "  300\t\t-very common (default on your KAYPRO II on reset)\r\n"
    db          "  600\t\t-not used very often\r\n"
    db          " 1200\t\t-used with many printers\r\n"
    db          " 1800\t\t-not used very often\r\n"
    db          " 2000\t\t-not used very often\r\n"
    db          " 2400\t\t-not used very often\r\n"
    db          " 3600\t\t-not used very often\r\n"
    db          " 4800\t\t-higher rate for faster printers\r\n"
    db          " 7200\t\t-not used very often\r\n"
    db          " 9600\t\t-highest rate normally used\r\n"
    db          "19200\t\t-very high rate (for special purposes)\r\n"
    db          "(* NOTE: the PRESENT baud rate remains in effect until the next RESET *)$"

msg_help_iobyte:
    db          clear_screen
    db          "\r\n"
    db          "In order to understand this command you should read the CP/M manual\r\n"
    db          "\"AN INTRODUCTION TO CP/M FEATURES AND FACILITIES\", the STAT command\r\n"
    db          "logical and physical devices. The logical CP/M devices are: CON: LST:\r\n"
    db          "RDR: and PUN:. The physical devices for the KAYPRO computer are:\r\n"
    db          "\n\tCRT:\tVideo and Keyboard\r\n"
    db          "\tTTY:\tSerial port (note the connector must be wired as in the manual)\r\n"
    db          "\tLPT:\tCentronics port\r\n"
    db          "\tUL1:\tThis is the same as TTY: above\r\n"
    db          "\tPTP:\tThis is the same as TTY: above\r\n"
    db          "\nPossible logical to physical assignments are:\r\n"
    db          "\n\tCON: =  TTY: or CRT:\r\n"
    db          "\tRDR: =  TTY:\r\n"
    db          "\tPUN: =  TTY: or CRT: or LPT: or UL1:\r\n"
    db          "\nBEFORE using this option try it with the STAT command in CP/M.\r\n\r\n$"

msg_help_write_safe:
    db          clear_screen
    db          "\r\n"
    db          "Your KAYPRO computer comes with a special \"Write Safe\" option that corrects\r\n"
    db          "a problem with CP/M when running with SOME application programs. It is not\r\n"
    db          "possible to make the following description nontechnical. If you do not under-\r\n"
    db          "stand it, ask your dealer. The wrong setting of the \"Write Safe\" flag may cause\r\n"
    db          "the IRREVOCABLE LOSS OF DATA AND OR PROGRAM(S).\r\n"
    db          "\nThe KAYPRO computer uses deblocking. When a disk write operation is\r\n"
    db          "immediately followed by a warm boot, the deblocking buffer may not be\r\n"
    db          "written to the disk. This is not a likely sequence of events. Most programs\r\n"
    db          "when finished writing to a file, will close it. ALL directory operations force\r\n"
    db          "the deblock buffer to disk on write. The \"Write Safe\" flag tells the BIOS\r\n"
    db          "that ALL disk operations are directory type. This forces the buffer to the\r\n"
    db          "disk. The price is performance, as \"Write Safe\" will slow the computer down\r\n"
    db          "from 2 to 4 times when writing to the disk. \"Write Safe\" is not a panacea\r\n"
    db          "for system or program problems. The chance you will need it is rare.\r\n\n\r\n$"

msg_help_cursor_keys:
    db          clear_screen
    db          "\r\n"
    db          "It is not possible to make the following discription nontechnical.\r\n"
    db          "If you do not understand it please ask your dealer.\r\n\n"
    db          "Your KAYPRO II computer comes with four arrow keys, they are at the upper right\r\n"
    db          "of the main keyboard. They are usually referred to as CURSOR keys. They are \r\n"
    db          "used in programs such as SELECT to move the cursor. These keys produce codes\r\n"
    db          "that are recognized by applications programs. The codes that they produce may\r\n"
    db          "or may not be the codes that an application you supply wants. The codes sent\r\n"
    db          "by the keyboard are unique, MSB set. The BIOS translates the keyboard codes\r\n"
    db          "using a table in the BIOS. This option of the configure program allows you\r\n"
    db          "to change the values in this table and record it on the disk. The memory\r\n"
    db          "image is not changed until you cold boot (reset).\r\n\n\r\n$"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BIOS: Local copy of the BIOS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This are the BIOS content for CPM 2.2f, US version with
; the KAYPRO II welcome message. See bios_22.s
bios_content:
    ;code
    db          0xC3,0x48,0xFA,0xC3,0x99,0xFA,0xC3,0xF3,0xFA,0xC3,0x09,0xFB,0xC3,0x2F,0xFB,0xC3
    db          0x48,0xFB,0xC3,0x43,0xFB,0xC3,0x3E,0xFB,0xC3,0x7C,0xFB,0xC3,0x80,0xFB,0xC3,0x84
    db          0xFB,0xC3,0x88,0xFB,0xC3,0x8C,0xFB,0xC3,0x90,0xFB,0xC3,0x98,0xFB,0xC3,0x65,0xFB
    db          0xC3,0xA8,0xFB

bios_content_io_byte:
    db          0x81
bios_content_config_byte:
    db          0x00
bios_content_arrow_key_map:
    db          0x0B,0x0A,0x08,0x0C
bios_content_keypad_map:
    db          0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x2D,0x2C,0x0D,0x2E
bios_content_baud_rate:
    db           0x05
    ; more code
    db          0xCD,0x78,0xFB,0xAF,0x32,0x04,0x00,0x3A
    db          0x33,0xFA,0x32,0x03,0x00,0x3A,0x47,0xFA,0xD3,0x00,0xCD,0xCF,0xFB
bios_content_welcome_message:
    db          clear_screen,"\r\nKAYPRO II 64k CP/M vers 2.2\r\n",0
    ; more code
    db          0x3E,0xC3
    db          0x21,0x03,0xFA,0x32,0x00,0x00,0x22,0x01,0x00,0x21,0x06,0xEC,0x32,0x05,0x00,0x22
    db          0x06,0x00,0x3A,0x04,0x00,0x4F,0xC3,0x00,0xE4,0xCD,0x78,0xFB,0xCD,0xCF,0xFB,0x0D
    db          0x0A,0x57,0x61,0x72,0x6D,0x20,0x42,0x6F,0x6F,0x74,0x0D,0x0A,0x00,0x31,0x00,0x01
    db          0x0E,0x00,0xCD,0x80,0xFB,0x01,0x00,0x00,0xCD,0x84,0xFB,0x21,0x00,0xE4,0x22,0x14
    db          0xFC,0x01,0x01,0x2C,0xC5,0xCD,0x88,0xFB,0xCD,0x90,0xFB,0xC1,0xB7,0x20,0xDE,0x2A
    db          0x14,0xFC,0x11,0x80,0x00,0x19,0x22,0x14,0xFC,0xAF,0x32,0x07,0xE4,0x05,0xCA,0x7E
    db          0xFA,0x0C,0x3E,0x28,0xB9,0xC2,0xC4,0xFA,0x0E,0x10,0xC5,0x0E,0x01,0xCD,0x84,0xFB
    db          0xC1,0x18,0xD1,0x21,0xDB,0xFB,0x34,0xCC,0x28,0xFB,0x3A,0x03,0x00,0xE6,0x03,0x2E
    db          0x33,0xCA,0xAC,0xFB,0x2E,0x2A,0xC3,0xAC,0xFB,0xCD,0x28,0xFB,0x3A,0x03,0x00,0xE6
    db          0x03,0x2E,0x36,0xCA,0xAC,0xFB,0x2E,0x2D,0xCD,0xAC,0xFB,0xB7,0xF0,0xE6,0x1F,0x21
    db          0x35,0xFA,0x4F,0x06,0x00,0x09,0x7E,0xC9,0xDB,0x1C,0xCB,0xF7,0xD3,0x1C,0xC9,0x3A
    db          0x03,0x00,0xE6,0x03,0x2E,0x39,0xCA,0xAC,0xFB,0x2E,0x45,0xC3,0xAC,0xFB,0x2E,0x36
    db          0xC3,0xAC,0xFB,0x2E,0x39,0xC3,0xAC,0xFB,0x3A,0x03,0x00,0xE6,0xC0,0x2E,0x39,0xCA
    db          0xAC,0xFB,0x2E,0x3F,0xFE,0x80,0xCA,0xAC,0xFB,0x2E,0x45,0xFE,0x40,0xCA,0xAC,0xFB
    db          0x2E,0x39,0xC3,0xAC,0xFB,0x3A,0x03,0x00,0xE6,0xC0,0x2E,0x42,0xCA,0xAC,0xFB,0x2E
    db          0x3C,0xFE,0x80,0xCA,0xAC,0xFB,0xAF,0xC9,0x2E,0x03,0x18,0x30,0x2E,0x0C,0x18,0x2C
    db          0x2E,0x0F,0x18,0x28,0x2E,0x12,0x18,0x24,0x2E,0x15,0x18,0x20,0x2E,0x18,0x18,0x1C
    db          0xAF,0x32,0xDB,0xFB,0x2E,0x1B,0x18,0x14,0xAF,0x32,0xDB,0xFB,0x2E,0x1E,0x3A,0x34
    db          0xFA,0xB7,0x28,0x08,0x0E,0x01,0x18,0x04,0x2E,0x21,0x18,0x00,0xD9,0xDB,0x1C,0xCB
    db          0xFF,0xD3,0x1C,0xED,0x73,0xDC,0xFB,0x31,0x00,0xFC,0x11,0xC2,0xFB,0xD5,0xD9,0x26
    db          0x00,0xE9,0x08,0xED,0x7B,0xDC,0xFB,0xDB,0x1C,0xCB,0xBF,0xD3,0x1C,0x08,0xC9,0xE3
    db          0x7E,0x23,0xE3,0xB7,0xC8,0x4F,0xCD,0x2F,0xFB,0x18,0xF4
    ; BIOS variables and filler. Can be diffent than the BIOS contents on disk.
    db          0x00,0x00,0x00,0xAC,0xFB
    db          0x2E,0x39,0xC3,0xAC,0xFB,0x3A,0x03,0x00,0xE6,0xC0,0x2E,0x42,0xCA,0xAC,0xFB,0x2E
    db          0x3C,0xFE,0x80,0xCA,0xAC,0xFB,0xAF,0xC9,0x2E,0x03,0x18,0x30,0x2E,0x0C,0x18,0x2C

filler:
    ; unused
    db          0x2E,0x0F,0x18,0x28,0x2E,0x12,0x18,0x24,0x2E,0x15,0x18,0x20,0x2E,0x18,0x18,0x1C
    db          0xAF,0x32,0xDB,0xFB,0x2E,0x1B,0x18,0x14,0xAF
