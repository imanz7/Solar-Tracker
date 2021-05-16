;
; Part1.asm
;
; Created: 29/12/2020 7:58:20 PM
; Author : imanz
;
.DEF	temp = r16			; temporary value
.DEF	adcstate = r17		; adc current state
.DEF	clow = R18			; pwm period
.DEF	chigh = R19
.DEF	offsetl = R20		; offset value	
.DEF	offseth = R21

.ORG	0x0000              
RJMP	Reset              
.ORG	0x0020                 
RJMP	TIMER_OVF  

Reset: 
 LDI	temp, 0b00000010	;Prescaler value of 1024
 OUT	TCCR0B, temp      
 LDI	temp, 0b00000001	;overflow interrupt enable
 STS	TIMSK0, temp      
 SEI						;set interrupt
 CLR	temp
 OUT	TCNT0, temp			;clear tc0 counter value register

Main:
 LDI    temp, 0xFF              
 OUT    DDRD, temp			; set port D as output            
 LDI	temp, 0xFC
 OUT	DDRC, temp			; set PC0 PC1 as input				

 LDI	temp, 0xFF
 OUT	DDRB, temp
 ;OUT	PORTB, temp			; set port B as output
 LDI	temp, 0x01
 STS	OCR1AH, temp		; store high byte value of OCR1
 LDI	temp, 0xFF
 STS	OCR1AL, temp		; store low byte value of OCR1

 LDI	temp, (1<<COM1A1|1<<WGM11)	        
 STS	TCCR1A, temp		; set output to low level, non-inverted PWM
 LDI	temp, (1<<WGM13|1<<WGM12|1<<CS11)	
 STS	TCCR1B, temp		; prescaler value of 8

 LDI	temp, 0b10011100	
 STS	ICR1H, temp			; store high byte value of ICR1	(max. value of ICR1A = 39999)
 LDI	temp, 0b00111111	
 STS	ICR1L, temp			; store low byte value of ICR1

 CALL	USART_Init			; call function USART_Init
 CALL	ADC_init			; call function ADC_init

loop:
 CALL	ADC0
 CALL	ADC1
 CALL	Output				; call function Output
 RJMP	loop

USART_Init:
 LDI	R16, 0x67
 LDI	R17, 0x00 
 STS	UBRR0H, R17			; set high byte baud rate
 STS	UBRR0L, R16			; set low byte baud rate (19200)
 LDI	temp, (1<<TXEN0)	
 STS	UCSR0B, temp		; enable transmitter to display data to Serial monitor
 LDI	temp, 0b00001110
 STS	UCSR0C, temp		; select 0 as stop bits, 8-bit data
 RET

ADC0:
 LDS	temp, ADMUX
 ANDI	temp, 0xC0			; REFS1 REFS0
 ORI	temp, 0				; ADC0
 ;LDI	temp, (1<<REFS1|1<<REFS0|0<<MUX0)									
 STS	ADMUX, temp
 CALL	ADC_read			; call function ADC_read
 CALL	ADC_wait			; call function ADC_wait
 LDS	R30, ADCL			; store low byte of ADC
 LDS	R31, ADCH			; store high byte of ADC
 RET

ADC1:
 LDS	temp, ADMUX
 ANDI	temp, 0xC0			; REFS1 REFS0
 ORI	temp, 1				; ADC1
 ;LDI	temp, (1<<REFS1|1<<REFS0|1<<MUX0)									
 STS	ADMUX, temp	
 CALL	ADC_read			; call function ADC_read
 CALL	ADC_wait			; call function ADC_wait
 LDS	R28, ADCL			; store low byte of ADC
 LDS	R29, ADCH			; store high byte of ADC
 RET

ADC_init:
 LDI	adcstate, (1<<ADEN|1<<ADPS2|1<<ADPS1|1<<ADPS0|1<<ADATE|1<<ADSC)	
 STS	ADCSRA, adcstate	; enable ADC, start conversion of ADC, enable auto trigger
 LDI	temp, (1<<REFS1|1<<REFS0)									
 STS	ADMUX, temp			; AVcc with external capacitor at AREF pin, read ADC0
