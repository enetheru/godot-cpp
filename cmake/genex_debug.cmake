# debug the libgodot-cpp targets

file( GENERATE
    OUTPUT ${TARGET_NAME}.genex_debug.txt
    CONTENT
"
Debugging Generator Expressions for ${TARGET_NAME}

Host System
Deteced Processors: ${PROC_MAX}
Compiler: ${CMAKE_CXX_COMPILER}

Variables

GODOT_GDEXTENSION_DIR:              ${GODOT_GDEXTENSION_DIR}
GODOT_CUSTOM_API_FILE:              ${GODOT_CUSTOM_API_FILE}
GODOT_GENERATE_TEMPLATE_GET_NODE:   ${GODOT_GENERATE_TEMPLATE_GET_NODE}
GODOT_PRECISION:                    ${GODOT_PRECISION}
GODOT_ARCH:                         ${GODOT_ARCH}
GODOT_THREADS:                      ${GODOT_THREADS}
GODOT_USE_HOT_RELOAD:               ${GODOT_USE_HOT_RELOAD}
GODOT_DISABLE_EXCEPTIONS:           ${GODOT_DISABLE_EXCEPTIONS}
GODOT_SYMBOL_VISIBILITY:            ${GODOT_SYMBOL_VISIBILITY}
GODOT_DEV_BUILD:                    ${GODOT_DEV_BUILD}
GODOT_SYSTEM_HEADERS:               ${GODOT_SYSTEM_HEADERS}
GODOT_WARNING_AS_ERROR:             ${GODOT_WARNING_AS_ERROR}

android_options()
ios_options()
linux_options()
macos_options()
web_options()
windows_options()
endfunction()

# Generator Expression Results
SYSTEM_NAME                 ${SYSTEM_NAME}
HOT_RELOAD-UNSET            ${HOT_RELOAD-UNSET}
DISABLE_EXCEPTIONS          ${DISABLE_EXCEPTIONS}
USE_THREADS                 ${USE_THREADS}
IS_DEV_BUILD                ${IS_DEV_BUILD}
NAME_SUFFIX                 ${NAME_SUFFIX}
DEBUG_FEATURES              ${DEBUG_FEATURES}
HOT_RELOAD                  ${HOT_RELOAD}
OUTPUT_NAME                 ${PROJECT_NAME}${NAME_SUFFIX}
ARCHIVE_OUTPUT_DIRECTORY    $<1:${CMAKE_BINARY_DIR}/bin>

TODO Generation steps for
android
ios
linux
macos
web
windows

Target Properties:
OUTPUT_NAME
    GenEx:  $<TARGET_PROPERTY:${TARGET_NAME},OUTPUT_NAME>
    Result: $<GENEX_EVAL:$<TARGET_PROPERTY:${TARGET_NAME},OUTPUT_NAME>>


Finished")
#    add_custom_target( ${TARGET_NAME}.genexdebug COMMAND DEPENDS ${TARGET_NAME}.genex_debug.txt )

#debug the libgdexample targets
