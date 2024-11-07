cmake_minimum_required(VERSION 3.13)

# As we are attempting to maintain feature parity, and ease of maintenance,
# these CMake scripts are built to resemble the structure of the SCons build system.
# The closer the two build systems look the easier they will be to maintain.

# include pulls in the code from godotcpp.cmake
# the equivalent in scons:
#   cpp_tool = Tool("godotcpp", toolpath=["tools"])
include( cmake/godotcpp.cmake )

godotcpp_options()

# godot-cpp targets three main configurations, editor, template_release and template_debug.
# These are all built in "Release" mode unless GODOT_DEV_BUILD is enabled, then the build type is "Debug".
# WARNING: If using Visual Studio Generators the build type is 'Debug' unless specified on the command line like so:
# cmake --build . --config Release
get_property( IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG )
if( NOT IS_MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE )
    if( GODOT_DEV_BUILD )
        set( CMAKE_BUILD_TYPE Debug )
    else ()
        set( CMAKE_BUILD_TYPE Release )
    endif ()
endif ()

#https://github.com/emscripten-core/emscripten/issues/15276
if( CMAKE_SYSTEM_NAME STREQUAL Emscripten )
    set_property(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS TRUE)
    set(CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS "-s SIDE_MODULE=1")
    set(CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS "-s SIDE_MODULE=1")
endif ()

# Get Python
find_package(Python3 3.4 REQUIRED) # pathlib should be present

IF(APPLE)
    set( CMAKE_OSX_SYSROOT $ENV{SDKROOT} )
    find_library( COCOA_LIBRARY REQUIRED
        NAMES Cocoa
        PATHS ${CMAKE_OSX_SYSROOT}/System/Library
        PATH_SUFFIXES Frameworks
        NO_DEFAULT_PATH)
ENDIF (APPLE)

#the emscripten toolchain doesn't support use of shared libraries.
set( CMAKE_PROJECT_INCLUDE cmake/emsdkHack.cmake )

# Define our project.
project( godot-cpp
        VERSION 4.4
        DESCRIPTION "C++ bindings for the Godot Engine's GDExtensions API."
        HOMEPAGE_URL "https://github.com/godotengine/godot-cpp"
        LANGUAGES CXX)

godotcpp_generate()

# Test Example
add_subdirectory( test )
