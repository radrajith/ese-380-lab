/*
 * avm5.asm
 *
 *
 * Lab 11 - 
 *
 ; This program will utilize the capture program build during last lab
 ; essentially, the program will read the value when an unknown voltage is 
 ; sent. it will read only once. the wire has to be removed and when connected
 ; again to a different value, it will read again. it will not constantly read 
 ; a value when its connected. This lab an audio feature has been added. The 
 ; read voltage will be read out loud after measurement. 
 ; register used
 ; r1-r4 - for storing the ascii values of the read voltage
 ; r5 - r8 - for storing the bcd value of the read voltage
 ; r16 - general pupose register 
 ; r18 - stores the lower nibble of the values sent from max144
 ; r19 - stores the upper nibble of the values sent from max144
 ; r17 - is used as a general purpose and also to sent data to audio
 ; every other register used is being pushed and poped, so will not affect
 ; r20 - used to navigate between different menus
 ; other codes when implemented. 
 ; no interrupts used for this lab. 
 *  Created: 10/29/2014 2:17:13 PM
 *   Author: radra_000
 
 */
 
.NOLIST 
.include "m16def.inc" 
.LIST 


 ;********************************************************************
	 .cseg 
	 .org 0								;reset/restart code entry point <<<<<<<< 
	 jmp reset	
	 
	.org 0x002							;when external interrupt is pressed
	jmp menu							;its located on pd2

;*************************************************************************



reset:
	 
	ldi r16, low(ramend)
	out spl, r16
	ldi r16, high(ramend)
	out sph, r16						;initialize stack pointer
	
	LDI r16,$03
	out mcucr, r16
	ldi r16, 1 << INT0
	out gicr, r16
	
	ldi r16, $00
	out ddrd, r16						;set up the port b as inputs to read the pbsw values
										; and nand gate input on pd(2)

	ldi r16, 0xff						; set portB = output.
	out portd, r16
	ldi r16, 0b10111111	
    out DDRB, r16						; for lcd display
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1
	sbi portb, 0
	ldi r16, 1							; set DDRC for all in but PC0
	out DDRC, r16
	sbi PortC, 0						; turn off sounder

	;enabling spi setup for the external voltage reader
	ldi r16, (1<<spe)|(1<<mstr)
	out SPCR, r16					;Enable SPI, Master, fck/4,
//ask weather it can be placed here or not
;***
;***
	rcall init_lcd_dog					; init display, using SPI serial interfac
	clt


;*************************capture mode**********************************
; in this mode, the value will be read and stays in the diplay until the next
; value is obtained.  

main:
	cpi r16,0
	breq run
	cpi r16,1
	breq hold
	cpi r16,2
	breq capture
	cpi r16,3
	breq alarm
	rjmp main
run:
	rcall spi_setup
	rcall unpack						;conver the obtained values to numbers and unpack
	rcall run_display					;display measured value. 
	//rcall beep						;turn on and off the beep for 10 ms
	/rcall audio						;read the measured value
	rjmp main

hold:
	rcall spi_setup
	brts hold
	rcall unpack						;conver the obtained values to numbers and unpack
	rcall display						;display measured value. 
	//rcall beep						;turn on and off the beep for 10 ms
	//rcall audio						;read the measured value
	rjmp main

capture:
	rcall spi_setup					;sets up and gets the voltage from the max144
	ldi r16, $00					;
	cp r16, r19					;comparing weather the obtained values are 0
	brne next					;if not equal to zero then it means a value 
	ldi r16, 250					;is sent from max144
	cp r16,r18					;check if r18 is also less than 100mv if r19 is 0
	brsh clear					;if its same or greater go to clear
next:
	brtc run_once					;if tflag is cleared go to run once. if tflag is set
							;it means wire is not removed, it just the old value 
	rjmp main				
clear:
	brtc done					;beeps when read
	clt						;if both r18 and r19 are zero then the wire has been removed
	rcall beep					;beeps when its ready to read next value
	rcall linechange				;displays ready to 
	//note update lcd everytime if there is error while running 
	;
done:
	rjmp main						; and new value has to be read soon. so clear the tflag

alarm:
	cpi r20, 0
	breq alarm_3.5
	cpi r20, 1
	breq alarm_3.6
	cpi r20, 2
	breq alarm_3.7
	cpi r20, 3
	breq alarm_3.8
	rjmp main
