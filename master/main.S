#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main
.global INT0_vect
.global INT1_vect
.global TIMER1_OVF_vect

; Register assignments:
; R16 - Temporary register for operations
; R17 - Humidity value from SPI
; R18 - Timer counter
; R19 - Second counter for 5-second timing
; R20-R22 - Used for delays

; Constants
.equ HUMIDITY_THRESHOLD, 50   ; Threshold for wet/dry soil (50%)

main:
    ; Initialize stack pointer (SP)
    LDI   R16, hi8(RAMEND)
    OUT   SPH, R16
    LDI   R16, lo8(RAMEND)
    OUT   SPL, R16

    ; Configure PORTD outputs
    SBI   DDRD, 4       ; Set PD4 as output (Green LED - Wet indicator)
    SBI   DDRD, 5       ; Set PD5 as output (Red LED/Buzzer - Dry indicator)
    SBI   DDRD, 7       ; Set PD7 as output (Additional timer LED)
    
    ; Initialize SPI as master
    SBI   DDRB, 5       ; Set PB5 as output (SCK)
    SBI   DDRB, 3       ; Set PB3 as output (MOSI)
    SBI   DDRB, 2       ; Set PB2 as output (SS)
    ;SBI   PORTB, 2      ; Set SS high 

    SBI   PORTD, 2      ; Enable pull-up on PD2 (INT0)
    SBI   PORTD, 3      ; Enable pull-up on PD3 (INT1)

    ; Enable INT0 and INT1, falling edge
    LDI   R16, (1<<INT0)|(1<<INT1)
    OUT   EIMSK, R16
    LDI   R16, (1<<ISC01)|(1<<ISC11)
    STS   EICRA, R16

    LDI   R16, hi8(49911)   ; Load high byte first
    STS   TCNT1H, R16
    LDI   R16, lo8(49911)    ; Then load low byte
    STS   TCNT1L, R16
    
    ; 1024 prescaler and overflow interrupt
    LDI   R16, (1<<CS12)|(1<<CS10)
    STS   TCCR1B, R16
    LDI   R16, (1<<TOIE1)
    STS   TIMSK1, R16

init_serial:
    CLR   R24
    STS   UCSR0A, R24    
    STS   UBRR0H, R24     
    LDI   R24, 103        
    STS   UBRR0L, R24     ;to set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ;enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     
    
    ; SPI: Enable, Master mode, Clock Rate fck/16
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16

    ; LEDs start off
    CBI   PORTD, 4      
    CBI   PORTD, 5      
    CBI   PORTD, 7     
    
    ; Clear initial values
    CLR   R17          
    CLR   R18           
    CLR   R19           
    LDI   R25, 5
    
    SEI                 ; Enable global interrupts

run:
    ; Main program loop
    RCALL delay_500ms    
    RCALL delay_500ms    
    RCALL delay_500ms    
    RCALL SPI_RECEIVE    ; Receive humidity data via SPI
    MOV   R16, R17
    MOV   R29, R17
    RCALL print_ADC
    RCALL CHECK_HUMIDITY ; Check humidity and set LEDs
    RCALL delay_500ms    
    RJMP  run            ; Loop forever

; SPI receive gets humidity value from slave
SPI_RECEIVE:
    ; First clear any pending flags
    IN    R16, SPSR      
    IN    R16, SPDR      
    
    RCALL delay_100ms   
    
    CBI   PORTB, 2      
    LDI   R16, 0x00      
    OUT   SPDR, R16      
    
SPI_WAIT:
    IN    R16, SPSR      ; Check SPI status
    SBRS  R16, SPIF      ; Skip if SPIF flag is set
    RJMP  SPI_WAIT       ; Wait for transmission to complete
    ;SBI   PORTB, 2       ; Set SS high to end transmission
    
    IN    R17, SPDR      ; Read received humidity data R17
    ;ROL   R17
    RET

; Check humidity value and set appropriate LED
CHECK_HUMIDITY:
    ;turn off all LEDs to avoid any overlap
    CBI   PORTD, 4    
    CBI   PORTD, 5      
    
    ; compare with threshold and set appropriate LED
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

    MOV   R30, R29           ; Store original value in R30
    
    ; Print "Temperature: " string
    LDI   R16, 'T'
    RCALL uart_transmit
    LDI   R16, 'e'
    RCALL uart_transmit
    LDI   R16, 'm'
    RCALL uart_transmit
    LDI   R16, 'p'
    RCALL uart_transmit
    LDI   R16, 'e'
    RCALL uart_transmit
    LDI   R16, 'r'
    RCALL uart_transmit
    LDI   R16, 'a'
    RCALL uart_transmit
    LDI   R16, 't'
    RCALL uart_transmit
    LDI   R16, 'u'
    RCALL uart_transmit
    LDI   R16, 'r'
    RCALL uart_transmit
    LDI   R16, 'e'
    RCALL uart_transmit
    LDI   R16, ':'
    RCALL uart_transmit
    LDI   R16, ' '
    RCALL uart_transmit

    MOV R16, R30
    CLR R24
    CLR R23

