#Silence warning from unused CMAKE_C_COMPILER from toolchain
if( CMAKE_C_COMPILER )
endif ()

# Detect processor count so we can use it in msvc builds
include(ProcessorCount)
ProcessorCount(PROC_N)
message( "Auto-detected ${PROC_N} CPU cores available for build parallelism." )

set( PLATFORM_LIST linux macos windows android ios web )
set( ARCH_LIST universal x86_32 x86_64 arm32 arm64 rv64 ppc32 ppc64 wasm32 )

set( ARCH_ALIAS  w64    amd64  armv7 armv8 arm64v8 aarch64 rv   riscv riscv64 ppcle ppc   ppc64le )
set( ARCH_ALIAS_VALUE  x86_64 x86_64 arm32 arm64 arm64   arm64   rv64 rv64  rv64    ppc32 ppc32 ppc64   )

# include lists of sources and generic configure function
include( cmake/sources.cmake )
include( cmake/common_compiler_flags.cmake)
include( cmake/android.cmake)
include( cmake/ios.cmake)
include( cmake/linux.cmake)
include( cmake/macos.cmake)
include( cmake/web.cmake)
include( cmake/windows.cmake)

function( godotcpp_options )
    #NOTE: platform is managed using toolchain files.

    # Input from user for GDExtension interface header and the API JSON file
    set(GODOT_GDEXTENSION_DIR "gdextension" CACHE PATH
            "Path to a custom directory containing GDExtension interface header and API JSON file ( /path/to/gdextension_dir )" )
    set(GODOT_CUSTOM_API_FILE "" CACHE FILEPATH
            "Path to a custom GDExtension API JSON file (takes precedence over `GODOT_GDEXTENSION_DIR`) ( /path/to/custom_api_file )")

    #TODO generate_bindings

    option(GODOT_GENERATE_TEMPLATE_GET_NODE
            "Generate a template version of the Node class's get_node. (ON|OFF)" ON)

    #TODO build_library

    set(GODOT_PRECISION "single" CACHE STRING
            "Set the floating-point precision level (single|double)")

    # The arch is typically set by the toolchain
    # however for Apple multi-arch setting it here will override.
    set( GODOT_ARCH "" CACHE STRING "Target CPU Architecture")
    set_property( CACHE GODOT_ARCH PROPERTY STRINGS ${ARCH_LIST} )

    #TODO threads
    #TODO compiledb
    #TODO compiledb_file

    #NOTE: build_profile's equivalent in cmake is CMakePresets.json

    set(GODOT_USE_HOT_RELOAD "" CACHE BOOL
            "Enable the extra accounting required to support hot reload. (ON|OFF)")

    # Disable exception handling. Godot doesn't use exceptions anywhere, and this
    # saves around 20% of binary size and very significant build time (GH-80513).
    option(GODOT_DISABLE_EXCEPTIONS "Force disabling exception handling code (ON|OFF)" ON )

    set( GODOT_SYMBOL_VISIBILITY "hidden" CACHE STRING
            "Symbols visibility on GNU platforms. Use 'auto' to apply the default value. (auto|visible|hidden)")
    set_property( CACHE GODOT_SYMBOL_VISIBILITY PROPERTY STRINGS "auto;visible;hidden" )

    #TODO optimize
    #TODO debug_symbols
    option( GODOT_DEBUG_SYMBOLS "" OFF )
    option( GODOT_DEV_BUILD "Developer build with dev-only debugging code (DEV_ENABLED)" OFF )

    # FIXME These options are not present in SCons, and perhaps should be added there.
    option( GODOT_SYSTEM_HEADERS "Expose headers as SYSTEM." OFF )
    option( GODOT_WARNING_AS_ERROR "Treat warnings as errors" OFF )

    # Run options commands on the following to populate cache for all platforms.
    # This type of thing is typically done conditionally
    # But as scons shows all options so shall we.
    android_options()
    ios_options()
    linux_options()
    macos_options()
    web_options()
    windows_options()
