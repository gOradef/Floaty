# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.27

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Disable VCS-based implicit rules.
% : %,v

# Disable VCS-based implicit rules.
% : RCS/%

# Disable VCS-based implicit rules.
% : RCS/%,v

# Disable VCS-based implicit rules.
% : SCCS/s.%

# Disable VCS-based implicit rules.
% : s.%

.SUFFIXES: .hpux_make_needs_suffix_list

# Command-line flag to silence nested $(MAKE).
$(VERBOSE)MAKESILENT = -s

#Suppress display of executed commands.
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
RM = /usr/bin/cmake -E rm -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/goradef/Floaty

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/goradef/Floaty/build

# Include any dependencies generated for this target.
include src/server_route/CMakeFiles/server_route.dir/depend.make
# Include any dependencies generated by the compiler for this target.
include src/server_route/CMakeFiles/server_route.dir/compiler_depend.make

# Include the progress variables for this target.
include src/server_route/CMakeFiles/server_route.dir/progress.make

# Include the compile flags for this target's objects.
include src/server_route/CMakeFiles/server_route.dir/flags.make

src/server_route/CMakeFiles/server_route.dir/crow.cpp.o: src/server_route/CMakeFiles/server_route.dir/flags.make
src/server_route/CMakeFiles/server_route.dir/crow.cpp.o: /home/goradef/Floaty/src/server_route/crow.cpp
src/server_route/CMakeFiles/server_route.dir/crow.cpp.o: src/server_route/CMakeFiles/server_route.dir/compiler_depend.ts
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green --progress-dir=/home/goradef/Floaty/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building CXX object src/server_route/CMakeFiles/server_route.dir/crow.cpp.o"
	cd /home/goradef/Floaty/build/src/server_route && /usr/sbin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -MD -MT src/server_route/CMakeFiles/server_route.dir/crow.cpp.o -MF CMakeFiles/server_route.dir/crow.cpp.o.d -o CMakeFiles/server_route.dir/crow.cpp.o -c /home/goradef/Floaty/src/server_route/crow.cpp

src/server_route/CMakeFiles/server_route.dir/crow.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green "Preprocessing CXX source to CMakeFiles/server_route.dir/crow.cpp.i"
	cd /home/goradef/Floaty/build/src/server_route && /usr/sbin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/goradef/Floaty/src/server_route/crow.cpp > CMakeFiles/server_route.dir/crow.cpp.i

src/server_route/CMakeFiles/server_route.dir/crow.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green "Compiling CXX source to assembly CMakeFiles/server_route.dir/crow.cpp.s"
	cd /home/goradef/Floaty/build/src/server_route && /usr/sbin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/goradef/Floaty/src/server_route/crow.cpp -o CMakeFiles/server_route.dir/crow.cpp.s

# Object files for target server_route
server_route_OBJECTS = \
"CMakeFiles/server_route.dir/crow.cpp.o"

# External object files for target server_route
server_route_EXTERNAL_OBJECTS =

src/server_route/server_route: src/server_route/CMakeFiles/server_route.dir/crow.cpp.o
src/server_route/server_route: src/server_route/CMakeFiles/server_route.dir/build.make
src/server_route/server_route: src/server_route/CMakeFiles/server_route.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color "--switch=$(COLOR)" --green --bold --progress-dir=/home/goradef/Floaty/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking CXX executable server_route"
	cd /home/goradef/Floaty/build/src/server_route && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/server_route.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
src/server_route/CMakeFiles/server_route.dir/build: src/server_route/server_route
.PHONY : src/server_route/CMakeFiles/server_route.dir/build

src/server_route/CMakeFiles/server_route.dir/clean:
	cd /home/goradef/Floaty/build/src/server_route && $(CMAKE_COMMAND) -P CMakeFiles/server_route.dir/cmake_clean.cmake
.PHONY : src/server_route/CMakeFiles/server_route.dir/clean

src/server_route/CMakeFiles/server_route.dir/depend:
	cd /home/goradef/Floaty/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/goradef/Floaty /home/goradef/Floaty/src/server_route /home/goradef/Floaty/build /home/goradef/Floaty/build/src/server_route /home/goradef/Floaty/build/src/server_route/CMakeFiles/server_route.dir/DependInfo.cmake "--color=$(COLOR)"
.PHONY : src/server_route/CMakeFiles/server_route.dir/depend

