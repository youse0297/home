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
    src/Rasterizer.cpp
    src/Shading.cpp
    src/SoftwareRenderer.cpp
    src/Texture2D.cpp
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

add_executable(triangle_rasterizer_acceptance
    src/rasterizer_main.cpp
)
target_link_libraries(triangle_rasterizer_acceptance PRIVATE software_renderer)

add_executable(depth_buffer_acceptance
    src/depth_buffer_main.cpp
)
target_link_libraries(depth_buffer_acceptance PRIVATE software_renderer)

add_executable(texture_sampling_acceptance
    src/texture_sampling_main.cpp
)
target_link_libraries(texture_sampling_acceptance PRIVATE software_renderer)
target_compile_definitions(
    texture_sampling_acceptance
    PRIVATE TEXTURE_FIXTURE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/checker.ppm"
)

add_executable(surface_attributes_acceptance
    src/surface_attributes_main.cpp
)
target_link_libraries(surface_attributes_acceptance PRIVATE software_renderer)

add_executable(diffuse_exposure_acceptance
    src/diffuse_exposure_main.cpp
)
target_link_libraries(diffuse_exposure_acceptance PRIVATE software_renderer)

if(MSVC)
    target_compile_options(graphics_math PRIVATE /utf-8)
    target_compile_options(vecmath PRIVATE /utf-8)
    target_compile_options(software_renderer PRIVATE /utf-8)
    target_compile_options(soft_renderer PRIVATE /utf-8)
    target_compile_options(obj_loader_acceptance PRIVATE /utf-8)
    target_compile_options(vertex_stage_acceptance PRIVATE /utf-8)
    target_compile_options(triangle_rasterizer_acceptance PRIVATE /utf-8)
    target_compile_options(depth_buffer_acceptance PRIVATE /utf-8)
    target_compile_options(texture_sampling_acceptance PRIVATE /utf-8)
    target_compile_options(surface_attributes_acceptance PRIVATE /utf-8)
    target_compile_options(diffuse_exposure_acceptance PRIVATE /utf-8)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(graphics_math PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(vecmath PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(software_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(soft_renderer PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(obj_loader_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(vertex_stage_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(triangle_rasterizer_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(depth_buffer_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(texture_sampling_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(surface_attributes_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
    target_compile_options(diffuse_exposure_acceptance PRIVATE -finput-charset=UTF-8 -fexec-charset=UTF-8)
endif()

include(CTest)
if(BUILD_TESTING)
    add_test(NAME graphics_math_acceptance COMMAND vecmath)
    add_test(NAME software_renderer_skeleton_acceptance COMMAND soft_renderer)
    add_test(NAME obj_vertex_data_acceptance COMMAND obj_loader_acceptance)
    add_test(NAME vertex_shading_stage_acceptance COMMAND vertex_stage_acceptance)
    add_test(NAME triangle_rasterizer_acceptance COMMAND triangle_rasterizer_acceptance)
    add_test(NAME depth_buffer_acceptance COMMAND depth_buffer_acceptance)
    add_test(NAME texture_sampling_acceptance COMMAND texture_sampling_acceptance)
    add_test(NAME surface_attributes_acceptance COMMAND surface_attributes_acceptance)
    add_test(NAME diffuse_exposure_acceptance COMMAND diffuse_exposure_acceptance)
endif()
