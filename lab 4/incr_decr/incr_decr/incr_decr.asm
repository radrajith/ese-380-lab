/*
 * incr_decr.asm
 *
 *  Created: 9/29/2014 5:02:01 PM
 *   Author: Raymond
 *
 *	Description: This program is used as a counter program for the seven segment led display
 *		When pin 0 is pressed then the counter is incremented and the LED will display the current count
 *		ranging from 0 to 9. When it goes over 9 then the overflow LED will be lit. When pin6 is pressed 
 *		then the counter will decrement. When pin7 is pressed then the program will display a 0 and the
 *		program is reset. The program checks for the switch bounces.
 // inputs : port c0, c6, c7, port d 
 // outputs: port b, port a0
 *
 */ 

 .nolist
 .include "m16def.inc"
 .list

  //load all the pins in port B, Port D and port A 0, as outputs, Port C (0,6,7) as inputs. 
 //pull ups enabled in port D and A
 reset:
    /*LDI R16, low(RAMEND)		
	OUT SPL, R16
    LDI R16, high(RAMEND)
    OUT SPH, R16				;this code is for rcall, from ese 123
	*/
	ldi r16, $ff				;load r16 with 1's
	out PORTB, r16				;set up the 7seg disp
	out DDRA, r16
	ldi r16, $00				;load r16 with 0's
	out DDRC, r16
	out DDRD, r16				;set up dip switch, port d as input
	ldi r16, $ff				;load r16 with 1's
	out PORTD, r16				;set up the pull ups in D
	out PORTC, r16				;set up the pull ups in C 
	//out DDRC, r16
	ldi r16, $c1				;set up pullups for
	out PORTD, r16				;the 8th 7th and 1st bit
	ldi r17, $ff				;delay timer
	ldi r19, $00  				;clear r19 to store counter
	ldi r18, $00				;clear r18 for use on counter
	//ldi r20, $00				;clear for overflow
	SBI PORTA, 0				;set the led to 1 //active low
main_loop:
	ldi r23, $10				;set the first delay counter to  10
	ldi r24, $10				;set the second delay coutner to 10
	ldi r25, $10				;set the third delay counter to  10
	ldi r21, $10				;set the fourth delay coutner to 10
	ldi r22, $10				;set the fifth delay coutner to 10
	sbic PINC,0  				;check for button press increment
	rjmp dec_check				;keep checking 
	delay1:
		dec r17						;decrement for 255 cycles
		brne delay1					;loop for 255 cyles
		dec r23						;decrement for 40 cycles
		ldi r17,$ff					;set the ldi back to 255 
		brne delay1					;go back to delay1 if not 0 
	sbic PINC,0  				;check for button press increment
	rjmp dec_check				;if false then check decrement button
	CPI r18,$09					;check if counter is at 9
	breq overflow				;if so then set overflow for led
	inc r18						;inc counter for LED
	rjmp bcd_7seg				;jump to bcd display
dec_check:						;check for dec pushbutton
	sbic PINC,6					;check if button is pressed
	rjmp reset_check			;if not jump to reset check
	//rcall delay				;delay for bounce
	delay2:
		dec r17						;decrement for 255 cycles
		brne delay2					;loop for 255 cyles
		dec r24						;decrement for 40 cycles
		ldi r17,$ff					;set the ldi back to 255 
		brne delay2					;go back to delay1 if not 0 			
	sbic PINC, 6				;check if button is pressed
	rjmp reset_check			;if not then check reset button
	dec r18						;if so then decrement
	rjmp bcd_7seg				;display 7 seg leds
reset_check:
	sbic PINC,7					;check if reset button is pressed
	rjmp main_loop				;if not then go back to main loop
	//rcall delay				;if so then delay for bounce
	delay3:
		dec r17						;decrement for 255 cycles
		brne delay3					;loop for 255 cyles
		dec r25						;decrement for 40 cycles
		ldi r17,$ff					;set the ldi back to 255 
		brne delay3					;go back to delay1 if not 0 		
	sbic PINC,7					;and check if button is pressed
	rjmp main_loop				;if not then check other buttons
	ldi r18,$40					;if so then
	out PORTB, r18				;display 0
	rjmp reset					;and reset the program

overflow:
	cbi PORTA, 0;				;turn on for overflow display
bcd_7seg:
	mov r19, r18				;move the value in r18 to r19 so that it will not change the counter
	ldi ZH, high (table * 2)	;set Z to start of table
	ldi ZL, low (table * 2)		;
	ldi r16, $00				;clear for later use
	add ZL, r19					;add low byte
	adc ZH, r16					;add in the CY
	lpm r19, Z					;Load in the byte pattern from table into r18
display:
	//out PORTA, r20			;ouput overflow
	out PORTB, r19				;output the LEDs
	sbis PINC, 0				;Check PINC0 for 
	rjmp display      			;when it is not pressed
	//rcall delay				;check for the	
	delay4:
		dec r17						;decrement for 255 cycles
		brne delay4					;loop for 255 cyles
		dec r21						;decrement for 40 cycles
		ldi r17,$ff					;set the ldi back to 255 
		brne delay4					;go back to delay1 if not 0 
	sbis PINC, 0				;debounce
	rjmp display				;if debounce then check again
	sbis PINC, 6				;Check PINC6 for 
	rjmp display      			;when it is not pressed
	//rcall delay					;check for the
	delay5:
		dec r17						;decrement for 255 cycles
		brne delay5					;loop for 255 cyles
		dec r22						;decrement for 40 cycles
		ldi r17,$ff					;set the ldi back to 255 
		brne delay5					;go back to delay1 if not 0 
	sbis PINC, 6				;debounce
	rjmp display				;if debounce then check again
	rjmp main_loop
/*//this is a subroutine
delay:
	dec r17						;decrement for 8 cycles
	brne delay					;loop for 8 cyles
	ldi r17, $2					;reset delay timer
	ret							;return
*/
		;table of seven segment display 0-9
table: .db $40,$79,$24,$30,$19,$12,$03,$78,$0,$18
	;		0	1	2	3	4	5	6	7	8	9