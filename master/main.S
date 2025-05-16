#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

; Register assignments:
; R16 - Temporary register for operations
; R17 - Humidity value from SPI
; R18-R19 - Used for delays and hex conversion
; R20-R22 - delay counters

; Constants
.equ HUMIDITY_THRESHOLD, 50   ; Threshold for wet/dry soil (50%)

main:
    ; Initialize stack pointer (SP)
    LDI   R16, hi8(RAMEND)
    OUT   SPH, R16
    LDI   R16, lo8(RAMEND)
    OUT   SPL, R16

    ; Configure PORTD: PD4 and PD5 as outputs (LEDs)
    SBI   DDRD, 4       ; Green LED
    SBI   DDRD, 5       ; Red LED/Buzzer

    ; Initialize SPI as master
    SBI   DDRB, 5       ; SCK
    SBI   DDRB, 3       ; MOSI
    SBI   DDRB, 2       ; SS
    SBI   PORTB, 2      ; SS high initially
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16

    ; LEDs start off
    CBI   PORTD, 4
    CBI   PORTD, 5

    ; Clear initial humidity
    CLR   R17

    ; Initialize UART
    RCALL uart_init

run:
    RCALL SPI_RECEIVE         ; Receive humidity via SPI
    RCALL SEND_HUMIDITY       ; Send humidity as two-digit decimal via UART
    RCALL CHECK_HUMIDITY      ; Set LEDs
    RCALL delay_500ms         ; Delay ~500ms
    RJMP  run                 ; Loop

;-----------------------------------------
; SPI receive
SPI_RECEIVE:
    CBI   PORTB, 2            ; SS low
    LDI   R16, 0xFF           ; Dummy byte
    OUT   SPDR, R16
wait_spi:
    IN    R16, SPSR
    SBRS  R16, SPIF
    RJMP  wait_spi
    IN    R17, SPDR           ; Read humidity into R17
    SBI   PORTB, 2            ; SS high
    RET

;-----------------------------------------
; Check humidity and set LEDs
CHECK_HUMIDITY:
    CBI   PORTD, 4
    CBI   PORTD, 5
    CPI   R17, HUMIDITY_THRESHOLD
    BRSH  SOIL_WET
    SBI   PORTD, 5            ; Dry soil
    RET
SOIL_WET:
    SBI   PORTD, 4            ; Wet soil
    RET

;-----------------------------------------
; Delay ~500ms
delay_500ms:
    LDI   R20, 250
outer:
    LDI   R21, 200
middle:
    LDI   R22, 200
inner:
    DEC   R22
    BRNE  inner
    DEC   R21
    BRNE  middle
    DEC   R20
    BRNE  outer
    RET

;-----------------------------------------
; UART initialization
uart_init:
    ; Baud 9600 @16MHz => UBRR0 = 103
    LDI   R16, hi8(103)
    STS   UBRR0H, R16
    LDI   R16, lo8(103)
    STS   UBRR0L, R16
    ; Enable transmitter
    LDI   R16, (1<<TXEN0)
    STS   UCSR0B, R16
    ; 8N1
    LDI   R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS   UCSR0C, R16
    RET

; UART transmit one byte in R17
uart_transmit:
    LDS   R16, UCSR0A
wait_udre:
    SBRS  R16, UDRE0
    RJMP  wait_udre
    STS   UDR0, R17
    RET

;-----------------------------------------
; Send R17 as two-digit decimal + CRLF
SEND_HUMIDITY:
    ; Tens digit
    MOV   R16, R17      ; Copy value
    LDI   R18, 0        ; R18 = tens count
dec_tens:
    CPI   R16, 10
    BRLO  send_units
    SUBI  R16, 10
    INC   R18
    RJMP  dec_tens
send_tens:
    ; ASCII tens
    LDI   R19, '0'
    ADD   R18, R19
    MOV   R17, R18
    RCALL uart_transmit
send_units:
    ; ASCII units
    LDI   R19, '0'
    ADD   R16, R19
    MOV   R17, R16
    RCALL uart_transmit
    ; CRLF
    LDI   R17, '\r'
    RCALL uart_transmit
    LDI   R17, '\n'
    RCALL uart_transmit
    RET