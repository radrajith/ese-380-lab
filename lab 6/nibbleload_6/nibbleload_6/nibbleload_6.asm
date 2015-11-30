/*6. Conditional data transfer techniques
 * nibble_load.asm
 *
 ;This program will wait for the press of pushbutton 1 connected to PC0, 
 ;when pressed, will load the values of the lower nibble dip switch, 
 ; and display the the output in 7seg display. anything above nine will 
 ;be ignored and displayed as zero
 ;
 ;debouncing will not be required because,no matter how many times the dip 
 ;switch is read due to bounce, the input value remain constant for the 
 ;bounce. 
 ;
 ;Inputs - dip switches conected to Port D, pbsw connected to PC0
 ;outputs - 7seg dispay connecte to port B
 ; 

 *  Created: 10/9/2014 10:16:05 AM
 *   Author: radra_000
 */ 
 .nolist
 .include "m16def.inc"
 .list

reset:
	ldi r16, $ff					;set port a and port b
	out ddrb, r16					;into outputs
//	out ddra, r16					;by loading 1s to the data direction register
	out portd, r16					;enable pullup resistors for the dip switch
	sbi portc, 0					;enable pullup resistor for the pushbutton1
	ldi r23, 6						;load r23 with 6 to check weather input is>10
	ldi r16, $00					;set port c and port d
	out ddrc, r16					;into inputs
	out ddrd, r16					;by loading 0s into the data direction register
	ldi r16, $40
	out portb, r16

main_loop:
	sbic pinc, 0					;check if LOAD pushbutton is pressed
	rjmp main_loop					;if not then check again
	in r17, pinD					;take value of portD into r17
	andi r17, $0F					;force the upper nibbles to 0
	mov r18, r17					;copy value of r17 to r18
	add r18, r23					;to check if greater than 9
	brcs check						;if greater, go to check
	rjmp hex_7seg					;jump to hex7seg otherwise

//check will output 0 in the 7seg if the dip switch value is 
//greater than 9
check:
	ldi r17, 0						;load r17 with 0 to diplay 0

hex_7seg:
	//mov r17, r18					;copy r18 to r17
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later use
	add ZL, r17						;add low byte
	adc ZH, r16						;add in the carry
	lpm r17, z						;load bid pattern from table into r18
display:
	out PORTB, r17					;output patter for 7 seg display
wait_1:
	sbis pinc, 0					;wait for a logic 1(when pushbutton is released)
	rjmp wait_1						;before updating the values
	rjmp main_loop
table: .db $40, $79, $24, $30, $19, $12, $03, $78,$0, $18
		//	0	 1	   2   3    4     5    6    7  8   9
/*
delay:
	ldi r18,100
	outer:
		ldi r19 33
		inner:
			dec r19
			brne inner
			dec r18
			brne outer
	ret

*/
