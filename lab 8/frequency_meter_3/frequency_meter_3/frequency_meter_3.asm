/*
 * frequency_meter_3.asm
 *
 ; This program will be the same as the previous lab. except the gate period will 
 ; be check by the timer and interrupt. The lcd display will now display in decimial 
 ; instead of hex. This is done using a subroutine provided by the atmel corp
 ; The Lcd setup code is copied from asm file provided in the previous lab. 
 ;the gater period of this code will be 1/2 second, meaning both positive and 
 ;negative edges will be counted. This is similar to the two other program. 
 ; only the compare register is changed from the previous code
 
 ;inputs - pa7(freq generator)
 ;outputs - pb(J2 - connecting to the lcd)
 ;switches are connected to pd, but since they are not used 
 ;they will not be initialized. 
 ;
 ; register modified for the code i added:
 ; r16 - general pupose 
 ; r8 and r9 - used as the positive edge counter
 ; r25  - has the values of the freq, which will later be sent to y
 ; r8, r9 - positive edge counters
 ; 
 ; r17 - incremented for 6 times, used to empty spaces on the lcd 
 ; for 6 times. The frequency will be located at the center
 ; 
 ; r27 - set to 6, so we can compare and stop after r17 is inc 
 ; 6 times.
 ; r1,r2,r3,r4, r5 are used to unpack and contain the values stored 
 ; in r8 and r9, which will later be accessed to display the freq
 ; 
 */ 


.NOLIST 
.include "m16def.inc" 
.LIST 
 

 ;********************************************************************
	 .cseg 
	 .org 0								;reset/restart code entry point <<<<<<<< 
	 rjmp reset	
	 //when the counter is equal to 1s, the interrupt will be called
	 //0x0E is the adress for timer compare match B. 
	 //when the interrupt is called, it will jump to isr_tc0_display
	 .org 0x0E
	 jmp isr_tc0_display		

;*********************TIMER INITIALIZATION*************************** 
;_____________________________________________________________________
	
start_tc1:	
//intialization for the timer
	ldi r16, $00
	out TCNT1H, r16						; set up counter with 0's
	out TCNT1L, r16						;
	;Init Timer/counter Interrupt MaSK (TIMSK) register to enable/set 
	ldi r16, 8							;load with bcd 1000, this will enable the 
										;"ocie1b" which is located in bit 4 of the
										;register. 
										;refer to datasheet pg 115 for details
	out TIMSK, r16						;set up the timer interrupt

	ldi r16, 1<<ICF1					;loading the timer interrupt flag register
	out TIFR, r16						;


	ldi r16, $1E						;load the counter with 15625
	out OCR1BH, r16						; so that we will get 1s 
	ldi r16, $84
	out OCR1BL, r16						;
	sei									;enable global interrupts...


	;TCCR1B = FOC0 : WGM11 : COM11 : COM10 : WGM11 : CS12 : CS11 : CS10 
	; 0 0 0 0 0 0 1 1 
	; FOC Off; No WF Gen; COM=Nrml Port Op; Pre-scaler= 1/64 
 

	ret
;_______________________________________________________________________


reset:
	ldi r16, low(ramend)
	out spl, r16
	ldi r16, high(ramend)
	out sph, r16						;initialize stack pointer


	ldi r16, $00
	out ddrd, r16						;set up the port b as inputs to read the
										; pbsw values
										; and nand gate input on pd(2)

	ldi r16, 0xff						; set portB = output.
    out DDRB, r16						; for lcd display
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1

	ldi r16, 1							; set DDRC for all in but PC0
	out DDRC, r16
	sbi PortC, 0						; turn off sounder

	ldi r16,0b01000000					; set up port a to 
	out ddra, r16						;read the frequency input on pa7 and output
										; pulse on pa6

	rcall init_lcd_dog					; init display, using SPI serial interface 

	
	rcall start_tc1						;init the timer counter 1
		/*
	ldi r16, 28
	mov r9, r16
	ldi r16, 60
	mov r8, r16*/						;for testing in simulation
	
main:
	//start timer code
	ldi r16, 0<<CS12|1<<CS11|1<<CS10	; load 64 PRESCaLE TCCR0 value. 
	out TCCR1B, r16						; and start timer
	rcall frequency_meter_3				; load the timer and count the frequency
	clt									;clear the t flag
	rcall unpack						;when timer is done, unpack the edge counts
	rcall message_dsp_loop				;after its unpacked, display 
	rjmp main						
