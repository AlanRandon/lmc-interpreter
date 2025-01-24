numA	DAT 901 // INP
	STA numA
numB	DAT 901 // INP

loop	BRZ endloop

	SUB one
	STA numB

	LDA answer
	ADD numA
	STA answer

	LDA numB

	BRA loop

endloop	LDA answer
	OUT
	HLT

one	DAT 1
answer	DAT 0

