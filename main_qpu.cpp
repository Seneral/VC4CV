#include <string>
#include <chrono>
#include <termios.h>
#include <math.h>

#include "fbUtil.h"
#include "qpu_program.h"
#include "qpu_info.h"
#include "gcs.h"

#include "interface/mmal/mmal_encodings.h"
#include "bcm_host.h"
#include "user-vcsm.h" // for vcsm_vc_hdl_from_ptr

#define DEFAULT 0		// source and target butter uniforms only
#define FULL_FRAME 1		// uniforms for full frame processing, e.g. blit
#define TILED 2			// uniforms and setup for tiled frame processing, e.g. blob detection
#define BITMSK 3		// uniforms and full frame processing, with bit mask target, e.g. blob detection

#define CAMERA

struct termios terminalSettings;
static void setConsoleRawMode();

uint32_t camWidth = 1280, camHeight = 720, camFPS = 30;

int main(int argc, char **argv)
{
	// ---- Read arguments ----

	GCS_CameraParams params = {
		.mmalEnc = MMAL_ENCODING_I420,
		.width = (uint16_t)camWidth,
		.height = (uint16_t)camHeight,
		.fps = (uint16_t)camFPS,
		.shutterSpeed = 0,
		.iso = -1
	};
	char codeFile[64];
	uint32_t maxNumFrames = -1; // Enough to run for years
	bool drawToFrameBuffer = false;
	int mode = FULL_FRAME;
	bool enableQPU[12];

	int arg;
	while ((arg = getopt(argc, argv, "c:w:h:f:s:i:m:o:t:dq:")) != -1)
	{
		switch (arg)
		{
			case 'c':
				strncpy(codeFile, optarg, sizeof(codeFile));
				break;
			case 'w':
				params.width = camWidth = std::stoi(optarg);
				break;
			case 'h':
				params.height = camHeight = std::stoi(optarg);
				break;
			case 'f':
				params.fps = camFPS = std::stoi(optarg);
				break;
			case 's':
				params.shutterSpeed = std::stoi(optarg);
				break;
			case 'i':
				params.iso = std::stoi(optarg);
				break;
			case 'm':
				if (strcmp(optarg, "full") == 0) mode = FULL_FRAME;
				else if (strcmp(optarg, "tiled") == 0) mode = TILED;
				else if (strcmp(optarg, "bitmsk") == 0) mode = BITMSK;
				else mode = DEFAULT;
				break;
			case 't':
				maxNumFrames = std::stoi(optarg);
				break;
			case 'd':
				drawToFrameBuffer = true;
				break;
			case 'q':
				for (int i = 0; i < 12 && i < strlen(optarg); i++)
				{
					enableQPU[i] = optarg[i] == '1';
				}
			default:
				printf("Usage: %s -c codefile [-w width] [-h height] [-f fps] [-s shutter-speed-ns] [-i iso] [-m mode (full, tiled, bitmsk)] [-d display-to-fb] [-t max-num-frames]\n", argv[0]);
				break;
		}
	}
	if (optind < argc - 1)
		printf("Usage: %s -c codefile [-w width] [-h height] [-f fps] [-s shutter-speed-ns] [-i iso] [-m mode (full, tiled, bitmsk)] [-d display-to-fb] [-t max-num-frames]\n", argv[0]);

	// ---- Init ----

	// Core QPU structures
	QPU_BASE base;
	QPU_PROGRAM program;
	QPU_BUFFER targetBuffer;
	QPU_BUFFER bitmskBuffer;
	// QPU Debugging
	QPU_PerformanceState perfState;
	QPU_HWConfiguration hwConfig;
	QPU_UserProgramInfo upInfo;
	// MMAL Camera
	GCS *gcs;
	// Camera emulation buffers
	const int emulBufCnt = 4;
	QPU_BUFFER camEmulBuf[emulBufCnt];
	// Frame Counter
	auto startTime = std::chrono::high_resolution_clock::now();
	auto lastTime = startTime;
	int lastFrames = 0, numFrames = 0;

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

	uint32_t tgtBufferPtr, tgtStride;
	uint32_t lineWidth = camWidth, lineCount = camHeight;
	int fbfd = 0;
	struct fb_var_screeninfo orig_vinfo;
	struct fb_var_screeninfo vinfo;
	struct fb_fix_screeninfo finfo;
	if (drawToFrameBuffer)
	{ // Get frame buffer information
		fbfd = setupFrameBuffer(&orig_vinfo, &vinfo, &finfo, true);
		if (!fbfd) drawToFrameBuffer = false;
		else
		{
			tgtStride = finfo.line_length;
			tgtBufferPtr = finfo.smem_start;
			lineWidth = std::min(camWidth, vinfo.xres);
			lineCount = std::min(camHeight, vinfo.yres);
		}
	}
	if (!drawToFrameBuffer)
	{ // Allocate buffer to render into
		qpu_allocBuffer(&targetBuffer, &base, camWidth*camHeight*4, 4096);
		tgtStride = camWidth*4;
		tgtBufferPtr = targetBuffer.ptr.vc;
	}
	if (mode == BITMSK)
	{ // Set up bit target, one bit per pixel
		// Width and height must be multiple of 32 and 16 respectively
		lineWidth = (uint32_t)std::floor((float)camWidth/8/4)*8*4;
		lineCount = (uint32_t)std::floor((float)camHeight/16)*16;
		qpu_allocBuffer(&bitmskBuffer, &base, lineWidth/8*lineCount, 4096);
		tgtStride = lineWidth/8;
		tgtBufferPtr = bitmskBuffer.ptr.vc;
	}

	// ---- Generate tiling setup ----

	// Split image in columns of 8x16 pixels assigned to one QPU each.
	// Split vertically until most or all QPUs are used
	int padding = 0; // padding on both sides of the image - set up for 5x5 kernel (2 on each side)
	int numTileCols = (int)floor((lineWidth-padding) / 8.0); // Num of 8px Tiles in a row with padding
	int numTileRows = (int)floor((lineCount-padding) / 8.0); // Num of 8px Tiles in a col with padding
	int numProgCols = (int)floor(numTileCols / 16.0); // Number of instances required (QPU is 16-way)
	int droppedTileCols = numTileCols - numProgCols * 16; // Some are dropped for maximum performance, extra effort is not worth it
	int splitCols = 1;
/*	while (numProgCols * (splitCols+1) <= 12)
	{ // Split columns among QPUs to minimize the number of idle QPUs
		splitCols++;
	}*/
	int numInstances = numProgCols * splitCols;
	if (mode == TILED)
		printf("SETUP: %d instances processing 1/%d columns each, covering %dx%d tiles, plus %d columns dropped\n",
			numInstances, splitCols, numProgCols*16, numTileRows, droppedTileCols);
	else numInstances = 1;

	// ---- Setup program ----

	// Setup program with specified progmem sizes
	QPU_PROGMEM progmemSetup {
		.codeSize = qpu_getCodeSize(codeFile), //4096*4;
		.uniformsSize =
			(mode==FULL_FRAME || mode==BITMSK)? 6 :
			(mode==TILED? (uint32_t)numInstances*6 : 2),
		.messageSize = 0 // 2 if qpu_executeProgramMailbox is used, instead of qpu_executeProgramDirect
	};
	qpu_initProgram(&program, &base, progmemSetup);
	qpu_loadProgramCode(&program, codeFile);

	// ---- Setup progmem ----

	// Set up uniforms of the QPU program
	qpu_lockBuffer(&program.progmem_buffer);
	if (mode == DEFAULT)
	{ // Simple default program with no additional requirements
		program.progmem.uniforms.arm.uptr[0] = 0; // Enter source pointer each frame
		program.progmem.uniforms.arm.uptr[1] = tgtBufferPtr;
	}
	else if (mode == FULL_FRAME || mode == BITMSK)
	{ // Set up one program to handle the full frame
		program.progmem.uniforms.arm.uptr[0] = 0; // Enter source pointer each frame
		program.progmem.uniforms.arm.uptr[1] = tgtBufferPtr;
		program.progmem.uniforms.arm.uptr[2] = camWidth; // Source stride
		program.progmem.uniforms.arm.uptr[3] = tgtStride;
		program.progmem.uniforms.arm.uptr[4] = lineWidth;
		program.progmem.uniforms.arm.uptr[5] = lineCount;
	}
	else if (mode == TILED)
	{ // Set up each program instance with their column
		for (int c = 0; c < numProgCols; c++)
		{
			for (int r = 0; r < splitCols; r++)
			{
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 0] = 0; // Enter source pointer each frame
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 1] = tgtBufferPtr + c*4*8*16 + r*lineCount/splitCols*tgtStride;
				program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 2] = camWidth; // Source stride
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

	// Debug QPU Hardware
	qpu_debugHW(&base);
	// VPM memory reservation
	base.peripherals[V3D_VPMBASE] = 16; // times 4 to get number of vectors; Default: 8 (32/4), Max: 16 (64/4)
	qpu_getHWConfiguration(&hwConfig, &base);
	qpu_getUserProgramInfo(&upInfo, &base);
	printf("Reserved %d / %d vectors of VPM memory for user programs!\n", upInfo.VPMURSV_V, hwConfig.VPMSZ_V);
	// QPU scheduler reservation
//	for (int i = 0; i < 12; i++) // Reset all QPUs to be freely sheduled
//		qpu_setReservationSetting(&base, i, 0b0000);

	for (int i = 0; i < 12; i++) // Disable ALL QPUs
		qpu_setReservationSetting(&base, i, 0b0001);
	for (int i = 0; i < 12; i++) // Enable only QPUs selected as parameter
		qpu_setReservationSetting(&base, i, enableQPU[i]? 0b1110 : 0b1111);
//	qpu_setReservationSetting(&base, 1, 0b1110); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 9, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 2, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 1, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 4, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 5, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 1, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 3, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 8, 0b0000); // Enable one QPU for user programs
//	qpu_setReservationSetting(&base, 5, 0b0000); // Enable one QPU for user programs

//	for (int i = 0; i < 12; i++) // Reserve ALL QPUs for user programs
//		qpu_setReservationSetting(&base, i, 0b0000);

//	for (int i = 0; i < numInstances; i++) // Reserve used QPUs for user programs
//		qpu_setReservationSetting(&base, i, 0b0000);
//	for (int i = numInstances; i < 12; i++) // Exempt unused QPUs from user programs
//		qpu_setReservationSetting(&base, i, 0b0111);
	qpu_logReservationSettings(&base);
	// Setup performance monitoring
	qpu_setupPerformanceCounters(&base, &perfState);

	// ---- Setup Camera ----

	// Create GPU camera stream (MMAL camera)
#ifdef CAMERA
	gcs = gcs_create(&params);
	if (gcs == NULL)
	{
		printf("Failed to greate GCS! \n");
		goto error_gcs;
	}
	gcs_start(gcs);
	printf("-- Camera Stream started --\n");
#else
	for (int i = 0; i < emulBufCnt; i++)
	{
		qpu_allocBuffer(&camEmulBuf[i], &base, camWidth*camHeight*3, 4096); // Emulating full YUV frame
		qpu_lockBuffer(&camEmulBuf[i]);
		uint8_t *YUVFrameData = (uint8_t*)camEmulBuf[i].ptr.arm.vptr;
		for (int x = 0; x < camWidth; x++)
		{
			for (int y = 0; y < camHeight; y++)
			{
				// Write test data in Y component (UV are after this, but are not used)
				YUVFrameData[y*camWidth + x] = ((x+camWidth/(i+1))*255/camWidth)%256 + ((y+camHeight/(i+1))*255/camHeight)%256;
			}
		}
		qpu_unlockBuffer(&camEmulBuf[i]);
	}
#endif

	// ---- Start Loop ----

	// For non-blocking input even over ssh
	setConsoleRawMode();

	lastTime = startTime = std::chrono::high_resolution_clock::now();
	while (numFrames < maxNumFrames)
	{
#ifdef CAMERA
		// Get most recent MMAL buffer from camera
		void *cameraBufferHeader = gcs_requestFrameBuffer(gcs);
		if (!cameraBufferHeader) printf("GCS returned NULL frame! \n");
		else
#else
		// Emulate framerate
		usleep(std::max(0,(int)(1.0f/camFPS*1000*1000)-4000));
#endif
		{
			// ---- Camera Frame Access ----

#ifdef CAMERA
			// Source: https://www.raspberrypi.org/forums/viewtopic.php?f=43&t=167652
			// Get buffer data from opaque buffer handle
			void *cameraBuffer = gcs_getFrameBufferData(cameraBufferHeader);
			// Get VCSM Handle of frameBuffer (works only if zero-copy is enabled, so buffer is in VCSM)
			uint32_t cameraBufferHandle = vcsm_vc_hdl_from_ptr(cameraBuffer);
			// Lock VCSM buffer to get VC-space address
			uint32_t cameraBufferPtr = mem_lock(base.mb, cameraBufferHandle);
#else
			qpu_lockBuffer(&camEmulBuf[numFrames%emulBufCnt]);
			uint32_t cameraBufferPtr = camEmulBuf[numFrames%emulBufCnt].ptr.vc;
#endif

			// ---- Uniform preparation ----

			// Set source buffer pointer in progmem uniforms
			qpu_lockBuffer(&program.progmem_buffer);
			if (mode == TILED)
			{ // Set up individual source pointer for each program instance
				for (int c = 0; c < numProgCols; c++)
					for (int r = 0; r < splitCols; r++)
						program.progmem.uniforms.arm.uptr[c*splitCols*6 + r*6 + 0] = cameraBufferPtr + c*8*16 + r*lineCount/splitCols*camWidth;
			}
			else
			{
				program.progmem.uniforms.arm.uptr[0] = cameraBufferPtr;
			}
			qpu_unlockBuffer(&program.progmem_buffer);

			// ---- Program execution ----

/*			if (mode == BITMSK)
				qpu_lockBuffer(&bitmskBuffer);
			else if (!drawToFrameBuffer)
				qpu_lockBuffer(&targetBuffer);
*/
			// Execute programs
			int result;
			if (mode == TILED)
			{ // Execute numInstances programs each with their own set of uniforms
				result = qpu_executeProgramDirect(&program, &base, numInstances, 6, 6, &perfState);
			}
			else
			{ // Execute single program handling full frame
				result = qpu_executeProgramDirect(&program, &base, 1, program.progmem.uniformsSize, 0, &perfState);
			}

			// Log errors occurred during execution
			qpu_logErrors(&base);

#ifdef CAMERA
			// Unlock VCSM buffer (no need to keep locked, VC-space adress won't change)
			mem_unlock(base.mb, cameraBufferHandle);
			// Return camera buffer to camera
			gcs_returnFrameBuffer(gcs);
#else
			qpu_unlockBuffer(&camEmulBuf[numFrames%emulBufCnt]);
#endif

/*			// Unlock target buffers
			if (mode == BITMSK)
				qpu_unlockBuffer(&bitmskBuffer);
			else if (!drawToFrameBuffer)
				qpu_unlockBuffer(&targetBuffer);
*/
			if (result != 0)
				break;


			// ---- Debugging and Statistics ----

			numFrames++;
			if (numFrames % 100 == 0)
			{ // Frames per second
				auto currentTime = std::chrono::high_resolution_clock::now();
				int elapsedMS = std::chrono::duration_cast<std::chrono::milliseconds>(currentTime - lastTime).count();
				float elapsedS = (float)elapsedMS / 1000;
				lastTime = currentTime;
				int frames = (numFrames - lastFrames);
				lastFrames = numFrames;
				float fps = frames / elapsedS;
				printf("%d frames over %.2fs (%.1ffps)! \n", frames, elapsedS, fps);
			}
			if (numFrames % 10 == 0)
			{ // Detailed QPU performance gathering (every 10th frame to handle QPU performance register overflows)
				qpu_updatePerformance(&base, &perfState);
			}
			if (numFrames % 100 == 0 && numFrames <= 500)
			{ // Detailed QPU performance report
				printf("QPU Performance over past 100 frames:\n");
				qpu_logPerformance(&perfState);
			}
			if (numFrames % 500 == 0 && numFrames > 500)
			{ // Detailed QPU performance report
				printf("QPU Performance over past 500 frames:\n");
				qpu_logPerformance(&perfState);
			}

			// ---- Framebuffer debugging ----

			if (drawToFrameBuffer)
			{ // Manual access to framebuffer
				void *fbp = lock_fb(fbfd, finfo.smem_len);
				if ((int)fbp == -1) {
					printf("Failed to mmap.\n");
				}
				else
				{
					if (mode == BITMSK && (numFrames % 1) == 0)
					{ // Copy custom bitmap from buffer to screen for debugging
						qpu_lockBuffer(&bitmskBuffer);
						uint8_t *ptr = (uint8_t*)bitmskBuffer.ptr.arm.uptr;
						for (int y = 0; y < lineCount; y++)
						{
							for (int x = 0; x < lineWidth/8; x++)
							{
								uint8_t msk = *(ptr + y*tgtStride + x);
								uint32_t *px = (uint32_t*)((uint8_t*)fbp + (y*finfo.line_length + x * 8 * vinfo.bits_per_pixel/8));
								for (int i = 0; i < 8; i++)
								{ // Colors are in ARGB order, to be precise A8RGB565
									if ((msk >> i) & 1) px[i] = 0xFFFFFFFF;
									else px[i] = 0xFF000000;
								}
							}
						}
						qpu_unlockBuffer(&bitmskBuffer);
					}
					unlock_fb(fbp, finfo.smem_len);
				}
			}
		}

		// ---- Input ----

//		if (numFrames % 10 == 0)
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

#ifdef CAMERA
	gcs_stop(gcs);
	gcs_destroy(gcs);
	printf("-- Camera Stream stopped --\n");
#else
	for (int i = 0; i < emulBufCnt; i++)
		qpu_releaseBuffer(&camEmulBuf[i]);
#endif


error_gcs:

	// Disable QPU
	if (qpu_enable(base.mb, 0))
		printf("-- QPU Disable failed --\n");
	else
		printf("-- QPU Disabled --\n");

	for (int i = 0; i < 12; i++) // Reset all QPUs to be freely sheduled
		qpu_setReservationSetting(&base, i, 0b0000);

error_qpu:

	if (drawToFrameBuffer)
		close(fbfd);
	else
		qpu_releaseBuffer(&targetBuffer);

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
