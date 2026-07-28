#pragma once

#include "ObjLoader.hpp"
#include "Pipeline.hpp"

#include <array>
#include <cstddef>
#include <vector>

namespace SoftRenderer {

enum class TriangleClipStatus {
    FullyInside,
    RequiresClipping,
    FullyOutside
};

struct VertexStageUniforms {
    Mat4 model = Mat4::identity();
    Mat4 view = Mat4::identity();
    Mat4 projection = Mat4::identity();
    Pipeline::Viewport viewport{};
};

struct ShadedVertex {
    ObjVertexIndex source;
    Pipeline::VertexResult transformed;
    double reciprocalW = 0.0;
};

struct ScreenTriangle {
    std::array<ShadedVertex, 3> vertices;
    std::size_t sourceTriangleIndex = 0;
    TriangleClipStatus clipStatus = TriangleClipStatus::RequiresClipping;
};

class VertexStage {
public:
    static std::vector<ScreenTriangle> shade(
        const ObjMesh& mesh,
        const VertexStageUniforms& uniforms
    );
};

} // namespace SoftRenderer
