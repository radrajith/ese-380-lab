/*
 *
 * Lab 11 - final code
 *
 ; This is the final program. Menu screen will be the default screen. The menu screen 
 ; will let you choose between RUN, HOLD, ALARM, CAPTURE, FREQUENCY. 
 ; when its in run mode the code will read the input analog voltage. when its in hold 
 ; mode it will retain the value, and doesnt read again until the pbsw is pressed again.
 ; When its in alarm mode, there will be option to set an alarm voltage between 4 option
 ; when the voltage is set, the circuit will beep when the read voltage is above it. 
 ; when in capture mode, the new voltage will be captured and remain in the screen 
 ; until next voltage is read. under the capture mode, it will speak out the voltage 
 ; that is read. the down button can be used to toggle between audio on and off. when 
 ; audio is off the captured voltage will not be read. Freq mode is similar to the one
 ; done in lab 8, the freq generated in inputted in PA5. The backlight will turn off 
 ; in 5 seconds when not used. If any button is pressed, or new voltage is read. 
 ; 
 ;Hardware used - max144 voltage reader, level shifter, audio output module
 ; registers used by code written by me
 ; r1 - r4 to unpack the bits of the read ascii voltage or frequency
 ; r5 - r7, r10 - to unpack the read ascii voltage or frequency
 ; r8 and r9 to copy the 12 bit value obtained after convertion
 ; r16 for general purpose like initilization etc
 ; r17 as a space counter used in the display subroutine
 ; r23 use as toggle between audio on and off
 ; r28 initialized to 6. to keep r17 in check 
 ; r21 - used to find which menu has been selected
 ; r18 and r19 - copies r8 and r9 values

 ; r27 as a toggle register. changes between 1 or 0 with press of center button 
 ;r8 and r9 will be used to store the adc conversion values
 *  Created: 10/29/2014 2:17:13 PM
 *   Author: radra_000
 
 */
 
.NOLIST 
.include "m16def.inc" 
.LIST 


 ;********************************************************************
	 .cseg 
	 .org 0								;reset/restart code entry point <<<<<<<< 
	 jmp reset	
	 
	 
	 
	 //when the counter is equal to 1s, the interrupt will be called
	 //0x0E is the adress for timer compare match B. 
	 //when the interrupt is called, it will jump to isr_tc0_display
	.org 0x002							;when external interrupt is pressed
	jmp menu							;its located on pd2
	.org 0x00C							;timer interrupt A
	jmp off								;to turn off backlight display

	.org 0x00E							; timer interrupt B
	jmp isr_tc0_display					; display the frequency count


reset:
	ldi r16, low(ramend)
	out spl, r16
	ldi r16, high(ramend)
	out sph, r16						;initialize stack pointer
//button interrupt
	LDI r16,$03
	out mcucr, r16
	ldi r16, 1 << INT0
	out gicr, r16						;initialize button interrupt
//input/output	
	ldi r16, $00
	out ddrd, r16						;set up the port b as inputs to read the pbsw values
	ldi r16, 0xff						; set portB = output.
	out portd, r16
	ldi r16, 0b10111111	
    out ddrb, r16						; for lcd display
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1
	sbi portb, 0
	ldi r16, 1							; set DDRC for all in but PC0
	out ddrc, r16
	sbi portc, 0						; turn off sounder
	ldi r16,0b00100111					; set up port a to 
	out ddra, r16						;read the frequency input on pa7 and output pulse on pa6
	sbi porta, 0						;
	sbi porta, 1						
	sbi porta, 2						;setting up the audio voltage reading inputs
	rcall init_lcd_dog					;initialize lcd dog
	//cbi porta, 5
	//rcall enable_backlight
	clt									;clear t flag
	ldi r16, 0
	ldi r21, 0
	ldi r24, $10
	rcall start_tc1
	ldi r16, 0<<CS12|1<<CS11|1<<CS10	; load 64 PRESCaLE TCCR0 value. 
	out TCCR1B, r16						; and start timer
	sei									;enable global interrupts
;***************************************
; check which menu is selected. r21 is  either incremented or decremented
; with press of right or left pbsw. when the go button is pressed the 
; corresponding menu is selected
;****************************************
main:
	cpi r21, 0
	breq run							
	cpi r21, 1
	breq hold
	cpi r21, 2
	breq capture1
	cpi r21, 3
	breq alarm
	cpi r21, 4
	breq freq_meter1
