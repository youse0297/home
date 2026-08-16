function(add_acceptance_target target_name source_name)
    add_executable(${target_name} acceptance/${source_name})
    target_link_libraries(${target_name} PRIVATE SoftwareRendererLab::software_renderer)
    configure_project_target(${target_name})
endfunction()

add_acceptance_target(obj_loader_acceptance obj_loader_acceptance.cpp)
target_compile_definitions(
    obj_loader_acceptance
    PRIVATE
        OBJ_FIXTURE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/data/vertex_data.obj"
)

add_acceptance_target(vertex_stage_acceptance vertex_stage_acceptance.cpp)
add_acceptance_target(triangle_rasterizer_acceptance triangle_rasterizer_acceptance.cpp)
add_acceptance_target(depth_buffer_acceptance depth_buffer_acceptance.cpp)

add_acceptance_target(texture_sampling_acceptance texture_sampling_acceptance.cpp)
target_compile_definitions(
    texture_sampling_acceptance
    PRIVATE
        TEXTURE_FIXTURE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/data/checker.ppm"
)

add_acceptance_target(surface_attributes_acceptance surface_attributes_acceptance.cpp)
add_acceptance_target(diffuse_exposure_acceptance diffuse_exposure_acceptance.cpp)
add_acceptance_target(ggx_brdf_acceptance ggx_brdf_acceptance.cpp)
add_acceptance_target(material_workflow_acceptance material_workflow_acceptance.cpp)
add_acceptance_target(release_acceptance release_acceptance.cpp)

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
    add_test(NAME ggx_brdf_acceptance COMMAND ggx_brdf_acceptance)
    add_test(NAME material_workflow_acceptance COMMAND material_workflow_acceptance)
    add_test(
        NAME release_acceptance
        COMMAND release_acceptance "${CMAKE_BINARY_DIR}/release_acceptance.ppm"
    )
endif()
