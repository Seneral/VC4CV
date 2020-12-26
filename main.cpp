#include <string>
#include <chrono>
#include <termios.h>
#include <math.h>
#include <algorithm>

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
	bool emulatedBuffer = false;
	int taskCount = 1;
	bool continuousMemory = false;

	int arg;
	while ((arg = getopt(argc, argv, "c:w:h:f:q:emt:")) != -1)
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
			case 'e':
				emulatedBuffer = true;
				break;
			case 't':
				taskCount = std::stoi(optarg);
				break;
			case 'm':
				continuousMemory = true;
				break;
			default:
				printf("Usage: %s -c codefile [-w width] [-h height] [-f fps] [-e toggle emulated buffer] [-m toggle continuous memory] [-t task count] [-q enabled qpu cores]\n", argv[0]);
				break;
		}
	}

	// ---- Init ----

	// Core QPU structures
	QPU_BASE base;
	QPU_PROGRAM program;
	QPU_BUFFER bitmskBuffer;
	QPU_BUFFER camEmulBuffer;
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

	// ---- Setup program ----

	// Setup program with specified progmem sizes
	const int unifCount = 3;
	QPU_PROGMEM progmemSetup {
		.codeSize = qpu_getCodeSize(codeFile), //4096*4;
		.uniformsSize = (uint32_t)taskCount*unifCount,
		.messageSize = 0 // 2 if qpu_executeProgramMailbox is used, instead of qpu_executeProgramDirect
	};
	qpu_initProgram(&program, &base, progmemSetup);
	qpu_loadProgramCode(&program, codeFile);

	// ---- Setup progmem ----

	uint32_t sourceSize = params.width*params.height * 3;
	uint32_t segmentSize = 16*4;
	uint32_t segmentCount = sourceSize/taskCount/segmentSize; // In iterations
	uint32_t srcStride, srcOffset;
	if (continuousMemory)
	{ // Task memory is one continuous block
		srcStride = segmentSize;
		srcOffset = segmentSize * segmentCount;
	}
	else
	{ // Task memory is interleaved with other tasks
		srcStride = segmentSize * taskCount;
		srcOffset = segmentSize;
	}

	// Set up uniforms of the QPU program
	qpu_lockBuffer(&program.progmem_buffer);
	for (int t = 0; t < taskCount; t++)
	{
		program.progmem.uniforms.arm.uptr[t*unifCount + 0] = 0; // Enter source pointer each frame
		program.progmem.uniforms.arm.uptr[t*unifCount + 1] = srcStride;
		program.progmem.uniforms.arm.uptr[t*unifCount + 2] = segmentCount;
	}
	qpu_unlockBuffer(&program.progmem_buffer);

	// ---- Setup QPU ----

	// Enable QPU
	if (qpu_enable(base.mb, 1)) {
		printf("QPU enable failed!\n");
		goto error_qpu;
	}
	printf("-- QPU Enabled --\n");

	// QPU scheduler reservation
	for (int i = 0; i < 12; i++) // Enable only QPUs selected as parameter
		qpu_setReservationSetting(&base, i, enableQPU[i]? 0b1110 : 0b1111);
	qpu_logReservationSettings(&base);
	// Setup performance monitoring
	qpu_setupPerformanceCounters(&base, &perfState);

	// ---- Setup Camera ----

	if (emulatedBuffer)
	{
		qpu_allocBuffer(&camEmulBuffer, &base, params.width*params.height*3, 4096); // Emulating full YUV frame
		qpu_lockBuffer(&camEmulBuffer);
		qpu_unlockBuffer(&camEmulBuffer);
	}
//	else // Doesn't actually matter if the camera is running, so even if we emulate the camera buffers, we'll let the camera run
	{
		// Create GPU camera stream (MMAL camera)
		gcs = gcs_create(&params);
		if (gcs == NULL)
		{
			printf("Failed to greate GCS! \n");
			goto error_gcs;
		}
		gcs_start(gcs);
		printf("-- Camera Stream started --\n");
	}

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

			if (emulatedBuffer)
			{ // Just replace camera buffer with emulated buffer
				qpu_lockBuffer(&camEmulBuffer);
				cameraBufferPtr = camEmulBuffer.ptr.vc;
			}

			// ---- Uniform preparation ----

			// Set source buffer pointer in progmem uniforms
			qpu_lockBuffer(&program.progmem_buffer);
			for (int t = 0; t < taskCount; t++)
				program.progmem.uniforms.arm.uptr[t*unifCount + 0] = cameraBufferPtr + t*srcOffset;
			qpu_unlockBuffer(&program.progmem_buffer);

			// ---- Program execution ----

			// Execute numInstances programs each with their own set of uniforms
			int result = qpu_executeProgramDirect(&program, &base, taskCount, unifCount, unifCount, &perfState);

			// Log errors occurred during execution
			qpu_logErrors(&base);

			if (emulatedBuffer)
				qpu_unlockBuffer(&camEmulBuffer);

			// Unlock VCSM buffer (no need to keep locked, VC-space adress won't change)
			mem_unlock(base.mb, cameraBufferHandle);
			// Return camera buffer to camera
			gcs_returnFrameBuffer(gcs);

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

	if (emulatedBuffer)
		qpu_releaseBuffer(&camEmulBuffer);

error_gcs:

	// Disable QPU
	if (qpu_enable(base.mb, 0))
		printf("-- QPU Disable failed --\n");
	else
		printf("-- QPU Disabled --\n");

	for (int i = 0; i < 12; i++) // Reset all QPUs to be freely sheduled
		qpu_setReservationSetting(&base, i, 0b0000);

error_qpu:

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
