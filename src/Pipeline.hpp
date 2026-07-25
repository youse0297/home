#pragma once

#include "Mat4.hpp"
#include "Vec3.hpp"

namespace Pipeline {

enum class ViewportOrigin {
    BottomLeft,
    TopLeft
};

struct Viewport {
    double x = 0.0;
    double y = 0.0;
    double width = 1.0;
    double height = 1.0;
    double minDepth = 0.0;
    double maxDepth = 1.0;
    ViewportOrigin origin = ViewportOrigin::TopLeft;
};

struct VertexResult {
    Vec4 world;
    Vec4 view;
    Vec4 clip;
    Vec3 ndc;
    Vec3 screen;
    bool insideClipVolume = false;
};

Mat4 composeMVP(const Mat4& model, const Mat4& view, const Mat4& projection);
Vec3 perspectiveDivide(const Vec4& clipPosition);
bool isInsideClipVolume(const Vec4& clipPosition);
Vec3 mapToViewport(const Vec3& ndcPosition, const Viewport& viewport);
VertexResult transformVertex(
    const Vec4& objectPosition,
    const Mat4& model,
    const Mat4& view,
    const Mat4& projection,
    const Viewport& viewport
);

} // namespace Pipeline
