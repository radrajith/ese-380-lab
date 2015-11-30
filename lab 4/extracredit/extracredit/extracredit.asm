 /*4. Software Switch Debouncing
 *---------------------------------------------------------------
 * 7-seg-diag.asm
 ; Extra credit code:
 ; When button 1 is pressed then a square wave will keep ouputting
 ; When button 2 is pressed once then a square wave will output for 
 ; 10 cycles.
 *
 * Inputs used: PD0 to PD7 (DIP-8 switch)
 *				PC0, PC6, PC7 (PBSW1, PBSW2, PBSW3,active low)
 * Outputs used: PA1, and PA2
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


 reset:
	 ldi r16, $ff			;activate only the pin1 of port A
	 out DDRA, r16
	 ldi r16, $ff
	 out PORTC, r16
	 ldi r16, $00
	 out DDRC, r16
	 ldi r17, $ff
	 ldi r18, $00
	 ldi r20, 10

 main_loop:
	SBIC PINC, 0				;check for button press
	rjmp button2
delay1:
	sbic PINC,6
	rjmp button2
	RJMP sqwave					;go to square wave
button2:
	sbic PINC,6
	Rjmp main_loop				;repeat until button pressed
delay2:
	sbic PINC, 6
	RJMP main_loop				;if its a noise repeat the program
	rjmp pulse
	
	
sqwave:
	out PORTA, r17				;output 1
	NOP NOP						;wait 2 clock cycles
	out PORTA, r18				;output 0
	SBIC PINC,0					;check weather the button is still pressed
	rjmp main_loop				;if its not pressed restart the code
	rjmp sqwave					;if its still pressd continue to display square wave
pulse:

	out PORTA, r17				;output 1
	NOP NOP						;wait 2 clock cycles
	out PORTA, r18				;output 0
	dec r20
	brne pulse
	rjmp main_loop				;if its not pressed restart the code
	