endfunction()


function( godotcpp_generate )
    ### Configure variables
    # CXX_VISIBILITY_PRESET supported values are: default, hidden, protected, and internal
    # which is inline with the gcc -fvisibility=
    # https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html
    # To match the scons options we need to change the text to match the -fvisibility flag
    # it is probably worth another PR which changes both to use the flag options
    if( ${GODOT_SYMBOL_VISIBILITY} STREQUAL "auto" OR ${GODOT_SYMBOL_VISIBILITY} STREQUAL "visible" )
        set( GODOT_SYMBOL_VISIBILITY "default" )
    endif ()

    # Setup variable to optionally mark headers as SYSTEM
    set(GODOT_SYSTEM_HEADERS_ATTRIBUTE "")
    if (GODOT_SYSTEM_HEADERS)
        set(GODOT_SYSTEM_HEADERS_ATTRIBUTE SYSTEM)
    endif ()

    ### Generate Bindings
    if(NOT DEFINED BITS)
        set(BITS 32)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(BITS 64)
        endif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    endif()

    set(GODOT_GDEXTENSION_API_FILE "${GODOT_GDEXTENSION_DIR}/extension_api.json")
    if (NOT "${GODOT_CUSTOM_API_FILE}" STREQUAL "")  # User-defined override.
        set(GODOT_GDEXTENSION_API_FILE "${GODOT_CUSTOM_API_FILE}")
    endif()

    # Generate source from the bindings file
    if(GODOT_GENERATE_TEMPLATE_GET_NODE)
        set(GENERATE_BINDING_PARAMETERS "True")
    else()
        set(GENERATE_BINDING_PARAMETERS "False")
    endif()

    execute_process(COMMAND "${Python3_EXECUTABLE}" "-c" "import binding_generator; binding_generator.print_file_list('${GODOT_GDEXTENSION_API_FILE}', '${CMAKE_CURRENT_BINARY_DIR}', headers=True, sources=True)"
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            OUTPUT_VARIABLE GENERATED_FILES_LIST
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    add_custom_command(OUTPUT ${GENERATED_FILES_LIST}
            COMMAND "${Python3_EXECUTABLE}" "-c" "import binding_generator; binding_generator.generate_bindings('${GODOT_GDEXTENSION_API_FILE}', '${GENERATE_BINDING_PARAMETERS}', '${BITS}', '${GODOT_PRECISION}', '${CMAKE_CURRENT_BINARY_DIR}')"
            VERBATIM
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            MAIN_DEPENDENCY ${GODOT_GDEXTENSION_API_FILE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/binding_generator.py
            COMMENT "Generating bindings"
    )

    ### Platform is derived from the toolchain target
    # See GeneratorExpressions PLATFORM_ID and CMAKE_SYSTEM_NAME
    set( SYSTEM_NAME
            $<$<PLATFORM_ID:Android>:android.${ANDROID_ABI}>
            $<$<PLATFORM_ID:iOS>:ios>
            $<$<PLATFORM_ID:Linux>:linux>
            $<$<PLATFORM_ID:Darwin>:macos>
            $<$<PLATFORM_ID:Emscripten>:web>
            $<$<PLATFORM_ID:Windows>:windows>
    )
    string(REPLACE ";" "" SYSTEM_NAME "${SYSTEM_NAME}")

    ### Derive SYSTEM_ARCH
    # from the toolchain first
    if (NOT GODOT_ARCH)
        set( SYSTEM_PROCESSOR "$<LOWER_CASE:${CMAKE_SYSTEM_PROCESSOR}>")
        set( ARCH_IN_LIST "$<IN_LIST:${SYSTEM_PROCESSOR},${ARCH_LIST}>" )
        set( ARCH_INDEX "$<LIST:FIND,${ARCH_ALIAS},${SYSTEM_PROCESSOR}>")
        set( SYSTEM_ARCH "$<IF:${ARCH_IN_LIST},${SYSTEM_PROCESSOR},$<LIST:GET,${ARCH_ALIAS_VALUE},${ARCH_INDEX}>>")
    else ()
        # override from manually specified GODOT_ARCH variable
        set(SYSTEM_ARCH ${GODOT_ARCH})
    endif ()

    ### Define our godot-cpp library targets
    foreach ( TARGET_NAME template_debug template_release editor )

        # Useful genex snippits used in subsequent genex's
        set( IS_RELEASE "$<STREQUAL:${TARGET_NAME},template_release>")
        set( IS_DEV "$<BOOL:${GODOT_DEV_BUILD}>")
        set( DEBUG_FEATURES "$<OR:$<STREQUAL:${TARGET_NAME},template_debug>,$<STREQUAL:${TARGET_NAME},editor>>" )
        set( HOT_RELOAD "$<IF:${HOT_RELOAD-UNSET},$<NOT:${IS_RELEASE}>,$<BOOL:${GODOT_USE_HOT_RELOAD}>>" )

        # Exclude non default targets
        if( NOT ${TARGET_NAME} STREQUAL template_debug )
            set( EXCLUDE EXCLUDE_FROM_ALL )
        else ()
            set( EXCLUDE )
        endif ()

        # the godot-cpp.* library targets
        add_library( ${TARGET_NAME} STATIC ${EXCLUDE} )
        add_library( godot-cpp::${TARGET_NAME} ALIAS ${TARGET_NAME} )

        target_sources( ${TARGET_NAME}
                PRIVATE
                ${GODOTCPP_SOURCES}
                ${GENERATED_FILES_LIST}
                ${GODOTCPP_HEADERS}
        )

        target_include_directories( ${TARGET_NAME} ${GODOT_SYSTEM_HEADERS_ATTRIBUTE} PUBLIC
                include
                ${CMAKE_CURRENT_BINARY_DIR}/gen/include
                ${GODOT_GDEXTENSION_DIR}
        )

        set_target_properties( ${TARGET_NAME}
                PROPERTIES
                CXX_STANDARD 17
                CXX_EXTENSIONS OFF
                CXX_VISIBILITY_PRESET ${GODOT_SYMBOL_VISIBILITY}

                COMPILE_WARNING_AS_ERROR ${GODOT_WARNING_AS_ERROR}
                POSITION_INDEPENDENT_CODE ON
                BUILD_RPATH_USE_ORIGIN ON

                PREFIX lib
                OUTPUT_NAME "${PROJECT_NAME}.${SYSTEM_NAME}.${TARGET_NAME}.${SYSTEM_ARCH}"
                ARCHIVE_OUTPUT_DIRECTORY "$<1:${CMAKE_SOURCE_DIR}/bin>"

                # Things that are handy to know for dependent targets
                GODOT_PLATFORM "${SYSTEM_NAME}"
                GODOT_TARGET "${TARGET_NAME}"
                GODOT_ARCH "${SYSTEM_ARCH}"
        )

        if( CMAKE_SYSTEM_NAME STREQUAL Android )
            android_generate( ${TARGET_NAME} )
        elseif ( CMAKE_SYSTEM_NAME STREQUAL iOS )
            ios_generate( ${TARGET_NAME} )
        elseif ( CMAKE_SYSTEM_NAME STREQUAL Linux )
            linux_generate( ${TARGET_NAME} )
        elseif ( CMAKE_SYSTEM_NAME STREQUAL Darwin )
            macos_generate( ${TARGET_NAME} )
        elseif ( CMAKE_SYSTEM_NAME STREQUAL Emscripten )
            web_generate( ${TARGET_NAME} )
        elseif ( CMAKE_SYSTEM_NAME STREQUAL Windows )
            windows_generate( ${TARGET_NAME} )
        endif ()

    endforeach ()

endfunction()