;*********************run menu***********************
; when in run mode the voltage is continuously read and 
; displayed. 
;****************************************************
run:
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1
	sbi portb, 0
	rcall spi_setup					;sets up and gets the voltage from the max144
	rcall unpack					;conver the obtained values to numbers
	mov r18, r10					; get the 1 and 3 digit of the voltage value
	mov r19, r6						; copy it to r18 and r19
	swap r18						; shift the 1 digit to upper dibble
	eor r18, r19					; exor it to obtain both digit in one register
	ldi r19, $49					; 
	cp r18,r19						; check if its more than 49, if its greater it 
	brsh overflow_dis				; means the read voltage is more than 4090
	rcall run_display				;display measured value. 
	rjmp main						;return to main to see if a different option is 
									;selected
overflow_dis:
	rcall overflow					;displays overflow on the display and goes back 
	rjmp main						; to main 
;********************hold mode***************************
;with the press of the center button it will toggle the tflag
;when t flag is set its in hold mode, if not it will just display
;voltage like in run mode
;********************************************************
hold:
	ldi r16, 0
	out TIMSK, r16						;set up the timer interrupt
	brts hold							;if t flag is set it means its in hold mode 
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1
	sbi portb, 0
	rcall spi_setup					;sets up and gets the voltage from the max144
	rcall unpack					;conver the obtained values to numbers
	mov r18, r10
	mov r19, r6
	swap r18
	eor r18, r19
	ldi r19, $49
	cp r18,r19
	brsh overflow_dis					;check if it overflows
	rcall hold_display					;display measured value. 
	rjmp main
freq_meter1:							;added because the rcall cannot reach there
	rjmp freq_meter				
capture1:
	rjmp capture
;******************alarm mode*************************************
;this mode will sound the beeper if the measured voltage is above
; the selected voltage range. 
;*****************************************************************
alarm:
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1
	sbi portb, 0
	rcall spi_setup					;sets up and gets the voltage from the max144
	rcall unpack					;conver the obtained values to numbers
	mov r18, r10
	mov r19, r6
	swap r18
	eor r18, r19
	ldi r19, $49
	cp r18,r19
	brsh overflow_dis					;check if the selected voltage overflows
	rcall alarm_display					;display measured value. 
	clr r18								; do the similar procedure as the overflow
	mov r18, r10						;check. to if the read voltage is above
	mov r19, r7							; the selected voltage
	swap r18							; load r19 with 30 and add it with r23
	eor r18, r19						; r23 contains the value of the selected 
	ldi r19, $30						;voltage limit(either 5/6/7/8)	
	add r19, r23					
	cp r18,r19							;compare if >35/36/37/38					
	brsh alarmed						;if higher than that go to alarm
	rjmp main							;if not just read the next voltage
alarmed:
	cbi portc, 0						;start the beeper
	rcall delay							;wait 
	sbi portc, 0						;stop the beeper
	rjmp main							;read the next voltage
;************************alarm mode*********************************
; read the voltage value and hold it. until the next voltage is read
; so it will only read a new value after the wire is removed, meaning
; the voltage has to be zero in order to read the next value
;******************************************************************

capture:
    sbi portB, 4					   	; set /SS of DOG LCD = 1 (Deselected)1
	sbi portb, 0
	rcall spi_setup					;sets up and gets the voltage from the max144
	ldi r16, $00
	cp r16, r9						; compare if the 4msb of the voltage is 0
	brne next						; if not then dont read next voltage value
	ldi r16, 250					; compare if the 8 lsb is <250mV
	cp r16,r8						; if its less than 250 
	brsh clear						; clear the t flag to read the next voltage value
next:
	brtc run_once					; if tflag is cleared then read the next voltage
	rjmp main
clear:
	clt								; clear t flag to read the next voltag
	rjmp main
run_once:
	rcall unpack					;conver the obtained values to numbers
	mov r18, r10
	mov r19, r6
	swap r18
	eor r18, r19
	ldi r19, $49
	cp r18,r19
	brsh overflow_dis1				;check for overflow
	rcall capture_display			;display measured value. 
	sbrs r23, 0						; if r23 is 0 it means audio should
	rcall audio						;be off
	cbi portc, 0					;beep 
	rcall delay						
	sbi portc, 0
	set								; set t flag to indicate to not read new value
	rjmp main						;calculation in the second run 
