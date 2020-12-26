# VC4CV
VideoCore IV Computer Vision framework and examples - GL- and QPU-based

This repository aims to make low-level CV on the RaspberryPis /w VideoCore IV (e.g. Zero) more accessible by providing examples and a slim framework to build on. It only covers real-time camera frame processing using both OpenGL shaders and QPU assembly programs.

## Test Commands:
Reduced testing case further

Left only a single program that works on the 3 B+ just fine, but stalls on the Zero IF the buffers fed to the program are camera frames.
The programs simply uses the TMU to read the buffer, but then discards the values.
Options to the main program include -t to set the amount of programs the buffer is split among, and -m to toggle the way the programs are distributed among the buffer (continuous or interleaved).
And -e, which will replace the camera buffer with a normal VCSM buffer.

Observations:
`sudo ./main -c qpu_tmu_read.asm -e`              And any combination of other parameters work fine on the Zero
`sudo ./main -c qpu_tmu_read.asm`                 And any combination without -e stall immediately (41/45 instructions in) or after a few frames

Note that -e does NOT stop the camera from running and supplying frames, it just replaces those with emulated buffers before feeding them to the program.


### For whom is this?
If you need time-critical CV tasks but are limited to the RaspberryPi Zero, you might want to go the extra mile and do as much of your CV pipeline as you can on the hardware, the VideoCore IV. This is only really a good choice if you need better performance than what OpenCV offers you, at all costs. If you don't have space, power or cost limitations, a more powerful RasperryPi or a Tinkerboard is probably way easier and better.

### Why both GL and QPU?
The QPU is the parallel vector processor in the VideoCore IV chip. The OpenGL ES 2.0 implementation uses the QPU hardware, so by using the GL path you can use the QPU without getting into it's details. However, the overhead of the GL implementation is really quite a lot. If you need the best performance, you can skip the GL layer and program the QPU directly in assembly code. <br>
The GL way is easier to implement and, given examples, relatively painless. However, your framerate is pretty much capped at 60fps and processing capabilities are limited. Your processing time is measured in tens of milliseconds when dealing with high resolutions (1640x1232) for any shader that is a bit more complex. <br>
The QPU way is a lot more involved, requires potentially weeks of research (maybe less if my examples serve their intended purpose), and errors are guaranteed. However, by directly using the QPUs instruction set, you can optimize your algorithm to fit the QPUs pecularities and ultimately achieve a much better framerate. Even with higher resolutions or more complex shaders the frame time is generally measured in milliseconds.

### Examples?
There are some clean examples on how to use both the GL and QPU way. Look into Commands.txt for example commands to invoke these examples. To compile the qpu_programs, you first need to make and install [vc4asm](https://github.com/maazl/vc4asm/).
#### GL
1. GLCV (main_gl): Simple program executing only a simple shader blitting the camera frame to the screen. Supports all color spaces (Y,YUV,RGB), and scales the frame to fit the screen.
2. GLBlobs (main_gl_blobs): Executes a two-pass blob-detection shader on the image, resulting in a binary full-resolution image. Also includes a simple CPU-side connected component labeling algorithm (fast, but does not merge close-by components, so large blobs might have smaller satellite blobs around it).
#### QPU
There is currently only one program, main_qpu, which is parameterized to be able to execute all the provided qpu_programs (those need to be compiled seperately with make qpu). Look into each qpu_program file for details (especially take note of which -mode parameter each program requires!):
1. qpu_fb_pattern: start here to experiment with the VPM (writing/reading blocks of data to/from memory in different ways) and writes it into the framebuffer to easily visualize 
2. qpu_debug_full: Debugs the access pattern of the single-program fullscreen shader. Shows in which order parts of the screen are handled in the shader.
3. qpu_blit_full: Same fullscreen access structure as above, but actually accesses the camera frame using the TMU and writes it to the framebuffer.
4. qpu_mask_full: Same fullscreen access structure as above, but executes a simple threshold effect on the camera frame before writing to the framebuffer. Currently a simple per-pixel 0.5 threshold value, including neighbouring pixels is not recommended in the full-screen shader.
5. qpu_debug_tiled: Debugs the access pattern of the multi-program tiled shader. Shows in which order parts of the screen are handled in the shader.
6. qpu_blit_tiled: Same tiled access structure as above, but actually accesses the camera frame using the TMU and writes it to the framebuffer (Warning: this does not work currently! VPM access and TMU interferes in a way which causes the QPU to crash, overwrite the whole physical memory and thus causes the whole RaspberryPi to crash. No permanent damage to the system, but power cut is required)
7. qpu_mask_tiled: Planned to create once qpu_blit_tiled works. Much higher performance expected.