alarm_3.5:
	push r16
	push r17
	ldi r16, 3
	ldi r17, 
		

run_once:
	rcall unpack					;conver the obtained values to numbers and unpack
	rcall capture_display			;display measured value. 
	rcall beep						;turn on and off the beep for 10 ms
	rcall audio						;read the measured value
	set								;set the tflag to notify the value is read and doesnt need to 
									; be read again
	rjmp main						; 

/******************
  interrupt menu
******************/

menu:
	push r17
	rcall delay
	in r17, pind
	cpi r17, $ff
	breq false_press
	sbis pind, 5
	rjmp not_hold
	sbis pind, 6
	rjmp not_hold
	cpi r16,3
	brne not_hold
alarm_mode: //r20 for voltage select
	sbis pind,3
	rcall delay
	sbis pind,3
	inc r20
	sbis pind,4
	rcall delay
	sbis pin, 4
	dec r20
	andi r20,$03
	sbis pind,7
	rcall delay
	sbis pind,7
	rjmp alarm_mode
	rjmp false_press
hold_mode:
	cpi r16, 2
	brne not_hold
	sbic pind,7
	rjmp false_press
	brts toggle
	set 
	rjmp false_press
toggle:
	clt
	rjmp false_press
not_hold:
 	rcall main_menu
	sbrs r17, 5
	inc r16
	clt
	sbrs r17, 6
	dec r16
	clt
	cpi r16, 3
	brne over16
	ldi r16, 0
	over16:
	cpi r16, $ff
	brne menu_exit
	ldi r16, 2
menu_exit:
	in r17, pind
	rcall main_menu
	sbic pind, 7
	rjmp not_hold
	rcall beep
false_press:
	pop r17
	reti

;*********************audio********************************
;puts the value in r16 and r17 and send it to the subroutine
; to make the audio module read the voltage on the screen 
;*******************************************************
audio:
cpse r22, 1
ret									;if r22 is 0 it means audio is off so it will just return
audioenable:						;if r22 is 1 the audio is enabled
	push r16
	push r17
	ldi r17, $00
	mov r16, r8						;send msb
	rcall send_audio_r17r16			;read the voltage, subrouitne
	ldi r16, $0A					;send dot
	rcall send_audio_r17r16			;read the voltage, subrouitne 
	mov r16, r7						;send 2nd number
	rcall send_audio_r17r16			;read the voltage, subrouitne
	mov r16, r6						;send third number
	rcall send_audio_r17r16			;read the voltage, subrouitne
	mov r16, r5						;send fourth number
	rcall send_audio_r17r16			;read the voltage, subrouitne
	pop r17
	pop r16

	
;*********************spi_setup*******************************
; Get the voltage from max144, by reading the input values for 
; 12 clock cycles. The registers used to store the 12 bits are 
; r18 and r19 registers are used
; r19 - first 8 msb
; r18 - last 8 lsb
; r16 - general purpose register
;**************************************************************
spi_setup:

	push r16
	in r16, spsr
	in r16, spdr
	sbi portb, 4					;stop the ss going to lcd	 
	cbi portb, 0					;clear the pb0 to enable ss going to voltage measu
	rcall delay						;delay added just in case any problems arise
	ldi r16, $AA					;load a dummy value
	out SPDR, r16					;set up dummy value in data register
	
	wait_H:
		sbis spsr, spif				;polling until first 8 msb data is received
		rjmp wait_H
		in r19, spdr				;copy the values to r19
		out spdr, r16				;send dummy value to get the next 8 values
	wait_L:
		sbis spsr, spif				;polling 
		rjmp wait_L
		in r18, spdr					;copy the values to r18
		push r16					
		ldi r16, $0f
		and r19, r18						;delete first four bits
		pop r16
	
		sbi pinb,0					;revert back to disabling the ss going to voltage measure
		cbi pinb, 4					;enabling the ss going to lcd
		pop r16
	ret

	
;*********************BEEP************************************
;beeps the sounder for 10ms 

beep:
	cbi portc, 0					;turn on the sounder
	rcall delay
	sbi portc, 0					;turn off the sounder
	ret
		

;**************************************************************************
;---------------------------- SUBROUTINES ----------------------------

;*********************LCD DISPLAY CODE******************************

