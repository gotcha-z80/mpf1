;===============================================================================
; This loader allows MPF-1B users to load assembled programs (Intel Hex format)
; into the MPF-1 system memory from a serial link (RS232 or TTL).
;
; The serial emitter (usually a computer) is connected to the MPF-1 audio input
; (EAR) with a specific cable that connects:
; - the TX serial output of the emitter to the MPF1 EAR center tip
; - the ground serial output of the emitter to the MPF1 EAR ground.
;
; The loader works with both RS232 (typically -12v, +12v but can be less) and
; TTL serial links (typically 0v, 3.3v or 5v).
; - RS232 corresponds to DB9 serial port of older PCs. It can also be provided
;   by USB-RS232 converters outputing a DB9 connector for modern PC
; - USB-Serial TTL converters are usually used for uploading firmware on modern
;   embedded systems. They can output either 3.3v or 5v signals. Boths will
;   work with the Hex loader.
;
; Note: This code is an improved version of the HEX-1BP loader from the FLite
; Electronics LTD company. The original loader only supports RS232 serial links
; and fails in case a record of type 2 to 5 is encountered in the Intel Hex file.
; Even if these record types don't apply to the Z80 system, it is not unusual
; to get such records generated by bin to hex converters.
;
; Created by Gotcha
;===============================================================================

;  Address of used monitor routines
monitorReset:	equ 0000h	; Reset
monitorTone:	equ 05E4h	; Generate sound
monitorScan:	equ 05FEh	; Scan keyboard and display until a new key-in
monitorScan1:	equ 0624h 	; Scan keyboard and display one cycle
monitorAddrDp:	equ 0665h

; Address of used monitor variables
monitorDISPBF:	equ 1FB6h	; Display buffer

; Variables
varIsTTL:		equ 1F6Fh	; 80h if TTL, 00h if RS232
varCRC:			equ 1F70h	; Used to compute the checksum
varNumBytesInLine:	equ 1F71h	; num bytes in the hex record
varDataPtr:		equ 1F72h	; address of the load destination (16 bits)
varOffset:		equ 1F74h	; offset to add to the Intel Hex address (16 bits)
					; to get the actual target address in memory
varSound:		equ 1F76h	; Sound (beeper) configuration


; IO addresses
io_8255_port_A:	 equ 0000h
io_8255_port_B:	 equ 0001h
io_8255_port_C:	 equ 0002h

;------------------
; Code
;------------------

	ORG 2000h

offsetQueryStage:
	LD          IX,displayOffset
	LD          DE,0x0
	LD          (varOffset),DE
	CALL        monitorScan			; Display "Offset" & wait for key
	CALL        fEmitSound1
	CP          0x10
	JR          NC,soundQueryStage		; Jump if pressed key is not hexa
						; (no address given by the user)
	CALL        getAddrFromKeybd
	LD          (varOffset),DE		; Store the user given offset

soundQueryStage:
	LD          IX,displaySound
	CALL        monitorScan			; Display "Sound" & wait for key
	LD          HL,varSound
	LD          (HL),0x7f			; Config for port C of 8255:
						; Speaker & LED tone-out = 0
                                		; --> Sound deactivated
	CP          0x12			; Key 'GO' was pressed ?
	JR          Z,plugQueryStage
	LD          (HL),0xff			; Config for port C of 8255:
						; Speaker & LED tone-out = 1
						; --> Sound activated

; Once the user has plugged the cable, we will detect weither we are connected to
; a RS232 serial port (-V, +V) or to a TTL serial port (0 +V).
; With this knowledge, we will determine how the bits received should be interpreted
plugQueryStage:

	LD          IX,displayPlug
	CALL        monitorScan			; Display "Plug" & wait for key
	CALL        fEmitSound2
	IN          A,(io_8255_port_A)
	BIT         0x7,A	; Bit7=0, then Z=1 if RS232 (tape input = 0v)
				; Bit7=1, then Z=0 if TTL   (tape input = 5v)
	JR          NZ,isTTL

isRS232:
	XOR         A				; No change to the input tape
	LD          IX,displayRS232
	JP	    plugQueryStageEnd

isTTL:
	LD          A,0x80			; Will invert input tape (bit 7)
	LD          IX,displayTTL

