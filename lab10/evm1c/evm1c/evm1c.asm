/*
 * evm1c.asm

 *
 ; This program will continuously read the voltage values coming in through
 ; port a pin 4, it will convert the analog signal to a digital signal. This 
 ; all done by processor, only initialization of the adc converters are required. 
 ; the converterted value 10 bit value is then sent to multiply with 50 and then 
 ; divide subroutine to divide by 10. Both of these subrouitnes are provided by atmel 
 ; the value obtained is then unpacked and displayed on the display. the process is '
 ; repeated forever. The only thing different about this program compared to the first 
 ; is that this will utilize an external interrupt to toggle between run and hold. 
 ; when its in run mode the code will read the input analog voltage. when its in hold 
 ; mode it will retain the value, and doesnt read again until the pbsw is pressed again.
 ; registers used by code written by me
 ; r1 - r5 to unpack the bits
 ; r8 and r9 to copy the 10 bit value obtained after convertion
 ; r16 for general purpose like initilization etc
 ; r17 as a space counter used in the display subroutine
 ; r28 initialized to 6. to keep r17 in check 
 ; r27 as a toggle register. changes between 1 or 0 with press of center button 
 ;r8 and r9 will be used to store the adc conversion values
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
	 
	 
	 
	 //when the counter is equal to 1s, the interrupt will be called
	 //0x0E is the adress for timer compare match B. 
	 //when the interrupt is called, it will jump to isr_tc0_display
	//.org 0x002							;when external interrupt is pressed
	//jmp switch							;its located on pd2

	// .org 0x01C							; timer intrrupt
	// jmp conv_check				;goes here when the time is up


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
    out DDRB, r16						; for lcd display
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1

	ldi r16, 1							; set DDRC for all in but PC0
	out DDRC, r16
	sbi PortC, 0						; turn off sounder

	ldi r16,0b01000000					; set up port a to 
	out ddra, r16						;read the frequency input on pa7 and output pulse on pa6

	rcall init_lcd_dog					; init display, using SPI serial interface 

	sei


main:
	//brtc display
	rcall spi_setup					;sets up and gets the voltage from the max144
	push r16
	ldi r16, $00
	cp r9, r16
	brne pass
	cp r8, r16
	breq display_capture1
	pop r16
	pass:
	clt
	rcall val_conv					;conver the obtained values to numbers
	rcall display					;display the contents
	clr r12
	clr r13
	clr r14
	clr r15
	clr r16
	clr r18
	clr r19
	clr r20
	clr r21
	clr r22
	clr r23
	clr r24
	clr r25
	clr r26
	;clr r27
	clr r28
	clr r29
	//sound buzzer
	cbi PortC, 0						; turn on sounder
	rcall delay
	rcall delay
	sbi PortC, 0						; turn off sounder
	rjmp main
display_capture1:
	rjmp display_capture
;*********************switch interrupt*************************
; swich subroutine is used when the external interrupt is used
;
;ask raymond to add the debounce 
switch:
	push r16
	in r16, sreg
	push r16
	push r17
	in r16, pind
	com r16
	andi r16, $80						;check if center pushbutton is pressed
	rcall delay
	in r17, pind	
	com r17
	andi r17, $80						;check if button is still pressed
	cp r17, r16
	breq sett
		clt
		rjmp finish
	sett:
		set
	finish:
	reti
;*********************spi_setup*******************************
; Get the voltage from max144, by reading the input values for 
; 12 clock cycles. The registers used to store the 12 bits are 
; r8 and r9 

spi_setup:
	.equ MISO = 6
	ldi r16, (1<<MISO)
	out ddrb, r16
	ldi r16, (1<<spe)|(1<<mstr)
	out SPCR, r16					;Enable SPI, Master, fck/4, 
	ldi r16, $AA
	out SPDR, r16					;set up dummy value in data register
	cbi PORTB, 0
	wait_H:
		sbis spsr, spif
		rjmp wait_H
		in r9, spdr
		push r18
		ldi r18, $0f
		and r9, r18						;delete first four bits
		pop r18
		out spdr, r16
	wait_L:
		sbis spsr, spif
		rjmp wait_L
		in r8, spdr
	ret

/*	
wait_spifH:
	nop nop nop
	in r9, SPDR	
wait_spifL:
	nop nop nop 
	in r8, spdr

	ldi r16, $0f
	and r9, r16						;delete first four bits
	ret
	*/



