function( linux_options )
    # Linux Options
endfunction()

function( linux_generate TARGET_NAME )

    target_compile_definitions( ${TARGET_NAME}
            PUBLIC
            LINUX_ENABLED
            UNIX_ENABLED
    )

    common_compiler_flags( ${TARGET_NAME} )
endfunction()
