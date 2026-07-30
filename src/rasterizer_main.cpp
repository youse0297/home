#include "Rasterizer.hpp"

#include <array>
#include <cmath>
#include <functional>
#include <iostream>
#include <limits>
#include <set>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace {

void expect(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void expectNear(const std::string& label, double actual, double expected) {
    constexpr double tolerance = 1e-9;
    if (!std::isfinite(actual) || std::abs(actual - expected) > tolerance) {
        throw std::runtime_error(
            label + " expected " + std::to_string(expected) +
            ", got " + std::to_string(actual)
        );
    }
}

template <typename Exception>
void expectFailure(
    const std::string& label,
    const std::string& expectedMessage,
    const std::function<void()>& operation
) {
    bool rejected = false;
    try {
        operation();
    } catch (const Exception& error) {
        rejected = std::string(error.what()).find(expectedMessage) != std::string::npos;
    }
    expect(rejected, label + " was not rejected with the expected error");
}

SoftRenderer::ScreenTriangle makeTriangle(
    const std::array<Vec3, 3>& positions,
    const std::array<double, 3>& reciprocalW = {1.0, 1.0, 1.0}
) {
    SoftRenderer::ScreenTriangle triangle;
    triangle.clipStatus = SoftRenderer::TriangleClipStatus::FullyInside;
    for (std::size_t index = 0; index < 3; ++index) {
        triangle.vertices[index].transformed.screen = positions[index];
        triangle.vertices[index].reciprocalW = reciprocalW[index];
    }
    return triangle;
}

const SoftRenderer::RasterSample& findSample(
    const std::vector<SoftRenderer::RasterSample>& samples,
    std::size_t x,
    std::size_t y
) {
    for (const SoftRenderer::RasterSample& sample : samples) {
        if (sample.x == x && sample.y == y) {
            return sample;
        }
    }
    throw std::runtime_error("expected raster sample was not generated");
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::ScreenTriangle triangle = makeTriangle(
            {Vec3(1.0, 1.0, 0.2), Vec3(5.0, 1.0, 0.6), Vec3(1.0, 5.0, 1.0)},
            {1.0, 0.5, 0.25}
        );
        expectNear(
            "edge function",
            SoftRenderer::Rasterizer::edgeFunction(
                Vec2(1.0, 1.0),
                Vec2(5.0, 1.0),
                Vec2(1.0, 5.0)
            ),
            16.0
        );

        const SoftRenderer::PixelBounds bounds =
            SoftRenderer::Rasterizer::boundingBox(triangle, 8, 8);
        expect(
            bounds.minX == 1 && bounds.minY == 1 &&
            bounds.maxXExclusive == 5 && bounds.maxYExclusive == 5,
            "clamped triangle bounding box is incorrect"
        );

        const std::array<double, 3> barycentric =
            SoftRenderer::Rasterizer::barycentricCoordinates(
                triangle,
                Vec2(1.5, 1.5)
            );
        expectNear("barycentric 0", barycentric[0], 0.75);
        expectNear("barycentric 1", barycentric[1], 0.125);
        expectNear("barycentric 2", barycentric[2], 0.125);

        SoftRenderer::ScreenTriangle geometryOnly = triangle;
        for (SoftRenderer::ShadedVertex& vertex : geometryOnly.vertices) {
            vertex.transformed.screen.z = std::numeric_limits<double>::infinity();
            vertex.reciprocalW = 0.0;
        }
        expect(
            !SoftRenderer::Rasterizer::boundingBox(geometryOnly, 8, 8).empty(),
            "geometry-only bounding box unexpectedly required interpolation attributes"
        );
        expectNear(
            "geometry-only barycentric 0",
            SoftRenderer::Rasterizer::barycentricCoordinates(
                geometryOnly,
                Vec2(1.5, 1.5)
            )[0],
            0.75
        );

        const std::vector<SoftRenderer::RasterSample> samples =
            SoftRenderer::Rasterizer::rasterize(triangle, 8, 8);
        expect(samples.size() == 6, "right triangle coverage count is incorrect");
        const SoftRenderer::RasterSample& first = findSample(samples, 1, 1);
        expectNear("sample barycentric 0", first.barycentric[0], 0.75);
        expectNear("sample barycentric 1", first.barycentric[1], 0.125);
        expectNear("sample barycentric 2", first.barycentric[2], 0.125);
        expectNear("sample reciprocal w", first.reciprocalW, 27.0 / 32.0);
        expectNear("perspective weight 0", first.perspectiveWeights[0], 8.0 / 9.0);
        expectNear("perspective weight 1", first.perspectiveWeights[1], 2.0 / 27.0);
        expectNear("perspective weight 2", first.perspectiveWeights[2], 1.0 / 27.0);
        expectNear("linearly interpolated screen depth", first.depth, 0.35);

        const Vec2 interpolatedUv = first.interpolatePerspective<Vec2>(
            {Vec2(0.0, 0.0), Vec2(1.0, 0.0), Vec2(0.0, 1.0)}
        );
        expectNear("perspective-correct uv.x", interpolatedUv.x, 2.0 / 27.0);
        expectNear("perspective-correct uv.y", interpolatedUv.y, 1.0 / 27.0);

        const SoftRenderer::ScreenTriangle reversed = makeTriangle(
            {Vec3(1.0, 1.0, 0.2), Vec3(1.0, 5.0, 1.0), Vec3(5.0, 1.0, 0.6)},
            {1.0, 0.25, 0.5}
        );
        const std::vector<SoftRenderer::RasterSample> reversedSamples =
            SoftRenderer::Rasterizer::rasterize(reversed, 8, 8);
        expect(reversedSamples.size() == samples.size(),
               "coverage changed when triangle winding was reversed");
        const SoftRenderer::RasterSample& reversedFirst =
            findSample(reversedSamples, 1, 1);
        const Vec2 reversedUv = reversedFirst.interpolatePerspective<Vec2>(
            {Vec2(0.0, 0.0), Vec2(0.0, 1.0), Vec2(1.0, 0.0)}
        );
        expectNear("reversed perspective-correct uv.x", reversedUv.x, interpolatedUv.x);
        expectNear("reversed perspective-correct uv.y", reversedUv.y, interpolatedUv.y);

        const SoftRenderer::ScreenTriangle upperRight = makeTriangle(
            {Vec3(1.0, 1.0, 0.5), Vec3(5.0, 1.0, 0.5), Vec3(5.0, 5.0, 0.5)}
        );
        const SoftRenderer::ScreenTriangle lowerLeft = makeTriangle(
            {Vec3(1.0, 1.0, 0.5), Vec3(5.0, 5.0, 0.5), Vec3(1.0, 5.0, 0.5)}
        );
        const std::vector<SoftRenderer::RasterSample> upperRightSamples =
            SoftRenderer::Rasterizer::rasterize(upperRight, 8, 8);
        const std::vector<SoftRenderer::RasterSample> lowerLeftSamples =
            SoftRenderer::Rasterizer::rasterize(lowerLeft, 8, 8);
        std::set<std::pair<std::size_t, std::size_t>> squareCoverage;
        for (const SoftRenderer::RasterSample& sample : upperRightSamples) {
            squareCoverage.emplace(sample.x, sample.y);
        }
        for (const SoftRenderer::RasterSample& sample : lowerLeftSamples) {
            expect(
                squareCoverage.emplace(sample.x, sample.y).second,
                "shared edge pixel was covered by both triangles"
            );
        }
        expect(squareCoverage.size() == 16,
               "two triangles did not cover the complete 4x4 square");

        const SoftRenderer::ScreenTriangle clippedBounds = makeTriangle(
            {Vec3(-2.0, -2.0, 0.5), Vec3(3.0, -2.0, 0.5), Vec3(-2.0, 3.0, 0.5)}
        );
        const SoftRenderer::PixelBounds clipped =
            SoftRenderer::Rasterizer::boundingBox(clippedBounds, 8, 8);
        expect(clipped.minX == 0 && clipped.minY == 0 &&
               clipped.maxXExclusive == 3 && clipped.maxYExclusive == 3,
               "bounding box was not clamped to the framebuffer");

        const SoftRenderer::ScreenTriangle degenerate = makeTriangle(
            {Vec3(1.0, 1.0, 0.5), Vec3(2.0, 2.0, 0.5), Vec3(3.0, 3.0, 0.5)}
        );
        expect(SoftRenderer::Rasterizer::rasterize(degenerate, 8, 8).empty(),
               "degenerate triangle generated coverage");
        expectFailure<std::domain_error>(
            "degenerate barycentric coordinates",
            "non-degenerate triangle",
            [&]() {
                SoftRenderer::Rasterizer::barycentricCoordinates(
                    degenerate,
                    Vec2(1.5, 1.5)
                );
            }
        );

        SoftRenderer::ScreenTriangle outside = triangle;
        outside.clipStatus = SoftRenderer::TriangleClipStatus::FullyOutside;
        outside.vertices[0].reciprocalW = -1.0;
        expect(SoftRenderer::Rasterizer::rasterize(outside, 8, 8).empty(),
               "fully outside triangle generated coverage");

        SoftRenderer::ScreenTriangle requiresClipping = triangle;
        requiresClipping.clipStatus = SoftRenderer::TriangleClipStatus::RequiresClipping;
        expectFailure<std::invalid_argument>(
            "unclipped triangle",
            "must be clipped",
            [&]() { SoftRenderer::Rasterizer::rasterize(requiresClipping, 8, 8); }
        );
        expectFailure<std::invalid_argument>(
            "zero framebuffer dimensions",
            "dimensions must be non-zero",
            [&]() { SoftRenderer::Rasterizer::rasterize(triangle, 0, 8); }
        );

        SoftRenderer::ScreenTriangle invalidReciprocalW = triangle;
        invalidReciprocalW.vertices[0].reciprocalW = 0.0;
        expectFailure<std::invalid_argument>(
            "invalid reciprocal w",
            "reciprocal w must be positive",
            [&]() { SoftRenderer::Rasterizer::rasterize(invalidReciprocalW, 8, 8); }
        );

        SoftRenderer::ScreenTriangle nonFinite = triangle;
        nonFinite.vertices[0].transformed.screen.x =
            std::numeric_limits<double>::infinity();
        expectFailure<std::invalid_argument>(
            "non-finite screen position",
            "screen positions must be finite",
            [&]() { SoftRenderer::Rasterizer::rasterize(nonFinite, 8, 8); }
        );

        std::cout << "Covered pixels: " << samples.size() << '\n';
        std::cout << "First barycentric coordinates: ("
                  << first.barycentric[0] << ", "
                  << first.barycentric[1] << ", "
                  << first.barycentric[2] << ")\n";
        std::cout << "Perspective-correct UV: ("
                  << interpolatedUv.x << ", " << interpolatedUv.y << ")\n";
        std::cout << "Triangle coverage and barycentric acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Triangle coverage and barycentric acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