; Calculate hundreds digit
hundreds_loop:
    CPI   R16, 100
    BRLO  tens             ; If less than 100, move to tens
    SUBI  R16, 100
    INC   R24              ; Increment hundreds counter
    RJMP  hundreds_loop
    
    ; Calculate tens digit
tens:
    CPI   R16, 10
    BRLO  ones             ; If less than 10, move to ones
    SUBI  R16, 10
    INC   R23              ; Increment tens counter
    RJMP  tens
    
ones:
    
    ; Print hundreds digit (only if non-zero)
    TST   R24
    BREQ  skip_hundreds    ; Skip printing if hundreds = 0
    MOV   R16, R24
    LDI R24, 48
    ADD  R16, R24         ; Convert to ASCII
    RCALL uart_transmit
    
skip_hundreds:
    
    TST   R24
    BRNE  print_tens       ; If hundreds was printed, always print tens
    TST   R23
    BREQ  skip_tens        ; Skip printing if tens = 0
    
print_tens:
    MOV   R16, R23
    LDI   R23, 48 
    ADD  R16, R23         ; Convert to ASCII
    RCALL uart_transmit
    
skip_tens:
    MOV   R16, R30          ; Get original value
    
    ; Get ones digit
    MOV   R16, R30          ; Get original value
    CLR   R24              ; Clear hundreds
    CLR   R23              ; Clear tens
    
hundreds_loop2:
    CPI   R16, 100
    BRLO  tens2            ; If less than 100, move to tens
    SUBI  R16, 100
    INC   R24              ; Increment hundreds counter
    RJMP  hundreds_loop2
    
tens2:
    CPI   R16, 10
    BRLO  ones2            ; If less than 10, move to ones
    SUBI  R16, 10
    INC   R23              ; Increment tens counter
    RJMP  tens2
    
ones2:
    ; R16 now has ones digit, convert to ASCII
    LDI R24, 48
    ADD  R16, R24         ; Convert to ASCII
    RCALL uart_transmit
    
    ; Print newline and carriage return
    LDI   R16, 0x0A        
    RCALL uart_transmit
    LDI   R16, 0x0D       
    RCALL uart_transmit
    
    RET
    ; Convert binary value (0-255) to decimal digits
    MOV   R16, R30         
    CLR   R24

; UART transmit function
uart_transmit:
    PUSH  R17
uart_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0       ; Wait until data register is empty
    RJMP  uart_wait
    STS   UDR0, R16        ; Send character
    POP   R17
    RET

l2: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l2
    
    STS   UDR0, R16       ;print ADC mid digit on serial monitor
    
    POP   R16             ;restore ADCH value from STACK register
    ANDI  R16, 0x0F       ;mask & extract low-nibble
    ADD   R16, R23
    MOV   R28, R16
    SUBI  R28, 58
    BRPL  A_F_LSD
    
l3: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l3
    
    STS   UDR0, R16       ;print ADC LSD on serial monitor
    
l4: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l4
   
    LDI   R18, 0x0A
    STS   UDR0, R18       ;print newline on serial monitor    
   
l5: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l5
   
    STS   UDR0, R18       ;print carriage return on serial monitor    

    RCALL delay_sec       ;1 second delay  
    RET
;=====================================================================
A_F_MSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  l2

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

;---------------------------------------------------------------------
; === INT0: Tambah Waktu ===
INT0_vect:
    PUSH  R16
    IN    R16, SREG
    PUSH  R16

    INC   R18
    CBI   PORTD, 5          ; Hijau OFF

    INC R25

    RCALL print_timer_add

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

    CPI R25, 6
    BRLO min_reached
    DEC R25

    RCALL print_timer_dec

min_reached:
    POP R16
    OUT SREG, R16
    POP R16
    RETI

