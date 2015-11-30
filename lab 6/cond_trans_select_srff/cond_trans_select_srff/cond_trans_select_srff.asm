/*6. Conditional data transfer technique
 * cond_trans_select_srff.asm
 *
 ; This program is a modification of the second program and
 ; will utilize 2 pbsw, pbsw 3 will used with the d_ff and act
 ; as select and Pbsw2(pc6) will be used as load. When the load 
 ; press is recognized a 1 will be outputted to PA6 to reset the 
 ; input going into PA7. Thus acting as a srff. Two leds will 
 ; be attached to PA0 and PA1. PA0 led will be turned on when the 
 ; lower nibble dip switch is used, and PA1 led for the other. 
 ; select pbsw will alternate between lower and upper dip switch
 ; for each press. load will load the input values of the selected
 ; dip switch.
 ;
 ;inputs : dip switch (Port D), PBSW 3 and 2(PC7,PC6)
 ;outputs: 7seg display (Port B), led 1 and 2(PA0,PA1), 
 ;			r18 used for porta output
 ;			r17 used to store and output dip switch input

 *  Created: 10/9/2014 10:53:35 AM
 *   Author: raymond ng
 */ 

 .nolist
 .include "m16def.inc"
 .list

reset:
	//initizling the stack pointer
	ldi r16, LOW(RAMEND)			;load SPL with low byte of
	out SPL, r16					;RAMEND adress
	ldi r16, HIGH(RAMEND)			;load SPH with low byte of 
	out SPH, r16					;RAMEND adress
	ldi r16, $FF					;load r16 with 1's and
	out portd, r16					;turn on pull up resistors in portd
	out ddrb, r16					;make portb as output
	ldi r16, $43					;PC6 and PC1, PC0 as output
	out ddra, r16					;port a as output 
	sbi portc, 0					;turn on pull up resistors in PC0
	sbi portc, 6					;turn on pull ups in pc6
	ldi r16, $00					;load r16 with 0's
	out ddrd, r16					;set portd and
	out ddrc, r16					;port c as inputs
	ldi r17, $00					;load r17 with 0's
	ldi r18, $00					;load r18 with 0's except for first
	ldi r16, $3F					;output "-" in 7seg 
	ldi r19, $00
	out ddrb, r16					;indicating no input
	sbi porta, 0					;indicate lower nibble 
	cbi porta, 1					;as default
	sbi porta, 6						;set default clear to be 1 
main_loop:
	in r17, portd					;input values of dip switch	
	sbic pina, 7					;wait for load button press
	rjmp LOAD_push					;check for other push button
	rcall delay						;jump
	sbis pinc,7						;back to
	rjmp clear					    ;main loop if false
	ldi r16, $03					;set 00000011
	in r18, porta					;take porta values
	eor r18, r16					;toggle first two bits
	out porta, r18					;turn on the led 1 or 2;
	clear:
	cbi pina, 6						;generate pulse 
	sbi pina, 6						;to clear register
LOAD_push:
	sbic pinc, 6					;check for load
	rjmp main_loop					;pushbutton
	sbis porta, 0					;dont swap if the first bit is selected
	swap r17						;swap nibbles
	andi r17, $0F					;force upper values to 0
	ldi r19, $06					;if it is
	add r19,r17					    ;then
	brhs overflow					;go to overflow
	rjmp hex_7seg					;if not then display
overflow:
	ldi r17, $09					;set max value possible with is 9
hex_7seg:
	//mov r17, r18					;copy r18 to r17
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later use
	add ZL, r17						;add low byte
	adc ZH, r16						;add in the carry
	lpm r17, z						;load bid pattern from table into r18
display:
	out PORTB,r17					;output pattern for 7 seg display
	rjmp main_loop
table: .db $40, $79, $24, $30, $19, $12, $03, $78, $0, $18
		//	0	 1	   2   3    4    5    6    7    8   9
/*
;	Delay:
;		This subroutine will utilize variables r16, and r17.
;		The variabled will be initialized to act as counters
;		to count a 10 ms delay
;		r17: 100, r16: 33
*/


delay:
	push r17						;push aside the registers
	push r16						;r16 and r17 
	ldi r16, 33						;loop through 33 times
	outer:
	ldi r17, 100					;of 100 decrements
	inner:
	dec r17
	brne inner
	dec r16
	brne outer	
	pop r16							;pop the registers back
	pop r17	
	ret							
