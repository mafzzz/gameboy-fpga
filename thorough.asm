SECTION "Start", CODE [$0000]
	
	LD	HL, $0100
	LD	DE, $0101
	
	LD	A, $00
write:
	CP	A, D
	JP	Z, cont
	LD	[DE], A
	LD	[HL], $FF
	INC	HL
	INC	DE
	INC	HL
	INC	DE
	JP	write

cont:	
	LD	DE, $FFFE
	LD	HL, $FFFF

read:
	LD	A, [HL-]
	CP	A, $00
	JP	NZ, fail
	DEC HL
	LD	A, [DE]
	CP	A, $FF
	JP	NZ, fail
	DEC	DE
	DEC	DE
	LD	A, $FF
	CP	A, H
	JP	NZ, read
	
	LD	A, $42
	STOP
	NOP
	NOP
	
fail:
	LD	A, $DE
	STOP
	NOP
	NOP