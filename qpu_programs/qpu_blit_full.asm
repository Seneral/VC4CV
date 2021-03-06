## Camera blit fullscreen
# Blit camera feed to framebuffer in fullscreen mode using VPM writes and TMU reads
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
.const segSz, 4 # Line segment size. segSz*4 <= num vectors in VPM reserved for user programs (default 32, 64 on RPi assigned)
.lconst segSplit, 1

# Register Constants
.set num16, rb5
ldi num16, 16;
.set segSize, rb6
mov segSize, segSz; # Need it as both compiler and register constant

# Calculate target stride
ldi r0, 0xc0000000;
add r0, r0, tgtStride;
mov r1, segSz*4 / segSplit * 4;
sub vdwStride, r0, r1;

mov line, 0; # Opposite of y, increases in multiples of 16
# Line Iterator: drop 4 LSB as the 16-way processor will blit 16 lines in parallel
shr r0, lineCount, 4;
max y, r0, 1;

:y # Loop over lines (16 at a time)

	# Calculate base source address of current 16 lines
	mul24 r0, line, srcStride;
	add r0, r0, srcAddr;
	mul24 r1, elem_num, srcStride;
	add srcPtr, r0, r1;

	# Calculate base target address of current block
	mul24 r0, line, tgtStride;
	add tgtPtr, r0, tgtAddr;

	# TODO: Generate vector mask to prevent overflow of source (720p and 1232p would work fine without)

	# Start loading first texture data
#	mov t0s, srcPtr;

	# Pixel iterator: drop 2 LSB as 4 pixels are loaded at once from camera
	shr r0, lineWidth, 2;
	mov x, r0; # To enable read in next instruction

	:x # Loop over line segments (max 512pixels can be written at once)

		# Calculate pixel count in current line segment
		# Can only handle a certain amount of pixels at a time, due to size of VPM, defined by segSz
		;min r0, r0, segSize;
		mov p, r0; mov s, r0; # Initialize segment iterator

		# Setup VPM for writing full 32Bits rows (Horizontal mode)
		read vw_wait;
		mov vw_setup, vpm_setup(0, 1, h32(0));

		:s # Loop for line segment

			# Load srcPtr from camera frame
			mov t0s, srcPtr; # remove for opt
			# Increase source pointer by 4 pixels (bytes)
			;add srcPtr, srcPtr, 4;
			# This will block until TMU has loaded the data (9-20 cycles)
			ldtmu0

			# Increase source pointer by 4 pixels (bytes)
#			add srcPtr, srcPtr, 4;
			# This will block until TMU has loaded the data (9-20 cycles)
#			ldtmu0
			# Load srcPtr from camera frame
#			mov t0s, srcPtr; # remove for opt

			# Read packed data out of r4
			mov ra20, r4.8a;
			mov ra21, r4.8b;
			fmul vpm.8888, ra20, 1.0; # using mul encoding
			fmul vpm.8888, ra21, 1.0; # using mul encoding
			mov ra22, r4.8c;
			mov ra23, r4.8d;
			fmul vpm.8888, ra22, 1.0; # using mul encoding
			fmul vpm.8888, ra23, 1.0; # using mul encoding

			# End branch :s
			sub.setf s, s, 1;
			brr.anynz -, :s
			nop
			nop
			nop

		# Set fixed target stride
		mov vw_setup, vdwStride;

		# Calculate split segment stride
		# TODO: Broken when width not divisible by segSize (so p != segSize)
		mov r0, 4/segSplit * 4;
		mul24 r1, p, r0;

		.rep i, segSplit
			read vw_wait;
			# Write VPM to memory (segSz, is multiplied by 16 for byte length, or 4 to get vector count)
			mov vw_setup, vdw_setup_0(16, segSz*4/segSplit, dma_v32(segSz*4/segSplit*i, 0));
			# Write address
			mov vw_addr, tgtPtr;
			# Increase adress
			add tgtPtr, tgtPtr, r1;
		.endr

		# End branch :x
		mov r0, p;
		sub.setf x, x, r0;
		brr.anynz -, :x
		nop
		nop
		nop

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
