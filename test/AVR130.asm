;Timer 0 divide-by-8  testing program
; Author: Robert G. Fries


;PURPOSE:
;************************************************************************
;Demonstrate how to use a reload value of other than 256 with Timer 0
; when using the Divide-by-8 clocking mode.  In this example,
; a DESIRED reload value of 250 is demonstrated.  Timer 0 interrupt
; will fire every (250 * 8) clock cycles.  Interrupt latency CAN have
; an effect on accuracy, so we must exercise care in exactly WHEN we
; modify the TCNT0 register.
;
;The response of the AVR to the overflow interrupt is as follows:
;   - finish the current instruction: (from 0 up to 4)
;   - interrupt response time:           4
;   - execute 'rjmp' vector:             2
;   - modify TCNT0 with hard override:   2
;
;Since the minimum number of cycles to respond & update TCNT0 is
; exactly 8, we can easily handle the worst-case situation of being
; part-way through executing a 4-cycle instruction (RET) without
; affecting the correct counter value.
;
; (Cycle counter values, if you run this code in the simulator)
; 22 23 24 25          29    31 32 33       37
; FF-FF-FF-00-00-00-00-00-00-00-00-07-07-07-07-07-07-07-07-08-08
;          |  |        |     |  |           |
;          |  |        |     |  |           |
;          |  |        |     |  |           ("OUT" worst-case)
;          |  |        |     |  |
;          |  |        |     |  OUT TCNT0,R31
;          |  |        |     |
;          |  |        |     LDI R31,(256-250+1)
;          |  |        |
;          |  |        Execute Vector
;          |  |
;          |  Starts 4-cycle response time
;          |
;          Int flag is raised
;
;The WRITE to TCNT0 in the code below just happens to occur
; on the same cycle that the counter would receive a clock.
; In such a case, the WRITE operation takes precedence over
; the INCREMENT of the counter.


.nolist
.include "1200def.inc"		;chip definition
.list
.listmac



;******************************************************************************
;Start of code space here...

	.cseg
	.org	0

	rjmp	RESET		;reset vector
	rjmp	NO_VEC		;ignore IRQ0
	rjmp	TIM_OVF0
	rjmp	NO_VEC

;-----------------------------------------------------------------------------
TIM_OVF0: ;this assumes R31 is available w/o saving it first
        ldi     r31,(256-250+1) ;256 minus DESIRED COUNT plus overhead
        out     TCNT0,r31	;write the MODIFIED value
	;
	nop	;not necessary, just to view TCNT0 change
	nop
	nop
	nop
	nop
	nop
	nop
	nop
        ;
        ;perform other Timer ISR functions
        ;
        reti


;--------------------------------------- -------------------------------------
RESET:	;initialize the machine
   ;set up Timer0
        ldi     r16,0x02        ;(CLK/8 src)
        out     TCCR0,r16
        ldi     r16,0x02        ;enable Timer0 Overflow int
        out     TIMSK,r16

	;done with all setup
	sei			;enable all interrupts now

        ldi     r16,0xFE        ;start off closer to FF, to
        out     TCNT0,r16       ; make it easier to see.
;--------------------------------------- 
Main:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
        rjmp    Main            ;loop


;--------------------------------------- 
NO_VEC:	reti
