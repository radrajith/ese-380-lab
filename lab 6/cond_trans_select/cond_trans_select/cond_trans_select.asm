/*6. Conditional data transfer technique
 * cond_trans_select.asm
 *
 ; This program will utilize 2 pbsw, pbsw 1(pc0) will will used 
 ; as select and Pbsw2(pc6) will be used as load. two leds will 
 ; be attached to PA0 and PA1. PA0 led will be turned on when the 
 ; lower nibble dip switch is used, and PA1 led for the other. 
 ; select pbsw will alternate between lower and upper dip switch
 ; for each press. load will load the input values of the selected
 ;	dip switch
 ;
 ;inputs : dip switch (Port D), PBSW 1 and 2(PC0,PC6).
 ;outputs: 7seg display (Port B), led 1 and 2(PA0,PA1)		

 *  Created: 10/9/2014 10:53:35 AM
 *   Author: radra_000
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
	out ddrb, r16					;make portb as output
	out ddra, r16					;port a as output 
	out portd r16					;turn on pull up resistors in portd
	sbi portc, 0					;turn on pull up resistors in PC0
	sbi portc, 6					;turn on pull ups in pc6
	ldi r16, $00					;load r16 with 0's
	out ddrd, r16					;set portd and
	out ddrc, r16					;port c as inputs
	ldi r17, $00					;load r17 with 0's
	ldi r18, $01					;load r18 with 0's
	ldi r16, $3E					;output "-" in 7seg 
	out ddrb, r16					;indicating no input
	sbi pina, 0
	cbi pina, 1
main_loop:
	in r17, pind					;input values of dip switch	
	sbic pinc, 0					;wait for load button press
	rjmp check_LOAD
	swap r17
	eor r18, $03
	out porta, r18					;turn on the led 1 or 2;
LOAD_push:
	sbic pinc, 6
	rjmp main_loop
	andi r17, $F0
hex_7seg:
	//mov r17, r18					;copy r18 to r17
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later use
	add ZL, r17						;add low byte
	adc ZH, r16						;add in the carry
	lpm r17, z						;load bid pattern from table into r18
display:
	out PORTB,r17					;output patter for 7 seg display
	rjmp main_loop
table: .db $40, $79, $24, $30, $19, $12, $03, $78,$0, $18
		//	0	 1	   2   3    4     5    6    7  8   9