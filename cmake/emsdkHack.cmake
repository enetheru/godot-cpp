# The emscripten platform doesn't support the use of shared libraries as known by cmake.
#https://github.com/emscripten-core/emscripten/issues/15276
#https://github.com/emscripten-core/emscripten/issues/17804
# This workaround only works due to the way the cmake scripts are loaded.
# in the main CMakeLists.txt we have defined CMAKE_PROJECT_INCLUDE=cmake/emscripten.cmake
# this loads this file after the toolchain, which overrides the settings preventing shared library building.
# I dont know how it might interact if another CMAKE_PROJECT_<projectName>_INCLUDE were to be included.
if( EMSCRIPTEN )
    # Overwrite Shared Library Properties to allow shared libs to be generated.
    set_property(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS TRUE)
    set(CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS "-sSIDE_MODULE=1")
    set(CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS "-sSIDE_MODULE=1")
    set(CMAKE_STRIP FALSE)  # used by default in pybind11 on .so modules

    # The Emscripten toolchain sets the default value for EMSCRIPTEN_SYSTEM_PROCESSOR to x86
    # and CMAKE_SYSTEM_PROCESSOR to this value. I don't want that.
    set(CMAKE_SYSTEM_PROCESSOR "wasm32" )
    # the above prevents the need for logic like:
#    if( ${CMAKE_SYSTEM_NAME} STREQUAL Emscripten )
#        set( SYSTEM_ARCH wasm32 )
#    endif ()
endif ()