;*********************frequency mode*********************************
; this mode is similar to the freuqency meter done in lab 8
; it will count the positive edges applied on pa7 for 1/2 second 
; and display it on the lcd
;********************************************************************
freq_meter:
	rcall freq_display					;after its unpacked, display 
	clr r8
	clr r9
	rcall start_tc1
	ldi r16, 0<<CS12|1<<CS11|1<<CS10	; load 64 PRESCaLE TCCR0 value. 
	out TCCR1B, r16						; and start timer
	rcall frequency_meter_3				; load the timer and count the frequency
	clt									;clear the t flag
	sub r8, r9
	mov r18, r8
	mov r19, r9
	rcall unpack						;when timer is done, unpack the edge counts
	rcall freq_display					;after its unpacked, display 
	rjmp main							

frequency_meter_3:
	ldi r16, $00
	mov r8, r16
	mov r9, r16
	in r25, pinA				;and positive edge counter
	andi r25,$80
	check_edge:		
		brts finish2
		in r16, pina			;take in the current wave signal logic 
		andi r16,$80
		cp r16,r25			;and compare to previous logic recorded, 
		breq check_edge			;if it is the same then skip to tweak delay		
		mov r25, r16
		inc r8				;and then increment the counter
		brne check_edge			;if it didnt over count then go to tweak delay
		inc r9				;if so then increment the second register
		brtc check_edge
	finish2:
		//ldi r16, 0<<OCIE1B
		//out TIMSK, r16						;set up the timer interrupt
		ret

overflow_dis1:
	rjmp overflow_dis
;-----------------------------
;when the interrupt is called it will jump to this subroutine
;set the T flag, resets the timer, update the display 


isr_tc0_display:
; when 1/2 secon dtim er is over this will be called, 
; this subroutine is dual purpose, Timer A is used to control backlight
; timer b is used to control the frequency. after .5 second is over
; the t flag is set.
		push r16
		inc r24
		cpi r24, $1a
		breq off							; 
		set
		ldi r16, $00
		out TCNT1H, r16						; 
		out TCNT1L, r16						;reset the timer counter
		pop r16
		reti
off:
		ldi r24, $10
		sbi porta, 5
		ldi r16, $00
		out TCNT1H, r16						; 
		out TCNT1L, r16						;reset the timer counter
		pop r16
		ldi r16, 0<<CS12|1<<CS11|1<<CS10	; load 64 PRESCaLE TCCR0 value. 
		out TCCR1B, r16						; and start timer
		reti


;************************menu button interrupt****************
;when any pushbutton is pressed,this intterupt will be activated
;*************************************************************
menu: 
	push r16
	cbi porta, 5							;turn backlight on			
	sbis pind, 3							;check if interrupt is pressed
	sbi porta, 5							;turn off te light
	cpi r21, 2								;check if the hold button is 
	brne check_hold							;pressed(go button) in hold mode
	sbis pind, 4							; check if down button is pressed
	rjmp audio_offon						;if pressed turn audio on/off
	rjmp menu_loop
check_hold:
	cpi r21, 1								;check if we are in hold mode
	brne menu_loop							;if not go to main loop
	sbis pind, 7							;if yes is the go button pressed
	rjmp switch								;if pressed then go to switch
menu_loop:	
	in r16, pind							;store the button presses
	sbis pind, 5							;see if right buton is pressed
	inc r21									; increment r21
	sbis pind, 6							;if left button is pressed 
	dec r21									;decrement r21
	sbrs r16, 7								;if go button is pressed 
	rjmp menu_check							;go to menu check 
wait_1:
	sbis pind,5								;wait until right button is released
	rjmp wait_1								
	sbis pind,6								;wait until left button is released
	rjmp wait_1
	cpi r21,$ff								;if its continuously pressed see if 
	brne check								;r21 is 255, if not go to check,if it
	ldi r21, 4								; is load r21 with 4 for hte freq mode
check:
	cpi r21,5								;
	brne good								; if r21 is 5 then reset back to 0
	ldi r21,0
good:
	clt										;clear t flag
	rcall main_menu							;go to main menu
	rjmp menu_loop							; chekc which button is pressed
menu_check:
	cpi r21,3								;if r21 is 3, ask for the check voltage
	breq alarm_set							;display 4 differnt volt to choose from 
menu_exit:
	ldi r16, 1 << INTF0						;when selection is done reset the interrupt
	out gifr, r16							;
	pop r16
	reti									;return from interrupt
audio_offon:
	com r23									;if r23 is 1 then audio is on and diplays it 
	rcall capture_display					; on the capture mode
	rjmp menu_exit 