print_timer_add:
    PUSH R16

    ; Print "Timer add 1"
    LDI   R16, 'T'
    RCALL uart_transmit
    LDI   R16, 'i'
    RCALL uart_transmit
    LDI   R16, 'm'
    RCALL uart_transmit
    LDI   R16, 'e'
    RCALL uart_transmit
    LDI   R16, 'r'
    RCALL uart_transmit
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, 'a'
    RCALL uart_transmit
    LDI   R16, 'd'
    RCALL uart_transmit
    LDI   R16, 'd'
    RCALL uart_transmit
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, '1'
    RCALL uart_transmit

    ; Print current timer value
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, '('
    RCALL uart_transmit
    
    ; Convert R25 to ASCII and print
    MOV   R16, R25
    SUBI  R16, -48         ; Convert to ASCII (add 48)
    RCALL uart_transmit
    
    LDI   R16, 's'
    RCALL uart_transmit
    LDI   R16, ')'
    RCALL uart_transmit
    
    ; Print newline and carriage return
    LDI   R16, 0x0A        ; Newline
    RCALL uart_transmit
    LDI   R16, 0x0D        ; Carriage return
    RCALL uart_transmit
    
    POP   R16
    RET
print_timer_dec:
    PUSH  R16
    
    ; Print "Timer dec 1"
    LDI   R16, 'T'
    RCALL uart_transmit
    LDI   R16, 'i'
    RCALL uart_transmit
    LDI   R16, 'm'
    RCALL uart_transmit
    LDI   R16, 'e'
    RCALL uart_transmit
    LDI   R16, 'r'
    RCALL uart_transmit
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, 'd'
    RCALL uart_transmit
    LDI   R16, 'e'
    RCALL uart_transmit
    LDI   R16, 'c'
    RCALL uart_transmit
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, '1'
    RCALL uart_transmit
    
    ; Print current timer value
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, '('
    RCALL uart_transmit
    
    ; Convert R25 to ASCII and print
    MOV   R16, R25
    SUBI  R16, -48         ; Convert to ASCII (add 48)
    RCALL uart_transmit
    
    LDI   R16, 's'
    RCALL uart_transmit
    LDI   R16, ')'
    RCALL uart_transmit
    
    ; Print newline and carriage return
    LDI   R16, 0x0A        ; Newline
    RCALL uart_transmit
    LDI   R16, 0x0D        ; Carriage return
    RCALL uart_transmit
    
    POP   R16
    RET

; === Timer1 Overflow: 5-Second Timer for PD7 ===
TIMER1_OVF_vect:
    PUSH  R16
    IN    R16, SREG
    PUSH  R16
    
    ; Reset Timer1 for next 1-second interval
    LDI   R16, hi8(49911)   ; Load high byte first (for 1-second timing)
    STS   TCNT1H, R16
    LDI   R16, lo8(49911)    ; Then load low byte
    STS   TCNT1L, R16
    
    ; This interrupt fires approximately every second
    INC   R19             ; Increment second counter
    CP   R19, R25          ; Check if we've reached 5 seconds
    BRNE  not_five_sec
    
    ; Five seconds have passed
    CLR   R19             ; Reset second counter
    
    ; Toggle PD7 LED - turn ON
    SBI   PORTD, 7        ; Turn ON PD7 LED

    RCALL print_water_message
    
    ; Decrement timer counter if active
    TST   R18
    BREQ  skip_dec        ; If counter = 0, don't decrement
    DEC   R18             ; Decrement timer counter
skip_dec:
    RJMP  timer_exit

not_five_sec:
    ; For other seconds, turn OFF PD7
    CPI   R19, 1          ; Check if we're at 1 second after the 5-second mark
    BRNE  timer_exit
    CBI   PORTD, 7        ; Turn OFF PD7 LED after 1 second

timer_exit:
    POP   R16
    OUT   SREG, R16
    POP   R16
    RETI

print_water_message:
    PUSH R16

    LDI   R16, 'W'
    RCALL uart_transmit
    LDI   R16, 'A'
    RCALL uart_transmit
    LDI   R16, 'T'
    RCALL uart_transmit
    LDI   R16, 'E'
    RCALL uart_transmit
    LDI   R16, 'R'
    RCALL uart_transmit
    LDI   R16, ' '
    RCALL uart_transmit
    LDI   R16, 'I'
    RCALL uart_transmit
    LDI   R16, 'N'
    RCALL uart_transmit
    LDI   R16, 'C'
    RCALL uart_transmit
    LDI   R16, 'O'
    RCALL uart_transmit
    LDI   R16, 'M'
    RCALL uart_transmit
    LDI   R16, 'I'
    RCALL uart_transmit
    LDI   R16, 'N'
    RCALL uart_transmit
    LDI   R16, 'G'
    RCALL uart_transmit
    
    LDI   R16, 0x0A        ; Newline
    RCALL uart_transmit
    LDI   R16, 0x0D        ; Carriage return
    RCALL uart_transmit
    
    POP   R16
    RET

