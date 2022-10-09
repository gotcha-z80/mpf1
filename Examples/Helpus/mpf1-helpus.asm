	org 1800h
start:	ld ix,help
disp:	call scan
	cp 13h			; KEY-STEP
	jr nz,disp
	halt

	org 1820h
help:	seek help-start
	defb 0aeh  		; 'S'
	defb 0b5h		; 'U'
	defb 01fh		; 'P'
	defb 085h		; 'L'
	defb 08fh		; 'E'
	defb 037h		; 'H'

scan:	equ 05feh
	