;*********************converion check***************************
; checks if  ADIF flag is set in the adscra register. 
; when the flag is 1 it means that the conversion is complete,
; so reset the flag, convert the bits stored in adch and adcl register 
; and covert
;display the converted value, by branching to display subroutine
val_conv:	
		//rcall mpy16u					;multiply the counts with 50
		//rcall div32u					;divide the counts by 10
		rcall unpack				;convert the answer to ascii
		ret								;go back and display
		



;*****************ADC initialization**************************
 ;intializes all the required registers located in port A, for 
 ; analag to digital conversion. 
 ; registers to be initialized:
 ; ADMUX - adc multiplexer selection register
 ; REFS1  REFS0  ADLAR  MUX4  MUX3  MUX2  MUX1  MUX0
 ; 
 ; REFS1 and REFS0 will be both set to 1, in order to get 2.56v 
 ; internal voltage reference, refer to pg(471). 
 ; Adlar -  by default is right adjusted.
 ;
 ; ADCSRA - adc control and status register A
 ; ADEN  ADSC  ADATE  ADIF ADIE  ADPS2  ADPS1  ADPS0
 ; 
 ; ADEN: ADC ENABLE
 ; ADSC - TO START CONVERSION 
 ; 
 ; SFIOR - Special functions io register
 ; ADTS2  ADTS1  ADTS0
 ;	7		6		5
 ; THE above three bits could be used to set various interrupts
 adc_init:
 
	ldi r16, 0b11000100					;load 16 to set the ADC4 and single ended
	out admux, R16						;input and internal voltage reference to 2.56v
										; the conversion is running in single run mode
	;the below code can be placed wherever its required to start the conversion
	ldi r16, 0b11100100					; for this lab we will be using a division factor
	out adcsra, r16						; of 16(clk/16)
	//sei
	;ldi r16, 0b01000000					;could be used to set the enternal int 0
	;out sfior, r16		
	ret
;_________________________________________________________________________________________


;**************************************************************************
;---------------------------- SUBROUTINES ----------------------------

;*********************LCD DISPLAY CODE******************************

;---------------------------------------------------------
;Code to load and display each line on the lcd 
;r25 is used to load the value of the each digit to the pointer
;line 2 refers to table, which containes numbers and depending 
;on the frequncy, each number is picked and displayed 
;---------------------------------------------------------
display_capture:
	set
display:
   rcall clr_dsp_buffs					; clear all three buffer lines
   brtc regular1
   brts regular2
  regular1:

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
line3_message:	.db 3, "RUN        EVM1C", 0  ; test string for line #3.