;---------------------------------------------------------
;Code to load and display each line on the lcd 
;r25 is used to load the value of the each digit to the pointer
;line 2 refers to table, which containes numbers and depending 
;on the frequncy, each number is picked and displayed 
;---------------------------------------------------------

display:
   
   rcall clr_dsp_buffs					; clear all three buffer lines
   brtc	run_display
   brts hold_display

main_menu:
   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message1<<1)		;
   ldi  ZL, low(line1_message1<<1)		;
   rcall load_msg						; load message into buffer(s).



   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
cpi r16, 0
breq menu_run							;if r16 is 1 display run highlighted
cpi r16, 1
breq menu_hold							;display hold highlighted
cpi r16, 2
breq menu_capture						;display capture highlighted
cpi r16, 3
breq menu_alarm

menu_run:
   ldi ZH, high(line2_message_r<<1)		;
   ldi ZL, low(line2_message_r<<1)		;load the table to stack
   rjmp thirdline
menu_hold:
   ldi ZH, high(line2_message_h<<1)		;
   ldi ZL, low(line2_message_h<<1)		;load the table to stack
   rjmp thirdline
menu_capture:
   ldi ZH, high(line2_message_c<<1)		;
   ldi ZL, low(line2_message_c<<1)		;load the table to stack
   rjmp thirdline

