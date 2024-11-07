function(ios_options)
    # iOS options
endfunction()

function(ios_generate TARGET_NAME)

    target_compile_definitions(${TARGET_NAME}
            PUBLIC
            IOS_ENABLED
            UNIX_ENABLED
    )

    common_compiler_flags(${TARGET_NAME})
endfunction()
