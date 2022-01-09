; CAMBIO.COM included on the kaypro CP/M 2.2 Spanish version

WARM_START_VECTOR: EQU 0001h ; Address 0h has a JP WARM_START
CONF_BYTE_OFFSET:  EQU 31h   ; The byte is a fixed offset from the warm start code

CONFIG_BIT:        EQU 5

BDOS_ENTRYPOINT:   EQU 0005h
CALL_WRITESTR:     EQU 09h   ; BDOS call

org	0100h
	ld hl, (WARM_START_VECTOR)
	ld de, CONF_BYTE_OFFSET
	add hl, de
	bit CONFIG_BIT, (hl)
	jr z, set_bit
clear_bit:
	res CONFIG_BIT, (hl)
	ld de, clear_message
	jr display_message
set_bit:
	set CONFIG_BIT, (hl)
	ld de, set_message
display_message:
	ld c, CALL_WRITESTR
	call BDOS_ENTRYPOINT
	ret 
clear_message:
	db "\r\nCambiando a caracteres espa",0c0h,"oles (EUR/USASCII)\r\n$"
set_message:
	db "\r\nCambiando a caracteres europeos (E-ASCII)\r\n$"
filler:
	db 0, 0
