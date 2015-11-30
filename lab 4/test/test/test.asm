/*
 * test.asm
 *
 *  Created: 9/30/2014 10:15:45 PM
 *   Author: radra_000
 */ 

 .nolist
 .include "m16def.inc"
 .list

 ldi r16, 0x80
 dloop: 
 dec r16
 nop
 nop
 brne dloop
add r16, r16