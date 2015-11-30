
/*LAB 3 - INTERNAL PULL UP RESISTORS, DIRECT DRIVE 7 SEGMENT DIGIT
 *---------------------------------------------------------------
 * prelab3.3_inout.asm
 *
 *This program will turn on the same number of led from the bottom
 * of the bargraph, as the number of swiches in position 1. 
 * This project will include the sws_lvl file.
 *
 * Inputs used: PD0 to PD7 (DIP-8 switch)
 * Outputs used: PB0 to PB7 (Bargraph, 8 LEDs, active low)
 *
 * assumes: nothing
 * alters: r16, SREG
 *  
 * Author: Rajith Radhakrishnan (109061463) , Raymond Ng(109223276)
 * ESE 380 L01, Bench 6
 * Version 1.0
 */ 


 .nolist
 .include "m16def.inc"			;include part specific header file
 .list

 reset:
	;configure I/O ports(1 pass only!)
	
	;configure port B as an output port
	ldi r16, $FF				;initizalize register 16, with all 1's
	out DDRB, r16				;set all bits in PORTB to outputs
	
	;configure port D as an input port
	ldi r16, $00				;initialize and load register 16 with all 0's
	out DDRD, r16				;set all bits in PORTD to inputs
	ldi r16, $FF				;initialize and load register 16 with all 1's
	out portD, r16				;enable portd pins as outputs, this activates the pull up resistor

main_loop:
	in r16, PIND				;input switch value stored in Pin D to r16
	;code to count switches in 1's position and output to bargraph
	ldi r17,8					;loop parameter for inner loop
	ldi r18, $00				;initialize r18 with 0, which is the initial value 
								;to be outputed on the bargraph
next_bit:
	lsl r16						;shift msb of r16 into carry
	brcc dec_bitcounter			;branch if carry clear
	ror r18						;rotate 1 from cary into bargraph image

dec_bitcounter:
	dec r17						;decrement the valuestored in r17
	brne next_bit				;branch if result after dec is not zero
	com r18						;complement the values, bargraph image
	out PORTB, r18				;output the value/bargraph image to portb
	rjmp main_loop				;start the code from the beginning
