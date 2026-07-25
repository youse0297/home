cmake_minimum_required(VERSION 3.10)
project(VecMath)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(vecmath
    src/main.cpp
    src/Vec2.cpp
    src/Vec3.cpp
    src/VectorUtils.cpp
    src/Vec4.cpp
    src/Mat4.cpp
    src/Transform.cpp
    src/Camera.cpp
    src/Projection.cpp
    src/Pipeline.cpp
)

target_include_directories(vecmath PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(MSVC)
    target_compile_options(vecmath PRIVATE /utf-8)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(vecmath PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
endif()
