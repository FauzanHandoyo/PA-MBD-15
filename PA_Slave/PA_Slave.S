#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

;R20 - R25 Buat data non essential (always changing)
;R16 - R19 Buat data essential 

main:

;======Setup Slave==========
  ;SBI   DDRB, 4       ;Set MISO for slave transmission
  ;LDI   R20, (1<<SPE)
  ;OUT   SPCR, R20
;===========================

;setup done

;run:
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

run:  
;Transmit data
RCALL I2C_init
RCALL I2C_start       ;transmit START condition
LDI   R27, 0b10010000 ;SLA(1001000) + W(0)
RCALL I2C_write       ;write slave address SLA+W
MOV   R27, R16        ;Use actual humidity data from R16
RCALL I2C_write       ;write data byte
RCALL I2C_stop        ;transmit STOP condition
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
    
delay_500ms:             ;delay 500ms - added for I2C communication
    LDI   R20, 255
d1: LDI   R21, 255
d2: LDI   R22, 41        ;adjusted for ~500ms
d3: DEC   R22
    BRNE  d3
    DEC   R21
    BRNE  d2
    DEC   R20
    BRNE  d1
    RET

;===================================================



I2C_init:
    LDI   R21, 0          ;Clear register
    STS   TWSR, R21       ;prescaler = 0
    LDI   R21, 72         ;division factor = 72 for 100kHz (slower and more reliable)
    STS   TWBR, R21       ;SCK freq = 100kHz
    LDI   R21, (1<<TWEN)
    STS   TWCR, R21       ;enable TWI
    RET
;==============================================================
I2C_start:
    LDI   R21, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS   TWCR, R21       ;transmit START condition
    ;----------------------------------------------------------
wt1:LDS   R21, TWCR
    SBRS  R21, TWINT      ;TWI interrupt = 1?
    RJMP  wt1             ;no, wait for end of transmission
    ;----------------------------------------------------------
    LDS   R21, TWSR       ; Check status
    ANDI  R21, 0xF8       ; Mask prescaler bits
    CPI   R21, 0x08       ; START transmitted?
    BRNE  I2C_start       ; If not, retry
    RET
;==============================================================
I2C_write:
    STS   TWDR, R27       ;copy SLA+W into data register
    LDI   R21, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R21       ;transmit SLA+W
    ;----------------------------------------------------------
wt2:LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt2             ;wait for end of transmission
    ;----------------------------------------------------------
    LDS   R21, TWSR       ; Check status
    ANDI  R21, 0xF8       ; Mask prescaler bits
    CPI   R21, 0x18       ; SLA+W transmitted, ACK received?
    BRNE  I2C_start       ; If not, restart
    RET
;==============================================================
I2C_stop:
    LDI   R21, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS   TWCR, R21       ;transmit STOP condition
    RET
