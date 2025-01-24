loop	LDA lhs
	OUT

	LDA store
	ADD one
	STA store
	LDA lhs
store	STA data

	ADD rhs
	STA next
	LDA rhs
	STA lhs
	LDA next
	STA rhs

	LDA iters
	SUB one
	STA iters
	BRZ end
	BRA loop
end	HLT


lhs	DAT 0
rhs	DAT 1
next	DAT
iters	DAT 21
one	DAT 1
data	DAT data

