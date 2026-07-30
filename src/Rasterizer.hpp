#pragma once

#include "VertexStage.hpp"

#include <array>
#include <cstddef>
#include <vector>

namespace SoftRenderer {

enum class CullMode {
    None,
    Front,
    Back
};

enum class FrontFace {
    Clockwise,
    CounterClockwise
};

struct RasterizerOptions {
    CullMode cullMode = CullMode::None;
    FrontFace frontFace = FrontFace::Clockwise;
};

struct PixelBounds {
    std::size_t minX = 0;
    std::size_t minY = 0;
    std::size_t maxXExclusive = 0;
    std::size_t maxYExclusive = 0;

    bool empty() const noexcept;
};

struct RasterSample {
    std::size_t x = 0;
    std::size_t y = 0;
    std::array<double, 3> barycentric{};
    std::array<double, 3> perspectiveWeights{};
    double reciprocalW = 0.0;
    double depth = 0.0;

    template <typename T>
    T interpolatePerspective(const std::array<T, 3>& values) const {
        return values[0] * perspectiveWeights[0] +
               values[1] * perspectiveWeights[1] +
               values[2] * perspectiveWeights[2];
    }
};

class Rasterizer {
public:
    static double edgeFunction(
        const Vec2& start,
        const Vec2& end,
        const Vec2& point
    ) noexcept;

    static PixelBounds boundingBox(
        const ScreenTriangle& triangle,
        std::size_t framebufferWidth,
        std::size_t framebufferHeight
    );

    static std::array<double, 3> barycentricCoordinates(
        const ScreenTriangle& triangle,
        const Vec2& point
    );

    static std::vector<RasterSample> rasterize(
        const ScreenTriangle& triangle,
        std::size_t framebufferWidth,
        std::size_t framebufferHeight,
        const RasterizerOptions& options = RasterizerOptions{}
    );
};

} // namespace SoftRenderer
