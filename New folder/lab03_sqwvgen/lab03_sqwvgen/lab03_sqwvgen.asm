/*LAB 3 - INTERNAL PULL UP RESISTORS, DIRECT DRIVE 7 SEGMENT DIGIT
 *---------------------------------------------------------------
 * prelab3.4_inout.asm
 *
 ;sqwvgen - simple square wave generating program 
 ; reset - loading all ports, will be used everytime chip is restarted
 ;
 
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
	out DDRA, r16				;set all bits in PORTA to outputs
	cbi PortA, 0				;clear all bit to 0
	

main_wave_loop:
	sbi PortA,0					;start pulse 'on' period
	nop
	nop
	nop
	nop							;some delay
	cbi PortA,0					;start pulse 'off' period
	nop
	nop							;some delay
	rjmp main_wave_loop			;repeat