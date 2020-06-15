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
.set y, ra4			# Iterator over all lines
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

# ------- Block 0 Start
#or.setf nop, mutex, nop;

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

# 	------- Block 1 Start -----
#	or.setf nop, mutex, nop;

	.rep px, 2

		# Initiate VPM write and make sure last VDW finished
		read vw_wait;
		mov vw_setup, vpmSetup;

	.if 1 # --- Code 1
		# Normal debug code. Always works, without mutex or whatever configuration
		# So VPM access should not be problematic

		 # Constant Alpha
		mov ra17.8dsi, 255;
		# Element number (1-16) in Red
		mul24 ra17.8csi, elem_num, num16;
		# Constant 0 green
		mov ra17.8bsi, 0;
		# QPU number in Blue
		ldi r0, 21;
		mul24 ra17.8asi, qpu_num, r0;
		nop;

		# Write to VPM
		mov vpm, ra17;
		mov vpm, ra17;
		mov vpm, ra17;
		mov vpm, ra17;

	.endif

	.if 0 # --- Code 2
		# Simple TMU Test code

		mov t0s, srcPtr;
		ldtmu0
		mov ra18, r4;

	.endif

	.if 0 # --- Code 3
		# TMU Test code with mutex

		read mutex;

		mov t0s, srcPtr;
		ldtmu0
		mov ra18, r4;

		mov mutex, 0;

	.endif

	.if 0 # --- Code 4
		# TMU read to r0
		mov t0s, srcPtr;
		ldtmu0

		mov r0, r4;

		# Write to VPM
		fmul vpm.8888, r0, 1.0; # using mul encoding
		fmul vpm.8888, r0, 1.0; # using mul encoding
		fmul vpm.8888, r0, 1.0; # using mul encoding
		fmul vpm.8888, r0, 1.0; # using mul encoding

	.endif

	.if 0 # --- Code 5
		# TMU read to r0 with nop; afterwards
		mov t0s, srcPtr;
		ldtmu0

		mov r0, r4;
		nop;

		# Write to VPM
		fmul vpm.8888, r0, 1.0; # using mul encoding
		fmul vpm.8888, r0, 1.0; # using mul encoding
		fmul vpm.8888, r0, 1.0; # using mul encoding
		fmul vpm.8888, r0, 1.0; # using mul encoding

	.endif

	.if 0 # --- Code 6
		# Normal TMU camera write (works if executed one after another

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

	.endif

		# Initiate VDW from VPM to memory
		mov vw_setup, vdwSetup;
		mov vw_setup, vdwStride;
		mov vw_addr, tgtPtr;

		# Increase address
		add srcPtr, srcPtr, 4;
#	nop;
		add tgtPtr, tgtPtr, num16;
#	nop;

		# Make sure to finish VDW
#		read vw_wait;

	.endr

# 	------- Block 1 End
#	or.setf mutex, nop, nop;

	# Increase adresses to next line
	add srcPtr, srcPtr, srcStride;
	add tgtPtr, tgtPtr, tgtStride;

	# Line loop :y
	sub.setf y, y, 1;
	brr.anynz -, :y
	nop
	nop
	nop

# ------- Block 0 End
#or.setf mutex, nop, nop;

mov.setf irq, nop;

nop; thrend
nop
nop
