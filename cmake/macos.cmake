function( macos_options )
    # macos options here
endfunction()

function( macos_generate TARGET_NAME )

    # OSX_ARCHITECTURES does not support generator expressions.
    if( NOT GODOT_ARCH OR GODOT_ARCH STREQUAL universal )
        set( OSX_ARCH "x86_64;arm64" )
        set( SYSTEM_ARCH universal )
    else()
        set( OSX_ARCH ${GODOT_ARCH} )
    endif()

    set_target_properties( ${TARGET_NAME}
            PROPERTIES

            OSX_ARCHITECTURES "${OSX_ARCH}"
    )

    target_compile_definitions(${TARGET_NAME}
            PUBLIC
            MACOS_ENABLED
            UNIX_ENABLED
    )

    target_link_options( ${TARGET_NAME}
            PUBLIC
            -Wl,-undefined,dynamic_lookup
    )

    target_link_libraries( ${TARGET_NAME}
            INTERFACE
            ${COCOA_LIBRARY}
    )

    common_compiler_flags( ${TARGET_NAME} )
endfunction()