switch:
	brts clear1								; if t flag is set, clear it 
	set										;if not set it 
	rjmp menu_exit							;return back
clear1:
	clt										;clear t falg
	rjmp menu_exit							;return back

alarm_set:
	rcall alarm_select						;alarm selection menu
wait_press:
	sbis pind, 3							
	rjmp done_select
	sbis pind, 4
	rjmp done_select
	sbis pind, 5
	rjmp done_select
	sbis pind, 6
	rjmp done_select
	rjmp wait_press				;check which voltage is pressed
done_select:
	rcall delay
	sbis pind, 3
	ldi r23, 5
	sbis pind, 4
	ldi r23, 8
	sbis pind, 5
	ldi r23, 6
	sbis pind, 6
	ldi r23, 7				;debouncing the buttons
wait_for_1:
	rcall delay
	sbis pind, 3
	rjmp wait_for_1
	sbis pind, 4
	rjmp wait_for_1
	sbis pind, 5
	rjmp wait_for_1
	sbis pind, 6
	rjmp wait_for_1
	clt
	rjmp menu_exit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.include "audio_playback_WTV20SD_beta.inc" 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;*********************audio********************************
;puts the value in r16 and r17 and send it to the subroutine
; to make the audio module read the voltage on the screen 
;*******************************************************
audio:
	push r16
	push r17
	ldi r17, $00
	ldi r16, $00
	mov r16, r10						;send msb
	rcall send_audio_r17r16			;read the voltage, subrouitne
	ldi r17, $00
	ldi r16, $0A					;send dot
	rcall send_audio_r17r16			;read the voltage, subrouitne 
	ldi r17, $00
	mov r16, r7						;send 2nd number
	rcall send_audio_r17r16			;read the voltage, subrouitne
	ldi r17, $00
	mov r16, r6						;send third number
	rcall send_audio_r17r16			;read the voltage, subrouitne
	ldi r17, $00
	mov r16, r5						;send fourth number
	rcall send_audio_r17r16			;read the voltage, subrouitne
	pop r17
	pop r16
	ret
;*********************TIMER INITIALIZATION*************************** 
;_____________________________________________________________________
	
start_tc1:	
//intialization for the timer
/*	ldi r16, $00
	out TCNT1H, r16						; set up counter with 0's
	out TCNT1L, r16			*/		;
	;Init Timer/counter Interrupt MaSK (TIMSK) register to enable/set 
	ldi r16, 8							;load with bcd 1000, this will enable the 
										;"ocie1b" which is located in bit 4 of the register. 
										;refer to datasheet pg 115 for details
	out TIMSK, r16						;set up the timer interrupt

	ldi r16, 1<<ICF1					;loading the timer interrupt flag register
	out TIFR, r16						;


	ldi r16, $1f						;load the counter with 15625
	out OCR1BH, r16						; so that we will get 1s 
	ldi r16, $07
	out OCR1BL, r16						;
	//sei									;enable global interrupts...


	;TCCR1B = FOC0 : WGM11 : COM11 : COM10 : WGM11 : CS12 : CS11 : CS10 
	; 0 0 0 0 0 0 1 1 
	; FOC Off; No WF Gen; COM=Nrml Port Op; Pre-scaler= 1/64 
 

	ret

	
;*********************spi_setup*******************************
; Get the voltage from max144, by reading the input values for 
; 12 clock cycles. The registers used to store the 12 bits are 
; r8 and r9 

spi_setup:

	ldi r16, (1<<spe)|(1<<mstr)
	out SPCR, r16					;Enable SPI, Master, fck/4,
	in r16, spsr
	in r16, spdr 
	cbi portb, 0
	sbi portb, 4
	rcall delay
	ldi r16, $AA
	out SPDR, r16					;set up dummy value in data register	
	wait_H:
		sbis spsr, spif
		rjmp wait_H
		in r9, spdr
		out spdr, r16
	wait_L:
		sbis spsr, spif
		rjmp wait_L
		in r8, spdr
		push r18
		ldi r18, $0f
		and r9, r18						;delete first four bits
		pop r18
		sbi pinb,0
		sbi pinb, 4
		mov r18, r8
		mov r19, r9
	ret




;**************************************************************************
;---------------------------- SUBROUTINES ----------------------------

;*********************LCD DISPLAY CODE******************************

