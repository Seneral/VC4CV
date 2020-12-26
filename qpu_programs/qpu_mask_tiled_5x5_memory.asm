.include "vc4.qinc"

# Uniforms
.set srcPtr, ra0
.set tgtPtr, ra1
.set srcStride, rb0
.set tgtStride, rb1
.set lineIter, ra2			# Iterator over blocks (16 lines)
mov srcPtr, unif;
mov tgtPtr, unif;
mov srcStride, unif;
mov tgtStride, unif;
read unif;					# line width not needed
mov lineIter, unif;			# line count

# Variables
.set vpmSetup, rb2
.set vdwSetup, rb3
.set mskAccum, ra3
.set mskIter, r3		# Could replace with register file on cost of 3 instructions in the innermost loop
.set maskCO, rb4

# Define variables storing the current headers
.func pxReg(y, x)
	.assert b < 5 && b >= 0
	.assert l < 4 && l >= 0
	.assert y < 5 && y >= 0
	.assert x <= 2 && x >= 0
	ra17 + ((b*4*3 + (l-y)*3 + x + 15)%15)
.endf

# TODO: Generate vector mask to allow for any multiple of 8-wide columns (not just 16x8)

# Calculate base source of each tile column
mul24 r0, elem_num, 8;
add srcPtr, srcPtr, r0;

# Set mask parameters
ldi maskCO, 0.5;

# Start loading very first line
mov t0s, srcPtr; add srcPtr, srcPtr, 4;
nop;
mov t0s, srcPtr; add srcPtr, srcPtr, 4;

# Create VPM Setup
ldi r0, vpm_setup(0, 1, h32(0));
mov r1, 5;
mul24 r1, qpu_num, r1;
add vpmSetup, r0, r1;

# Create VPM DMA Basic setup
shl r1, r1, 7;
ldi r0, vdw_setup_0(16, 5, dma_v32(0, 0));
add vdwSetup, r0, r1;

# Adjust stride
mov r0, 8;
sub srcStride, srcStride, r0; # Remove read bytes
mov r0, 20;
mul24 tgtStride, tgtStride, r0;

# Initiate line iterator
ldi r0, 20;
sub lineIter, lineIter, r0;

# Init defaults
.lset b, 0
.lset l, 0
mov pxReg(4,0), 0;
mov pxReg(4,1), 0;
mov pxReg(4,2), 0;
mov pxReg(3,0), 0;
mov pxReg(3,1), 0;
mov pxReg(3,2), 0;
mov pxReg(2,0), 0;
mov pxReg(2,1), 0;
mov pxReg(2,2), 0;
mov pxReg(1,0), 0;
mov pxReg(1,1), 0;
mov pxReg(1,2), 0;

:blockIter # Loop over blocks

	# Initiate VPM write and make sure last VDW finished
	read vw_wait;
	mov vw_setup, vpmSetup;

	.rep b, 5 # 5 Blocks of 32Bits each

		# Clear mask accumulator, init mask iterator
		mov mskAccum, 0; mov mskIter, 1;

		.rep l, 4 # 4 Lines of 8Bits each

			# Wait for current load and start next (line)
			;ldtmu0
			mov pxReg(0,0), r4;
			mov t0s, srcPtr; add srcPtr, srcPtr, srcStride;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, pxReg(4,0).8cf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, pxReg(4,0).8df, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

			# Wait for current load and start next
			;ldtmu0
			mov pxReg(0,1), r4;
			mov t0s, srcPtr; add srcPtr, srcPtr, 4;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, pxReg(3,1).8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, pxReg(3,1).8bf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, pxReg(2,1).8cf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, pxReg(2,1).8df, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

			# Wait for current load and start next
			;ldtmu0
			mov pxReg(0,2), r4;
			mov t0s, srcPtr; add srcPtr, srcPtr, 4;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, pxReg(0,2).8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, pxReg(0,2).8bf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

		.endr

		# Write to VPM
		nop;
		mov vpm, mskAccum;

	.endr

# Simulate loop when testing with 4 block loops
#	.rep i, 4
#		nop;
#		add srcPtr, srcPtr, srcStride;
#		nop;
#		add srcPtr, srcPtr, 8;
#	.endr

	# Initiate VDW from VPM to memory
	mov vw_setup, vdwSetup;
	ldi vw_setup, vdw_setup_1(0);
	mov vw_addr, tgtPtr;

	# Increase adresses to next line
	add tgtPtr, tgtPtr, tgtStride;

	# Line loop :blockIter
	ldi r0, 20;
	sub.setf lineIter, lineIter, r0;
	brr.anynn -, :blockIter
	nop
	nop
	nop

# Read last two unused lines (outside of bounds)
ldtmu0
ldtmu0

mov.setf irq, nop;

nop; thrend
nop
nop
