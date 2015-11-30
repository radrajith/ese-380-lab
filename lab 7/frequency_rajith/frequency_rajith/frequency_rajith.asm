/*
 * frequency_rajith.asm
 *
 ;For this program we will measure the freuquency of the wave,
 ;(pa7) genereated by a wavefunction generator. The freq value 
 ; read is displayed on the lcd, attached to port b. THe program 
 ; will count the number of positive edges for a 1s period, and 
 ; stores that value on r8 and r9, we are using two registers 
 ; becuase number will be in thousands. The r18 and r19 will
 ; be used as loop counter to count for 1s. The subroutines
 ; clr_dsp_buff ,update_dsp and load_msg are taken directly
 ; from the codes provided(creidts:Scott Tierno). The first
 ;line of lcd displays "frequency", the second line will display
 ; the frequency values unpacked and stored in r1 -r4. 
 ;
 ;inputs - pa7(freq generator)
 ;outputs - pb(J2 - connecting to the lcd)
 ;switches are connected to pd, but since they are not used 
 ;they will not be initialized. 
 ;
 ; register modified:
 ; r16 
 ; r21 - used as the positive edge counter
 ; r25  - has the values of the freq, which will later be sent to y
 ; r8, r9 - positive edge counters
 ; r17 - incremented for 6 times, used to empty spaces on the lcd 
 ; for 6 times. The frequency will be located at the center
 ; r18, r19 - 1 s loop counter
 ; r27 - set to 6, so we can compare and stop after r17 is inc 
 ; 6 times.
 ; r1,r2,r3,r4 are used to unpack and contain the values stored 
 ; in r8 and r9, which will later be accessed to display the freq
 ; 


 *  Created: 10/18/2014 9:19:14 AM
 *   Author: radra_000
 */ 


 .nolist
 .include "m16def.inc"
 .list

reset:
	ldi r16, low(RAMEND)				; init stack/pointer
    out SPL, r16						;
    ldi r16, high(RAMEND)				;
    out SPH, r16	

    ldi r16, 0xff						; set portB = output.
    out DDRB, r16						; 
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1

	ldi r16, 1							; set DDRC for all in but PC0
	out DDRC, r16

	sbi PortC, 0						; turn off sounder
//  ldi r21, 0							;load edge counter 
//	ldi r22, $A0						;load loop counter
//	ldi r23, $fa						;load r23 with 250, so whenever other 
										;counter registers reach 250 we could find the 
										;frequency or delay accurately			
					
//	ldi r16, 0x59						;this is just a test code used for simulating 
//	mov r8, r16							;purposes
//	ldi r16, 0x13
//	mov r9, r16
//	ldi r27, 6
    rcall init_lcd_dog					; init display, using SPI serial interface
	

//main will call various subroutines. first it will measure the frequcency
; The unpack will take the ferquency values and store each number in r1 - r4
; the message_dsp_loop will take the values stored in r1-r4 and displays it 
; and it will repeat forever.

main:
	//rcall freq_meas_1secgate			;count the freqency of the wave. 
	rcall unpack						;unpack the calcualted frequency value
	rcall message_dsp_loop				;display the values unpacked
	rjmp main							;repeat the process

;-------------------------------------------------
;code to count the number of positive edges and store
;the value in r8 and r9, counted for 1s. 
;--------------------------------------------------

freq_meas_1secgate:
	ldi r19, $a0						;set initial values	
	ldi r18, $00						;for the outer loop counter
	in r25, pinA						;and positive edge counter
	pos_edge:
		ldi r17, 10						;set tweak delay to 10
		in r16, pina					;take in the current wave signal logic 
		cp r16,r25						;and compare to previous logic recorded, 
		breq tweak						;if it is the same then skip to tweak delay
		ldi r17, 7						;set tweak delaay for 7
		ldi r25, $00					;set previous logic to 0 just in case
		brcs tweak						;if there is a carry then branch
		ldi r17, 2						;if not then set tweak delay to 2
		ldi r25, $80					;and set previous logic to be 1
		inc r8							;and then increment the counter
		brne tweak						;if it didnt over count then go to tweak delay
		inc r9							;if so then increment the second register
		tweak:		
			dec r17						;decrement the tweak counter
			brne tweak					;and keep looping
		neg_edge:	
			dec r18						;decrement outer loop 
			brne pos_edge				;counter and if 0
			dec r19						;then decrement the second register
			brne pos_edge				;if second register is not 0 then keep looping	
	ret
;---------------------------------------------------------
;Code to load and display each line on the lcd 
;r25 is used to load the value of the each digit to the pointer
;line 2 refers to table, which containes numbers and depending 
;on the frequncy, each number is picked and displayed 
;---------------------------------------------------------
	
message_dsp_loop:
   rcall clr_dsp_buffs					 ; clear all three buffer lines
   rcall update_lcd_dog					 ;
   

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

;--------------------------------------
;lines to display on the lcd
;--------------------------------------

line1_message:	.db 1, "***FREQUENCY****", 0  ; test string for line #1.
line2_message:	.db 2," ",0

line3_message:	.db 3, "\/\/\HERTZ/\/\/\", 0  ; test string for line #3.





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
	mov r2, r8						;make a copy of r8 in r2
	mov r4, r9						;make a copy of r9 in r4
	ldi r16, $0f					;use and function to
	and r8, r16						;mask the upper nibble of r8
	mov r1, r8						;move lower nibble to r1
	and r9, r16						;mask upper nibble of r9
	mov r3, r9						;move lower nible to r3
	com r16							;load with f0 to mask lower nibble
	and r2, r16						;mask lower nibble of r8
	swap r2							;switch upper and lower nibble
	and r4, r16						;mask lower nibble of r9
	swap r4							;switch upper and lower nibble
	/*
	ldi r17, $10					;add thirty to every number 
	ldi r18, $30					;add thirty to every number 
	ldi r16, 6						; 
	add r16, r1
	brcs hex_check					;carry is set, skip the bit

	add r1, r17						;
	add r1, r18						; 
	ldi r16, 6						; 
	push r2
	add r16, r2
	sbrc sreg, 1					;carry is set, skip the bit
	add r2, r17						;
	add r2, r18						; 	
	ldi r16, 6						; 
	push r3
	add r16, r3
	sbrc sreg, 1					;carry is set, skip the bit
	add r3, r17						;
	add r3, r18						; 
	
	ldi r16, $30					;add thirty to every number
	 */
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later use
	add ZL, r1						;add low byte
	adc ZH, r16						;add in the carry
	lpm r1, z						;load bid pattern from table into r25
	
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later useadd ZL, r2						;add low byte
	add ZL, r2						;add low byte
	adc ZH, r16						;add in the carry
	lpm r2, z						;load bid pattern from table into r25
	
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later useadd ZL, r3						;add low byte
	add ZL, r3						;add low byte
	adc ZH, r16						;add in the carry
	lpm r3, z						;load bid pattern from table into r25
	
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later useadd ZL, r4						;add low byte
	add ZL, r4						;add low byte
	adc ZH, r16						;add in the carry
	lpm r4, z						;load bid pattern from table into r25
	
	pop r16							;retrive the value previosly stored
	

	ret
	table: .db $30, $31, $32, $33, $34, $35, $36, $37,$38, $39, $41, $42, $43, $44, $45, $46
			//	0	 1	   2   3    4     5    6    7  8   9	A	  B    C	D	  E	   F

	

;-------------------------------------------------
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

