.include "vc4.qinc"

# Uniforms
.set srcPtr, ra0
.set tgtPtr, ra1
.set srcStride, rb0
.set tgtStride, rb1
.set blockIter, ra2			# Iterator over blocks (16 lines)
mov srcPtr, unif;
mov tgtPtr, unif;
mov srcStride, unif;
mov tgtStride, unif;
read unif;					# line width not needed
mov blockIter, unif;		# line count

# Variables
.set vpmSetup, rb2
.set vdwSetup, rb3
.set mskAccum, ra3
.set mskIter, r3		# Could replace with register file on cost of 3 instructions in the innermost loop
.set maskCO, rb4

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
ldi r1, 4;
mul24 r1, qpu_num, r1;
add vpmSetup, r0, r1;

# Create VPM DMA Basic setup
;shl r1, r1, 7;
ldi r0, vdw_setup_0(16, 4, dma_v32(0, 0));
add vdwSetup, r0, r1;

# Adjust stride
mov r0, 8;
sub srcStride, srcStride, r0; # Remove read bytes
mov r0, 4;
shl tgtStride, tgtStride, r0; # Multiply by 16 (block size)

# Initiate block iterator
shr r0, blockIter, 4;	# Block iterator = line count / 16
max blockIter, r0, 1;	# At least one iteration in loop

:blockIter # Loop over blocks

	# Initiate VPM write and make sure last VDW finished
	read vw_wait;
	mov vw_setup, vpmSetup;

	.rep b, 4 # 4 Blocks of 32Bits each

		# Clear mask accumulator, init mask iterator
		mov mskAccum, 0; mov mskIter, 1;

		.rep l, 4 # 4 Lines of 8Bits each

			# Wait for current load and start next (line)
			;ldtmu0
			mov t0s, srcPtr; add srcPtr, srcPtr, srcStride;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, r4.8cf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, r4.8df, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

			# Wait for current load and start next
			;ldtmu0
			mov t0s, srcPtr; add srcPtr, srcPtr, 4;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, r4.8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, r4.8bf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, r4.8cf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, r4.8df, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

			# Wait for current load and start next
			;ldtmu0
			mov t0s, srcPtr; add srcPtr, srcPtr, 4;

			# Read 4 loaded pixels and update mask
			fmin.setf nop, r4.8af, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;
			fmin.setf nop, r4.8bf, maskCO;
			shl mskIter, mskIter, 1; v8adds.ifcs mskAccum, mskAccum, mskIter;

		.endr

		# Write to VPM
		nop;
		mov vpm, mskAccum;

	.endr

	# Initiate VDW from VPM to memory
	mov vw_setup, vdwSetup;
	ldi vw_setup, vdw_setup_1(0);
	mov vw_addr, tgtPtr;

	# Increase adresses to next line
	add tgtPtr, tgtPtr, tgtStride;

	# Make sure to finish VDW
#	read vw_wait;

	# Line loop :blockIter
	sub.setf blockIter, blockIter, 1;
	brr.anynz -, :blockIter
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