/*********************************************************************************
    subroutine: frequency_meter_3
      This subroutine uses r9:r8 to store the positive edge counters
      Every time there is a logic change from 0 to 1 or 1 to 0 it updates the 
      new value into r25 and for every logic change the edge counter is
      incremented. This program runs for half a second until the t flag is set
*********************************************************************************/
frequency_meter_3:
	ldi r16, $00
	mov r8, r16
	mov r9, r16
	in r25, pinA				;and positive edge counter
	check_edge:		
		brts check_edge
		in r16, pina			;take in the current wave signal logic 
		cp r16,r25			;and compare to previous logic recorded, 
		breq check_edge			;if it is the same then skip to tweak delay		
		mov r25, r16
		inc r8				;and then increment the counter
		brne check_edge			;if it didnt over count then go to tweak delay
		inc r9				;if so then increment the second register
		brtc check_edge
		ret


;-----------------------------
;when the interrupt is called it will jump to this subroutine
;set the T flag, resets the timer, update the display 


isr_tc0_display:
;codes will be added here after frequency subroutine is added. 
		push r16
		set									;set the tflag
		ldi r16, $00
		out TCNT1H, r16						; 
		out TCNT1L, r16						;reset the timer counter
		pop r16
		reti


;*********************LCD DISPLAY CODE******************************
;---------------------------------------------------------
;Code to load and display each line on the lcd 
;r25 is used to load the value of the each digit to the pointer
;line 2 refers to table, which containes numbers and depending 
;on the frequncy, each number is picked and displayed 
;---------------------------------------------------------
	
message_dsp_loop:
   rcall clr_dsp_buffs					; clear all three buffer lines
   rcall update_lcd_dog					;
   ldi r16, $3A							; compare weather the frequency value 
   cp r9, r16							; is less than 15k
   BRLO regular							;if less then branch off and display the
										; calculated value
										;if not continue.
   
overflow:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message<<1)		;
   ldi  ZL, low(line1_message<<1)		;
   rcall load_msg						; load message into buffer(s).

   /*second line will be left blank when overflows
   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message<<1)		;
   ldi ZL, low(line2_message<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   */

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message<<1)		;
   ldi  ZL, low(line3_message<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg

line1_message:	.db 1, "****overflow****", 0  ; test string for line #1.
line2_message:	.db 2,"",0
line3_message:	.db 3, "~~~~~>15khz~~~~~", 0  ; test string for line #3.




regular:

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

;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message0:	.db 1, "***FREQUENCY****", 0  ; test string for line #1.
line2_message0:	.db 2,"",0
line3_message0:	.db 3, "FM3***HZ**0.5SEC", 0  ; test string for line #3.



;**************************************************************************
;---------------------------- SUBROUTINES ----------------------------

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
     ldi YH, high (dsp_buff_1)			; Load YH and YL as a pointer to 1st
     ldi YL, low (dsp_buff_1)			; byte of dsp_buff_1 (Note - assuming 
										; (dsp_buff_1 for now).
     lpm R16, Z+						; get dsply buff number (1st byte of msg).
     cpi r16, 1							; if equal to '1', ptr already setup.
     breq get_msg_byte					; jump and start message load.
     adiw YH:YL, 16						; else set ptr to dsp buff 2.
	 ldi r17, $00
	 ldi r27, 6
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
	cpse r17, r27					;check if 6 places typed
	rjmp digit_load					;repeat until 6 places
	mov r25, r5						;load the first number in freq
	rcall get_dis_freq				;display 
	mov r25, r4						;load the first number in freq
	rcall get_dis_freq				;display 
	mov r25, r3						;load the second number in freq
	rcall get_dis_freq				;display 
	mov r25, r2						;load the third number in freq
	rcall get_dis_freq				;display 
	mov r25, r1						;load the fourth number in freq
	rcall get_dis_freq				;display 
	rjmp msg_loaded					;go to the next line of the lcd

get_dis_freq:
//	ldi r16, $00					;clear for later use
//	add ZL, r25						;add low byte
//	adc ZH, r16						;add in the carry
//	lpm r25, Z+						;load bid pattern from table into r25
	st Y+, r25						;display the selected frquency
	ret		

	
msg_loaded:
     ret

;------------------------------------------------
;unpacks the values store in r8 and r9 to r1- r4
; r4 containe the left most number ie the thousanth
;digit and r1 the right most number
;------------------------------------------------
unpack:
	push r16						;store the value currently in r16
	rcall bin2BCD16					;convert the values from binary to bcd
	//sub r13, r9						;to fix slight error in frequency conversion
	mov r2, r13						;make a copy of r13 in r2
	mov r4, r14						;make a copy of r14 in r4
	mov r6, r15						;make a copy of r15 in r6
	ldi r16, $0f					;use and function to
	and r13, r16					;mask the upper nibble of r8
	mov r1, r13						;move lower nibble to r1
	and r14, r16					;mask upper nibble of r9
	mov r3, r14						;move lower nible to r3
	and r15, r16					;mask the upper nibble of r8
	mov r5, r15						;move lower nibble to r1
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
	sub r8, r9
	mov fbinH, r9			;copy the values of edge counter to fbin
	mov fbinL, r8
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


