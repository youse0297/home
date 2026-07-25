#include "Pipeline.hpp"

#include <cmath>
#include <stdexcept>

namespace Pipeline {

namespace {

constexpr double kEpsilon = 1e-12;

void validateViewport(const Viewport& viewport) {
    if (!std::isfinite(viewport.x) || !std::isfinite(viewport.y) ||
        !std::isfinite(viewport.width) || !std::isfinite(viewport.height) ||
        !std::isfinite(viewport.minDepth) || !std::isfinite(viewport.maxDepth)) {
        throw std::invalid_argument("viewport values must be finite");
    }
    if (viewport.width <= 0.0 || viewport.height <= 0.0) {
        throw std::invalid_argument("viewport width and height must be positive");
    }
    if (viewport.maxDepth < viewport.minDepth) {
        throw std::invalid_argument("viewport maxDepth must be >= minDepth");
    }
}

} // namespace

Mat4 composeMVP(const Mat4& model, const Mat4& view, const Mat4& projection) {
    return projection * view * model;
}

Vec3 perspectiveDivide(const Vec4& clipPosition) {
    if (!std::isfinite(clipPosition.x) || !std::isfinite(clipPosition.y) ||
        !std::isfinite(clipPosition.z) || !std::isfinite(clipPosition.w) ||
        std::abs(clipPosition.w) <= kEpsilon) {
        throw std::domain_error("perspective divide requires a finite non-zero w");
    }
    return Vec3(
        clipPosition.x / clipPosition.w,
        clipPosition.y / clipPosition.w,
        clipPosition.z / clipPosition.w
    );
}

bool isInsideClipVolume(const Vec4& clipPosition) {
    const double w = clipPosition.w;
    if (!std::isfinite(w) || w <= 0.0) {
        return false;
    }
    return clipPosition.x >= -w && clipPosition.x <= w &&
           clipPosition.y >= -w && clipPosition.y <= w &&
           clipPosition.z >= -w && clipPosition.z <= w;
}

Vec3 mapToViewport(const Vec3& ndcPosition, const Viewport& viewport) {
    validateViewport(viewport);
    if (!std::isfinite(ndcPosition.x) || !std::isfinite(ndcPosition.y) ||
        !std::isfinite(ndcPosition.z)) {
        throw std::invalid_argument("NDC position must be finite");
    }

    const double normalizedX = ndcPosition.x * 0.5 + 0.5;
    const double normalizedY = ndcPosition.y * 0.5 + 0.5;
    const double normalizedZ = ndcPosition.z * 0.5 + 0.5;

    const double screenX = viewport.x + normalizedX * viewport.width;
    const double screenY = viewport.origin == ViewportOrigin::TopLeft
        ? viewport.y + (1.0 - normalizedY) * viewport.height
        : viewport.y + normalizedY * viewport.height;
    const double screenZ = viewport.minDepth +
        normalizedZ * (viewport.maxDepth - viewport.minDepth);

    return Vec3(screenX, screenY, screenZ);
}

VertexResult transformVertex(
    const Vec4& objectPosition,
    const Mat4& model,
    const Mat4& viewMatrix,
    const Mat4& projection,
    const Viewport& viewport
) {
    VertexResult result;
    result.world = model * objectPosition;
    result.view = viewMatrix * result.world;
    result.clip = projection * result.view;
    result.insideClipVolume = isInsideClipVolume(result.clip);
    result.ndc = perspectiveDivide(result.clip);
    result.screen = mapToViewport(result.ndc, viewport);
    return result;
}

} // namespace Pipeline
