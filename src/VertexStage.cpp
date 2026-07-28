#include "VertexStage.hpp"

#include <optional>
#include <stdexcept>
#include <string>

namespace SoftRenderer {

namespace {

void validateVertexIndex(
    const ObjMesh& mesh,
    const ObjVertexIndex& vertex,
    std::size_t triangleIndex,
    std::size_t cornerIndex
) {
    const std::string location =
        "triangle " + std::to_string(triangleIndex) +
        " corner " + std::to_string(cornerIndex);
    if (vertex.positionIndex >= mesh.positions.size()) {
        throw std::out_of_range(location + " position index is out of range");
    }
    if (vertex.hasTexCoord() && vertex.texCoordIndex >= mesh.texCoords.size()) {
        throw std::out_of_range(location + " texture coordinate index is out of range");
    }
    if (vertex.hasNormal() && vertex.normalIndex >= mesh.normals.size()) {
        throw std::out_of_range(location + " normal index is out of range");
    }
}

template <typename PlaneDistance>
bool allOutsidePlane(
    const ScreenTriangle& triangle,
    PlaneDistance planeDistance
) {
    for (const ShadedVertex& vertex : triangle.vertices) {
        if (planeDistance(vertex.transformed.clip) >= 0.0) {
            return false;
        }
    }
    return true;
}

TriangleClipStatus classifyTriangle(const ScreenTriangle& triangle) {
    bool fullyInside = true;
    for (const ShadedVertex& vertex : triangle.vertices) {
        fullyInside = fullyInside && vertex.transformed.insideClipVolume;
    }
    if (fullyInside) {
        return TriangleClipStatus::FullyInside;
    }

    const bool fullyOutside =
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.w; }) ||
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.x + clip.w; }) ||
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.w - clip.x; }) ||
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.y + clip.w; }) ||
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.w - clip.y; }) ||
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.z + clip.w; }) ||
        allOutsidePlane(triangle, [](const Vec4& clip) { return clip.w - clip.z; });
    return fullyOutside
        ? TriangleClipStatus::FullyOutside
        : TriangleClipStatus::RequiresClipping;
}

} // namespace

std::vector<ScreenTriangle> VertexStage::shade(
    const ObjMesh& mesh,
    const VertexStageUniforms& uniforms
) {
    std::vector<ScreenTriangle> output;
    output.reserve(mesh.triangles.size());
    std::vector<std::optional<Pipeline::VertexResult>> transformedPositions(
        mesh.positions.size()
    );

    for (std::size_t triangleIndex = 0;
         triangleIndex < mesh.triangles.size();
         ++triangleIndex) {
        const ObjTriangle& sourceTriangle = mesh.triangles[triangleIndex];
        ScreenTriangle triangle;
        triangle.sourceTriangleIndex = triangleIndex;

        for (std::size_t cornerIndex = 0; cornerIndex < 3; ++cornerIndex) {
            const ObjVertexIndex& sourceVertex = sourceTriangle.vertices[cornerIndex];
            validateVertexIndex(mesh, sourceVertex, triangleIndex, cornerIndex);

            std::optional<Pipeline::VertexResult>& cached =
                transformedPositions[sourceVertex.positionIndex];
            if (!cached.has_value()) {
                cached = Pipeline::transformVertex(
                    Vec4(mesh.positions[sourceVertex.positionIndex], 1.0),
                    uniforms.model,
                    uniforms.view,
                    uniforms.projection,
                    uniforms.viewport
                );
            }

            ShadedVertex& vertex = triangle.vertices[cornerIndex];
            vertex.source = sourceVertex;
            vertex.transformed = *cached;
            vertex.reciprocalW = 1.0 / vertex.transformed.clip.w;
        }

        triangle.clipStatus = classifyTriangle(triangle);
        output.push_back(triangle);
    }

    return output;
}

} // namespace SoftRenderer
