set(GRAPHICS_MATH_SOURCES
    Camera.cpp
    Fresnel.cpp
    Mat3.cpp
    Mat4.cpp
    Pipeline.cpp
    Projection.cpp
    TangentSpace.cpp
    Transform.cpp
    Vec2.cpp
    Vec3.cpp
    Vec4.cpp
    VectorUtils.cpp
)

add_library(graphics_math ${GRAPHICS_MATH_SOURCES})
add_library(SoftwareRendererLab::graphics_math ALIAS graphics_math)
target_include_directories(
    graphics_math
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)
configure_project_target(graphics_math)

set(SOFTWARE_RENDERER_SOURCES
    Framebuffer.cpp
    ImageIO.cpp
    Material.cpp
    ObjLoader.cpp
    Rasterizer.cpp
    Shading.cpp
    SoftwareRenderer.cpp
    Texture2D.cpp
    VertexStage.cpp
)

add_library(software_renderer ${SOFTWARE_RENDERER_SOURCES})
add_library(SoftwareRendererLab::software_renderer ALIAS software_renderer)
target_include_directories(
    software_renderer
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)
target_link_libraries(
    software_renderer
    PUBLIC
        SoftwareRendererLab::graphics_math
)
configure_project_target(software_renderer)
