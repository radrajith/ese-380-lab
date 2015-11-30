
/*LAB 3 - INTERNAL PULL UP RESISTORS, DIRECT DRIVE 7 SEGMENT DIGIT
 *---------------------------------------------------------------
 * prelab3.4_inout.asm
 *
 ; This program will output the Number in the 7 segment display(MAN72A)
 ; after reading the number of switches in on position. It will utilize
 ; the built in pull resistos in port D. 
 ; reset - loading all ports, will be used everytime chip is restarted
 ; main_loop - sets the loop counter to zero(r18), reads the value of switch(r16)
 ; next_bit - shift msb(r16) to left,  keeps count of loops.  
 
 *
 * Inputs used: PD0 to PD7 (DIP-8 switch)
 * Outputs used: PB0 to PB7 (7 segment display, active low)
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

	;code to count switches in 1's position and set up a loop counter 

main_loop:
	in r16, PIND				;input switch value stored in Pin D to r16
	ldi r17,8					;loop parameter for inner loop
	ldi r18, $00				;initialize r18 with 0, which is the initial value 
								;to be outputed on the bargraph

	;shifts msb to left. branchesto dec_bitcounter if 0, add one to r18 if 1.

next_bit:
	lsl r16						;shift msb of r16 into carry
	brcc dec_bitcounter			;branch if carry clear/ when the value is 0
	inc r18						;when the value is 1, increment the counter value
	
	;when msb of r16 is 0, the value stored in r17 is reduced by 1, this happens for 8 times
	;after r17 is 0, it goes to bcd_7seg

dec_bitcounter:
	dec r17						;decrement the valuestored in r17
	brne next_bit				;branch if result after dec is not zero

	
bcd_7seg:
	ldi ZH, high (table*2)		;set z to point to start of the table
	ldi ZL, low	 (table*2)		
	ldi r16, $00				;Clear for later use
	add ZL, r18					;add zlow with the bits of r18
	adc ZH, r16					;add in the Carry
	lpm r18, Z					;load bit battern from table into r18

display:
	out PORTB, r18				;output pattern for 7seg diplay
	rjmp main_loop				;start the process again

	;table of 7 segment bit patterns to display digits 0-8
	;for each hex number listed, the number of 1(because of active low)
	;in the hex number indicate the number of leds thats goint to be off.

table: .db $40,$79,$24,$30,$19,$12,$03,$78,$0
		   ;0	 1	 2	 3	 4	 5	 6	 7	 8