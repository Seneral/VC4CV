#include <string>
#include <chrono>
#include <termios.h>
#include <math.h>
#include <algorithm>

#include "fbUtil.h"
#include "qpu_program.h"
#include "qpu_info.h"
#include "gcs.h"

#include "interface/mmal/mmal_encodings.h"
#include "bcm_host.h"
#include "user-vcsm.h" // for vcsm_vc_hdl_from_ptr

struct termios terminalSettings;
static void setConsoleRawMode();

int main(int argc, char **argv)
{
	// ---- Read arguments ----

	GCS_CameraParams params = {
		.mmalEnc = MMAL_ENCODING_I420,
		.width = 640,
		.height = 480,
		.fps = 10,
		.shutterSpeed = 5000,
		.iso = 60000,
		.disableEXP = true,
		.disableAWB = true,
		.disableISPBlocks = 0 // https://www.raspberrypi.org/forums/viewtopic.php?f=43&t=175711
//			  (1<<2) // Black Level Compensation
//			| (1<<3) // Lens Shading
//			| (1<<5) // White Balance Gain
//			| (1<<7) // Defective Pixel Correction
//			| (1<<9) // Crosstalk
//			| (1<<18) // Gamma
//			| (1<<22) // Sharpening
//			| (1<<24) // Some Color Conversion
	};
	char codeFile[64];
	uint32_t numFrames = 0;
	bool enableQPU[12] = { 1,1,1,1, 1,1,1,1, 1,1,1,1 };

	int arg;
	while ((arg = getopt(argc, argv, "c:w:h:f:s:i:m:b:o:t:da:e:q:")) != -1)
	{
		switch (arg)
		{
			case 'c':
				strncpy(codeFile, optarg, sizeof(codeFile));
				break;
			case 'w':
				params.width = std::stoi(optarg);
				break;
			case 'h':
				params.height = std::stoi(optarg);
				break;
			case 'f':
				params.fps = std::stoi(optarg);
				break;
			case 'q':
				for (int i = 0; i < 12 && i < strlen(optarg); i++)
					enableQPU[i] = optarg[i] == '1';
				break;
			default:
				printf("Usage: %s -c codefile [-w width] [-h height] [-f fps] [-s shutter-speed-ns] [-i iso] [-m mode (full, tiled, bitmsk)] [-d display-to-fb] [-t max-num-frames]\n", argv[0]);
				break;
		}
	}

	// ---- Init ----

	// Core QPU structures
	QPU_BASE base;
	QPU_PROGRAM program;
	QPU_BUFFER bitmskBuffer;
	// QPU Debugging
	QPU_PerformanceState perfState;
	// MMAL Camera
	GCS *gcs;

	// Init BCM Host
	bcm_host_init();

	// Init QPU Base (basic information to work with QPU)
	int ret = qpu_initBase(&base);
	if (ret != 0)
	{
		printf("Failed to init qpu base! %d \n", ret);
		return ret;
	}

	// ---- Setup target buffer ----

	// Width and height must be multiple of 32 and 16 respectively
	uint32_t lineWidth = (uint32_t)std::floor((float)params.width/8/4)*8*4;
	uint32_t lineCount = (uint32_t)std::floor((float)params.height/16)*16;
	// Allocate buffer
	qpu_allocBuffer(&bitmskBuffer, &base, lineWidth/8*lineCount, 4096);
	uint32_t tgtStride = lineWidth/8;
	uint32_t tgtBufferPtr = bitmskBuffer.ptr.vc;

	// ---- Generate tiling setup ----

	// Split image in columns of 8x16 pixels assigned to one QPU each.
	// Split vertically until most or all QPUs are used
	int padding = 0; // padding on both sides of the image - set up for 5x5 kernel (2 on each side)
	int numTileCols = (int)floor((lineWidth-padding) / 8.0); // Num of 8px Tiles in a row with padding
	int numTileRows = (int)floor((lineCount-padding) / 8.0); // Num of 8px Tiles in a col with padding
	int numProgCols = (int)floor(numTileCols / 16.0); // Number of instances required (QPU is 16-way)
	int droppedTileCols = numTileCols - numProgCols * 16; // Some are dropped for maximum performance, extra effort is not worth it
	int splitCols = 1;
	while (numProgCols * (splitCols+1) <= 12)
	{ // Split columns among QPUs to minimize the number of idle QPUs
		splitCols++;
	}
	int numInstances = numProgCols * splitCols;
	printf("SETUP: %d instances processing 1/%d columns each, covering %dx%d tiles, plus %d columns dropped\n",
		numInstances, splitCols, numProgCols*16, numTileRows, droppedTileCols);

	// ---- Setup program ----

	// Setup program with specified progmem sizes
	QPU_PROGMEM progmemSetup {
		.codeSize = qpu_getCodeSize(codeFile), //4096*4;
		.uniformsSize = (uint32_t)numInstances*6,
		.messageSize = 0 // 2 if qpu_executeProgramMailbox is used, instead of qpu_executeProgramDirect
	};
	qpu_initProgram(&program, &base, progmemSetup);
	qpu_loadProgramCode(&program, codeFile);

	// ---- Setup progmem ----

	// Set up uniforms of the QPU program
	qpu_lockBuffer(&program.progmem_buffer);
	{ // Set up each program instance with their column
		for (int c = 0; c < numProgCols; c++)
		{
			for (int r = 0; r < splitCols; r++)
			{
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 0] = 0; // Enter source pointer each frame
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 1] = tgtBufferPtr + c*16*16 + r*lineCount/splitCols*tgtStride;
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 2] = params.width;
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 3] = tgtStride;
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 4] = 8*16; // 16 elements working on 8-pixel columns each
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 5] = lineCount / splitCols;
			}
		}
	}
	qpu_unlockBuffer(&program.progmem_buffer);

	// ---- Setup QPU ----

	// Enable QPU
	if (qpu_enable(base.mb, 1)) {
		printf("QPU enable failed!\n");
		goto error_qpu;
	}
	printf("-- QPU Enabled --\n");

	// VPM memory reservation
	base.peripherals[V3D_VPMBASE] = 16; // times 4 to get number of vectors; Default: 8 (32/4), Max: 16 (64/4)
	// QPU scheduler reservation
	for (int i = 0; i < 12; i++) // Enable only QPUs selected as parameter
		qpu_setReservationSetting(&base, i, enableQPU[i]? 0b1110 : 0b1111);
	qpu_logReservationSettings(&base);
	// Setup performance monitoring
	qpu_setupPerformanceCounters(&base, &perfState);

	// ---- Setup Camera ----

	// Create GPU camera stream (MMAL camera)
	gcs = gcs_create(&params);
	if (gcs == NULL)
	{
		printf("Failed to greate GCS! \n");
		goto error_gcs;
	}
	gcs_start(gcs);
	printf("-- Camera Stream started --\n");

	// ---- Start Loop ----

	// For non-blocking input even over ssh
	setConsoleRawMode();

	while (1)
	{
		// Get most recent MMAL buffer from camera
		void *cameraBufferHeader = gcs_requestFrameBuffer(gcs);
		if (!cameraBufferHeader) printf("GCS returned NULL frame! \n");
		else
		{
			// ---- Camera Frame Access ----

			// Get buffer data from opaque buffer handle
			void *cameraBuffer = gcs_getFrameBufferData(cameraBufferHeader);
			// Source: https://www.raspberrypi.org/forums/viewtopic.php?f=43&t=167652
			// Get VCSM Handle of frameBuffer (works only if zero-copy is enabled, so buffer is in VCSM)
			uint32_t cameraBufferHandle = vcsm_vc_hdl_from_ptr(cameraBuffer);
			uint32_t cameraBufferPtr = mem_lock(base.mb, cameraBufferHandle);

			// ---- Uniform preparation ----

			// Set source buffer pointer in progmem uniforms
			qpu_lockBuffer(&program.progmem_buffer);
			{ // Set up individual source pointer for each program instance
				for (int c = 0; c < numProgCols; c++)
					for (int r = 0; r < splitCols; r++)
						program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 0] = cameraBufferPtr + c*8*16 + r*lineCount/splitCols*params.width;
			}
			qpu_unlockBuffer(&program.progmem_buffer);

			// ---- Program execution ----

			qpu_lockBuffer(&bitmskBuffer);

			// Execute numInstances programs each with their own set of uniforms
			int result = qpu_executeProgramDirect(&program, &base, numInstances, 6, 6, &perfState);

			// Log errors occurred during execution
			qpu_logErrors(&base);

			// Unlock VCSM buffer (no need to keep locked, VC-space adress won't change)
			mem_unlock(base.mb, cameraBufferHandle);
			// Return camera buffer to camera
			gcs_returnFrameBuffer(gcs);

			// Unlock target buffers
			qpu_unlockBuffer(&bitmskBuffer);

			if (result != 0)
			{
				printf("Encountered an error after %d frames!\n", numFrames);
				break;
			}

			// ---- Debugging and Statistics ----

			numFrames++;
			if (numFrames % 1 == 0)
			{ // Detailed QPU performance gathering
				qpu_updatePerformance(&base, &perfState);
			}
			if (numFrames % 10 == 0)
			{ // Detailed QPU performance report
				printf("QPU Performance over past 10 frames:\n");
				qpu_logPerformance(&perfState);
			}
		}

		// ---- Input ----

		{ // Check for keys
			char cin;
			if (read(STDIN_FILENO, &cin, 1) == 1)
			{
				if (iscntrl(cin)) printf("%d", cin);
				else if (cin == 'q') break;
				else printf("%c", cin);
			}
		}
	}

	gcs_stop(gcs);
	gcs_destroy(gcs);
	printf("-- Camera Stream stopped --\n");

error_gcs:

	// Disable QPU
	if (qpu_enable(base.mb, 0))
		printf("-- QPU Disable failed --\n");
	else
		printf("-- QPU Disabled --\n");

	for (int i = 0; i < 12; i++) // Reset all QPUs to be freely sheduled
		qpu_setReservationSetting(&base, i, 0b0000);

error_qpu:

	qpu_releaseBuffer(&bitmskBuffer);

	qpu_destroyProgram(&program);

	qpu_destroyBase(&base);

	return EXIT_SUCCESS;
}

/* Sets console to raw mode which among others allows for non-blocking input, even over SSH */
static void setConsoleRawMode()
{
	tcgetattr(STDIN_FILENO, &terminalSettings);
	struct termios termSet = terminalSettings;
	atexit([]{ // Reset at exit
		tcsetattr(STDIN_FILENO, TCSAFLUSH, &terminalSettings);
	});
	termSet.c_lflag &= ~ECHO;
	termSet.c_lflag &= ~ICANON;
	termSet.c_cc[VMIN] = 0;
	termSet.c_cc[VTIME] = 0;
	tcsetattr(STDIN_FILENO, TCSAFLUSH, &termSet);
}
