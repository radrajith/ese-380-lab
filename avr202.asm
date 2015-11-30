;**** A P P L I C A T I O N   N O T E   A V R 2 0 2 ************************
;*
;* Title:		16-bit Arithmetics
;* Version:		1.1
;* Last updated:	97.07.04
;* Target:		AT90Sxxxx (All AVR Devices)
;*
;* Support E-mail:	avr@atmel.com
;*
;* DESCRIPTION
;* This application note lists applications for the following 
;* Add/Subtract/Compare operations:
;*
;* "add16"	ADD 16+16	
;* "adddi16"	ADD 16+Immediate(16)
;* "sub16"	SUB 16-16
;* "subi16"     SUB 16-Immediate(16)
;* "cp16"	COMPARE 16/16 
;* "cpi16"    	COMPARE 16/Immediate 
;* "neg16"      NEGATION 16
;*
;***************************************************************************

.cseg
	ldi	r16,0x12	;Set up some registers to show usage of
	ldi	r17,0x34	;the subroutines below.
	ldi	r18,0x56	;All expected results are presented as 
	ldi	r19,0x78	;comments


;***************************************************************************
;* 
;* "add16" - Adding 16-bit registers
;*
;* This example adds the two pairs of register variables (add1l,add1h)
;* and (add2l,add2h)  The result is placed in (add1l, add1h).
;*
;* Number of words	:2
;* Number of cycles	:2
;* Low registers used	:None
;* High registers used	:4
;*
;* Note: The sum and the addend share the same register.  This causes the
;* addend to be overwritten by the sum.
;*
;***************************************************************************

;**** Register Variables
.def add1l = r16
.def add1h = r17
.def add2l = r18
.def add2h = r19

;***** Code
add16:	add	add1l, add2l		;Add low bytes
	adc	add1h, add2h		;Add high bytes with carry
	;Expected result is 0xAC68



;***************************************************************************
;* 
;* "addi16" - Adding 16-bit register with immediate
;*
;* This example adds a register variable (addi1l,addi1h) with an 
;* immediate 16-bit number defined with .equ-statement.   The result is
;* placed in (addi1l, addi1h).
;*
;* Number of words	:2
;* Number of cycles	:2
;* Low registers used	:None
;* High registers used	:2
;*
;* Note: The sum and the addend share the same register.  This causes the
;* addend to be overwritten by the sum.
;*
;***************************************************************************

;***** Register Variables
.def addi1l = r16
.def addi1h = r17

;***** Immediate 16-bit number
.equ addi2 = 0x1234

;***** Code
addi16:	subi	add1l, low(-addi2)	;Add low byte ( x -(-y)) = x + y
	sbci	add1h, high(-addi2)	;Add high byte with carry
	;Expected result is 0xBE9C



;***************************************************************************
;* 
;* "sub16" - Subtracting 16-bit registers 
;*
;* This example subtracts two pairs of register variables (sub1l,sub1h) 
;* from (sub2l, sub2h)  The result is stored in registers sub1l, sub1h.
;*
;* Number of words	:2
;* Number of cycles	:2
;* Low registers used	:None
;* High registers used	:4
;*
;* Note: The result and "sub1" share the same register.  This causes "sub1"
;* to be overwritten by the result.
;*
;***************************************************************************

;***** Register Variables
.def sub1l = r16
.def sub1h = r17
.def sub2l = r18
.def sub2h = r19

;***** Code
sub16:	sub	sub1l,sub2l		;Subtract low bytes
	sbc	sub1h,sub2h		;Add high byte with carry
	;Expected result is 0x4646



;***************************************************************************
;* 
;* "subi16" - Subtracting immediate 16-bit number from a 16-bit register
;*
;* This example subtracts the immediate 16-bit number subi2 from the
;* 16-bit register (subi1l,subi1h)  The result is placed in registers
;* subi1l, subi1h.
;*
;* Number of words	:2
;* Number of cycles	:2
;* Low registers used	:None
;* High registers used	:2
;*
;* Note: The result and "subi1" share the same register.  This causes 
;* "subi1" to be overwritten by the result.
;*
;***************************************************************************

;***** Register Variables
.def subi1l = r16
.def subi1h = r17

;***** Immediate 16-bit number
.equ subi2 = 0x1234

;***** Code
subi16:	subi	subi1l,low(subi2)	;Subtract low bytes
	sbci	subi1h,high(subi2)	;Subtract high byte with carry
	;Expected result is 0x3412



;***************************************************************************
;* 
;* "cp16" - Comparing two 16-bit numbers 
;*
;* This example compares the register pairs (cp1l,cp1h) with the register
;* pairs (cp2l,cp2h)  If they are equal the zero flag is set(one) 
;* otherwise it is cleared(zero)
;*
;* Number of words	:2
;* Number of cycles	:2
;* Low registers used	:None
;* High registers used	:4
;*
;* Note: The contents of "cp1" will be overwritten.
;*
;***************************************************************************

;***** Register Variables
.def cp1l = r16
.def cp1h = r17
.def cp2l = r18
.def cp2h = r19

;***** Code
cp16:	cp	cp1l,cp2l	;Compare low byte
	cpc	cp1h,cp2h	;Compare high byte with carry from
				;previous operation
ncp16:
	;Expected result is Z=0



;***************************************************************************
;* 
;* "cpi16" - Comparing 16-bit register with 16-bit immediate 
;*
;* This example compares the register pairs (cpi1l,cpi1h) with the value
;* cpi2.  If they are equal the zero flag is set(one), otherwise it is 
;* cleared(zero). This is enabled by the AVR's zero propagation. Carry is
;* also set if the result is negative. This means that all conditional
;* branch instructions can be used after the comparison. 
;*
;* Number of words	:3
;* Number of cycles	:3
;* Low registers used	:None
;* High registers used	:3
;*
;*
;***************************************************************************

;***** Register Variables
.def cp1l =r16
.def cp1h =r17
.def c_tmp=r18 
.equ cp2 = 0x3412		;Immediate to compare with

;***** Code
cpi16:	cpi	cp1l,low(cp2)	;Compare low byte
	ldi	c_tmp,high(cp2)	;
	cpc	cp1h,c_tmp	;Compare high byte

	;Expected result is Z=1, C=



;***************************************************************************
;* 
;* "neg16" - Negating 16-bit register
;*
;* This example negates the register pair (ng1l,ng1h)  The result will 
;* overwrite the register pair.
;*
;* Number of words	:4
;* Number of cycles	:4
;* Low registers used	:None
;* High registers used	:2
;*
;***************************************************************************

;***** Register Variables
.def ng1l = r16
.def ng1h = r17

;***** Code
ng16:	
	com	ng1l		;Invert low byte	;Calculated by 
	com	ng1h		;Invert high byte	;incverting all 
	subi	ng1l,low(-1)	;Add 0x0001, low byte	;bits then adding
	sbci	ng1h,high(-1)	;Add high byte		;one (0x0001)
	;Expected result is 0xCBEE


;***************************************************************************
;*
;* End of examples.
;*
;***************************************************************************


forever:rjmp	forever