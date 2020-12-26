# Commands

### Setup
```
mkdir build
cd build
cmake ..
```

NOTE: Terminate all examples with Q (soft) or Ctrl-C (hard)

### GL examples

#### Building
```
make gl
```

#### Simple camera blit
```
./GLCV -c Y -w 640 -h 480 -f 40
./GLCV -c YUV -w 640 -h 480 -f 40
./GLCV -c RGB -w 640 -h 480 -f 40
```

#### Blob detection: Need some LEDs or a Flashlight at hand
```
./GLBlobs -c Y -w 640 -h 480 -f 45 -s 100
./GLBlobs -c Y -w 960 -h 540 -f 30 -s 100
./GLBlobs -c Y -w 1280 -h 720 -f 20 -s 100
./GLBlobs -c Y -w 1640 -h 1232 -f 12 -s 100
```

### QPU Examples

#### Building
Important: REQUIRES vc4asm to be installed!
```
make qpu
```
Notes on the properties: Programs code files are selected with -c, but each requires special properties to be executed properly. <br>
-m specifies the mode (full or tiled), -b the target buffer (RGB, bitmsk for qpu_mask_full, blkmsk for qpu_mask_tiled_1x*, bilmsk for qpu_mask/blob_tiled_5x5*) <br>
-d specifies the display option - this switches to the framebuffer for RGB target and copies the bitmasks from all other target buffers to the framebuffer using the CPU otherwise - that means, -d is very slow for the mask/blob examples, and is done only every 10th frame. <br>
-q allows you to select which QPU cores are reserved for the program using a {0,1}-string of length 12 <br>
-w, -h, -f control the basic camera parameters, -s, -i control shutter speed and iso value, -e, -a disable automatic exposure and auto white balance respectively
There are some more specific ones.

#### First test of VPM
```
sudo ./QPUCV -c qpu_fb_pattern.bin -m full -b RGB -d
```

#### Full-Frame programs
Debug and camera blit using simple fullscreen mode (a single QPU core processing the whole frame)
```
sudo ./QPUCV -c qpu_debug_full.bin -m full -b RGB -w 640 -h 480 -f 40 -d
sudo ./QPUCV -c qpu_blit_full.bin -m full -b RGB -w 640 -h 480 -f 40 -d
```
A simple threshold filter (0.5) to custom 1-bit buffer in fullscreen mode (CPU then blits that buffer to framebuffer)
```
sudo ./QPUCV -c qpu_mask_full.bin -m full -b bitmsk -w 640 -h 480 -f 30 -d
sudo ./QPUCV -c qpu_mask_full.bin -m full -b bitmsk -w 640 -h 480 -f 90
```

#### Tiled programs
Debug tiled mode (multiple QPUs working on tiles of the screen)
```
sudo ./QPUCV -c qpu_debug_tiled.bin -m tiled -b RGB -w 640 -h 480 -f 40 -d
```
The following have been tested on a 3 B+, but stall or even crash on a Zero, if real camera frames are used:
```
sudo ./QPUCV -c qpu_blit_tiled.bin -m tiled -b RGB -w 640 -h 480 -f 30 -d
sudo ./QPUCV -c qpu_mask_tiled_1x1.bin -m tiled -b blkmsk -w 640 -h 480 -f 30 -d
sudo ./QPUCV -c qpu_mask_tiled_5x5_blobwrite.bin -m tiled -b bilmsk -l 20 -w 640 -h 480 -f 30 -q 100000000000 -d
```
However, by commenting the define USE_CAMERA in main_qpu.cpp, and thus using emulated camera frames, they will work just fine on a Zero as well. See #1 for more information. <br>
Also note, that the last command seems to have problems writing correct results using the VPM on some QPU cores (namely 4th, 7th and 10th) even on the 3 B+. This is still being investigated.

#### Higher resolutions
All QPU commands also work fine in higher resolutions, but sometimes crop the image (can be addressed later). Also if you target 1640x1232, use 1632x1232, else the results will be wrong (still being investigated). Framerates can be set higher as well, most commands easily surpass the rate at which the camera can supply frames though, even using a single QPU core, so if you use emulated frames (comment RUN_CAMERA and USE_CAMERA) it can freely run (some programs, like the 1x1_optimized threshold shader, reaching up to 3000fps @ 480p).
