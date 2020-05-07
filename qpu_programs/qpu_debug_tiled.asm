## Debug tiles
# Debug tiled access pattern on the framebuffer using VPM writes to the framebuffer
# Visualizes how the different QPUs traverse the screen in tiled mode
# Use mode tiled (-m tiled) to execute

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

# Adjust stride, removing the written bytes
sub tgtStride, tgtStride, num32;
mov tgtPtr, tgtAddr;

# Line Iterator - at least one line else loop will break
max y, lineCount, 1;

:y # Loop over lines

	.rep px, 2

		# Setup VPM for writing
		read vw_wait;
		mov vw_setup, vpmSetup;

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

		# Write VPM to memory
		mov vw_setup, vdwSetup;
		mov vw_setup, vdwStride;
		mov vw_addr, tgtPtr;
		# Increase address
		add tgtPtr, tgtPtr, num16;
		read vw_wait;

	.endr

	# Increase adresses to next line
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
