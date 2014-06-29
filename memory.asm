SECTION "Start", CODE[$0000]
	
	LD	SP, $C000;
	
	LD	HL, $A000	; Beginning of memory to store array
	LD	A, $13		; First number to store
	LD	C, $16		; Counter
	LD	B, $01		; Incrementer
	
load_mem:
	LD	[HL+], A
	ADD	A, B
	INC	B
	DEC	C
	JP	NZ, load_mem
	
	LD	B, $16		; Max
	LD	C, $00		; Min
	LD	A, $00		; Middle
	LD	HL, $A000	; Start address
	LD	E, $9C		; Key
	
search:
	LD	A, C
	CP	A, B
	JP	Z, fail
	ADD	A, B
	SRL	A
	LD	L, A
	LD	D, [HL]
	PUSH AF
	LD	A, E
	CP	A, D
	JP	Z, pass
	JP	C, lower
	JP	higher
	
lower:
	POP AF
	LD B, A
	JP search
	
higher:
	POP AF
	INC A
	LD C, A
	JP search
	
pass:
	POP AF
	STOP
	
fail:
	STOP