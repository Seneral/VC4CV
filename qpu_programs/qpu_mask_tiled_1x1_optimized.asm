.include "vc4.qinc"

# Uniforms
.set srcAddr, ra0
.set tgtAddr, ra1
.set srcStride, rb0
.set tgtStride, rb1
.set lineWidth, ra2
.set lineCount, ra3
mov srcAddr, unif;
mov tgtAddr, unif;
mov srcStride, unif;
mov tgtStride, unif;
mov lineWidth, unif;
mov lineCount, unif;

# Variables
.set y, ra4		# Iterator over all lines
.set srcPtr, ra5
.set tgtPtr, ra6
.set vpmSetup, rb2
.set vdwSetup, rb3
.set vdwStride, rb4

# Register Constants
.set num8, ra7
ldi num8, 8;
.set num16, rb5
ldi num16, 16;
.set num32, ra8
ldi num32, 32;
.set maskCO, rb6
ldi maskCO, 0.5;

# TODO: Generate vector mask to allow for any multiple of 8-wide columns (not just 16x8)

# Create VPM Setup
ldi r0, vpm_setup(0, 1, h32(0));
ldi r1, 4;
mul24 r1, qpu_num, r1;
add vpmSetup, r0, r1;

# Create VPM DMA Basic setup
;shl r1, r1, 7;
ldi r0, vdw_setup_0(16, 4, dma_v32(0, 0));
add vdwSetup, r0, r1;

# Create VPM DMA Stride setup
ldi vdwStride, vdw_setup_1(0);

# Calculate base source and target address of each tile column
mul24 r0, elem_num, 8;
add srcPtr, srcAddr, r0;
mov tgtPtr, tgtAddr;

# Adjust stride
sub srcStride, srcStride, num8; # Remove read bytes
;mov r0, 4;
shl tgtStride, tgtStride, r0; # Multiply by 16 (block size)

# Line Iterator
shr r0, lineCount, 4; # Move in steps of 16 lines
max y, r0, 1; # At least one iteration in for loop

# Start loading very first line
mov r2, srcPtr;
mov t0s, r2; add r2, r2, 4;
mov t0s, r2; add r2, r2, 4;

:y # Loop over lines

	# Initiate VPM write and make sure last VDW finished
	read vw_wait;
	mov vw_setup, vpmSetup;

	.rep b, 4 # 4 Blocks of 32Bits each

		# Clear mask accumulator r0, init mask iterator r1
		mov r0, 0; mov r1, 1;

		.rep l, 4 # 4 Lines of 8Bits each

			# Increase address to next line (one ahead of current)
			add r2, r2, srcStride;

			.rep px, 2 # 2 loads of 4 Pixels each

				# Wait for current load and start next
				;ldtmu0
				mov t0s, r2; add r2, r2, 4;

				# Read 4 loaded pixels and update mask
				fmin.setf nop, r4.8af, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;
				fmin.setf nop, r4.8bf, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;
				fmin.setf nop, r4.8cf, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;
				fmin.setf nop, r4.8df, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;

			.endr

		.endr

		# Write to VPM
		mov vpm, r0;

	.endr

	# Initiate VDW from VPM to memory
	mov vw_setup, vdwSetup;
	mov vw_setup, vdwStride;
	mov vw_addr, tgtPtr;

	# Increase adresses to next line
	add tgtPtr, tgtPtr, tgtStride;

	# Make sure to finish VDW
#	read vw_wait;

	# Line loop :y
	sub.setf y, y, 1;
	brr.anynz -, :y
	nop
	nop
	nop

# Read last two unused lines (outside of bounds)
ldtmu0;
ldtmu0;

mov.setf irq, nop;

nop; thrend
nop
nop
