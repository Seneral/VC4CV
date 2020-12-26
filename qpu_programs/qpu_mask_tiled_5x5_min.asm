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
.set mskIter, r3			# Could replace with register file on cost of 3 instructions in the innermost loop
.set maskCO, rb4
.set sh1, ra4
.set sh2, ra5
.set sh3, ra6
.set minAccum, ra7

# Define variables storing the current headers
.func valReg(y, x)
	.assert b < 5 && b >= 0
	.assert l < 4 && l >= 0
	.assert y < 5 && y >= 0
	.assert x <= 2 && x >= 0
	ra17 + ((b*4*3 + (l-y)*3 + x + 15)%15)
.endf
.func minReg(n, x)
	.assert n <= 5  && n >= 2
	.assert x <= 2 && x >= 0
	rb20 + ((n-2)*3 + x)
.endf

# TODO: Generate vector mask to allow for any multiple of 8-wide columns (not just 16x8)

# Calculate base source of each tile column
mul24 r0, elem_num, 8;
add srcPtr, srcPtr, r0;

# Set mask parameters
ldi maskCO, 0.5;
ldi sh1, 8;
ldi sh2, 16;
ldi sh3, 24;

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
mov valReg(4,0), 0;
mov valReg(4,1), 0;
mov valReg(4,2), 0;
mov valReg(3,0), 0;
mov valReg(3,1), 0;
mov valReg(3,2), 0;
mov valReg(2,0), 0;
mov valReg(2,1), 0;
mov valReg(2,2), 0;
mov valReg(1,0), 0;
mov valReg(1,1), 0;
mov valReg(1,2), 0;
mov minReg(2,0), 0xFFFFFFFF;
mov minReg(2,1), 0xFFFFFFFF;
mov minReg(2,2), 0xFFFFFFFF;
mov minReg(3,0), 0xFFFFFFFF;
mov minReg(3,1), 0xFFFFFFFF;
mov minReg(3,2), 0xFFFFFFFF;
mov minReg(4,0), 0xFFFFFFFF;
mov minReg(4,1), 0xFFFFFFFF;
mov minReg(4,2), 0xFFFFFFFF;

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
			mov valReg(0,0), r4;
			mov t0s, srcPtr; add srcPtr, srcPtr, srcStride;

			# Update column-wise minimum values for the first 4 columns
			v8min minReg(5,0), minReg(4,0), r4;
			v8min minReg(4,0), minReg(3,0), r4;
			v8min minReg(3,0), minReg(2,0), r4;
			v8min minReg(2,0), valReg(1,0), r4;

			# Wait for current load and start next
			;ldtmu0
			mov valReg(0,1), r4;
			mov t0s, srcPtr; add srcPtr, srcPtr, 4;

			# Update column-wise minimum values for the middle 4 columns
			v8min minReg(5,1), minReg(4,1), r4;
			v8min minReg(4,1), minReg(3,1), r4;
			v8min minReg(3,1), minReg(2,1), r4;
			v8min minReg(2,1), valReg(1,1), r4;

			# Calculate 5x5 min for first four pixels
			# First and second column
			shl r0, minReg(5,0), sh1;
			shr r1, minReg(5,1), sh3;
			v8adds r0, r0, r1;
			v8min minAccum, r0, minReg(5,0);
			# Third column
			shl r0, minReg(5,0), sh2;
			shr r1, minReg(5,1), sh2;
			v8adds r0, r0, r1;
			v8min minAccum, r0, minAccum;
			# Fourth column
			shl r0, minReg(5,0), sh3;
			shr r1, minReg(5,1), sh1;
			v8adds r0, r0, r1;
			v8min r1, r0, minAccum;
			# Fifth column
			v8min minAccum, r1, minReg(5,1);
			nop;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, minAccum.8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, minAccum.8bf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, minAccum.8cf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, minAccum.8df, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

			# Wait for current load and start next
			;ldtmu0
			mov valReg(0,2), r4;
			mov t0s, srcPtr; add srcPtr, srcPtr, 4;

			# Update column-wise minimum values for the last 4 columns
			v8min minReg(5,2), minReg(4,2), r4;
			v8min minReg(4,2), minReg(3,2), r4;
			v8min minReg(3,2), minReg(2,2), r4;
			v8min minReg(2,2), valReg(1,2), r4;

			# Calculate 5x5 min for last four pixels
			# First and second column
			shl r0, minReg(5,1), sh1;
			shr r1, minReg(5,2), sh3;
			v8adds r0, r0, r1;
			v8min minAccum, r0, minReg(5,1);
			# Third column
			shl r0, minReg(5,1), sh2;
			shr r1, minReg(5,2), sh2;
			v8adds r0, r0, r1;
			v8min minAccum, r0, minAccum;
			# Fourth column
			shl r0, minReg(5,1), sh3;
			shr r1, minReg(5,2), sh1;
			v8adds r0, r0, r1;
			v8min r1, r0, minAccum;
			# Fifth column
			v8min minAccum, r1, minReg(5,2);
			nop;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, minAccum.8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, minAccum.8bf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, minAccum.8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, minAccum.8bf, maskCO;
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
