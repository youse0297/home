cmake_minimum_required(VERSION 3.10)
project(VecMath)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(vecmath
    src/main.cpp
    src/Vec2.cpp
    src/Vec3.cpp
    src/VectorUtils.cpp
)

target_include_directories(vecmath PRIVATE src)