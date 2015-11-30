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
 ;r17- stores dip switch values
 ;r18 - eliminates upper or lower nible depending on the select
 ;r19 - alternates between 01 and 10 to turn on the leds
 ;r20 - serves as a check for value above 9 and used in delay
		subroutines with value 100
 ;r21 - has a value of 33, used in delay loop, combined with 
		r21 and r20 will delay for 9999ms
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
	out portd, r16					;turn on pull up resistors in portd
	sbi portc, 0					;turn on pull up resistors in PC0
	sbi portc, 6					;turn on pull ups in pc6
	ldi r16, $00					;load r16 with 0's
	out ddrd, r16					;set portd and
	out ddrc, r16					;port c as inputs
	ldi r17, $00					;load r17 with 0's
	ldi r18, $F0					;load r18 with 11110000 to read
									; upper or lower switch		
	ldi r23, 6						;to check wheather or not input value is <10							
	ldi r19, 0b01					;load r19 with 01 to turn on led				
	ldi r16, $3F					;output "-" in 7seg 
	out ddrb, r16					;indicating no input

main_loop:
	
	sbis pinc, 6					;wait for load button press
	rjmp check_LOAD					;go to check load if pressed
	sbis pinc, 0					;wait for select button press
	rjmp check_select				;go to checkselect if pressed
	rjmp main_loop					;repeat the code

;when called will alternate between reading upper nibble and lower 
;nibble for every press of the select switch

check_select:
	rcall delay						;delay 10ms for debounce
	sbic pinc,0						;check if select is still pressed
	rjmp main_loop					;if not pressed go to main loop
	in r17, pind					;input values of dip switch
	rcall selectingnibble			;go to selectingnibble subroutine
	rjmp main_loop					;go to main loop

;when load button is pressed, will take the current value of r17 and sends to 
;hex7seg subroutine
check_load:
	rcall delay						;delay 10ms debounce
	sbic pinc, 6					;check if load is  still pressed
	rjmp main_loop					;if not pressed go to main loop
	mov r20, r25					;copy bits from r25 to r20 to check 
	add r20, r23					;wheather is above 9 
	brcs dis_zero					;if above 9 display zero
	rcall hex_7seg					;go to hex7seg and display the 
									;value in 7seg
	rjmp main_loop					;go to main loop

;when called will display 0 in the 7seg display
dis_zero:
	ldi r25, 0						;load r25 with0
	rcall hex_7seg					;go to hex7seg and display the 
									;value in 7seg
	rjmp main_loop					;go to main loop

	;when called, will take the value in r17 and diplays it in the 7seg
hex_7seg:
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later use
	add ZL, r25						;add low byte
	adc ZH, r16						;add in the carry
	lpm r25, z						;load bid pattern from table into r25
display:
	out PORTB,r25					;output patter for 7 seg display
	ret
table: .db $40, $79, $24, $30, $19, $12, $03, $78,$0, $18
		//	0	 1	   2   3    4     5    6    7  8   9

selectingnibble:
	mov r25, r17					;copy r17 to r25
	com r18							;com r17, to alternate between the 
	and r25, r18					;upper nibble and lower nibble
	com r19							;turn led upper or lower
	sbrc r19, 0						;skip if bit 0 is 0, indicating upper nibble
	rcall swap_nibble				; goto swap nibble to swap the upper to lower
	rcall dis_led					;display the led to indicate
	ret

;when the r19 is 10, indicating the upper nibble is selected
;the digits is r17 will be swapped, so the 7seg could be display1
swap_nibble:
	swap r25						;swap r17, so the upper nibble will be in
									;lower nibble
	ret
;***************************
;diplay the corresponding led to nibble,
;when r19:10 the upper nibble led will be on
;when r19:01 the lower nibble led will be on

dis_LED:
	//code to yet be determined based on led placements
	out porta, r19					;turn on the led 1 or 2;
	ret

;**************************
;delays for 10ms 

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
