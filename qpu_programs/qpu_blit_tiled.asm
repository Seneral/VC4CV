.include "vc4.qinc"

# Uniforms
.set srcAddr, ra0
.set tgtAddr, ra1
.set srcStride, rb0
.set tgtStride, rb7
.set lineWidth, ra2
.set lineCount, ra3
mov srcAddr, unif;
mov tgtAddr, unif;
mov	srcStride, unif;
mov	tgtStride, unif;
mov	lineWidth, unif;
mov lineCount, unif;

# Variables
.set y, ra4			# Iterator over all lines
.set srcPtr, ra5
.set tgtPtr, ra10
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

# TODO: Generate vector mask to allow for any multiple of 8-wide columns (not just 16x8)

# ------- Block: Protect whole program -----
or.setf nop, mutex, nop;

# Create VPM Setup
ldi r0, vpm_setup(0, 1, h32(0));
mov r1, 4;
mul24 r1, qpu_num, r1;
add vpmSetup, r0, r1;

# Create VPM DMA Basic setup
shl r1, r1, 7;
ldi r0, vdw_setup_0(16, 4, dma_v32(0, 0));
add vdwSetup, r0, r1;

# Create VPM DMA Stride setup
ldi vdwStride, vdw_setup_1(16);

# Calculate base source and target address of each tile column
mul24 r0, elem_num, 8;
add srcPtr, srcAddr, r0;
mov tgtPtr, tgtAddr;

# Adjust stride, removing the written bytes
sub srcStride, srcStride, num8;
sub tgtStride, tgtStride, num32;

# Line Iterator - at least one line else loop will break
max y, lineCount, 1;

:y # Loop over lines

# 	------- Block: Protect each line -----
#	or.setf nop, mutex, nop;

	.rep px, 2

		# Setup VPM for writing
#		read vw_wait;

		# Load two times 4 pixels from camera frame using TMU
		mov t0s, srcPtr;

		# This will block until TMU has loaded the next request (9-20 cycles)
		ldtmu0

		# Read packed data out of r4
		mov ra20, r4.8a;
		mov ra21, r4.8b;
		mov ra22, r4.8c;
		mov ra23, r4.8d;

		# Write VPM to memory
		read vw_wait;
# 		------- Block: Protect individual VPM acesses -----
#		or.setf nop, mutex, nop;

		mov vw_setup, vpmSetup;

		fmul vpm.8888, ra20, 1.0; # using mul encoding
		fmul vpm.8888, ra21, 1.0; # using mul encoding
		fmul vpm.8888, ra22, 1.0; # using mul encoding
		fmul vpm.8888, ra23, 1.0; # using mul encoding

		read vw_wait;

		mov vw_setup, vdwSetup;
		mov vw_setup, vdwStride;

		mov vw_addr, tgtPtr;

		read vw_wait;
# 		------- Block: Protect individual VPM accesses -----
#		or.setf mutex, nop, nop;

		# Increase address
		add srcPtr, srcPtr, 4;
		add tgtPtr, tgtPtr, num16;

	.endr

# 	------- Block: Protect each line -----
#	or.setf mutex, nop, nop;

	.rep i, 10
		nop;
		nop;
		nop;
	.endr

	# Increase adresses to next line
	add srcPtr, srcPtr, srcStride;
	add tgtPtr, tgtPtr, tgtStride;

	# Line loop :y
	sub.setf y, y, 1;
	brr.anynz -, :y
	nop
	nop
	nop

nop;
nop;
nop;

# ------- Block: Protect whole program -----
or.setf mutex, nop, nop;

mov.setf irq, nop;

nop; thrend
nop
nop
