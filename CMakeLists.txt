cmake_minimum_required(VERSION 3.10)
project(VecMath)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(vecmath
    main.cpp
    Vec2.cpp
    Vec3.cpp
    VectorUtils.cpp
    Vec4.cpp
    Mat4.cpp
    Transform.cpp
    Camera.cpp
)

target_include_directories(vecmath PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

if(MSVC)
    target_compile_options(vecmath PRIVATE /utf-8)
endif()
