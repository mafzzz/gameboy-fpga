SECTION "Start", CODE[$0000]
	LD	A, $C5
	LD	B, $00
	LD	D, $00
	LD	E, $FF
	LD	H, $10
	LD	L, $00
		
write:
	LD [HL+], A
	INC A
	CP A, E
	JP NZ, write
	
	DEC HL
	
read:
	DEC A
	LD C, [HL]
	DEC HL
	CP A, C
	JP NZ, fail
	CP A, D
	JP NZ, read
	
	LD B, $42
	NOP
	NOP
	STOP
	
fail:
	LD B, $DE
	NOP
	NOP
	STOP