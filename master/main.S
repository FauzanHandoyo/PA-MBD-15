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
    ;SBI   DDRB, 5       ; Set PB5 as output (SCK)
    ;SBI   DDRB, 3       ; Set PB3 as output (MOSI)
    ;SBI   DDRB, 2       ; Set PB2 as output (SS)
    ;SBI   PORTB, 2      ; Set SS high initially

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
    
    ; Configure SPI: Enable, Master mode, Clock Rate fck/16
    ;LDI   R17, (1<<SPE)
    ;OUT   SPCR, R17       ;enable SPI as slave


    ; LEDs start off - ensure both are off initially
    CBI   PORTD, 4      ; Turn off green LED (wet indicator)
    CBI   PORTD, 5      ; Turn off red LED/buzzer (dry indicator)
    
    ; Clear initial value
    CLR   R17           ; Clear humidity reading

run:
    ; Main program loop
    RCALL SPI_RECEIVE    ; Receive humidity data via SPI
    ;LDI   R17, 0x30
    MOV   R16, R17
    MOV   R29, R17
    RCALL print_ADC
    RCALL CHECK_HUMIDITY ; Check humidity and set LEDs
    RCALL delay_500ms    ; Short delay between readings
    RJMP  run            ; Loop forever

; SPI receive function - gets humidity value from slave
SPI_RECEIVE:    
    
SPI_WAIT:
    IN    R16, SPSR      ; Check SPI status
    SBRS  R16, SPIF      ; Skip if SPIF flag is set
    RJMP  SPI_WAIT       ; Wait for transmission to complete
    
    IN    R17, SPDR      ; Read received humidity data into R17
    ;SBI   PORTB, 2       ; Set SS high to end transmission
    RET

; Check humidity value and set appropriate LED
CHECK_HUMIDITY:
    ; First, turn off all LEDs to avoid any overlap
    CBI   PORTD, 4       ; Turn off green LED
    CBI   PORTD, 5       ; Turn off red LED/buzzer
    
    ; Now compare with threshold and set appropriate LED
    CPI   R29, HUMIDITY_THRESHOLD  ; Compare humidity with threshold
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

l2: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l2
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
l3: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l3
    ;-----------------------------------------------------------------
    STS   UDR0, R16       ;print ADC LSD on serial monitor
    ;-----------------------------------------------------------------
l4: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l4
    ;-----------------------------------------------------------------
    LDI   R18, 0x0A
    STS   UDR0, R18       ;print newline on serial monitor    
    ;-----------------------------------------------------------------
l5: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l5
    ;-----------------------------------------------------------------
    LDI   R18, 0x0D
    STS   UDR0, R18       ;print carriage return on serial monitor    
    ;-----------------------------------------------------------------
    RCALL delay_sec       ;1 second delay  
    RET
;=====================================================================
A_F_MSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  l2
;---------------------------------------------------------------------
A_F_LSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  l3

delay_sec:                ;1s delay
    LDI   R20, 255
l6: LDI   R21, 255
l7: LDI   R22, 80
l8: DEC   R22
    BRNE  l8
    DEC   R21
    BRNE  l7
    DEC   R20
    BRNE  l6
    RET