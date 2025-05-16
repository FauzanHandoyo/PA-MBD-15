#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

;R20 - R25 Buat data non essential (always changing)
;R16 - R19 Buat data essential 

main:

;======Setup Slave==========
  SBI   DDRB, 4       ;Set MISO for slave transmission
  LDI   R20, (1<<SPE)
  OUT   SPCR, R20
;===========================

;setup done

run:
  RCALL delay_2s

;=======Setup DHT11=========
  SBI   DDRB, 1       ;Set PB1 as output
  CBI   PORTB, 1      ;Send low pulse
  CALL  delay_20ms    ;Delay 20ms
  SBI   PORTB, 1      ;Send High pulse
;===========================


;==================================================
;Response signal
;==================================================
  CBI   DDRB, 1       ;pin PB1 as i/p
wait1: 
  SBIC  PINB, 1
  RJMP  wait1            ;wait for DHT11 low pulse
wait2: 
  SBIS  PINB, 1
  RJMP  wait2            ;wait for DHT11 high pulse
wait3: 
  SBIC  PINB, 1
  RJMP  wait3
;===================================================


;===================================================
;Save DTH11 Data
;====================================================
  RCALL DHT11_reading
  MOV   R16, R21
  RCALL DHT11_reading
  MOV   R17, R21
  RCALL DHT11_reading
  MOV   R18, R21
  RCALL DHT11_reading
  MOV   R19, R21
  
;Transmit data 
  MOV   R26, R16
  RCALL transmitt
  MOV   R26, R17
  ;RCALL transmitt
  RJMP  run

;===================================================
;Read DTH11 
;================================================
DHT11_reading:
  LDI   R20, 8          ;Counter untuk menghitung bit yang masuk (8-bit)
  CLR   R21             ;

wait4: 
  SBIS  PINB, 1
  RJMP  wait4            
  RCALL delay_timer0  
  SBIS  PINB, 1       
  RJMP  skip           
  SEC                   ;Set Carry Flag
  ROL   R21           
  RJMP  wait5           ;

skip:
  LSL   R21             ;

wait5: 
  SBIC  PINB, 1         ;Cek bit yang masuk
  RJMP  wait5           
  DEC   R20             ;Decrement counter untuk setiap bit yang masuk
  BRNE  wait4            
  RET                 
;=====================================================


;=====================================================
;Transmission
;=====================================================
transmitt:
  OUT   SPDR, R26
done:
  in    R27, SPSR
  SBRS  R27, SPIF
  RJMP  done
  ret
;=====================================================


;=====================================================
;Delay Subroutine
;=====================================================
delay_20ms:             ;delay 20ms
    LDI   R20, 255
l1: LDI   R21, 210
l2: LDI   R22, 2
l3: DEC   R22
    BRNE  l3
    DEC   R21
    BRNE  l2
    DEC   R20
    BRNE  l1
    RET


delay_2s:               ;delay 2s
    LDI   R20, 255
l4: LDI   R21, 255
l5: LDI   R22, 164
l6: DEC   R22
    BRNE  l6
    DEC   R21
    BRNE  l5
    DEC   R20
    BRNE  l4
    RET


delay_timer0:             ;50 usec delay via Timer 0
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 100
    OUT   OCR0A, R20      ;OCR0 = 100
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 8
    ;---------------------------------------------------------
l7: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l7              ;else, loop back & check OCF0 flag
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;---------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET

;===================================================