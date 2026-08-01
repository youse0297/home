#include "VertexStage.hpp"

#include "TangentSpace.hpp"

#include <cmath>
#include <optional>
#include <stdexcept>
#include <string>

namespace SoftRenderer {

namespace {

constexpr double kSurfaceEpsilon = 1e-12;

struct TriangleSurfaceFrame {
    Vec3 geometricNormal;
    Vec3 tangent;
    Vec3 bitangent;
    bool hasGeometricNormal = false;
    bool hasTangentFrame = false;
};

bool isFinite(const Vec2& value) {
    return std::isfinite(value.x) && std::isfinite(value.y);
}

bool isFinite(const Vec3& value) {
    return std::isfinite(value.x) &&
           std::isfinite(value.y) &&
           std::isfinite(value.z);
}

bool hasUsableLength(const Vec3& value) {
    const double lengthSquared = value.lengthSquared();
    return std::isfinite(lengthSquared) &&
           lengthSquared > kSurfaceEpsilon;
}

Vec3 requireUnitVector(const Vec3& value, const std::string& message) {
    if (!isFinite(value) || !hasUsableLength(value)) {
        throw std::invalid_argument(message);
    }
    return value.normalized();
}

std::string cornerLocation(
    std::size_t triangleIndex,
    std::size_t cornerIndex
) {
    return "triangle " + std::to_string(triangleIndex) +
           " corner " + std::to_string(cornerIndex);
}

void validateVertexIndex(
    const ObjMesh& mesh,
    const ObjVertexIndex& vertex,
    std::size_t triangleIndex,
    std::size_t cornerIndex
) {
    const std::string location = cornerLocation(triangleIndex, cornerIndex);
    if (vertex.positionIndex >= mesh.positions.size()) {
        throw std::out_of_range(location + " position index is out of range");
    }
    if (vertex.hasTexCoord() && vertex.texCoordIndex >= mesh.texCoords.size()) {
        throw std::out_of_range(location + " texture coordinate index is out of range");
    }
    if (vertex.hasNormal() && vertex.normalIndex >= mesh.normals.size()) {
        throw std::out_of_range(location + " normal index is out of range");
    }
    if (!isFinite(mesh.positions[vertex.positionIndex])) {
        throw std::invalid_argument(location + " position must be finite");
    }
    if (vertex.hasTexCoord() && !isFinite(mesh.texCoords[vertex.texCoordIndex])) {
        throw std::invalid_argument(location + " texture coordinate must be finite");
    }
    if (vertex.hasNormal()) {
        requireUnitVector(
            mesh.normals[vertex.normalIndex],
            location + " normal must be finite and non-zero"
        );
    }
}

TriangleSurfaceFrame buildSurfaceFrame(
    const ObjMesh& mesh,
    const ObjTriangle& triangle,
    std::size_t triangleIndex
) {
    TriangleSurfaceFrame frame;
    const Vec3& position0 = mesh.positions[triangle.vertices[0].positionIndex];
    const Vec3& position1 = mesh.positions[triangle.vertices[1].positionIndex];
    const Vec3& position2 = mesh.positions[triangle.vertices[2].positionIndex];
    const Vec3 edge1 = position1 - position0;
    const Vec3 edge2 = position2 - position0;
    const Vec3 geometricNormal = edge1.cross(edge2);
    if (!isFinite(geometricNormal)) {
        throw std::invalid_argument(
            "triangle " + std::to_string(triangleIndex) +
            " geometric normal must be finite"
        );
    }
    if (hasUsableLength(geometricNormal)) {
        frame.geometricNormal = geometricNormal.normalized();
        frame.hasGeometricNormal = true;
    }

    for (const ObjVertexIndex& vertex : triangle.vertices) {
        if (!vertex.hasTexCoord()) {
            return frame;
        }
    }

    const Vec2& uv0 = mesh.texCoords[triangle.vertices[0].texCoordIndex];
    const Vec2& uv1 = mesh.texCoords[triangle.vertices[1].texCoordIndex];
    const Vec2& uv2 = mesh.texCoords[triangle.vertices[2].texCoordIndex];
    const Vec2 deltaUv1 = uv1 - uv0;
    const Vec2 deltaUv2 = uv2 - uv0;
    const double determinant = deltaUv1.x * deltaUv2.y -
                               deltaUv1.y * deltaUv2.x;
    if (!std::isfinite(determinant)) {
        throw std::invalid_argument(
            "triangle " + std::to_string(triangleIndex) +
            " UV derivatives must be finite"
        );
    }
    if (std::abs(determinant) <= kSurfaceEpsilon) {
        return frame;
    }

    const double inverseDeterminant = 1.0 / determinant;
    frame.tangent = (
        edge1 * deltaUv2.y - edge2 * deltaUv1.y
    ) * inverseDeterminant;
    frame.bitangent = (
        edge2 * deltaUv1.x - edge1 * deltaUv2.x
    ) * inverseDeterminant;
    if (!isFinite(frame.tangent) || !isFinite(frame.bitangent)) {
        throw std::invalid_argument(
            "triangle " + std::to_string(triangleIndex) +
            " tangent frame must be finite"
        );
    }
    frame.hasTangentFrame =
        hasUsableLength(frame.tangent) &&
        hasUsableLength(frame.bitangent);
    return frame;
}

void populateSurfaceAttributes(
    ShadedVertex& vertex,
    const ObjMesh& mesh,
    const ObjVertexIndex& sourceVertex,
    const TriangleSurfaceFrame& frame,
    const VertexStageUniforms& uniforms,
    std::optional<Mat3>& normalMatrix,
    std::size_t triangleIndex,
    std::size_t cornerIndex
) {
    if (sourceVertex.hasTexCoord()) {
        vertex.texCoord = mesh.texCoords[sourceVertex.texCoordIndex];
        vertex.hasTexCoord = true;
    }

    Vec3 objectNormal;
    if (sourceVertex.hasNormal()) {
        objectNormal = requireUnitVector(
            mesh.normals[sourceVertex.normalIndex],
            cornerLocation(triangleIndex, cornerIndex) +
                " normal must be finite and non-zero"
        );
    } else if (uniforms.generateMissingNormals && frame.hasGeometricNormal) {
        objectNormal = frame.geometricNormal;
        vertex.normalWasGenerated = true;
    } else {
        return;
    }

    if (!normalMatrix.has_value()) {
        normalMatrix = TangentSpace::makeNormalMatrix(uniforms.model);
    }
    vertex.worldNormal = TangentSpace::transformNormal(*normalMatrix, objectNormal);
    vertex.hasNormal = true;

    if (!frame.hasTangentFrame) {
        return;
    }
    Vec3 objectTangent = frame.tangent -
        objectNormal * frame.tangent.dot(objectNormal);
    if (!isFinite(objectTangent) || !hasUsableLength(objectTangent)) {
        return;
    }
    objectTangent = objectTangent.normalized();

    Vec3 worldTangent = TangentSpace::transformDirection(
        uniforms.model,
        objectTangent
    );
    worldTangent -= vertex.worldNormal * worldTangent.dot(vertex.worldNormal);
    if (!isFinite(worldTangent) || !hasUsableLength(worldTangent)) {
        return;
    }
    vertex.worldTangent = worldTangent.normalized();

    const Vec3 worldBitangent = TangentSpace::transformDirection(
        uniforms.model,
        frame.bitangent
    );
    const double handedness = vertex.worldNormal
        .cross(vertex.worldTangent)
        .dot(worldBitangent);
    if (!std::isfinite(handedness) ||
        std::abs(handedness) <= kSurfaceEpsilon) {
        return;
    }
    vertex.tangentSign = handedness < 0.0 ? -1.0 : 1.0;
    vertex.hasTangent = true;
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
    std::optional<Mat3> normalMatrix;

    for (std::size_t triangleIndex = 0;
         triangleIndex < mesh.triangles.size();
         ++triangleIndex) {
        const ObjTriangle& sourceTriangle = mesh.triangles[triangleIndex];
        ScreenTriangle triangle;
        triangle.sourceTriangleIndex = triangleIndex;

        for (std::size_t cornerIndex = 0; cornerIndex < 3; ++cornerIndex) {
            validateVertexIndex(
                mesh,
                sourceTriangle.vertices[cornerIndex],
                triangleIndex,
                cornerIndex
            );
        }
        const TriangleSurfaceFrame surfaceFrame = buildSurfaceFrame(
            mesh,
            sourceTriangle,
            triangleIndex
        );

        for (std::size_t cornerIndex = 0; cornerIndex < 3; ++cornerIndex) {
            const ObjVertexIndex& sourceVertex = sourceTriangle.vertices[cornerIndex];

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
            populateSurfaceAttributes(
                vertex,
                mesh,
                sourceVertex,
                surfaceFrame,
                uniforms,
                normalMatrix,
                triangleIndex,
                cornerIndex
            );
        }

        triangle.clipStatus = classifyTriangle(triangle);
        output.push_back(triangle);
    }

    return output;
}

} // namespace SoftRenderer