; LDI	temp, (0<<ADTS2|0<<ADTS1|1<<ADTS0)
; STS	ADCSRB, temp		; free running mode
 RET

ADC_read:
 LDI	temp, (1<<ADSC)							
 STS	ADCSRA, temp		; start conversion of adc (read input)
 OR		temp, adcstate		; OR adcsra with prev adcstate (to ensure the value of ADC is read)
 STS	ADCSRA, temp		; write current state to ADCSRA
 RET	

ADC_wait:
 LDS	R17, ADCSRA			; load ADCSRA (current state to R17)
 SBRS	R17, 4				; skip if bit 4 is set (skip if ADC conversion is completed)
 JMP	ADC_wait			; if ADC conversion is not completed yet, jump to ADC_wait function
 LDI	temp, 0b00010000	; write done conversion
 LDS	R17, ADCSRA			; load ADCSRA (current state to R17)
 OR		R17, temp			; OR R17 (ADCRSA) with ADIF (double check if conversion is done)
 STS	ADCSRA, R17 		; write current state to ADCSRA
 RET

Output:	
 CP		R30, R28				
 CPC	R31, R29			; compare 10-bit value of ADC0 and ADC1
 BRLO	cw					; if ADC0 < ADC1, go to ccw
 ;JMP	ccw					; if ADC0 >= ADC1, go to cw
 ;RET

ccw:
 LDI	offseth, 0b00000011	; store high byte offset value
 LDI	offsetl, 0b00100000	; store low byte offset value (offset = 800)
 LDI	chigh, 0b00001111	; store high byte value 
 LDI	clow, 0b10011111	; store low byte value	(constant = 3999)
 ADD	offsetl, clow		; add value of low byte offset value with constant
 ADC	offseth, chigh		; add value of high byte offset value with constant
 STS	OCR1AL, offsetl		; store value of low byte to OCR1AL
 STS	OCR1AH, offseth		; store value of low byte to OCR1AH
 LDI	R26, $48			; store H to display later
 CALL	Display_USART
 CALL	delay
 JMP	loop

cw:
 LDI	offseth, 0b00000011	; store high byte offset value
 LDI	offsetl, 0b00100000	; store low byte offset value (offset = 800)
 LDI	chigh, 0b00000111	; store high byte value
 LDI	clow, 0b11001111	; store low byte value	(constant = 1999)
 SUB	clow, offsetl		; subtract value of low byte offset value with constant
 SBC	chigh, offseth		; subtract value of high byte offset value with constant
 STS	OCR1AL, offsetl		; store value of low byte to OCR1AL
 STS	OCR1AH, offseth		; store value of low byte to OCR1AH
 LDI	R26, $4C			; store L to display later
 CALL	Display_USART
 CALL	delay
 JMP	loop

Display_USART:
 RCALL  USART_Transmit
 LDI	R26, $D				; store "carriage return" to display later
 RCALL	USART_Transmit
 LDI	R26, $0A			; store "new line" to have new line
 RCALL	USART_Transmit
 RET

USART_Transmit:
 LDS	R16, UCSR0A			; wait for empty transmit buffer
 SBRS	R16, UDRE0			; skip if data register is empty (hence, ready to write the data)
 RJMP	USART_Transmit		; otherwise, wait until data is received 
 STS	UDR0, R26			; put data into buffer and sends the data
 RET

delay:
 CLR	R24          
L1:
 CPI	R24,30    
 BRNE	L1       
 RET  

delay_servo:			;delay loop
 LDI	R24,100
 LDI	R23,50
L2:
 DEC	R22
 BRNE   L2
 DEC	R23
 BRNE   L2
 DEC	R24
 BRNE   L2
 NOP
 RET

TIMER_OVF:
 INC	R24         
 CPI	R24, 61    
 BRNE	PC+2            
 CLR	R24         
 RETI