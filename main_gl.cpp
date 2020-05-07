#include <sys/time.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <vector>
#include <chrono>
#include <termios.h>

#include "applog.h"

#include "bcm_host.h"

#include "eglUtil.h"
#include "camGL.h"

#include "defines.hpp"
#include "mesh.hpp"
#include "shader.hpp"
#include "texture.hpp"

CamGL *camGL;
int dispWidth, dispHeight;
int camWidth = 1280, camHeight = 720, camFPS = 30;
float renderRatioCorrection;

EGL_Setup eglSetup;
Mesh *SSQuad;
ShaderProgram *shaderCamBlitRGB, *shaderCamBlitY, *shaderCamBlitYUV;
int texRGBAdr, texYAdrY, texYUVAdrY, texYUVAdrU, texYUVAdrV;

struct termios terminalSettings;

static void setConsoleRawMode();
static void processCameraFrame(CamGL_Frame *frame);
static void bindExternalTexture(GLuint adr, GLuint tex, int slot);

int main(int argc, char **argv)
{
	// ---- Read arguments ----

	CamGL_Params params = {
		.format = CAMGL_YUV,
		.width = (uint16_t)camWidth,
		.height = (uint16_t)camHeight,
		.fps = (uint16_t)camFPS,
		.shutterSpeed = 0,
		.iso = -1
	};

	int arg;
	while ((arg = getopt(argc, argv, "c:w:h:f:s:i:")) != -1)
	{
		switch (arg)
		{
			case 'c':
				if (strcmp(optarg, "YUV") == 0) params.format = CAMGL_YUV;
				else if (strcmp(optarg, "Y") == 0) params.format = CAMGL_Y;
				else if (strcmp(optarg, "RGB") == 0) params.format = CAMGL_RGB;
				break;
			case 's':
				params.shutterSpeed = std::stoi(optarg);
				break;
			case 'i':
				params.iso = std::stoi(optarg);
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
			default:
				printf("Usage: %s [-c (RGB, Y, YUV)] [-w width] [-h height] [-f fps] [-s shutter-speed-ns] [-i iso]\n", argv[0]);
				break;
		}
	}
	if (optind < argc - 1)
		printf("Usage: %s [-c (RGB, Y, YUV)] [-w width] [-h height] [-f fps] [-s shutter-speed-ns] [-i iso]\n", argv[0]);

	// ---- Init ----

	// Init BCM Host
	bcm_host_init();

	// Create native window (not real GUI window)
	EGL_DISPMANX_WINDOW_T window;
	if (createNativeWindow(&window) != 0)
		return EXIT_FAILURE;
	dispWidth = window.width;
	dispHeight = window.height;
	renderRatioCorrection = (((float)dispHeight / camHeight) * camWidth) / dispWidth;

	// Setup EGL context
	setupEGL(&eglSetup, (EGLNativeWindowType*)&window);
	glClearColor(0.8f, 0.2f, 0.1f, 1.0f);

	// ---- Setup GL Resources ----

	// Create screen-space quad for rendering
	SSQuad = new Mesh ({ POS, TEX }, {
		-1,  1, 0, 0, 1,
		 1,  1, 0, 1, 1,
		-1, -1, 0, 0, 0,
		 1,  1, 0, 1, 1,
		 1, -1, 0, 1, 0,
		-1, -1, 0, 0, 0,
	}, {});

	// Load shaders
	shaderCamBlitRGB = new ShaderProgram("../gl_shaders/CamES/vert.glsl", "../gl_shaders/CamES/frag_camRGB.glsl");
	shaderCamBlitY = new ShaderProgram("../gl_shaders/CamES/vert.glsl", "../gl_shaders/CamES/frag_camY.glsl");
	shaderCamBlitYUV = new ShaderProgram("../gl_shaders/CamES/vert.glsl", "../gl_shaders/CamES/frag_camYUV.glsl");
	
	// Load shader uniform adresses
	texRGBAdr = glGetUniformLocation(shaderCamBlitRGB->ID, "image");
	texYAdrY = glGetUniformLocation(shaderCamBlitY->ID, "imageY");
	texYUVAdrY = glGetUniformLocation(shaderCamBlitYUV->ID, "imageY");
	texYUVAdrU = glGetUniformLocation(shaderCamBlitYUV->ID, "imageU");
	texYUVAdrV = glGetUniformLocation(shaderCamBlitYUV->ID, "imageV");

	// ---- Setup Camera ----

	// Init camera GL
	printf("Initializing Camera GL!\n");
	camGL = camGL_create(eglSetup, (const CamGL_Params*)&params);
	if (camGL == NULL)
	{
		printf("Failed to start Camera GL\n");
		terminateEGL(&eglSetup);
		return EXIT_FAILURE;
	}
	else
	{ // Start CamGL

		printf("Starting Camera GL!\n");
		int status = camGL_startCamera(camGL);
		if (status != CAMGL_SUCCESS)
		{
			printf("Failed to start camera GL with code %d!\n", status);
		}
		else
		{ // Process incoming frames

			// For non-blocking input even over ssh
			setConsoleRawMode();

			auto startTime = std::chrono::high_resolution_clock::now();
			auto lastTime = startTime;
			int numFrames = 0, lastFrames = 0;

			// Get handle to frame struct, stays the same when frames are updated
			CamGL_Frame *frame = camGL_getFrame(camGL);
			while ((status = camGL_nextFrame(camGL)) == CAMGL_SUCCESS)
			{ // Frames was available and has been processed

				// ---- Set camera frame as source ----

				ShaderProgram *shader;
				if (frame->format == CAMGL_RGB)
				{
					shader = shaderCamBlitRGB;
					shader->use();
					bindExternalTexture(texRGBAdr, frame->textureRGB, 0);
				}
				else if (frame->format == CAMGL_Y)
				{
					shader = shaderCamBlitY;
					shader->use();
					bindExternalTexture(texYAdrY, frame->textureY, 0);
				}
				else if (frame->format == CAMGL_YUV)
				{
					shader = shaderCamBlitYUV;
					shader->use();
					bindExternalTexture(texYUVAdrY, frame->textureY, 0);
					bindExternalTexture(texYUVAdrU, frame->textureU, 1);
					bindExternalTexture(texYUVAdrV, frame->textureV, 2);
				}

				// ---- Render frame ----

				// Render to screen
				glViewport((int)((1-renderRatioCorrection) * dispWidth / 2), 0, (int)(renderRatioCorrection * dispWidth), dispHeight);
				glBindFramebuffer(GL_FRAMEBUFFER, 0);
				SSQuad->draw();
				eglSwapBuffers(eglSetup.display, eglSetup.surface);

				// ---- Debugging and Statistics ----
	
				numFrames++;
				if (numFrames % 100 == 0)
				{ // Log FPS
					auto currentTime = std::chrono::high_resolution_clock::now();
					int elapsedMS = std::chrono::duration_cast<std::chrono::milliseconds>(currentTime - lastTime).count();
					float elapsedS = (float)elapsedMS / 1000;
					lastTime = currentTime;
					int frames = (numFrames - lastFrames);
					lastFrames = numFrames;
					float fps = frames / elapsedS;
					int droppedFrames = 0;
					printf("%d frames over %.2fs (%.1ffps)! \n", frames, elapsedS, fps);
				}
				if (numFrames % 10 == 0)
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
			if (status != 0)
				printf("Camera GL was interrupted with code %d!\n", status);
			else
				camGL_stopCamera(camGL);
		}
		camGL_destroy(camGL);
		terminateEGL(&eglSetup);

		return status == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
	}
}

/* Sets console to raw mode which among others allows for non-blocking input, even over SSH */
static void setConsoleRawMode()
{
	tcgetattr(STDIN_FILENO, &terminalSettings);
	struct termios termSet = terminalSettings;
	atexit([]{
		tcsetattr(STDIN_FILENO, TCSAFLUSH, &terminalSettings);
		camGL_stopCamera(camGL);
	});
	termSet.c_lflag &= ~ECHO;
	termSet.c_lflag &= ~ICANON;
	termSet.c_cc[VMIN] = 0;
	termSet.c_cc[VTIME] = 0;
	tcsetattr(STDIN_FILENO, TCSAFLUSH, &termSet);
}

/* Bind external EGL tex to adr using specified texture slot */
static void bindExternalTexture (GLuint adr, GLuint tex, int slot)
{
	glUniform1i(adr, slot);
	glActiveTexture(GL_TEXTURE0 + slot);
	glBindTexture(GL_TEXTURE_EXTERNAL_OES, tex);
	CHECK_GL();
}