;---------------------------------------------------------
;Code to load and display each line on the lcd 
;r25 is used to load the value of the each digit to the pointer
;line 2 refers to table, which containes numbers and depending 
;on the frequncy, each number is picked and displayed 
;---------------------------------------------------------

display:
   
   rcall clr_dsp_buffs					; clear all three buffer lines
   //brtc	run_display
   //brts hold_display

main_menu:
   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message1<<1)		;
   ldi  ZL, low(line1_message1<<1)		;
   rcall load_msg						; load message into buffer(s).



   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
cpi r21, 0
breq menu_run							;if r16 is 1 display run highlighted
cpi r21, 1
breq menu_hold							;display hold highlighted
cpi r21, 2
breq menu_capture						;display capture highlighted
cpi r21, 3
breq menu_alarm
cpi r21, 4
breq menu_freq
menu_run:
   ldi ZH, high(line2_message_r<<1)		;
   ldi ZL, low(line2_message_r<<1)		;load the table to stack
   rcall load_msg
   rjmp thirdline
menu_hold:
   ldi ZH, high(line2_message_h<<1)		;
   ldi ZL, low(line2_message_h<<1)		;load the table to stack
   rcall load_msg
   rjmp thirdline
menu_capture:
   ldi ZH, high(line2_message_c<<1)		;
   ldi ZL, low(line2_message_c<<1)		;load the table to stack
   rcall load_msg
   rjmp thirdline
 menu_freq:
   ldi ZH, high(line2_message_t<<1)		;
   ldi ZL, low(line2_message_t<<1)		;load the table to stack
   rcall load_msg
   rjmp thirdline
menu_alarm:
   ldi ZH, high(line2_message_a<<1)		;
   ldi ZL, low(line2_message_a<<1)		;load the table to stack
   rcall load_msg