plugQueryStageEnd:
	LD	    (varIsTTL),A
	LD          B,0x64
	CALL        fDisplayAndLoopBTimes	; Delay of 1s

startTransmissionStage:
	LD          IX,displaySend
	LD          B,0x64
	CALL        fDisplayAndLoopBTimes	; Delay of 1s
	CALL        fEmitSound2
	LD          A,0x40
	OUT         (io_8255_port_B),A		; Configure '.' to print on display
	LD          A,0xff
	OUT         (io_8255_port_C),A		; Print '.' on the display 6 digits


;*****************************************************
; Intel Hex Record handling
;*****************************************************

handleRecord:

waitForColon:
	CALL        readCharFromTape
	CP          0x3a			; Did we get ':' ?
	JR          NZ,waitForColon

getNumBytes:
	XOR         A
	LD          (varCRC),A
	CALL        getByteFromTape
	LD          (varNumBytesInLine),A
	CALL        addAToCRC

getDestAddr:
	CALL        getByteFromTape		; Address higher order byte
	CALL        addAToCRC
	LD          D,A
	CALL        getByteFromTape		; Address lower order byte
	CALL        addAToCRC
	LD          E,A
	LD          HL,(varOffset)
	ADD         HL,DE
	LD          (varDataPtr),HL

; Record type handling
; --------------------
	CALL        getByteFromTape		; Type of Intel Hex record
	CALL        addAToCRC
	CP          0x0				; Data record
	JR	    NZ,type1
	CALL        fGetDataAndCopy
	JP	    getAndCheckCRC
type1:
	CP          0x1				; End Of File
	JR	    NZ,typeOther
	CALL        fGetDataAndIgnore
	JP	    theEndGood

typeOther:
	; For now, we just ignore records of type 2, 3, 4 and 5 since
	; they don't apply to the Z80 processor
	; - 2: Extended Segment Address
	; - 3: Start Segment Address
	; - 4: Extended Linear Address
	; - 5: Start Linear Address
	CP          0x6
	JR          C,ignoreRecordData		; jump if < 6

recordError:
	CALL        fEmitSound3
	LD          IX,displayRecord
	LD          B,0x64
	CALL        fDisplayAndLoopBTimes	; Delay : 100 iterations
	JP          startTransmissionStage


; Record data field
; --------------------

fGetDataAndIgnore:
	LD          A,(varNumBytesInLine)
	OR	    A
	RET	    Z

	LD          B,A
fGetDataAndIgnore_loop:
	CALL        getByteFromTape
	CALL        addAToCRC			; Compute the CRC
	DJNZ        fGetDataAndIgnore_loop
	RET

fGetDataAndCopy:
	LD          A,(varNumBytesInLine)
	LD          B,A
	LD          IX,(varDataPtr)
fGetDataAndCopy_loop:
	CALL        getByteFromTape
	LD          (IX+0x0),A			; Store the read byte in memory
	CALL        addAToCRC			; Compute the CRC
	INC         IX
	DJNZ        fGetDataAndCopy_loop
	RET

ignoreRecordData:
	CALL        fGetDataAndIgnore

; End of Record: CRC
; --------------------

getAndCheckCRC:
	CALL        getByteFromTape
	LD          HL,varCRC
	ADD         A,(HL)
	JR          Z,getNextRecord

errorCRC:
	CALL        fEmitSound3
	LD          IX,displayChecksum
	LD          B,0x64
	CALL        fDisplayAndLoopBTimes	; Delay: 100 iterations
	JP          startTransmissionStage

getNextRecord:
	JP          handleRecord

theEndGood:
	CALL        fEmitSound4
	LD          IX,displayGood
	LD          B,0x64
	CALL        fDisplayAndLoopBTimes	; Delay: 100 iterations
	JP          monitorReset		; Back to monitor

        ;***************************************
        ;***        end of program           ***
	;***************************************


;************************************************************************************************
;* triggersSoundAndTempoD:
;*
;* Beep and turn the tone-out LED if configured in varSound
;* Loop D times as a delay.
;************************************************************************************************

triggersSoundAndTempoD:
	PUSH        AF
	PUSH        HL
	LD          HL,varSound
	AND         (HL)
	OUT         (io_8255_port_C),A	; Beep if configured
