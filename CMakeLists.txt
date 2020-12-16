cmake_minimum_required(VERSION 2.8)
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

include_directories(./camera)
include_directories(./qpu)

link_directories(/opt/vc/lib/)

find_library(LIB_BCMH NAMES bcm_host HINTS /opt/vc/lib/)
find_library(LIB_VCOS NAMES vcos HINTS /opt/vc/lib/)
find_library(LIB_VCSM NAMES vcsm HINTS /opt/vc/lib/)
find_library(LIB_MMAL NAMES mmal HINTS /opt/vc/lib/)
find_library(LIB_MMAL_CORE NAMES mmal_core HINTS /opt/vc/lib/)
find_library(LIB_MMAL_UTIL NAMES mmal_util HINTS /opt/vc/lib/)
find_library(LIB_MMAL_COMP NAMES mmal_components HINTS /opt/vc/lib/)

set(VC4CV_QPU_SOURCES
   camera/gcs.c
   qpu/fbUtil.c
   qpu/mailbox.c
   qpu/qpu_base.c
   qpu/qpu_program.c
   qpu/qpu_info.c)

set(VC4CV_LIBRARIES
	m dl pthread
	${LIB_BCMH} ${LIB_VCOS} ${LIB_VCSM}
	${LIB_MMAL} ${LIB_MMAL_CORE} ${LIB_MMAL_UTIL} ${LIB_MMAL_COMP})

add_custom_target(QPU ALL DEPENDS qpu QPUCV QPUMin)

# QPU CV Sample application
add_executable(QPUCV ${VC4CV_QPU_SOURCES} main.cpp)
target_link_libraries(QPUCV ${VC4CV_LIBRARIES})

# QPU CV minimal application for tiled mode with bitmask buffer
add_executable(QPUMin ${VC4CV_QPU_SOURCES} main_minimal.cpp)
target_link_libraries(QPUMin ${VC4CV_LIBRARIES})

# Set VC4ASM compiler to compile all asm source files
set(QPU_SOURCES
	qpu_programs/qpu_fb_pattern.asm
	qpu_programs/qpu_debug_full.asm
	qpu_programs/qpu_debug_tiled.asm
	qpu_programs/qpu_blit_full.asm
	qpu_programs/qpu_blit_tiled.asm
	qpu_programs/qpu_mask_full.asm
	qpu_programs/qpu_mask_tiled.asm
	qpu_programs/qpu_free_mutex.asm
)
add_custom_target(qpu)
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
	add_dependencies(qpu ${file_name})
endforeach()
