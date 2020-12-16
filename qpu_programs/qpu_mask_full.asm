## Camera mask fullscreen
# Mask camera feed and blit to custom 1-bit-per-pixel buffer in fullscreen mode using VPM writes and TMU reads
# Currently set up to a simple threshold of 0.5 (maskCO register constant)
# More complex programs with neighbour pixel access would be a pain to implement, easier in tiled mode once it works
# Use mode full (-m full) to execute

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
mov	srcStride, unif;
mov	tgtStride, unif;
mov	lineWidth, unif;
mov lineCount, unif;

# Variables
.set x, ra4			# Iterator over current line
.set y, ra5			# Iterator over all lines
.set s, ra6 		# Iterator of current line segment
.set p, rb2 		# Number of pixels in the current segment
.set line, ra7
.set srcPtr, ra8
.set tgtPtr, rb3
.set vdwStride, rb4

# Compiler Constants
.const segSize, 20 # Line segment size. segSize = num vectors in VPM reserved for user programs (default 32, 64 on RPi assigned)
.const segSplit, 5

# Register Constants
.set num16, rb5
ldi num16, 16;
.set maskCO, rb7
ldi maskCO, 0.5;

# Calculate target stride
ldi r0, 0xc0000000;
add r0, r0, tgtStride;
mov r1, segSize/segSplit * 4;
sub vdwStride, r0, r1;

mov line, 0; # Opposite of y, increases in multiples of 16
# Line Iterator: drop 4 LSB as the 16-way processor will blit 16 lines in parallel
shr r0, lineCount, 4;
max y, r0, 1;

:y # Loop over lines (16 at a time)

	# Calculate base source address of current 16 lines
	mul24 r0, line, srcStride;
	add r0, r0, srcAddr;
	mul24 r1, elem_num, srcStride; # individual offset of each SIMD vector element
	add srcPtr, r0, r1;

	nop;
	nop;
	nop;
	nop;
	nop;
	nop;
	nop;
	nop;
	nop;

	# Calculate base target address of current block
	mul24 r0, line, tgtStride;
	add tgtPtr, r0, tgtAddr;

	# TODO: Generate vector mask to prevent overflow of source (720p and 1232p would work fine without)

	# Setup VPM for writing full 32Bits rows (Horizontal mode)
	read vw_wait;
	mov vw_setup, vpm_setup(0, 1, h32(0));

	# Pixel iterator: Drop 5 LSB as 32 pixels (8 loads of 4 pixels) are processed at once
	shr x, lineWidth, 5;

	:x # Loop over line segments (max 512pixels can be written at once)

		# Clear mask accumulator r0, init mask iterator r1
		mov r0, 0; mov r1, 1;

#		.rep c, 4		# 4 channels of 8bit each, total of 32bit
			.rep l, 8	# 2 loads of 4 pixels each, total of 8pixels processed to 8bit

				.back 0
					# Load srcPtr from camera frame
					mov t0s, srcPtr; # remove for opt
					# Increase source pointer by 4 pixels (bytes)
					;add srcPtr, srcPtr, 4;
				.endb

				# This will block until TMU has loaded the data (9-20 cycles)
				ldtmu0

				# Increase source pointer by 4 pixels (bytes)
#				add srcPtr, srcPtr, 4;
				# This will block until TMU has loaded the data (9-20 cycles)
#				ldtmu0
				# Load srcPtr from camera frame
#				mov t0s, srcPtr; # remove for opt

				fmin.setf nop, r4.8af, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;

				fmin.setf nop, r4.8bf, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;

				fmin.setf nop, r4.8cf, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;

				fmin.setf nop, r4.8df, maskCO;
				shl r1, r1, 1; v8adds.ifcs r0, r0, r1;

			.endr
#		.endr

		# Write all 32bits (32pixels) to VPM
		mov vpm, r0;

		# End branch :x
		sub.setf x, x, 1;
		brr.anynz -, :x
		nop
		nop
		nop

	# Set fixed target stride
	mov vw_setup, vdwStride;

	# Calculate split segment stride
	mov r1, segSize/segSplit * 4;

	.rep i, segSplit
		read vw_wait;
		# Write VPM to memory (segSize in vectors, is multiplied by 4 for byte length)
		mov vw_setup, vdw_setup_0(16, segSize/segSplit, dma_v32(segSize/segSplit*i, 0));
		# Write address
		mov vw_addr, tgtPtr;
		# Increase adress
		add tgtPtr, tgtPtr, r1;
	.endr

#	ldtmu0

	# Increase line to next 16 lines
	add line, line, num16;

	# End branch :y
	sub.setf y, y, 1;
	brr.anynz -, :y
	nop
	nop
	nop

mov.setf irq, nop;

nop; thrend
nop
nop
