#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main
.global INT0_vect
.global INT1_vect
.global TIMER1_OVF_vect

; === Register ===
; R16 - temp
; R17 - humidity
; R18 - counter (delay)
; R20-R22 - delay counters

.equ HUMIDITY_THRESHOLD, 50

; === Main Program ===
main:
    ; Inisialisasi Stack
    LDI   R16, hi8(RAMEND)
    OUT   SPH, R16
    LDI   R16, lo8(RAMEND)
    OUT   SPL, R16

    ; Setup LED: PD5 (Green), PD4 (Red)
    SBI   DDRD, 5
    SBI   DDRD, 4

    ; Setup SPI (Master): PB5 (SCK), PB3 (MOSI), PB2 (SS)
    SBI   DDRB, 5
    SBI   DDRB, 3
    SBI   DDRB, 2
    SBI   PORTB, 2             ; SS high (idle)

    ; Enable SPI, Master mode, clk/16
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16

    ; Pull-up untuk tombol INT0 dan INT1
    SBI   PORTD, 2
    SBI   PORTD, 3

    ; Enable INT0 dan INT1, falling edge
    LDI   R16, (1<<INT0)|(1<<INT1)
    OUT   EIMSK, R16
    LDI   R16, (1<<ISC01)|(1<<ISC11)
    STS   EICRA, R16

    ; Timer1: Prescaler 1024, Overflow interrupt
    LDI   R16, (1<<CS12)|(1<<CS10)
    STS   TCCR1B, R16
    LDI   R16, (1<<TOIE1)
    STS   TIMSK1, R16

    ; Inisialisasi LED
    SBI   PORTD, 5         ; Green ON
    CBI   PORTD, 4         ; Red OFF

    CLR   R17              ; humidity
    CLR   R18              ; counter

    SEI                    ; Enable global interrupt

loop:
    CALL  SPI_RECEIVE
    CALL  CHECK_LED
    CALL  delay_500ms
    RJMP  loop

; === SPI RECEIVE ===
SPI_RECEIVE:
    CBI   PORTB, 2         ; SS low
    LDI   R16, 0xFF
    OUT   SPDR, R16

spi_wait:
    IN    R16, SPSR
    SBRS  R16, SPIF
    RJMP  spi_wait

    IN    R17, SPDR        ; Baca humidity
    SBI   PORTB, 2         ; SS high
    RET

CHECK_LED:
    TST   R18              ; Cek apakah counter > 0
    BREQ  DEFAULT_MODE

    ; Timer aktif, hijau OFF
    CBI   PORTD, 5         ; matikan hijau
    CPI   R17, HUMIDITY_THRESHOLD
    BRSH  RED_OFF
    SBI   PORTD, 4         ; hidupkan merah
    RET

RED_OFF:
    CBI   PORTD, 4         ; matikan merah
    RET

DEFAULT_MODE:
    CPI   R17, HUMIDITY_THRESHOLD
    BRSH  GREEN_OFF
    SBI   PORTD, 4         ; hidupkan merah
    CBI   PORTD, 5         ; matikan hijau
    RET

GREEN_OFF:
    SBI   PORTD, 5         ; hidupkan hijau
    CBI   PORTD, 4         ; matikan merah
    RET

; === DELAY 500ms ===
delay_100ms:
    LDI   R20, 100
d1:
    LDI   R21, 200
d2:
    LDI   R22, 200
d3:
    DEC   R22
    BRNE  d3
    DEC   R21
    BRNE  d2
    DEC   R20
    BRNE  d1
    RET

delay_500ms:
    CALL  delay_100ms
    CALL  delay_100ms
    CALL  delay_100ms
    CALL  delay_100ms
    CALL  delay_100ms
    RET

; === INT0: Tambah Waktu ===
INT0_vect:
    PUSH  R16
    IN    R16, SREG
    PUSH  R16

    INC   R18
    CBI   PORTD, 5          ; Hijau OFF

    POP   R16
    OUT   SREG, R16
    POP   R16
    RETI

; === INT1: Kurangi Waktu ===
INT1_vect:
    PUSH  R16
    IN    R16, SREG
    PUSH  R16

    TST   R18
    BREQ  no_dec
    DEC   R18
no_dec:
    CBI   PORTD, 5

    POP   R16
    OUT   SREG, R16
    POP   R16
    RETI

; === Timer1 Overflow: Kurangi Counter ===
TIMER1_OVF_vect:
    PUSH  R16
    IN    R16, SREG
    PUSH  R16

    TST   R18
    BREQ  skip_dec
    DEC   R18
skip_dec:

    POP   R16
    OUT   SREG, R16
    POP   R16
    RETI