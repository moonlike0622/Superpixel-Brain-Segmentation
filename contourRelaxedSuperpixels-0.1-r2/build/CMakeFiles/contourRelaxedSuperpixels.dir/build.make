# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 2.8

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list

# Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# The program to use to edit the cache.
CMAKE_EDIT_COMMAND = /usr/bin/ccmake

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/build

# Include any dependencies generated for this target.
include CMakeFiles/contourRelaxedSuperpixels.dir/depend.make

# Include the progress variables for this target.
include CMakeFiles/contourRelaxedSuperpixels.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/contourRelaxedSuperpixels.dir/flags.make

CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o: CMakeFiles/contourRelaxedSuperpixels.dir/flags.make
CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o: /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src/contourRelaxedSuperpixels.cpp
	$(CMAKE_COMMAND) -E cmake_progress_report /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/build/CMakeFiles $(CMAKE_PROGRESS_1)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building CXX object CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_FLAGS) -o CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o -c /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src/contourRelaxedSuperpixels.cpp

CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_FLAGS) -E /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src/contourRelaxedSuperpixels.cpp > CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.i

CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_FLAGS) -S /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src/contourRelaxedSuperpixels.cpp -o CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.s

CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.requires:
.PHONY : CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.requires

CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.provides: CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.requires
	$(MAKE) -f CMakeFiles/contourRelaxedSuperpixels.dir/build.make CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.provides.build
.PHONY : CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.provides

CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.provides.build: CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o

# Object files for target contourRelaxedSuperpixels
contourRelaxedSuperpixels_OBJECTS = \
"CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o"

# External object files for target contourRelaxedSuperpixels
contourRelaxedSuperpixels_EXTERNAL_OBJECTS =

contourRelaxedSuperpixels: CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o
contourRelaxedSuperpixels: /usr/local/lib/libopencv_calib3d.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_contrib.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_core.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_features2d.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_flann.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_gpu.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_highgui.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_imgproc.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_legacy.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_ml.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_nonfree.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_objdetect.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_photo.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_stitching.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_ts.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_video.so
contourRelaxedSuperpixels: /usr/local/lib/libopencv_videostab.so
contourRelaxedSuperpixels: /usr/lib/libboost_filesystem-mt.so
contourRelaxedSuperpixels: /usr/lib/libboost_system-mt.so
contourRelaxedSuperpixels: CMakeFiles/contourRelaxedSuperpixels.dir/build.make
contourRelaxedSuperpixels: CMakeFiles/contourRelaxedSuperpixels.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --red --bold "Linking CXX executable contourRelaxedSuperpixels"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/contourRelaxedSuperpixels.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/contourRelaxedSuperpixels.dir/build: contourRelaxedSuperpixels
.PHONY : CMakeFiles/contourRelaxedSuperpixels.dir/build

CMakeFiles/contourRelaxedSuperpixels.dir/requires: CMakeFiles/contourRelaxedSuperpixels.dir/contourRelaxedSuperpixels.cpp.o.requires
.PHONY : CMakeFiles/contourRelaxedSuperpixels.dir/requires

CMakeFiles/contourRelaxedSuperpixels.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/contourRelaxedSuperpixels.dir/cmake_clean.cmake
.PHONY : CMakeFiles/contourRelaxedSuperpixels.dir/clean

CMakeFiles/contourRelaxedSuperpixels.dir/depend:
	cd /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/src /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/build /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/build /home/tgelles1/Desktop/contourRelaxedSuperpixels-0.1-r2/build/CMakeFiles/contourRelaxedSuperpixels.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/contourRelaxedSuperpixels.dir/depend

