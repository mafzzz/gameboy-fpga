SECTION "Start", CODE [$0000]
	
init:	LD	B, $00		; Fib(0)
		LD	A, $01		; Fib(1)
		LD	D, $0D		; Max fibonacci number
		LD	E, $01		; Counter
		
		LD	H, $50
		LD	L, $00		; Starting address
		
		LD	[HL], B
		INC	HL
		LD	[HL+], A
		
write:	LD	C, A
		ADD A, B
		LD	B, C
		LD	[HL], $42
		INC	HL
		INC	E
		LD	C, A
		LD	A, D
		CP	A, E
		LD	A, C
		JP	NZ, write
		
read:	LD	L, $08
		LD	A, [HL-]
		LD	E, A
		LD	A, [HL-]
		LD	D, A
		LD	A, [$5006]
		LD	C, A
		DEC	HL
		LD	B, [HL]
		DEC	HL
		LD	A, $01
		ADD	A, $ff
		STOP