delay_:
	DEC         D
	JR          NZ,delay_
	POP         HL
	POP         AF
	RET

;************************************************************************************************
;* addAToCRC:
;*
;* Add A to the variable that keps the CRC value
;************************************************************************************************

addAToCRC:
	PUSH        AF
	PUSH        HL
	LD          HL,varCRC
	ADD         A,(HL)
	LD          (HL),A
	POP         HL
	POP         AF
	RET

;************************************************************************************************
;* getByteFromTape:
;*
;* Read 2 ASCII characters (representing an hexadecimal byte) from the audio input and return
;* the corresponding integer value byte in A.
;************************************************************************************************

getByteFromTape:
	CALL        readAsciiByteIntoHL
	CALL        getByteValueFromHexAscii
	RET


;************************************************************************************************
;* readAsciiByteIntoHL:
;*
;* Read 2 ASCII characters from the audio input and return their ASCII code in HL
;*  - H (1st)
;*  - L (2nd)
;************************************************************************************************

readAsciiByteIntoHL:
	CALL        readCharFromTape
	LD          H,A
	CALL        readCharFromTape
	LD          L,A
	RET


;************************************************************************************************
;* getByteValueFromHexAscii:
;*
;* Take 2 ASCII characters that represent a byte in Hexa (2 nibbles in HL) and return the
;* corresponding integer value byte in A
;************************************************************************************************

getByteValueFromHexAscii:
	LD          A,L
	CALL        getHexaValueFromASCII	; LSB
	LD          C,A
	LD          A,H
	CALL        getHexaValueFromASCII	; MSB
	SLA         A
	SLA         A
	SLA         A
	SLA         A
	OR          C
	RET

;************************************************************************************************
;* getHexaValueFromASCII:
;*
;* Compute the integer value of an ASCII character representing a hexa nibble (4 bits).
;*  - In: A = ASCII code of the nibble
;*  - out: A = integer value of the nibble
;************************************************************************************************

getHexaValueFromASCII:
	CP          0x3a
	JR          NC,isLetter

isNumber:
	SUB         0x30		; A = valeur du chiffre decimal
	RET

isLetter:
	SUB         0x37		; A = valeur de la lettre Hexa
					; (elle doit etre en majuscule)
	RET

;************************************************************************************************
;* readCharFromTape:
;*
;* Read a 7 bits ASCII character from the audio input
;* Return its ASCII code in A
;************************************************************************************************

readCharFromTape:
	PUSH        BC
	PUSH        DE
	LD          C,0x0
	LD          B,0x8 			; We will read 8 bits after the start bit
	LD	    A,(varIsTTL) 		; Bit interpretation will be inverted for TTL
	LD 	    E,A

waitForTapeInputLow:
	IN          A,(io_8255_port_A)		; Potentially wait for the completion of the
						; previous character
	XOR	    E				; invert A
	BIT         0x7,A
	JR          NZ,waitForTapeInputLow

waitForTapeInputHigh:
	IN          A,(io_8255_port_A)		; Wait for start bit
	XOR	    E				; invert A if TTL
	BIT         0x7,A
	JR          Z,waitForTapeInputHigh
	LD          D,0x35
	CALL        triggersSoundAndTempoD	; Delay of 53 iterations
						; to check: wait until the middle of the next bit transmission
						; ??? ms

getNotBitFromTape:
	IN          A,(io_8255_port_A)
	XOR	    E				; Invert A if TTL, Flag C = 0
	BIT         0x7,A			; Flag Z = inverse of bit read from audio input
	JR          NZ,insertBit		; Flag C=0 if Z==0 (when read bit==1 for RS232)
	SCF					; Flag C=1 if Z==1 (when read bit==0 for RS232)

insertBit:
	RR          C				; Rotate right C and inject C as most significant bit
	LD          D,0x24
	CALL        triggersSoundAndTempoD	; Wait for 36 iterations (next bit)
						; ??? ms
	DJNZ        getNotBitFromTape
	RES         0x7,C			; Reset the last received bit (parity of stop bit)
	LD          A,C
	POP         DE
	POP         BC
	RET

displaySend:
	defb           00h	 ;' '
	defb           00h       ;' '
	defb           0B3h      ;'d'
	defb           23h       ;'n'
	defb           8Fh       ;'E'
	defb           0AEh      ;'S'
