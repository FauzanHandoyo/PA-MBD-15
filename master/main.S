#define __SFR_OFFSET 0x00
#include "avr/io.h"

; ******************************************************************
; NOTE: Despite being in the "master" folder, this is actually the 
; SLAVE device code that receives humidity data via SPI from the 
; master device and controls the LEDs based on humidity threshold.
; ******************************************************************

.global main

; Register assignments:
; R16 - Temporary register for operations
; R17 - Humidity value from SPI
; R29 - Copy of humidity value for comparison
; R20-R22 - Used for delays

; Constants
.equ HUMIDITY_THRESHOLD, 0x50   ; BCD threshold for wet/dry soil (50%)

main:
    ; Initialize stack pointer (SP)
    LDI   R16, hi8(RAMEND)
    OUT   SPH, R16
    LDI   R16, lo8(RAMEND)
    OUT   SPL, R16

    ; Configure PORTD: PD4 and PD5 as outputs (LEDs)
    SBI   DDRD, 4       ; Set PD4 as output (RED LED - Wet indicator)
    SBI   DDRD, 5       ; Set PD5 as output (GREEN LED - Dry indicator)
    
    ; Initialize SPI as slave
    SBI   DDRB, 4       ; Set PB4/MISO as output
    CBI   DDRB, 5       ; Set PB5/SCK as input
    CBI   DDRB, 3       ; Set PB3/MOSI as input
    CBI   DDRB, 2       ; Set PB2/SS as input
    
    ; Configure SPI: Enable as slave
    LDI   R16, (1<<SPE)
    OUT   SPCR, R16     ; Enable SPI as slave

    ; Initialize serial communication
    RCALL init_serial
    
    ; Clear initial value
    CLR   R17           ; Clear humidity reading

run:
    ; Main program loop
    RCALL SPI_RECEIVE    ; Receive humidity data via SPI    ; Verify the received value
    MOV   R16, R17       ; Copy for print_ADC
    RCALL print_ADC      ; Print the received value
    
    ; Debug - print raw hex value 
    MOV   R16, R17       ; Copy value again
    RCALL print_hex      ; Print raw hex value for debugging
    
    ; Ensure proper copying to R29
    MOV   R29, R17       ; Copy for comparison
    
    RCALL CHECK_HUMIDITY ; Check humidity and set LEDs
    RCALL delay_500ms    ; Short delay between readings
    RJMP  run            ; Loop forever

; Initialize serial communication
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
    RET

; SPI receive function - gets humidity value from master
SPI_RECEIVE:    
    ; Set a timeout counter
    LDI   R20, 250      ; Timeout counter
    
SPI_WAIT:
    IN    R16, SPSR     ; Check SPI status
    SBRS  R16, SPIF     ; Skip if SPIF flag is set (data received)
    RJMP  CHECK_TIMEOUT ; If not set, check timeout
    
    ; If we get here, data was received (SPIF is set)
    IN    R17, SPDR     ; Read received data into R17
    
    ; Clear the SPIF flag by reading SPSR (already done) and then SPDR (already done)
    ; At this point, R17 contains our received humidity value
    RET
    
CHECK_TIMEOUT:
    DEC   R20           ; Decrement timeout counter
    BRNE  SPI_WAIT      ; If not zero, keep waiting
    
SPI_TIMEOUT:
    ; If timeout occurred, keep previous value
    RET

; Check humidity value and set appropriate LED
CHECK_HUMIDITY:
    ; Turn off both LEDs first
    CBI   PORTD, 4       ; Turn off RED LED
    CBI   PORTD, 5       ; Turn off GREEN LED
    
    ; For testing - explicitly print the value
    MOV   R16, R29
    RCALL print_ADC    
      ; Debug: Print a marker to indicate the comparison is happening
    LDI   R16, 'C'        ; Load character 'C' into R16
waitC:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ; Test data buffer if data can be sent
    RJMP  waitC
    STS   UDR0, R16       ; Print 'C' to indicate comparison
    
    ; Compare with threshold and set LEDs accordingly
    CPI   R29, HUMIDITY_THRESHOLD      ; BCD threshold of 50% (0x50)
    
    ; Skip next instruction if R29 < 50
    BRLO  DRY_LABEL
    
    ; WET condition (R29 >= 50)
    SBI   PORTD, 4       ; Turn on RED LED
    RJMP  HUMIDITY_DONE
    
DRY_LABEL:
    ; DRY condition (R29 < 50)
    SBI   PORTD, 5       ; Turn on GREEN LED

HUMIDITY_DONE:
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

;=====================================================================
; Print raw hex value (for debugging)
; Input: R16 - value to print
;=====================================================================
print_hex:
    PUSH  R16             ; Save R16
    PUSH  R17             ; Save R17
      ; Print prefix to indicate hex
    LDI   R16, '$'
print_hex_prefix:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  print_hex_prefix
    STS   UDR0, R16
    
    ; Print high nibble
    POP   R17             ; Restore original value
    PUSH  R17             ; And save it again
    SWAP  R17             ; Swap nibbles
    ANDI  R17, 0x0F       ; Mask low nibble
    
    CPI   R17, 10         ; Check if 0-9 or A-F
    BRSH  print_hex_hi_af
    SUBI  R17, -'0'       ; Convert to '0'-'9'
    RJMP  print_hex_hi_done
print_hex_hi_af:
    SUBI  R17, -('A'-10)  ; Convert to 'A'-'F'
print_hex_hi_done:
    MOV   R16, R17
print_hex_hi_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  print_hex_hi_wait
    STS   UDR0, R16
    
    ; Print low nibble
    POP   R17             ; Restore original value
    ANDI  R17, 0x0F       ; Mask low nibble
    
    CPI   R17, 10         ; Check if 0-9 or A-F
    BRSH  print_hex_lo_af
    SUBI  R17, -'0'       ; Convert to '0'-'9'
    RJMP  print_hex_lo_done
print_hex_lo_af:
    SUBI  R17, -('A'-10)  ; Convert to 'A'-'F'
print_hex_lo_done:
    MOV   R16, R17
print_hex_lo_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  print_hex_lo_wait
    STS   UDR0, R16
      ; Print newline
    LDI   R16, 0x0A
print_hex_nl_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  print_hex_nl_wait
    STS   UDR0, R16
      ; Print carriage return
    LDI   R16, 0x0D
print_hex_cr_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  print_hex_cr_wait
    STS   UDR0, R16
    
    POP   R17             ; Restore R17
    RET