thirdline:
   //rcall load_msg						;load the frequency number into the buffer

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message1<<1)		;
   ldi  ZL, low(line3_message1<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message1:	.db 1, "***Main Menu****", 0  ; test string for line #1.
line2_message_r:.db 4,"FREQ   RUN  HOLD",0
line2_message_h:.db 4,"RUN    HOLD  CAP",0
line2_message_c:.db 4,"HOLD   CAP   ALM",0
line2_message_a:.db 4,"CAP    ALM  FREQ",0
line2_message_t:.db 4,"ALM    FREQ  RUN",0
line3_message1:	.db 3,"       ^^^^     ", 0  ; test string for line #3.
;*************************************************************************************
alarm_select:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message7<<1)		;
   ldi  ZL, low(line1_message7<<1)		;
   rcall load_msg						; load message into buffer(s).

   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2


   ldi ZH, high(line2_message_7<<1)		;
   ldi ZL, low(line2_message_7<<1)		;load the table to stack
   rcall load_msg

   //rcall load_msg						;load the frequency number into the buffer

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message7<<1)		;
   ldi  ZL, low(line3_message7<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message7:	.db 1,"       3.5      ", 0  ; test string for line #1.
line2_message_7:.db 4,"3.6          3.7",0
line3_message7:	.db 3,"       3.8      ", 0  ; test string for line #3.

 capture_display:

 // rcall spi_setup
   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message<<1)		;
   ldi  ZL, low(line1_message<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message<<1)		;
   ldi ZL, low(line2_message<<1)		;load the table to stack
   rcall load_msg			.			;load the frequency number into the buffer
   sbrs r23, 1
   rjmp linechange

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message<<1)		;
   ldi  ZL, low(line3_message<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message:	.db 2,"",0
line3_message:	.db 3, "CAPTURE      off", 0  ; test string for line #3.


 linechange: 
   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message0<<1)		;
   ldi  ZL, low(line3_message0<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message0:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message0:	.db 2,"",0
line3_message0:	.db 3, "Capture       on", 0  ; test string for line #3.

;**************************************************************************************
  run_display:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message2<<1)		;
   ldi  ZL, low(line1_message2<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message2<<1)		;
   ldi ZL, low(line2_message2<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message2<<1)		;
   ldi  ZL, low(line3_message2<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message2:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message2:	.db 2,"",0
line3_message2:	.db 3, "RUN         MODE", 0  ; test string for line #3.

;***************************************************************************************
;**************************************************************************************
  hold_display:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message3<<1)		;
   ldi  ZL, low(line1_message3<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message3<<1)		;
   ldi ZL, low(line2_message3<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message3<<1)		;
   ldi  ZL, low(line3_message3<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message3:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message3:	.db 2,"",0
line3_message3:	.db 3, "HOLD        MODE", 0  ; test string for line #3.
;*****************************************************************************
alarm_display:


   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message6<<1)		;
   ldi  ZL, low(line1_message6<<1)		;
   rcall load_msg						; load message into buffer(s).


   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message6<<1)		;
   ldi ZL, low(line2_message6<<1)		;load the table to stack
   rcall load_msg			.			;load the frequency number into the buffer
   

   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message6<<1)		;
   ldi  ZL, low(line3_message6<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message6:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message6:	.db 2,"",0
line3_message6:	.db 3, "ALARM       MODE", 0  ; test string for line #3.
;*****************************************************************************
 overflow: 
   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line2_message5<<1)		;
   ldi  ZL, low(line2_message5<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog

   ret
;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message5:	.db 1, "*****Voltage****", 0  ; test string for line #1.
line2_message5:	.db 4, " over the limit ",0
line3_message5:	.db 3, "                ", 0  ; test string for line #3.
;********************************************************************************
freq_display:

   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message8<<1)		;
   ldi  ZL, low(line1_message8<<1)		;
   rcall load_msg						; load message into buffer(s).

   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message8<<1)		;
   ldi ZL, low(line2_message8<<1)		;load the table to stack
   rcall load_msg						;load the frequency number into the buffer
   
   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message8<<1)		;
   ldi  ZL, low(line3_message8<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret

;--------------------------------------
;lines to display on the lcd
;--------------------------------------

.cseg
line1_message8:	.db 1, "***FREQUENCY****", 0  ; test string for line #1.
line2_message8:	.db 5,"",0
line3_message8:	.db 3, "KHZ       0.5SEC", 0  ; test string for line #3.
;*******************************************************************************************
backlight_display:


   ;load 1st line of prompt message into dbuff1
   ldi  ZH, high(line1_message10<<1)		;
   ldi  ZL, low(line1_message10<<1)		;
   rcall load_msg						; load message into buffer(s).

  //sbrs r24, 1
  //rjmp linechange1

   ;LOAD 2ND LINE OF THE MESSAGE INTO DBUFF2
   ldi ZH, high(line2_message10<<1)		;
   ldi ZL, low(line2_message10<<1)		;load the table to stack
   rcall load_msg			.			;load the frequency number into the buffer


   ;load 3rd line of prompt message into dbuff3
   ldi  ZH, high(line3_message10<<1)		;
   ldi  ZL, low(line3_message10<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
   ret

  linechange1:
   ldi  ZH, high(line21_message10<<1)		;
   ldi  ZL, low(line21_message10<<1)		;
   rcall load_msg						; load message into buffer(s).
   rcall update_lcd_dog
;--------------------------------------
;lines to display on the lcd
;--------------------------------------
.cseg 
line1_message10:	.db 1, "BACKLIGHT   CTRL", 0  ; test string for line #1.
line2_message10:	.db 4, "     ENABLED    ",0
line21_message10:	.db 4, "    DISABLED    ",0
line3_message10:	.db 3, "5s  INACTIVE OFF", 0  ; test string for line #3.
;*************************************************************************************
;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================

;************************
;NAME:      clr_dsp_buffs
;FUNCTION:  Initializes dsp_buffers 1, 2, and 3 with blanks (0x20)
;ASSUMES:   Three CONTIGUOUS 16-byte dram based buffers named
;           dsp_buff_1, dsp_buff_2, dsp_buff_3.
;RETURNS:   nothing.
;MODIFIES:  r25,r26, Z-ptr
;CALLS:     none
;CALLED BY: main application and diagnostics
;********************************************************************
clr_dsp_buffs:
     ldi R25, 48						; load total length of both buffer.
     ldi R26, ' '						; load blank/space into R26.
     ldi ZH, high (dsp_buff_1)			; Load ZH and ZL as a pointer to 1st
     ldi ZL, low (dsp_buff_1)			; byte of buffer for line 1.
   
    ;set DDRAM address to 1st position of first line.
store_bytes:
     st  Z+, R26						; store ' ' into 1st/next buffer byte and
										; auto inc ptr to next location.
     dec  R25							; 
     brne store_bytes					; cont until r25=0, all bytes written.
     ret


;*******************
;NAME:      load_msg
;FUNCTION:  Loads a predefined string msg into a specified diplay
;           buffer.
;ASSUMES:   Z = offset of message to be loaded. Msg format is 
;           defined below.
;RETURNS:   nothing.
;MODIFIES:  r16, Y, Z
;CALLS:     nothing
;CALLED BY:  
;********************************************************************
; Message structure:
;   label:  .db <buff num>, <text string/message>, <end of string>
;
; Message examples (also see Messages at the end of this file/module):
;   msg_1: .db 1,"First Message ", 0   ; loads msg into buff 1, eom=0
;   msg_2: .db 1,"Another message ", 0 ; loads msg into buff 1, eom=0
;
; Notes: 
;   a) The 1st number indicates which buffer to load (either 1, 2, or 3).
;   b) The last number (zero) is an 'end of string' indicator.
;   c) Y = ptr to disp_buffer
;      Z = ptr to message (passed to subroutine)
;********************************************************************
load_msg:
	 push r26
	 push r17
     ldi YH, high (dsp_buff_1)			; Load YH and YL as a pointer to 1st
     ldi YL, low (dsp_buff_1)			; byte of dsp_buff_1 (Note - assuming 
										; (dsp_buff_1 for now).
     lpm R16, Z+						; get dsply buff number (1st byte of msg).
     cpi r16, 1							; if equal to '1', ptr already setup.
     breq get_msg_byte					; jump and start message load.
     adiw YH:YL, 16						; else set ptr to dsp buff 2.
	 ldi r17, $00
	 ldi r26, 6
     cpi r16, 2							; if equal to '2', ptr now setup.
     breq digit_load					; jump and start message load.
	 ldi r17, $00
	 ldi r26, 6
     cpi r16, 5							; if equal to '2', ptr now setup.
     breq digit_load					; jump and start message load.
	 cpi r16, 4
	 breq get_msg_byte
     adiw YH:YL, 16						; else set ptr to dsp buff 3.
        
get_msg_byte:
     lpm R16, Z+						; get next byte of msg and see if '0'.        
     cpi R16, 0							; if equal to '0', end of message reached.
     breq msg_loaded					; jump and stop message loading operation.
     st Y+, R16							; else, store next byte of msg in buffer.
     rjmp get_msg_byte					; jump back and continue...

;__________________________________________
; digital_load will only be accessed when displaying line 2, 
; since the frequency to be displayed in line 2 is constantly 
; changing for different waveform, the line 2 has to be adjusted 
; according. 
; r17, will inc until 6, to display 6 empty spaces
; r4 will contain the first digit of the frequency
; r3 will contain the second digit of the frequency
; r2 will contain the third digit of the frequency
; r1 will contian the fouth digit of the frequency
;get_dis_freq subroutine will just transfer each value stored in 
; r25 to y pointer
;_______________________________________________	
digit_load:
	ldi r27, 5
	inc r17
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	cpse r17, r26					;check if 6 places typed
	rjmp digit_load					;repeat until 6 places
	;mov r25, r5						;load the first number in freq
	;rcall get_dis_freq				;display 
	mov r25, r4					;load the first number in freq
	rcall get_dis_freq				;display 
	ldi r25, $2E
	rcall get_dis_freq				;load period to display inbetween numbers
	mov r25, r3					;load the second number in freq
	rcall get_dis_freq				;display 
	mov r25, r2						;load the third number in freq
	rcall get_dis_freq				;display 
	mov r25, r1						;load the fourth number in freq
	rcall get_dis_freq				;display 
	cpse r16, r27
	rcall disp_volts				;display
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	ldi r25, $20					;load empty spaces for 6 places
	rcall get_dis_freq				;display 
	rjmp msg_loaded					;go to the next line of the lcd

disp_volts:
	ldi r25, $56					;load the fourth number in freq
	rcall get_dis_freq				;display 
	ret
get_dis_freq:
	st Y+, r25						;display the selected frquency
	ret		

	
msg_loaded:
	 pop r17
	 pop r26
     ret
;________________________________________________________________________________________

;------------------------------------------------
;unpacks the values store in r8 and r9 to r1- r4
; r4 containe the left most number ie the thousanth
;digit and r1 the right most number
;------------------------------------------------
;------------------------------------------------
;unpacks the values store in r13 and r14 to r1- r4
; r4 containe the left most number ie the thousanth
;digit and r1 the right most number
;------------------------------------------------
.def bit01 = r13				;values taken from bin2bcd
.def bit23 = r14
unpack:
	rcall bin2BCD16					;convert the values from binary to bcd
	push r16						;store the value currently in r16
	mov r2, bit01					;make a copy of r13 in r2
	mov r4, bit23					;make a copy of r14 in r4
	ldi r16, $0f					;use and function to
	and bit01, r16					;mask the upper nibble of r8
	mov r1, bit01					;move lower nibble to r1
	and bit23, r16					;mask upper nibble of r9
	mov r3, bit23					;move lower nible to r3
	com r16							;load with f0 to mask lower nibble
	and r2, r16						;mask lower nibble of r8
	swap r2							;switch upper and lower nibble
	and r4, r16						;mask lower nibble of r9
	swap r4							;switch upper and lower nibble

	mov r10, r4
	mov r7, r3
	mov r6, r2
	mov r5, r1						;copy the bcd values to r8-r5
	ldi r16, $30
	add r1, r16
	add r2, r16
	add r3, r16
	add r4, r16
	pop r16							;retrive the value previosly stored
	ret

.undef bit01 
.undef bit23	
		







;_____________________________________________________________________________________





;***************************************************************************
;*
;* "bin2BCD16" - 16-bit Binary to BCD conversion
;*
;* This subroutine converts a 16-bit number (fbinH:fbinL) to a 5-digit
;* packed BCD number represented by 3 bytes (tBCD2:tBCD1:tBCD0).
;* MSD of the 5-digit number is placed in the lowermost nibble of tBCD2.
;*
;* Number of words	:25
;* Number of cycles	:751/768 (Min/Max)
;* Low registers used	:3 (tBCD0,tBCD1,tBCD2)
;* High registers used  :4(fbinL,fbinH,cnt16a,tmp16a)	
;* Pointers used	:Z
;*
;***************************************************************************
//.include "..\8515def.inc"
;***** Subroutine Register Variables


.equ	AtBCD0	=13			;address of tBCD0
.equ	AtBCD2	=15			;address of tBCD1

.def	tBCD0	=r13		;BCD value digits 1 and 0
.def	tBCD1	=r14		;BCD value digits 3 and 2
.def	tBCD2	=r15		;BCD value digit 4
.def	fbinL	=r16		;binary value Low byte
.def	fbinH	=r17		;binary value High byte
.def	cnt16a	= r18		;loop counter
.def	tmp16a	= r19		;temporary value

;***** Code

bin2BCD16:
	//sub r18, r19
	mov fbinH, r19			;copy the values of edge counter to fbin
	mov fbinL, r18
	ldi	cnt16a, 16			;Init loop counter	
	clr	tBCD2				;clear result (3 bytes)
	clr	tBCD1		
	clr	tBCD0		
	clr	ZH					;clear ZH (not needed for AT90Sxx0x)
bBCDx_1:
	lsl	fbinL				;shift input value
	rol	fbinH				;through all bytes
	rol	tBCD0				;
	rol	tBCD1
	rol	tBCD2
	dec	cnt16a				;decrement loop counter
	brne bBCDx_2			;if counter not zero
	ret						;   return

bBCDx_2:
	ldi	r30,AtBCD2+1		;Z points to result MSB + 1
bBCDx_3:	
	ld	tmp16a,-Z			;get (Z) with pre-decrement
	subi tmp16a,-$03		;add 0x03
	sbrc tmp16a,3			;if bit 3 not clear
	st Z,tmp16a				;store back
	ld	tmp16a,Z			;get (Z)
	subi tmp16a,-$30		;add 0x30
	sbrc tmp16a,7			;if bit 7 not clear
	st	Z,tmp16a			;store back
	cpi	ZL,AtBCD0			;done all three?
	brne bBCDx_3			;loop again if not
	rjmp bBCDx_1	

.undef	tBCD0				;BCD value digits 1 and 0
.undef	tBCD1				;BCD value digits 3 and 2
.undef	tBCD2				;BCD value digit 4
.undef	fbinL				;binary value Low byte
.undef	fbinH				;binary value High byte
.undef	cnt16a				;loop counter
.undef	tmp16a				;temporary value



;------------DELAY 10 MS--------------------------
;This subroutine is placed here, if it was required during 
; the lab. Its not called anywhere in the code. 
;delays for 10ms 
;r20 set to 100
;r21 set to 33
; combined delay will yield 9999 clock cycles
;-------------------------------------------------
delay:
	push r16
	push r17
	ldi r16,100
	outer:
		ldi r17, 33
		inner:
			dec r17
			brne inner
			dec r16
			brne outer
	pop r17
	pop r16
	ret
;________________________________________________________________________
