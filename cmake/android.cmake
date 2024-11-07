function( android_options )
    # Android Options
endfunction()

function( android_generate TARGET_NAME )

    target_compile_definitions(${TARGET_NAME}
            PUBLIC
            ANDROID_ENABLED
            UNIX_ENABLED
    )

    common_compiler_flags( ${TARGET_NAME} )
endfunction()