thirdline:
   rcall load_msg						;load the frequency number into the buffer

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message1<<1)		;
   ldi  ZL, low(line3_message1<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message1:	.db 1, "***Main Menu****", 0  ; test string for line #1.
line2_message_r:.db 2,"HOLD   RUN    CAP",0
line2_message_h:.db 2,"CAP    HOLD    RUN",0
line2_message_c:.db 2,"RUN    CAP    HOLD",0
line3_message1:	.db 3,"      ??????      ", 0  ; test string for line #3.
;*************************************************************************************

 capture_display:

 // rcall spi_setup
   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message<<1)		;
   ldi  ZL, low(line1_message<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message<<1)		;
   ldi ZL, low(line2_message<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message<<1)		;
   ldi  ZL, low(line3_message<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message:	.db 2,"",0
line3_message:	.db 3, "CAPTURE         ", 0  ; test string for line #3.


 linechange: 
   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message0<<1)		;
   ldi  ZL, low(line3_message0<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message0:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message0:	.db 2,"",0
line3_message0:	.db 3, "READY      ", 0  ; test string for line #3.

;**************************************************************************************
  run_display:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message2<<1)		;
   ldi  ZL, low(line1_message2<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message2<<1)		;
   ldi ZL, low(line2_message2<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message2<<1)		;
   ldi  ZL, low(line3_message2<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message2:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message2:	.db 2,"",0
line3_message2:	.db 3, "RUN         MODE", 0  ; test string for line #3.

;***************************************************************************************
;**************************************************************************************
  hold_display:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message3<<1)		;
   ldi  ZL, low(line1_message3<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message3<<1)		;
   ldi ZL, low(line2_message3<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message3<<1)		;
   ldi  ZL, low(line3_message3<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message3:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message3:	.db 2,"",0
line3_message3:	.db 3, "HOLD         MODE", 0  ; test string for line #3.


;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================

;************************
;NAME:      clr_dsp_buffs
;FUNCTION:  Initializes dsp_buffers 1, 2, and 3 with blanks (0x20)
;ASSUMES:   Three CONTIGUOUS 16-byte dram based buffers named
;           dsp_buff_1, dsp_buff_2, dsp_buff_3.
;RETURNS:   nothing.
;MODIFIES:  r25,r26, Z-ptr
;CALLS:     none
;CALLED BY: main application and diagnostics
;********************************************************************
clr_dsp_buffs:
	push r25
	push r26
     ldi R25, 48						; load total length of both buffer.
     ldi R26, ' '						; load blank/space into R26.
     ldi ZH, high (dsp_buff_1)			; Load ZH and ZL as a pointer to 1st
     ldi ZL, low (dsp_buff_1)			; byte of buffer for line 1.
   
    ;set DDRAM address to 1st position of first line.
store_bytes:
     st  Z+, R26						; store ' ' into 1st/next buffer byte and
										; auto inc ptr to next location.
     dec  R25							; 
     brne store_bytes					; cont until r25=0, all bytes written.
	 pop r26
	 pop r25
     ret


;*******************
;NAME:      load_msg
;FUNCTION:  Loads a predefined string msg into a specified diplay
;           buffer.
;ASSUMES:   Z = offset of message to be loaded. Msg format is 
;           defined below.
;RETURNS:   nothing.
;MODIFIES:  r16, Y, Z
;CALLS:     nothing
;CALLED BY:  
;********************************************************************
; Message structure:
;   label:  .db <buff num>, <text string/message>, <end of string>
;
; Message examples (also see Messages at the end of this file/module):
;   msg_1: .db 1,"First Message ", 0   ; loads msg into buff 1, eom=0
;   msg_2: .db 1,"Another message ", 0 ; loads msg into buff 1, eom=0
;
; Notes: 
;   a) The 1st number indicates which buffer to load (either 1, 2, or 3).
;   b) The last number (zero) is an 'end of string' indicator.
;   c) Y = ptr to disp_buffer
;      Z = ptr to message (passed to subroutine)
;********************************************************************
load_msg:
	 push r26
	 push r17
     ldi YH, high (dsp_buff_1)			; Load YH and YL as a pointer to 1st
     ldi YL, low (dsp_buff_1)			; byte of dsp_buff_1 (Note - assuming 
										; (dsp_buff_1 for now).
     lpm R16, Z+						; get dsply buff number (1st byte of msg).
     cpi r16, 1							; if equal to '1', ptr already setup.
     breq get_msg_byte					; jump and start message load.
     adiw YH:YL, 16						; else set ptr to dsp buff 2.
	 ldi r17, $00
	 ldi r26, 6
     cpi r16, 2							; if equal to '2', ptr now setup.
     breq digit_load					; jump and start message load.
     adiw YH:YL, 16						; else set ptr to dsp buff 3.
        
get_msg_byte:
     lpm R16, Z+						; get next byte of msg and see if '0'.        
     cpi R16, 0							; if equal to '0', end of message reached.
     breq msg_loaded					; jump and stop message loading operation.
     st Y+, R16							; else, store next byte of msg in buffer.
     rjmp get_msg_byte					; jump back and continue...

;__________________________________________
; digital_load will only be accessed when displaying line 2, 
; since the frequency to be displayed in line 2 is constantly 
; changing for different waveform, the line 2 has to be adjusted 
; according. 
; r17, will inc until 6, to display 6 empty spaces
; r4 will contain the first digit of the frequency
; r3 will contain the second digit of the frequency
; r2 will contain the third digit of the frequency
; r1 will contian the fouth digit of the frequency
;get_dis_freq subroutine will just transfer each value stored in 
; r25 to y pointer
;_______________________________________________	
digit_load:
	inc r17
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	cpse r17, r26					;check if 6 places typed
	rjmp digit_load					;repeat until 6 places
	mov r25, r4						;load the first number in voltage
	rcall get_dis_freq				;display 
	ldi r25, $2E
	rcall get_dis_freq				;load period to display inbetween numbers
	mov r25, r3						;load the second number in voltage
	rcall get_dis_freq				;display 
	mov r25, r2						;load the third number in voltage
	rcall get_dis_freq				;display 
	mov r25, r1						;load the fourth number in voltage
	rcall get_dis_freq				;display 
	ldi r25, $56					;load the V in voltage
	rcall get_dis_freq				;display 
	rjmp msg_loaded					;go to the next line of the lcd

get_dis_freq:
	st Y+, r25						;display the selected frquency
	ret		

	
msg_loaded:
	 pop r17
	 pop r26
     ret
;________________________________________________________________________________________

;------------------------------------------------
;unpacks the values store in r13 and r14 to r1- r4
; r4 containe the left most number ie the thousanth
;digit and r1 the right most number
;------------------------------------------------
.def bit01 = r13				;values taken from bin2bcd
.def bit23 = r14
unpack:
	push r16						;store the value currently in r16
	rcall bin2BCD16					;convert the values from binary to bcd
	mov r2, bit01						;make a copy of r13 in r2
	mov r4, bit23						;make a copy of r14 in r4
	;mov r6, bit45						;make a copy of r15 in r6
	ldi r16, $0f					;use and function to
	and bit01, r16					;mask the upper nibble of r8
	mov r1, bit01						;move lower nibble to r1
	and bit23, r16					;mask upper nibble of r9
	mov r3, bit23						;move lower nible to r3
	com r16							;load with f0 to mask lower nibble
	and r2, r16						;mask lower nibble of r8
	swap r2							;switch upper and lower nibble
	and r4, r16						;mask lower nibble of r9
	swap r4							;switch upper and lower nibble
	mov r8, r4
	mov r7, r3
	mov r6, r2
	mov r5, r1						;copy the bcd values to r8-r5
	ldi r16, $30
	add r1, r16
	add r2, r16
	add r3, r16
	add r4, r16
	;add r5, r16						;converting the bcd's to ascii
	pop r16							;retrive the value previosly stored
	ret

.undef bit01 
.undef bit23	
.undef bit45		
	





;_____________________________________________________________________________________





;***************************************************************************
;*
;* "bin2BCD16" - 16-bit Binary to BCD conversion
;*
;* This subroutine converts a 16-bit number (fbinH:fbinL) to a 5-digit
;* packed BCD number represented by 3 bytes (tBCD2:tBCD1:tBCD0).
;* MSD of the 5-digit number is placed in the lowermost nibble of tBCD2.
;*
;* Number of words	:25
;* Number of cycles	:751/768 (Min/Max)
;* Low registers used	:3 (tBCD0,tBCD1,tBCD2)
;* High registers used  :4(fbinL,fbinH,cnt16a,tmp16a)	
;* Pointers used	:Z
;*
;***************************************************************************
//.include "..\8515def.inc"
;***** Subroutine Register Variables


.equ	AtBCD0	=13			;address of tBCD0
.equ	AtBCD2	=15			;address of tBCD1

.def	tBCD0	=r13		;BCD value digits 1 and 0
.def	tBCD1	=r14		;BCD value digits 3 and 2
.def	tBCD2	=r15		;BCD value digit 4
.def	fbinL	=r16		;binary value Low byte
.def	fbinH	=r17		;binary value High byte
.def	cnt16a	= r18		;loop counter
.def	tmp16a	= r19		;temporary value

;***** Code

bin2BCD16:
	mov fbinH, r19			;copy the values of edge counter to fbin
	mov fbinL, r18
	ldi	cnt16a, 16			;Init loop counter	
	clr	tBCD2				;clear result (3 bytes)
	clr	tBCD1		
	clr	tBCD0		
	clr	ZH					;clear ZH (not needed for AT90Sxx0x)
bBCDx_1:
	lsl	fbinL				;shift input value
	rol	fbinH				;through all bytes
	rol	tBCD0				;
	rol	tBCD1
	rol	tBCD2
	dec	cnt16a				;decrement loop counter
	brne bBCDx_2			;if counter not zero
	ret						;   return

bBCDx_2:
	ldi	r30,AtBCD2+1		;Z points to result MSB + 1
bBCDx_3:	
	ld	tmp16a,-Z			;get (Z) with pre-decrement
	subi tmp16a,-$03		;add 0x03
	sbrc tmp16a,3			;if bit 3 not clear
	st Z,tmp16a				;store back
	ld	tmp16a,Z			;get (Z)
	subi tmp16a,-$30		;add 0x30
	sbrc tmp16a,7			;if bit 7 not clear
	st	Z,tmp16a			;store back
	cpi	ZL,AtBCD0			;done all three?
	brne bBCDx_3			;loop again if not
	rjmp bBCDx_1	

.undef	tBCD0				;BCD value digits 1 and 0
.undef	tBCD1				;BCD value digits 3 and 2
.undef	tBCD2				;BCD value digit 4
.undef	fbinL				;binary value Low byte
.undef	fbinH				;binary value High byte
.undef	cnt16a				;loop counter
.undef	tmp16a				;temporary value



;------------DELAY 10 MS--------------------------
;This subroutine is placed here, if it was required during 
; the lab. Its not called anywhere in the code. 
;delays for 10ms 
;r20 set to 100
;r21 set to 33
; combined delay will yield 9999 clock cycles
;-------------------------------------------------
delay:
	push r20
	push r21
	ldi r20,100
	outer:
		ldi r21, 33
		inner:
			dec r21
			brne inner
			dec r20
			brne outer
	pop r21
	pop r20
	ret
;________________________________________________________________________