regular2:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message0<<1)		;
   ldi  ZL, low(line1_message0<<1)		;
   rcall load_msg						; load message into buffer(s).

   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message0<<1)		;
   ldi ZL, low(line2_message0<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   
   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message0<<1)		;
   ldi  ZL, low(line3_message0<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   rjmp main
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message0:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message0:	.db 2,"",0
line3_message0:	.db 3, "CAPTURE    EVM1B", 0  ; test string for line #3.


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
	;mov r25, r5						;load the first number in freq
	;rcall get_dis_freq				;display 
	mov r25, r4					;load the first number in freq
	rcall get_dis_freq				;display 
	ldi r25, $2E
	rcall get_dis_freq				;load period to display inbetween numbers
	mov r25, r3					;load the second number in freq
	rcall get_dis_freq				;display 
	mov r25, r2						;load the third number in freq
	rcall get_dis_freq				;display 
	mov r25, r1						;load the fourth number in freq
	rcall get_dis_freq				;display 
	ldi r25, $56						;load the fourth number in freq
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
;unpacks the values store in r8 and r9 to r1- r4
; r4 containe the left most number ie the thousanth
;digit and r1 the right most number
;------------------------------------------------
.def bit01 = r8
.def bit23 = r9
.def bit45 = r15
unpack:
	push r16						;store the value currently in r16
	rcall bin2BCD16					;convert the values from binary to bcd
	mov r2, bit01						;make a copy of r13 in r2
	mov r4, bit23						;make a copy of r14 in r4
	mov r6, bit45						;make a copy of r15 in r6
	ldi r16, $0f					;use and function to
	and bit01, r16					;mask the upper nibble of r8
	mov r1, bit01						;move lower nibble to r1
	and bit23, r16					;mask upper nibble of r9
	mov r3, bit23						;move lower nible to r3
	and bit45, r16					;mask the upper nibble of r8
	mov r5, bit45						;move lower nibble to r1
	com r16							;load with f0 to mask lower nibble
	and r2, r16						;mask lower nibble of r8
	swap r2							;switch upper and lower nibble
	and r4, r16						;mask lower nibble of r9
	swap r4							;switch upper and lower nibble
	//and r6, r16					;mask lower nibble of r9
	//swap r6						;switch upper and lower nibble	
	ldi r16, $30
	add r1, r16
	add r2, r16
	add r3, r16
	add r4, r16
	add r5, r16						;converting the bcd's to ascii
	pop r16							;retrive the value previosly stored
	ret

.undef bit01 
.undef bit23	
.undef bit45		
	



;------------------------------------------------
; converts the values from bcd to ascii by adding 
; 30 to it. 
;------------------------------------------------

bcd_to_ascii:
	push r16
	ldi r16, $30
	add r18, r16
	add r19, r16
	add r20, r16
	add r21, r16
	pop r16							;retrive the value previosly stored
	ret


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
.def	cnt16a	=r18		;loop counter
.def	tmp16a	=r19		;temporary value

;***** Code

bin2BCD16:
	//sub r18, r19
	mov fbinH, r19			;copy the values of edge counter to fbin
	mov fbinL, r18
	ldi	cnt16a,16			;Init loop counter	
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

;________________________________________________________________________________	

;***************************************************************************
;*
;* "mpy16u" - 16x16 Bit Unsigned Multiplication
;*
;* This subroutine multiplies the two 16-bit register variables 
;* mp16uH:mp16uL and mc16uH:mc16uL.
;* The result is placed in m16u3:m16u2:m16u1:m16u0.
;*  
;* Number of words	:14 + return
;* Number of cycles	:153 + return
;* Low registers used	:None
;* High registers used  :7 (mp16uL,mp16uH,mc16uL/m16u0,mc16uH/m16u1,m16u2,
;*                          m16u3,mcnt16u)	
;*
;***************************************************************************

;***** Subroutine Register Variables
.def	mc16uL	=r16		;multiplicand low byte
.def	mc16uH	=r17		;multiplicand high byte
.def	mp16uL	=r18		;multiplier low byte
.def	mp16uH	=r19		;multiplier high byte

.def	m16u0	=r18		;result byte 0 (LSB)
.def	m16u1	=r19		;result byte 1
.def	m16u2	=r20		;result byte 2
.def	m16u3	=r21		;result byte 3 (MSB)
.def	mcnt16u	=r22		;loop counter

;***** Code

mpy16u:	
	clr r19
	mov mc16uL, r8
	mov mc16uH, r9			;copy the counts to multiplicand
	ldi r18, 5				;load the multiplier, to measure the
	mov mp16uL, r18			;5v range
	clr	m16u3				;clear 2 highest bytes of result
	clr	m16u2
	ldi	mcnt16u,16			;init loop counter
	lsr	mp16uH
	ror	mp16uL

m16u_1:	brcc	noad8		;if bit 0 of multiplier set
	add	m16u2,mc16uL	;add multiplicand Low to byte 2 of res
	adc	m16u3,mc16uH	;add multiplicand high to byte 3 of res

noad8:	ror	m16u3		;shift right result byte 3
	ror	m16u2		;rotate right result byte 2
	ror	m16u1		;rotate result byte 1 and multiplier High
	ror	m16u0		;rotate result byte 0 and multiplier Low
	dec	mcnt16u		;decrement loop counter
	brne	m16u_1		;if not done, loop more

	//////////////////////////////////
.undef	mc16uL				;multiplicand low byte
.undef	mc16uH				;multiplicand high byte
.undef	mp16uL				;multiplier low byte
.undef	mp16uH				;multiplier high byte
.undef	m16u0				;result byte 0 (LSB)
.undef	m16u1				;result byte 1
.undef	m16u2				;result byte 2
.undef	m16u3				;result byte 3 (MSB)
.undef	mcnt16u				;loop counter

ret	
	
;______________________________________________________________________

;***************************************************************************
;*
;* "div32u" - 32/32 Bit Unsigned Division
;*
;* Ken Short
;*
;* This subroutine divides the two 32-bit numbers 
;* "dd32u3:dd32u2:dd32u1:dd32u0" (dividend) and "dv32u3:dv32u2:dv32u3:dv32u2"
;* (divisor). 
;* The result is placed in "dres32u3:dres32u2:dres32u3:dres32u2" and the
;* remainder in "drem32u3:drem32u2:drem32u3:drem32u2".
;*  
;* Number of words	:
;* Number of cycles	:655/751 (Min/Max) ATmega16
;* #Low registers used	:2 (drem16uL,drem16uH)
;* #High registers used  :5 (dres16uL/dd16uL,dres16uH/dd16uH,dv16uL,dv16uH,
;*			    dcnt16u)
;* A $0000 divisor returns $FFFF
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	drem32u0=r12    ;remainder
.def	drem32u1=r13
.def	drem32u2=r14
.def	drem32u3=r15

