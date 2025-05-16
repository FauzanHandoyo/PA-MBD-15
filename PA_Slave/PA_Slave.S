#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

;R20 - R25 Buat data non essential (always changing)
;R16 - R19 Buat data essential 

.equ  SCK, 5
.equ  MOSI, 3
.equ  SS, 2

main:


init_serial:
    CLR   R24
    STS   UCSR0A, R24     ;clear UCSR0A register
    STS   UBRR0H, R24     ;clear UBRR0H register
    LDI   R24, 103        ;& store in UBRR0L 103
    STS   UBRR0L, R24     ;to set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ;enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     ;asynch, no parity, 1 stop, 8 bits

loop_main:
  RCALL   dht11
  RCALL   print_ADC
  RCALL   spi
  IN      R16, SPDR
  RCALL   print_ADC
  RJMP    loop_main



dht11:
  RCALL delay_2s

;=======Setup DHT11============================================
  SBI   DDRB, 1       ;Set PB1 as output
  CBI   PORTB, 1      ;Send low pulse
  CALL  delay_20ms    ;Delay 20ms
  SBI   PORTB, 1      ;Send High pulse

;==============================================================

;=======Response signal========================================
    CBI   DDRB, 1       ;pin PB0 as i/p
w1: SBIC  PINB, 1
    RJMP  w1            ;wait for DHT11 low pulse
w2: SBIS  PINB, 1
    RJMP  w2            ;wait for DHT11 high pulse
w3: SBIC  PINB, 1
    RJMP  w3            ;wait for DHT11 low pulse

;=======Data DHT11============================================
  RCALL DHT11_reading ;read humidity (1st byte of 40-bit data)
  MOV   R16, R21
  RCALL DHT11_reading
  RCALL DHT11_reading ;read temp (3rd byte of 40-bit data)
  RCALL DHT11_reading
  RET
;-----------------------------------------------------------------

;=================================================================
DHT11_reading:
    LDI   R20, 8        ;set counter for receiving 8 bits
    CLR   R21           ;clear data register
    ;-------------------------------------------------------
w4: SBIS  PINB, 1
    RJMP  w4            ;detect data bit (high pulse)
    RCALL delay_timer0  ;wait 50us & then check bit value
    ;-------------------------------------------------------
    SBIS  PINB, 1       ;if received bit=1, skip next inst
    RJMP  skp           ;else, received bit=0, jump to skp
    SEC                 ;set carry flag (C=1)
    ROL   R21           ;shift in 1 into LSB data register
    RJMP  w5            ;jump & wait for low pulse
skp:LSL   R21           ;shift in 0 into LSB data register
    ;-------------------------------------------------------
w5: SBIC  PINB, 1
    RJMP  w5            ;wait for DHT11 low pulse
    ;-------------------------------------------------------
    DEC   R20           ;decrement counter
    BRNE  w4            ;go back & detect next bit
    RET                 ;return to calling subroutine


spi:
;==========Master Setup========================================
  LDI   R20, (1<<MOSI)|(1<<SCK)|(1<<SS)
  OUT   DDRB, R20       ;set MOSI, SCK, SS as o/p
  
  LDI   R20, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
  OUT   SPCR, R20       ;enable SPI as master, fsck=fosc/16
;==============================================================

;=================Transmission=================================
transmission:
  CBI   PORTB, SS       ;enable slave device
  OUT   SPDR, R25       ;transmit byte to slave
  
loop: 
  IN    R18, SPSR
  SBRS  R18, SPIF       ;wait for byte transmission
  RJMP  loop            ;to complete
  ;--------------------------------------------------------
  SBI   PORTB, SS       ;disable slave device
  ;--------------------------------------------------------
  RCALL my_delay        ;delay
  COM   R25             ;1's compliment of byte
  ;RJMP  transmission           ;repeat transmission
  RET
;==============================================================


;=================================================================
;delay subroutines
;=================================================================

my_delay:                   ;delay in ms
    LDI   R20, 255
l1: LDI   R21, 255
l2: LDI   R22, 40
l3: DEC   R22
    BRNE  l3
    DEC   R21
    BRNE  l2
    DEC   R20
    BRNE  l1
    RET

delay_20ms:             ;delay 20ms
    LDI   R21, 255
l4: LDI   R22, 210
l5: LDI   R23, 2
l6: DEC   R23
    BRNE  l6
    DEC   R22
    BRNE  l5
    DEC   R21
    BRNE  l4
    RET
;-----------------------------------------------------------------
delay_2s:               ;delay 2s
    LDI   R21, 255
l7: LDI   R22, 255
l8: LDI   R23, 164
l9: DEC   R23
    BRNE  l9
    DEC   R22
    BRNE  l8
    DEC   R21
    BRNE  l7
    RET
;===============================================================
delay_timer0:             ;50 usec delay via Timer 0
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 100
    OUT   OCR0A, R20      ;OCR0 = 100
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 8
    ;---------------------------------------------------------
l10: 
    IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l10              ;else, loop back & check OCF0 flag
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;---------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET




print_ADC:
    LDI   R23, 48         ;constants used to get ASCII values
    LDI   R24, 7          ;for chars 0-->9 & A-->F

    ;ADD   R25, R23        ;add 48 to byte to get ASCII char 0 to 9
    ;-----------------------------------------------------------------
    PUSH  R16             ;store copy of ADCH in STACK register
    ANDI  R16, 0xF0       ;mask & extract high-nibble
    SWAP  R16             ;swap high-nibble with low-nibble
    ADD   R16, R23        ;add 48 to byte to get ASCII char 0 to 9
    MOV   R28, R16        ;store a copy of byte in R28
    SUBI  R28, 58         ;subtract 58 from R28
    BRPL  A_F_MSD         ;jump if result is +ve

lo2: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  lo2
    ;-----------------------------------------------------------------
    STS   UDR0, R16       ;print ADC mid digit on serial monitor
    ;-----------------------------------------------------------------
    POP   R16             ;restore ADCH value from STACK register
    ANDI  R16, 0x0F       ;mask & extract low-nibble
    ADD   R16, R23
    MOV   R28, R16
    SUBI  R28, 58
    BRPL  A_F_LSD
    ;-----------------------------------------------------------------
lo3: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  lo3
    ;-----------------------------------------------------------------
    STS   UDR0, R16       ;print ADC LSD on serial monitor
    ;-----------------------------------------------------------------
lo4: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  lo4
    ;-----------------------------------------------------------------
    LDI   R18, 0x0A
    STS   UDR0, R18       ;print newline on serial monitor    
    ;-----------------------------------------------------------------
lo5: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  lo5
    ;-----------------------------------------------------------------
    LDI   R18, 0x0D
    STS   UDR0, R18       ;print carriage return on serial monitor    
    ;-----------------------------------------------------------------
    RCALL delay_2s       ;1 second delay  
    ;RCALL delay_2s
    RET
;=====================================================================
A_F_MSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  lo2
;---------------------------------------------------------------------
A_F_LSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  lo3