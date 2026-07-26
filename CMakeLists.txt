cmake_minimum_required(VERSION 3.10)
project(VecMath)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(vecmath
    src/main.cpp
    src/Vec2.cpp
    src/Vec3.cpp
    src/VectorUtils.cpp
    src/Mat3.cpp
    src/Vec4.cpp
    src/Mat4.cpp
    src/Transform.cpp
    src/Camera.cpp
    src/Projection.cpp
    src/Pipeline.cpp
    src/TangentSpace.cpp
    src/Fresnel.cpp
)

target_include_directories(vecmath PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_library(software_renderer
    src/Framebuffer.cpp
    src/SoftwareRenderer.cpp
)
target_include_directories(software_renderer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_executable(soft_renderer
    src/soft_renderer_main.cpp
)
target_link_libraries(soft_renderer PRIVATE software_renderer)

if(MSVC)
    target_compile_options(vecmath PRIVATE /utf-8)
    target_compile_options(software_renderer PRIVATE /utf-8)
    target_compile_options(soft_renderer PRIVATE /utf-8)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(vecmath PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(software_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(soft_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
endif()

include(CTest)
if(BUILD_TESTING)
    add_test(NAME graphics_math_acceptance COMMAND vecmath)
    add_test(NAME software_renderer_skeleton_acceptance COMMAND soft_renderer)
endif()