displayRecord:
	defb           0B3h      ;'d'
	defb           03h       ;'r'
	defb           0A3h      ;'o'
	defb           83h       ;'c'
	defb           8Fh       ;'E'
	defb           03h       ;'r'
displayChecksum:
	defb           0B5h      ;'U'
	defb           0AEh      ;'S'
	defb           8Dh       ;'C'
	defb           8Fh       ;'E'
	defb           37h       ;'H'
	defb           8Dh       ;'C'
displayGood:
	defb           00h       ;' '
	defb           00h       ;' '
	defb           0B3h      ;'d'
	defb           0A3h      ;'o'
	defb           0A3h      ;'o'
	defb           0ADh      ;'G'
displayOffset:
	defb           87h       ;'t'
	defb           8Fh       ;'E'
	defb           0AEh      ;'S'
	defb           0Fh       ;'F'
	defb           0Fh       ;'F'
	defb           0BDh      ;'O'
displaySound:
	defb           00h       ;' '
	defb           0B3h      ;'d'
	defb           23h       ;'n'
	defb           0A1h      ;'u'
	defb           0A3h      ;'o'
	defb           0AEh      ;'S'

displayPlug:
	defb           00h       ;' '
	defb           00h       ;' '
	defb           0ADh      ;'g'
	defb           0B5h      ;'u'
	defb           85h       ;'l'
	defb           1Fh       ;'P'
displayTTL:
	defb           00h       ;' '
	defb           00h       ;' '
	defb           00h       ;' '
	defb           05h       ;'l'
	defb           87h       ;'t'
	defb           87h       ;'t'
displayRS232:
	defb           00h       ;' '
	defb           9Bh       ;'2'
	defb           0BAh      ;'3'
	defb           9Bh       ;'2'
	defb           0AEh      ;'s'
	defb           03h       ;'r'

fDisplayAndLoopBTimes:
	PUSH        BC
	CALL        monitorScan1
	POP         BC
	DJNZ        fDisplayAndLoopBTimes
	RET

;************************************************************************************************
;* getAddrFromKeybd:
;*
;* Function that read a 16 bit address from the keyboard
;*
;* The function prints digits on the display as their are entered by the user
;* If the user enters more than 4 digit, then only the last 4 are kept.
;*
;* The function returns as soon as the user pushed a key that is not an hexa digit
;* - Input:
;*   A: value of the first digit key pressed
;* - Output
;*   DE: the 2 bytes of the collected address
;************************************************************************************************

getAddrFromKeybd:
	LD          IX,monitorDISPBF			; @ of the monitor display buffer (6 bytes)
	LD          DE,0x0
	LD          (monitorDISPBF),DE

nextKey:
	CALL        shiftL_DE_insert_A_4bits		; Insert the digit of the last key pressed in DE
	CALL        monitorAddrDp			; Convert DE (4 nibbles) for the display
	CALL        monitorScan
	CALL        fEmitSound1
	CP          0x10
	RET         NC
	JR          nextKey


shiftL_DE_insert_A_4bits:
	LD          B,0x4

shift_DE_and_decrement_B:
	SLA         E					; DE = DE << 1
	RL          D
	DJNZ        shift_DE_and_decrement_B		; DE = DE << 1

	AND         0xf
	OR          E
	LD          E,A
	RET

;*********************************************************
;* Sound functions
;* TODO: determine the frequency
;*********************************************************

fEmitSound1:
	PUSH        BC
	PUSH        HL
	LD          C,0x1e
	LD          HL,0xc8
	JR          call_tone_and_return

fEmitSound2:
	PUSH        BC
	PUSH        HL
	LD          C,0x46
	LD          HL,0x190
	JR          call_tone_and_return

fEmitSound3:
	PUSH        BC
	PUSH        HL
	LD          C,0xc8
	LD          HL,0x320
	JR          call_tone_and_return

fEmitSound4:
	PUSH        BC
	PUSH        HL
	LD          C,0x32
	LD          HL,0x258
	JR          call_tone_and_return

call_tone_and_return:
	PUSH        AF
	PUSH        DE
	CALL        monitorTone
	POP         DE
	POP         AF
	POP         HL
	POP         BC
	RET