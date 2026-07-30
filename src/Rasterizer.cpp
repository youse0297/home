#include "Rasterizer.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace SoftRenderer {

namespace {

constexpr double kDegenerateAreaEpsilon = 1e-12;

Vec2 screenPosition(const ShadedVertex& vertex) {
    return Vec2(vertex.transformed.screen.x, vertex.transformed.screen.y);
}

void requireFramebufferDimensions(std::size_t width, std::size_t height) {
    if (width == 0 || height == 0) {
        throw std::invalid_argument("rasterizer dimensions must be non-zero");
    }
}

void requireFiniteScreenPositions(const ScreenTriangle& triangle) {
    for (const ShadedVertex& vertex : triangle.vertices) {
        const Vec3& screen = vertex.transformed.screen;
        if (!std::isfinite(screen.x) || !std::isfinite(screen.y)) {
            throw std::invalid_argument("rasterizer screen positions must be finite");
        }
    }
}

void requireRasterAttributes(const ScreenTriangle& triangle) {
    for (const ShadedVertex& vertex : triangle.vertices) {
        if (!std::isfinite(vertex.transformed.screen.z) ||
            !std::isfinite(vertex.reciprocalW)) {
            throw std::invalid_argument("rasterizer interpolation values must be finite");
        }
        if (vertex.reciprocalW <= 0.0) {
            throw std::invalid_argument("rasterizer reciprocal w must be positive");
        }
    }
}

std::size_t lowerPixel(double coordinate, std::size_t extent) {
    if (coordinate <= 0.0) {
        return 0;
    }
    if (coordinate >= static_cast<double>(extent)) {
        return extent;
    }
    return static_cast<std::size_t>(std::floor(coordinate));
}

std::size_t upperPixel(double coordinate, std::size_t extent) {
    if (coordinate <= 0.0) {
        return 0;
    }
    if (coordinate >= static_cast<double>(extent)) {
        return extent;
    }
    return static_cast<std::size_t>(std::ceil(coordinate));
}

bool isTopLeftEdge(const Vec2& start, const Vec2& end) noexcept {
    const double deltaX = end.x - start.x;
    const double deltaY = end.y - start.y;
    return deltaY < 0.0 || (deltaY == 0.0 && deltaX > 0.0);
}

bool acceptsEdge(double edgeValue, bool topLeft) noexcept {
    return edgeValue > 0.0 || (edgeValue == 0.0 && topLeft);
}

double triangleArea(const ScreenTriangle& triangle) {
    return Rasterizer::edgeFunction(
        screenPosition(triangle.vertices[0]),
        screenPosition(triangle.vertices[1]),
        screenPosition(triangle.vertices[2])
    );
}

bool shouldCull(double signedArea, const RasterizerOptions& options) {
    bool frontFacing = false;
    switch (options.frontFace) {
    case FrontFace::Clockwise:
        frontFacing = signedArea > 0.0;
        break;
    case FrontFace::CounterClockwise:
        frontFacing = signedArea < 0.0;
        break;
    default:
        throw std::invalid_argument("rasterizer front face is invalid");
    }

    switch (options.cullMode) {
    case CullMode::None:
        return false;
    case CullMode::Front:
        return frontFacing;
    case CullMode::Back:
        return !frontFacing;
    default:
        throw std::invalid_argument("rasterizer cull mode is invalid");
    }
}

} // namespace

bool PixelBounds::empty() const noexcept {
    return minX >= maxXExclusive || minY >= maxYExclusive;
}

double Rasterizer::edgeFunction(
    const Vec2& start,
    const Vec2& end,
    const Vec2& point
) noexcept {
    return (end.x - start.x) * (point.y - start.y) -
           (end.y - start.y) * (point.x - start.x);
}

PixelBounds Rasterizer::boundingBox(
    const ScreenTriangle& triangle,
    std::size_t framebufferWidth,
    std::size_t framebufferHeight
) {
    requireFramebufferDimensions(framebufferWidth, framebufferHeight);
    requireFiniteScreenPositions(triangle);

    const double minX = std::min({
        triangle.vertices[0].transformed.screen.x,
        triangle.vertices[1].transformed.screen.x,
        triangle.vertices[2].transformed.screen.x
    });
    const double minY = std::min({
        triangle.vertices[0].transformed.screen.y,
        triangle.vertices[1].transformed.screen.y,
        triangle.vertices[2].transformed.screen.y
    });
    const double maxX = std::max({
        triangle.vertices[0].transformed.screen.x,
        triangle.vertices[1].transformed.screen.x,
        triangle.vertices[2].transformed.screen.x
    });
    const double maxY = std::max({
        triangle.vertices[0].transformed.screen.y,
        triangle.vertices[1].transformed.screen.y,
        triangle.vertices[2].transformed.screen.y
    });

    return PixelBounds{
        lowerPixel(minX, framebufferWidth),
        lowerPixel(minY, framebufferHeight),
        upperPixel(maxX, framebufferWidth),
        upperPixel(maxY, framebufferHeight)
    };
}

