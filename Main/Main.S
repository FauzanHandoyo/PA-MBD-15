#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main
.global INT0_vect
.global INT1_vect
.global TIMER1_OVF_vect

.equ HUMIDITY_THRESHOLD, 50

main:

    SBI   DDRD, 4
    SBI   DDRD, 5
    
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

;init usart

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
    
    ; LEDs start off - ensure both are off initially
    CBI   PORTD, 4      ; Turn off green LED (wet indicator)
    CBI   PORTD, 5      ; Turn off red LED/buzzer (dry indicator)
    
    ; Clear initial value
    CLR   R17           ; Clear humidity reading
    CLR   R19           ; R19 will store previous humidity value

loop:
    
agn:RCALL delay_2s      ;wait 2s for DHT11 to get ready
;-----------------------------------------------------------------
;send start signal
;------------
    SBI   DDRB, 1       ;pin PB0 as o/p
    CBI   PORTB, 1      ;first, send low pulse
    RCALL delay_20ms    ;for 20ms
    SBI   PORTB, 1      ;then send high pulse
;-----------------------------------------------------------------
;wait for response signal
;---------------
    CBI   DDRB, 1       ;pin PB0 as i/p
w1: SBIC  PINB, 1
    RJMP  w1            ;wait for DHT11 low pulse
w2: SBIS  PINB, 1
    RJMP  w2            ;wait for DHT11 high pulse
w3: SBIC  PINB, 1
    RJMP  w3            ;wait for DHT11 low pulse
;-----------------------------------------------------------------
    RCALL DHT11_reading ;read humidity (1st byte of 40-bit data)
    MOV   R16, R18      ;move new humidity to R16
    CP    R16, R19      ;compare with previous humidity
    BREQ  skip_print    ;if equal, skip printing
    MOV   R29, R18
    RCALL check_humidity
    RCALL print_ADC     ;print if changed
    MOV   R19, R16      ;update previous humidity
skip_print:
    ; Discard the next 4 bytes from DHT11 to keep protocol in sync
    RCALL DHT11_reading ;humidity decimal
    RCALL DHT11_reading ;temperature integer
    RCALL DHT11_reading ;temperature decimal
    RCALL DHT11_reading ;checksum
    RJMP  agn           ;go back & get another sensor reading



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
    RCALL delay_sec       ;1 second delay  
    RET
;=====================================================================
A_F_MSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  lo2
;---------------------------------------------------------------------
A_F_LSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  lo3

delay_sec:                ;1s delay
    LDI   R20, 255
lo6: LDI   R21, 255
lo7: LDI   R22, 80
lo8: DEC   R22
    BRNE  lo8
    DEC   R21
    BRNE  lo7
    DEC   R20
    BRNE  lo6
    RET




;=================================================================
DHT11_reading:
    LDI   R17, 8        ;set counter for receiving 8 bits
    CLR   R18           ;clear data register
    ;-------------------------------------------------------
w4: SBIS  PINB, 1
    RJMP  w4            ;detect data bit (high pulse)
    RCALL delay_timer0  ;wait 50us & then check bit value
    ;-------------------------------------------------------
    SBIS  PINB, 1       ;if received bit=1, skip next inst
    RJMP  skp           ;else, received bit=0, jump to skp
    SEC                 ;set carry flag (C=1)
    ROL   R18           ;shift in 1 into LSB data register
    RJMP  w5            ;jump & wait for low pulse
skp:LSL   R18           ;shift in 0 into LSB data register
    ;-------------------------------------------------------
w5: SBIC  PINB, 1
    RJMP  w5            ;wait for DHT11 low pulse
    ;-------------------------------------------------------
    DEC   R17           ;decrement counter
    BRNE  w4            ;go back & detect next bit
    RET                 ;return to calling subroutine
;=================================================================
;delay subroutines
;=================================================================
delay_20ms:             ;delay 20ms
    LDI   R21, 255
l3: LDI   R22, 210
l4: LDI   R23, 2
l5: DEC   R23
    BRNE  l5
    DEC   R22
    BRNE  l4
    DEC   R21
    BRNE  l3
    RET
;-----------------------------------------------------------------
delay_2s:               ;delay 2s
    LDI   R21, 255
l6: LDI   R22, 255
l7: LDI   R23, 164
l8: DEC   R23
    BRNE  l8
    DEC   R22
    BRNE  l7
    DEC   R21
    BRNE  l6
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
l2: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l2              ;else, loop back & check OCF0 flag
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;---------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET

check_humidity:
    CBI   PORTD, 4       ; Turn off red LED
    CBI   PORTD, 5       ; Turn off green LED/buzzer
    CPI   R29, 50
    BRSH  SOIL_WET

; Soil is dry - turn on only green LED/buzzer
SOIL_DRY:
    SBI   PORTD, 5       ; Turn on green LED/buzzer
    RET
    
SOIL_WET:
    ; Soil is wet - turn on only red LED
    SBI   PORTD, 4       ; Turn on red LED
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