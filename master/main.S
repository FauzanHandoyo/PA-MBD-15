#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

; Register assignments:
; R16 - Temporary register for operations
; R17 - Humidity value from SPI
; R20-R22 - Used for delays

; Constants
.equ HUMIDITY_THRESHOLD, 50   ; Threshold for wet/dry soil (50%)

main:
    ; Initialize stack pointer (SP)
    LDI   R16, hi8(RAMEND)
    OUT   SPH, R16
    LDI   R16, lo8(RAMEND)
    OUT   SPL, R16

    ; Configure PORTD: PD4 and PD5 as outputs (LEDs)
    SBI   DDRD, 4       ; Set PD4 as output (Green LED - Wet indicator)
    SBI   DDRD, 5       ; Set PD5 as output (Red LED/Buzzer - Dry indicator)
    
    ; Initialize SPI as master
    SBI   DDRB, 5       ; Set PB5 as output (SCK)
    SBI   DDRB, 3       ; Set PB3 as output (MOSI)
    SBI   DDRB, 2       ; Set PB2 as output (SS)
    SBI   PORTB, 2      ; Set SS high initially
    
    ; Configure SPI: Enable, Master mode, Clock Rate fck/16
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16

    ; LEDs start off - ensure both are off initially
    CBI   PORTD, 4      ; Turn off green LED (wet indicator)
    CBI   PORTD, 5      ; Turn off red LED/buzzer (dry indicator)
    
    ; Clear initial value
    CLR   R17           ; Clear humidity reading

run:
    ; Main program loop
    RCALL SPI_RECEIVE    ; Receive humidity data via SPI
    RCALL CHECK_HUMIDITY ; Check humidity and set LEDs
    RCALL delay_500ms    ; Short delay between readings
    RJMP  run            ; Loop forever

; SPI receive function - gets humidity value from slave
SPI_RECEIVE:
    CBI   PORTB, 2       ; Clear SS to start transmission
    
    LDI   R16, 0xFF      ; Dummy byte to send while receiving
    OUT   SPDR, R16      ; Start transmission
    
SPI_WAIT:
    IN    R16, SPSR      ; Check SPI status
    SBRS  R16, SPIF      ; Skip if SPIF flag is set
    RJMP  SPI_WAIT       ; Wait for transmission to complete
    
    IN    R17, SPDR      ; Read received humidity data into R17
    SBI   PORTB, 2       ; Set SS high to end transmission
    RET

; Check humidity value and set appropriate LED
CHECK_HUMIDITY:
    ; First, turn off all LEDs to avoid any overlap
    CBI   PORTD, 4       ; Turn off green LED
    CBI   PORTD, 5       ; Turn off red LED/buzzer
    
    ; Now compare with threshold and set appropriate LED
    CPI   R17, HUMIDITY_THRESHOLD  ; Compare humidity with threshold
    BRSH  SOIL_WET       ; Branch if humidity >= threshold (soil is wet)
    
    ; Soil is dry - turn on only red LED/buzzer
    SBI   PORTD, 5       ; Turn on red LED/buzzer
    RET
    
SOIL_WET:
    ; Soil is wet - turn on only green LED
    SBI   PORTD, 4       ; Turn on green LED
    RET

; Delay functions
delay_100ms:
    LDI   R20, 100       ; Outer counter
outer1:
    LDI   R21, 200       ; Middle counter
middle1:
    LDI   R22, 200       ; Inner counter
inner1:
    DEC   R22
    BRNE  inner1
    DEC   R21
    BRNE  middle1
    DEC   R20
    BRNE  outer1
    RET

delay_500ms:
    LDI   R20, 250       ; Longer delay for testing
outer2:
    LDI   R21, 200
middle2:
    LDI   R22, 200
inner2:
    DEC   R22
    BRNE  inner2
    DEC   R21
    BRNE  middle2
    DEC   R20
    BRNE  outer2
    RET