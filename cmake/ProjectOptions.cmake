function(configure_project_target target_name)
    target_compile_features(${target_name} PRIVATE cxx_std_17)

    if(MSVC)
        target_compile_options(${target_name} PRIVATE /utf-8)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(
            ${target_name}
            PRIVATE
                -finput-charset=UTF-8
                -fexec-charset=UTF-8
        )
    endif()
endfunction()