.def	dres32u0=r18    ;result (quotient)
.def	dres32u1=r19
.def	dres32u2=r20
.def	dres32u3=r21
.undef	dres32u0	    ;result (quotient)
.undef	dres32u1	
.undef	dres32u2	
.undef	dres32u3
.def	dd32u0	=r18    ;dividend
.def	dd32u1	=r19
.def	dd32u2	=r20
.def	dd32u3	=r21

.def	dv32u0	=r22    ;divisor
.def	dv32u1	=r23
.def	dv32u2	=r24
.def	dv32u3	=r25

.def	dcnt32u	=r17

;***** Code

div32u:
	ldi r22, 4
	mov dv32u0, r22			; divide by 10

	clr	drem32u0	;clear remainder Low byte
    clr drem32u1
    clr drem32u2
	sub	drem32u3,drem32u3;clear remainder High byte and carry
	ldi	dcnt32u,33	;init loop counter
d32u_1:
	rol	dd32u0		;shift left dividend
	rol	dd32u1
	rol	dd32u2    
	rol	dd32u3
	dec	dcnt32u		;decrement counter
	brne d32u_2		;if done
	ret			;    return
d32u_2:
	rol	drem32u0	;shift dividend into remainder
    rol	drem32u1
    rol	drem32u2
	rol	drem32u3

	sub	drem32u0,dv32u0	;remainder = remainder - divisor
    sbc	drem32u1,dv32u1
    sbc	drem32u2,dv32u2
	sbc	drem32u3,dv32u3	;
	brcc	d32u_3		;   branch if reult is pos or zero

	add	drem32u0,dv32u0	;    if result negative restore remainder
	adc	drem32u1,dv32u1
	adc	drem32u2,dv32u2
	adc	drem32u3,dv32u3
	clc			;    clear carry to be shifted into result
	rjmp	d32u_1		;else
d32u_3:	sec			;    set carry to be shifted into result
	rjmp	d32u_1
	/*
.undef	drem32u0	    ;remainder
.undef	drem32u1	
.undef	drem32u2	
.undef	drem32u3	
	
.undef	dd32u0		    ;dividend
.undef	dd32u1		
.undef	dd32u2		
.undef	dd32u3		
.undef	dv32u0		    ;divisor
.undef	dv32u1		
.undef	dv32u2		
.undef	dv32u3		
.undef	dcnt32u	

*/
;------------DELAY 10 MS--------------------------
;This subroutine is placed here, if it was required during 
; the lab. Its not called anywhere in the code. 
;delays for 10ms 
;r20 set to 100
;r21 set to 33
; combined delay will yield 9999 clock cycles
;-------------------------------------------------
delay:
	ldi r20,100
	outer:
		ldi r21, 33
		inner:
			dec r21
			brne inner
			dec r20
			brne outer
	ret
;________________________________________________________________________

