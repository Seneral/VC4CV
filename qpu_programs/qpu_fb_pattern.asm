## FrameBuffer pattern
# Generates a simple pattern using VPM writes to the framebuffer
# Works in full mode (default is fine)

.include "vc4.qinc"
# includes macros for accessing VPM and other stuff not used in here

# NOTE: prefer RegFile A, Load Immediate prevents access from RegFile B, also only RegFile A supports pack/unpack operations
# But regile location of variables has been considered to reduce instructions
# As only one access to each regfile can be made in each instruction

# Setup acronyms for uniform registers - assembler only, doesn't generate instructions
.set srcAddr, rb0
.set tgtAddr, rb1
.set tgtStride, rb2

# Load uniforms and constants - can't combine as unif can only be read in sequence
mov srcAddr, unif;
mov tgtAddr, unif;
read unif; # discard srcStride uniform
mov tgtStride, unif;

# nvec determines the number of pixels in each block
# Limited by VPM memory has been reserved for user programs (by default 32 vectors, 64 when overwritten on RPi)
.const nvec, 32

# VPM setup using macros from vc4.qinc - refer to vc4.qinc and VC4 docs for usage
# vpm_setup(num_of_reads, stride_in_units, units_setup)
# units_setup: h32(y_start) is a 32Bit Horizontal unit starting at a specific row (standard)

# Note:
# Whenever it says VPM DMA, it's for VPM <=> Memory (storing/loading whole blocks of VPM to memory)
# If it just says VPM, it's for QPU <=> VPM (writing/loading single 16-Comp vectors of QPU to VPM)

.macro genpattern, num, block

	# Setup VPM for writing full 32Bits rows (Horizontal mode)
	mov vw_setup, vpm_setup(0, 1, h32(0));

	# Write num 32-Bit 16-component color vectors into the VPM buffer, row by row
	.rep index, num
		;mov ra10.8dsi, 255; # Alpha / Don't care if framebuffer target
		mov ra10.8csi, block*25; # Red - plus 1 bc mov in vc4asm has a bug where writing 0 ignores packing
		mov ra10.8bsi, index*255/num; # Green
		mov ra10.8asi, 255; # Blue
		nop;
		mov vpm, ra10; # Note: Merged with the first instruction of the next loop!
	.endr
.endm

.macro writeblock, num, offset

	# Setup VPM DMA for writing full VPM contents to target buffer

	# Option 0
#	mov vw_setup, vdw_setup_0(16, num/4, vdr_h32(1, 0, 0));
#	mov vw_setup, vdw_setup_1(10);
#	.lset offset, offset * num

	# Option 1 - Write num*16 Block, one row per QPU, num pixels per row
	mov vw_setup, vdw_setup_0(16, num, dma_v32(0, 0));
	# Calculate target stride
	ldi r0, 0xc0000000; # vdw_setup_1 base
	add r0, r0, tgtStride; # FrameBuffer line length
	# stride should not include already written bytes, so substract them
	mov r1, num*4;
	sub r0, r0, r1;
	# Block mode
	mov r1, 0;
#	mov r1, 0x00010000;
	add vw_setup, r0, r1;

	# Option 2
#	mov vw_setup, vdw_setup_0(32, 16, vdr_h32(1, 0, 0));
#	mov vw_setup, vdw_setup_1(16);

	# Write target buffer adress using offset
	mov r0, offset; # becomes ldi most likely
	add vw_addr, tgtAddr, r0;
	read vw_wait;
.endm

# Repeatedly write blocks of generated colors into target framebuffer
.rep index, 12

	genpattern nvec, index
	writeblock nvec, index * nvec*4*2

.endr

mov.setf irq, nop;

nop; thrend
nop
nop