std::array<double, 3> Rasterizer::barycentricCoordinates(
    const ScreenTriangle& triangle,
    const Vec2& point
) {
    requireFiniteScreenPositions(triangle);
    if (!std::isfinite(point.x) || !std::isfinite(point.y)) {
        throw std::invalid_argument("barycentric point must be finite");
    }

    const Vec2 positions[3] = {
        screenPosition(triangle.vertices[0]),
        screenPosition(triangle.vertices[1]),
        screenPosition(triangle.vertices[2])
    };
    const double area = edgeFunction(positions[0], positions[1], positions[2]);
    if (!std::isfinite(area) || std::abs(area) <= kDegenerateAreaEpsilon) {
        throw std::domain_error("barycentric coordinates require a non-degenerate triangle");
    }

    return {
        edgeFunction(positions[1], positions[2], point) / area,
        edgeFunction(positions[2], positions[0], point) / area,
        edgeFunction(positions[0], positions[1], point) / area
    };
}

std::vector<RasterSample> Rasterizer::rasterize(
    const ScreenTriangle& triangle,
    std::size_t framebufferWidth,
    std::size_t framebufferHeight,
    const RasterizerOptions& options
) {
    requireFramebufferDimensions(framebufferWidth, framebufferHeight);
    if (triangle.clipStatus == TriangleClipStatus::FullyOutside) {
        return {};
    }
    if (triangle.clipStatus == TriangleClipStatus::RequiresClipping) {
        throw std::invalid_argument("triangle must be clipped before rasterization");
    }
    requireFiniteScreenPositions(triangle);
    requireRasterAttributes(triangle);

    const double originalArea = triangleArea(triangle);
    if (!std::isfinite(originalArea)) {
        throw std::invalid_argument("rasterizer triangle area must be finite");
    }
    if (std::abs(originalArea) <= kDegenerateAreaEpsilon) {
        return {};
    }
    if (shouldCull(originalArea, options)) {
        return {};
    }

    std::array<std::size_t, 3> order{0, 1, 2};
    if (originalArea < 0.0) {
        std::swap(order[1], order[2]);
    }
    const Vec2 positions[3] = {
        screenPosition(triangle.vertices[order[0]]),
        screenPosition(triangle.vertices[order[1]]),
        screenPosition(triangle.vertices[order[2]])
    };
    const double area = std::abs(originalArea);
    const PixelBounds bounds = boundingBox(
        triangle,
        framebufferWidth,
        framebufferHeight
    );

    std::vector<RasterSample> samples;
    for (std::size_t y = bounds.minY; y < bounds.maxYExclusive; ++y) {
        for (std::size_t x = bounds.minX; x < bounds.maxXExclusive; ++x) {
            const Vec2 point(
                static_cast<double>(x) + 0.5,
                static_cast<double>(y) + 0.5
            );
            const double orientedEdges[3] = {
                edgeFunction(positions[1], positions[2], point),
                edgeFunction(positions[2], positions[0], point),
                edgeFunction(positions[0], positions[1], point)
            };
            if (!acceptsEdge(
                    orientedEdges[0],
                    isTopLeftEdge(positions[1], positions[2])
                ) ||
                !acceptsEdge(
                    orientedEdges[1],
                    isTopLeftEdge(positions[2], positions[0])
                ) ||
                !acceptsEdge(
                    orientedEdges[2],
                    isTopLeftEdge(positions[0], positions[1])
                )) {
                continue;
            }

            RasterSample sample;
            sample.x = x;
            sample.y = y;
            for (std::size_t index = 0; index < 3; ++index) {
                sample.barycentric[order[index]] = orientedEdges[index] / area;
            }

            for (std::size_t index = 0; index < 3; ++index) {
                sample.reciprocalW += sample.barycentric[index] *
                    triangle.vertices[index].reciprocalW;
                sample.depth += sample.barycentric[index] *
                    triangle.vertices[index].transformed.screen.z;
            }
            if (!std::isfinite(sample.reciprocalW) || sample.reciprocalW <= 0.0 ||
                !std::isfinite(sample.depth)) {
                throw std::domain_error("rasterizer interpolation produced an invalid value");
            }
            for (std::size_t index = 0; index < 3; ++index) {
                sample.perspectiveWeights[index] =
                    sample.barycentric[index] *
                    triangle.vertices[index].reciprocalW /
                    sample.reciprocalW;
            }
            samples.push_back(sample);
        }
    }
    return samples;
}

} // namespace SoftRenderer
