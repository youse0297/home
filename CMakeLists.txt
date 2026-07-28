cmake_minimum_required(VERSION 3.10)
project(VecMath)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(graphics_math
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
target_include_directories(graphics_math PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_executable(vecmath
    src/main.cpp
)
target_link_libraries(vecmath PRIVATE graphics_math)

add_library(software_renderer
    src/Framebuffer.cpp
    src/ObjLoader.cpp
    src/SoftwareRenderer.cpp
    src/VertexStage.cpp
)
target_include_directories(software_renderer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(software_renderer PUBLIC graphics_math)

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

add_executable(vertex_stage_acceptance
    src/vertex_stage_main.cpp
)
target_link_libraries(vertex_stage_acceptance PRIVATE software_renderer)

if(MSVC)
    target_compile_options(graphics_math PRIVATE /utf-8)
    target_compile_options(vecmath PRIVATE /utf-8)
    target_compile_options(software_renderer PRIVATE /utf-8)
    target_compile_options(soft_renderer PRIVATE /utf-8)
    target_compile_options(obj_loader_acceptance PRIVATE /utf-8)
    target_compile_options(vertex_stage_acceptance PRIVATE /utf-8)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(graphics_math PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(vecmath PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(software_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(soft_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(obj_loader_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(vertex_stage_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
endif()

include(CTest)
if(BUILD_TESTING)
    add_test(NAME graphics_math_acceptance COMMAND vecmath)
    add_test(NAME software_renderer_skeleton_acceptance COMMAND soft_renderer)
    add_test(NAME obj_vertex_data_acceptance COMMAND obj_loader_acceptance)
    add_test(NAME vertex_shading_stage_acceptance COMMAND vertex_stage_acceptance)
endif()
