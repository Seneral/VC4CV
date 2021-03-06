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

	.rep px, 2

		# Initiate VPM write and make sure last VDW finished
		read vw_wait;
		mov vw_setup, vpmSetup;

		# Read TMU
		mov t0s, srcPtr;
		ldtmu0

		# Read packed data out of r4
		mov ra20, r4.8a;
		mov ra21, r4.8b;
		mov ra22, r4.8c;
		mov ra23, r4.8d;

		# Write to VPM
		fmul vpm.8888, ra20, 1.0; # using mul encoding
		fmul vpm.8888, ra21, 1.0; # using mul encoding
		fmul vpm.8888, ra22, 1.0; # using mul encoding
		fmul vpm.8888, ra23, 1.0; # using mul encoding

		# Initiate VDW from VPM to memory
		mov vw_setup, vdwSetup;
		mov vw_setup, vdwStride;
		mov vw_addr, tgtPtr;

		# Increase address
		add srcPtr, srcPtr, 4;
		add tgtPtr, tgtPtr, num16;

		# Make sure to finish VDW
#		read vw_wait;

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

mov.setf irq, nop;

nop; thrend
nop
nop
