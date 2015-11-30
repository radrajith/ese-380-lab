/*Introduction to the ATmega16A MCU and Atmel Studio 6.1 Software
 *---------------------------------------------------------------
 * prelab2_inout.asm
 * This is a simple program to display the positions
 * of 8 SPST switches on 8 LEDs. If the switch is a 
 * logic 1, the corresponding LED is on. If the SW
 * is a logic 0, the led is off. 
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
	ldi r16, $FF				;load r16 with all 1's
	out DDRB, r16				;set all bits in PORTB to outputs
	ldi r16, $00				;load r16 with all 0's
	out DDRD, r16				;set all bits in PORTD to inputs

again:
	;Infinite loop... Input to switch values, and output to LEDs
	in r16, PIND				;read swtich values
	com r16						;complement swich values to drive LEDs
	out PORTB, r16				;complemented values of the switches are sent to LEDs
	rjmp again					;repeat the instuction listed under "again:"
