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
.set thresholdCO, rb4
.set diffCO, rb6
.set sh1, ra4
.set sh2, ra5
.set sh2B, rb8
.set sh3, ra6
.set num4, rb9
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
mov thresholdCO, 0.4;
mov diffCO, 0.2;
;mov num4, 4;
;mov sh1, 8;
ldi sh2, 16;
ldi sh2B, 16;
ldi sh3, 24;

# Start loading very first line
mov t0s, srcPtr; add srcPtr, srcPtr, 4;
nop;
mov t0s, srcPtr;

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

			# Wait for current load and start next
			# Update column-wise minimum values for the first 4 columns
			add srcPtr, srcPtr, num4; ldtmu0
			mov valReg(0,0), r4;	v8min minReg(5,0), minReg(4,0), r4;
			mov t0s, srcPtr;		v8min minReg(4,0), minReg(3,0), r4;

			# Finish updating column-wise minimum for next iteration
			v8min minReg(3,0), minReg(2,0), r4;
			v8min minReg(2,0), valReg(1,0), r4;

			# Wait for current load and start next
			# Update column-wise minimum values for the middle 4 columns
			add srcPtr, srcPtr, srcStride; ldtmu0
			mov valReg(0,1), r4;		v8min minReg(5,1), minReg(4,1), r4;
			mov t0s, srcPtr;			v8min minReg(4,1), minReg(3,1), r4;

			# Calculate 5x5 min for first four pixels
												shr r1, minReg(5,1), sh3;
												shl r0, minReg(5,0), sh1;
			v8adds r0, r0, r1; 					shr r1, minReg(5,1), sh2;
			v8min r2, r0, minReg(5,0);			shl r0, minReg(5,0), sh2;
			v8adds r0, r0, r1; 					shr r1, minReg(5,1), sh1;
			v8min r2, r0, r2;					shl r0, minReg(5,0), sh3;
			v8adds r0, r0, r1; 					v8min r2, r2, minReg(5,1);
			v8min minAccum, r0, r2;

			# Finish updating column-wise minimum for next iteration
			v8min minReg(3,1), minReg(2,1), r4;
			v8min minReg(2,1), valReg(1,1), r4;

			# Read 4 loaded pixels and update mask
			fadd r0, minAccum.8af, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,0).8cf, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fadd r0, minAccum.8bf, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,0).8df, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fadd r0, minAccum.8cf, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,1).8af, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fadd r0, minAccum.8df, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,1).8bf, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

			# Wait for current load and start next
			# Update column-wise minimum values for the last 4 columns
			add srcPtr, srcPtr, num4; ldtmu0
			mov valReg(0,2), r4;	v8min minReg(5,2), minReg(4,2), r4;
			mov t0s, srcPtr;		v8min minReg(4,2), minReg(3,2), r4;

			# Calculate 5x5 min for last four pixels
												shr r1, minReg(5,2), sh3;
												shl r0, minReg(5,1), sh1;
			v8adds r0, r0, r1; 					shr r1, minReg(5,2), sh2;
			v8min r2, r0, minReg(5,1);			shl r0, minReg(5,1), sh2;
			v8adds r0, r0, r1; 					shr r1, minReg(5,2), sh1;
			v8min r2, r0, r2;					shl r0, minReg(5,1), sh3;
			v8adds r0, r0, r1; 					v8min r2, r2, minReg(5,2);
			v8min minAccum, r0, r2;

			# Finish updating column-wise minimum for next iteration
			v8min minReg(3,2), minReg(2,2), r4;
			v8min minReg(2,2), valReg(1,2), r4;

			# Read 4 loaded pixels and update mask
			fadd r0, minAccum.8af, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,1).8cf, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fadd r0, minAccum.8bf, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,1).8df, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fadd r0, minAccum.8cf, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,2).8af, r0;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fadd r0, minAccum.8df, diffCO;
			fmin r0, r0, thresholdCO;
			fmin.setf nop, valReg(2,2).8bf, r0;
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
