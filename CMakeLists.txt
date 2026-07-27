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
    src/ObjLoader.cpp
    src/SoftwareRenderer.cpp
    src/Vec2.cpp
    src/Vec3.cpp
)
target_include_directories(software_renderer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_executable(soft_renderer
    src/soft_renderer_main.cpp
)
target_link_libraries(soft_renderer PRIVATE software_renderer)

add_executable(obj_loader_acceptance
    src/obj_loader_main.cpp
)
target_link_libraries(obj_loader_acceptance PRIVATE software_renderer)
target_compile_definitions(
    obj_loader_acceptance
    PRIVATE OBJ_FIXTURE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/vertex_data.obj"
)

if(MSVC)
    target_compile_options(vecmath PRIVATE /utf-8)
    target_compile_options(software_renderer PRIVATE /utf-8)
    target_compile_options(soft_renderer PRIVATE /utf-8)
    target_compile_options(obj_loader_acceptance PRIVATE /utf-8)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(vecmath PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(software_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(soft_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(obj_loader_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
endif()

include(CTest)
if(BUILD_TESTING)
    add_test(NAME graphics_math_acceptance COMMAND vecmath)
    add_test(NAME software_renderer_skeleton_acceptance COMMAND soft_renderer)
    add_test(NAME obj_vertex_data_acceptance COMMAND obj_loader_acceptance)
endif()
