# Uniforms
.set srcPtr, ra0
.set srcStride, rb0
.set segSize, ra1
mov srcPtr, unif;
mov srcStride, unif;
mov segSize, unif;

.macro sleep(n)
	.rep x, n
		nop; nop;
	.endr
.endm

# Calculate base source address of each tile column
mul24 r0, elem_num, 4;
add srcPtr, srcPtr, r0;
nop;

# Start loading very first line
#mov t0s, srcPtr;
#add srcPtr, srcPtr, srcStride;

sleep(30)

:loop

	mov t0s, srcPtr;
	add srcPtr, srcPtr, srcStride;
	ldtmu0

	sleep(30)

	sub.setf segSize, segSize, 1;
	brr.anynz -, :loop
	nop
	nop
	nop

# Read last unused load
#ldtmu0;

mov.setf irq, nop;

nop; thrend
nop
nop
