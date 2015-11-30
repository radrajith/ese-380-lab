 /*4. Software Switch Debouncing
 *---------------------------------------------------------------
 * 7-seg-diag.asm
 ; This program will enable a user to turn on and off all segments 
 ; of the 7seg, with a press of a pushbutton switch (PBSW1).
 *
 * Inputs used: PD0 to PD7 (DIP-8 switch)
 *				PC0, PC6, PC7 (PBSW1, PBSW2, PBSW3,active low)
 * Outputs used: PB0 to PB7 (7 seg display, active low)
 *				 PA0 (overflow indicating LED)
 *
 *
 * assumes: nothing
 * alters: r16, SREG
 *  
 * Author: Rajith Radhakrishnan (109061463) , Raymond Ng(109223276)
 * Date: 10/01/14
 * ESE 380 L01, Bench 6
 * Version 1.0
 */ 

 
 .nolist
 .include "m16def.inc"			;include part specific header file
 .list

 //load all the pins in port B, Port D and port A 0, as outputs, Port C (0,6,7) as inputs. 
 //pull ups enabled in port D and A

reset:
   /* LDI    R16, low(RAMEND)
	OUT    SPL, R16
    LDI    R16, high(RAMEND)
    OUT    SPH, R16				;this code is for rcall, from ese 123
	*/
	ldi r16, $00				;load r16 with 0's
	out DDRD, r16				;set up dip switch, port d as input
	out DDRC, r16				
	ldi r16, $ff				;load r16 with 1's
	out PORTD, r16				;set up the pull ups in D
	out PORTC, r16				;set up the pull ups in C
	ldi r17, $ff				;delay timer	///changed from 2 to ff
	ldi r16, $00				;load r16 with 1's
	out PORTB, r16				;load PORT B, active low/turn on light
//wait for the PBSW1 signal, activate or deactivate 7seg for every press
//eliminate the debounces

main_loop:

	SBIC PINC, 0				;wait for the button press
	rjmp main_loop				;if button is not pressed repeat the loop
	ldi r18, $10				;reset delay timer	 ///changed from 2 to 10
	ldi r19, $10				;reset second delay timer	 ///changed from 2 to 10
	rjmp delay1					;delay for 10 clock cycles
	
	//This will delay for 10000 us, which is equal to 10 ms

delay1:


	dec r17						;decrement for 255 cycles
	brne delay1					;loop for 255 cyles
	dec r18						;decrement for 40 cycles
	ldi r17,$ff					;set the ldi back to 255 
	brne delay1					;go back to delay1 if not 0 
	rjmp seg_on_off				



//turn on the light when the button pressed and when the button is 0
//if its still pressed it will just keep the lit on, until 0 and 
// it will start the program over. 

seg_on_off:

	SBIC PINC,0					;Check if the button is still pressed
	rjmp main_loop				;repeat the program it is a noise
	com r16						;invert all bits in r16
	out PORTB, r16				;Turn on led

check_button:
	SBIC PINC,0					;check if the button is not pressed
	rjmp delay2					;delay for 10ms for debounce
	SBIC PINC,0					;check if the button is still not pressed
	rjmp main_loop				;restart the program
	rjmp check_button			;loop again

	//This will delay for 10000 us, which is equal to 10 ms. 
delay2:
	dec r17						;decrement for 255 cycles
	brne delay2					;loop for 255 cyles
	dec r19						;decrement for 40 cycles
	ldi r17,$ff					;set the ldi back to 255 
	brne delay2					;go back to delay1 if not 0 
	rjmp main_loop				;restart the program			

/*

//this is a subroutine
delay:
	dec r17						;decrement for 8 cycles
	brne delay					;loop for 8 cyles
	ldi r17, $2					;reset delay timer
	ret							;return
	
*/