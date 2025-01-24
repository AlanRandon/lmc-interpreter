lhs	INP
	STA lhs
rhs	INP
	STA rhs
loop	LDA lhs
	SUB rhs
	STA lhs
	BRP incr
	BRA end
incr	LDA result
	ADD one
	STA result
	BRA loop
end	LDA result
	OUT
	HLT

result	DAT 0
one	DAT 1
