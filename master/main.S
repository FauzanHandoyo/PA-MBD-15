#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Define ports and pins
.equ LED_RED, 0     ; Red LED connected to PORTB0
.equ LED_GREEN, 1   ; Green LED connected to PORTB1
.equ BUZZER, 2      ; Buzzer connected to PORTB2

; Interrupt Vector Table
rjmp RESET                ; Address 0x0000: Reset vector
rjmp SOIL_WET_HANDLER     ; Address 0x0002: INT0 vector
rjmp SOIL_DRY_HANDLER     ; Address 0x0004: INT1 vector

RESET:
    ; Initialize I/O
    ldi r16, 0b00000111   ; Set PORTB0, PORTB1, PORTB2 as output
    out DDRB, r16

    ; Initialize LEDs and buzzer (all off)
    ldi r16, 0x00
    out PORTB, r16

    ; Configure INT0 and INT1
    ldi r16, 0b00001100   ; Falling edge triggers INT1 and INT0
    sts EICRA, r16        ; Use 'sts' to store the value in EICRA
    ldi r16, 0b00000011   ; Enable INT0 and INT1
    out EIMSK, r16

    sei                   ; Enable global interrupts

MAIN_LOOP:
    rjmp MAIN_LOOP        ; Infinite loop

SOIL_WET_HANDLER:
    ; Soil is wet: Turn on green LED, turn off red LED and buzzer
    ldi r16, (1 << LED_GREEN)
    out PORTB, r16
    reti                  ; Return from interrupt

SOIL_DRY_HANDLER:
    ; Soil is dry: Turn on red LED and buzzer, turn off green LED
    ldi r16, (1 << LED_RED) | (1 << BUZZER)
    out PORTB, r16
    reti                  ; Return from interrupt