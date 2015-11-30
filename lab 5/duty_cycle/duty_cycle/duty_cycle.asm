/* 5. Pulse width modulation & program modeularity part 1
 * duty_cycle.asm
 ; components used:
 ; 4 bit nibble DIP switches(2), 7 seg dispaly, 3 leds with 270 ohm resisotr
 ; 3 pushbuttons
 ;
 * This program will read the lower DIP switches and output a PWM signal depending 
 ; on the BCD number entered using the switch. The MSB will be on the top and LSB 
 ; on the bottom of the switch. The first pushbutton on top will be utilized for 
 ; as the load button and led as output, and the duty cycle will be displayed on 
 ; the 7seg. 
 ; output 0 for all the values above 9
 ; 
 * inputs used: PD4-7(switches), PC 7(PBSW) 
 * outputs used: PB 0-7(7seg), PA0 (LED)
 *
 ;register r20 and 21 used for delay timers
 ;r18 - to store switch values
 *   Author: radra_000
 */ 
 .nolist
 .include "m16def.inc"
 .list

 ;equates for delay loop countes
 .equ outer = 100					;delays 241 clk cyles
 .equ inner = 33					;delays 13 clk cycles
	
//loads the registers and ports required, run and repated when powere up or reset
 reset:
	//initizling the stack pointer
	ldi r16, LOW(RAMEND)			;load SPL with low byte of
	out SPL, r16					;RAMEND adress
	ldi r16, HIGH(RAMEND)			;load SPH with low byte of 
	out SPH, r16					;RAMEND adress

	LDI r16, $00					;load register 16 with 1's
//	OUT PORTB, r16					;load the 7seg diplay
	OUT DDRB, r16					;turn on all leds in 7seg
	ldi r16, 1						;load r16 with 1
	OUT DDRA, r16					;set up led as output
	ldi r16, 0b01111111				;set only the first switch
	out DDRC, r16					;set the pc7 as the input
//	ldi	r16, 0b11111111	 
//	out DDRD, r16					;set the lower DIP Switch
	LDI r16, $ff					;load register 16 with 0's 
	OUT PORTD, r16					;load the pull ups for dip switch
	OUT PORTC, r16					;load the pull ups for PBSW
	OUT PORTB, r16					;output 0 on 7seg

//check if the load button is pressed 

main_loop:
	ldi r19, 4						;r19 used as counter
	SBIC PINC, 7					;check if the PB switch is pressed
	rjmp main_loop					;repeat until button is pressed
	rcall delay						;wait for 10ms(debounce)
	SBIS PINC, 7					;check if PB is still pressed
	rjmp read_switch				; jump to read switch
	rjmp main_loop					;repeat the main loop

//read values of switch 
read_switch:
	in r18, PIND					;input the switch values to r18
//	ldi r16, 0						;load with 0 to compare with swtich
	CPI r18, 0						;check weather r18 is 0
	BREQ clear						;jump to clear if equal
	ldi r16, $f6						;load r16 with 90 in hex, to check if its 9+
	add r16,r18						;if there is a negative value then 
	brcs clear						;output 0 for anything greater than 9

	rcall hex_7seg					;go to hex7seg and return
	rcall duty_pwm					;go to dutypwm and return

//output the pwm singal
duty_pwm:
	SBIC PINC, 7					;check if load button is pressed
	rjmp main_loop					;if pressed restart 
	SBI PORTA, 0					;set port a to high
	rcall delay_on					;turn on the led for cetain period
	CBI PORTA, 0					;set port a to low
	rcall delay_off					;turn off the led for certain period
	rjmp duty_pwm					;output the signal until button press




//subroutines
//-----------
/*
//get r18 to 4 digits from 8 digits 
hex_7seg:
	lsr r18							;shift lsb to carry
	dec r19							;decrement r19 for 4 times
	BRNE hex_7seg					;after shifting 4 digits go to bcd_7seg
	*/

//display the duty cycle value
hex_7seg:
	mov r17, r18					;copy r18 to r17
	ldi ZH, HIGH(table*2)
	ldi ZL, LOW(table*2)			;set z to point to start of the table
	ldi r16, $00					;clear for later use
	add ZL, r17						;add low byte
	adc ZH, r16						;add in the carry
	lpm r17, z						;load bid pattern from table into r18
display:
	out PORTB,r17					;output patter for 7 seg display
	ret
table: .db $40, $79, $24, $30, $19, $12, $03, $78,$0, $18
		//	0	 1	   2   3    4     5    6    7  8   9


//output 0 in the signal
clear:
	CBI PORTA, 0					;set port a to 0
	rjmp main_loop

//turn on the signal for the switch value
	
delay_on:
	ldi r20, 33						;load r20 with 100
	mov r21, r18					;load r21 with switch values
	rjmp inner_loop					;delay for r18*100 cycles

//turn off the signal for 10 minus switch value
delay_off:
	ldi r20, 33						;load r20 with 100
	ldi r21, 10						;load r21 with 10
	sub r21, r18					;subract 10 - switch values
	rjmp inner_loop					;delay for r21*100 cycles

delay:
	ldi r20, inner					;set r20 to 240
	ldi r21, outer					;	set r21 to 13
inner_loop:
	dec r20							;decrements 240
	brne inner_loop					;repeat until r20 is 0
outer_loop:
	ldi r20, inner					;reset the r20 to 240
	dec r21							;decrement for 13 cycles
	brne inner_loop					;repeat until r21 is 0 
	ldi r21, outer					;reset r21 for next delay
	ret								;return 
/*
delay:
	ldi r20, inner					;set r20 to 240
	//ldi r21, outer					;	set r21 to 13
inner_loop:	
	ldi r21, outer
outer_loop:
	dec r21							;decrements 240
	brne outer_loop					;repeat until r20 is 0
	dec r20
	brne inner_loop
	ret								;return 

	*/
