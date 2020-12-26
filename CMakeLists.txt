cmake_minimum_required(VERSION 3.0)
project(VC4CV)

# For desktop compilation
#cmake_policy(SET CMP0015 NEW)
#cmake_policy(SET CMP0081 OLD)

SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror -Wall -std=gnu99 -g")

# Set --no-as-needed to stop the linker discarding mmal_vc_client
# as it can't see that the constructor registers a load of functionality
# with the MMAL core.
#SET(CMAKE_EXE_LINKER_FLAGS "-Wl,--no-as-needed" )

include_directories(/usr/local/include)
include_directories(/opt/vc/include/)
include_directories(/opt/vc/include/interface/vcos/pthreads)
include_directories(/opt/vc/include/interface/vmcs_host/linux)
include_directories(/opt/vc/include/interface/vcsm)

find_library(LIB_BCMH NAMES bcm_host HINTS /opt/vc/lib/)
find_library(LIB_VCOS NAMES vcos HINTS /opt/vc/lib/)
find_library(LIB_VCSM NAMES vcsm HINTS /opt/vc/lib/)
find_library(LIB_MMAL NAMES mmal HINTS /opt/vc/lib/)
find_library(LIB_MMAL_CORE NAMES mmal_core HINTS /opt/vc/lib/)
find_library(LIB_MMAL_UTIL NAMES mmal_util HINTS /opt/vc/lib/)
find_library(LIB_MMAL_COMP NAMES mmal_components HINTS /opt/vc/lib/)
find_library(LIB_BEGL NAMES brcmEGL HINTS /opt/vc/lib/)
find_library(LIB_GLES NAMES brcmGLESv2 HINTS /opt/vc/lib/)

set(VC4CV_QPU_SOURCES
   camera/gcs.c
   qpu/fbUtil.c
   qpu/mailbox.c
   qpu/qpu_base.c
   qpu/qpu_program.c
   qpu/qpu_info.c)
set(VC4CV_GL_SOURCES
   camera/gcs.c
   camera/camGL.c
   gl/eglUtil.c
   gl/mesh.cpp
   gl/shader.cpp
   gl/texture.cpp)

set(VC4CV_LIBRARIES
	m dl pthread
	${LIB_BCMH} ${LIB_VCOS} ${LIB_VCSM}
	${LIB_MMAL} ${LIB_MMAL_CORE} ${LIB_MMAL_UTIL} ${LIB_MMAL_COMP})
set(VC4CV_GL_LIBRARIES
	${LIB_BEGL} ${LIB_GLES})

# Grouped targets
add_custom_target(qpu DEPENDS QPUCV qpu_programs)
add_custom_target(gl DEPENDS GLCV GLBlobs)

# QPU CV Sample application
add_executable(QPUCV ${VC4CV_QPU_SOURCES} main_qpu.cpp)
target_link_libraries(QPUCV ${VC4CV_LIBRARIES})
target_include_directories(QPUCV PRIVATE qpu camera)

# GL CV sample application
add_executable(GLCV ${VC4CV_GL_SOURCES} main_gl.cpp)
target_link_libraries(GLCV ${VC4CV_LIBRARIES} ${VC4CV_GL_LIBRARIES})
target_include_directories(GLCV PRIVATE gl camera)

# GL blob tracking application
add_executable(GLBlobs ${VC4CV_GL_SOURCES} main_gl_blobs.cpp gl_blobs/blobdetection.cpp)
target_link_libraries(GLBlobs ${VC4CV_LIBRARIES} ${VC4CV_GL_LIBRARIES})
target_include_directories(GLBlobs PRIVATE gl gl_blobs camera)

# Set VC4ASM compiler to compile all asm source files
set(QPU_SOURCES
	qpu_programs/qpu_fb_pattern.asm
	qpu_programs/qpu_debug_full.asm
	qpu_programs/qpu_debug_tiled.asm
	qpu_programs/qpu_blit_full.asm
	qpu_programs/qpu_blit_tiled.asm
	qpu_programs/qpu_mask_full.asm
	qpu_programs/qpu_mask_tiled_1x1.asm
	qpu_programs/qpu_mask_tiled_1x1_optimized.asm
	qpu_programs/qpu_mask_tiled_1x5.asm
	qpu_programs/qpu_mask_tiled_1x5_organized.asm
	qpu_programs/qpu_mask_tiled_5x5.asm
	qpu_programs/qpu_mask_tiled_5x5_memory.asm
	qpu_programs/qpu_mask_tiled_5x5_min.asm
	qpu_programs/qpu_mask_tiled_5x5_minopt.asm
	qpu_programs/qpu_mask_tiled_5x5_blob.asm
	qpu_programs/qpu_mask_tiled_5x5_blobopt.asm
	qpu_programs/qpu_mask_tiled_5x5_blobwrite.asm
	qpu_programs/qpu_free_mutex.asm
)
add_custom_target(qpu_programs)
foreach (file ${QPU_SOURCES})
    get_filename_component(file_name ${file} NAME_WE)
    add_custom_command(
		OUTPUT ${file_name}.bin
		DEPENDS ${file}
	    COMMAND vc4asm -V -o ${CMAKE_CURRENT_BINARY_DIR}/${file_name}.bin ${CMAKE_SOURCE_DIR}/${file}
	)
    add_custom_target(${file_name}
		DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${file_name}.bin
	)
	add_dependencies(qpu_programs ${file_name})
endforeach()
