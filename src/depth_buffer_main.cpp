#include "Framebuffer.hpp"
#include "Rasterizer.hpp"

#include <array>
#include <cmath>
#include <functional>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
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

void expectColor(
    const std::string& label,
    const SoftRenderer::Color& actual,
    const SoftRenderer::Color& expected
) {
    expectNear(label + ".r", actual.r, expected.r);
    expectNear(label + ".g", actual.g, expected.g);
    expectNear(label + ".b", actual.b, expected.b);
    expectNear(label + ".a", actual.a, expected.a);
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

SoftRenderer::ScreenTriangle makeTriangle(const std::array<Vec3, 3>& positions) {
    SoftRenderer::ScreenTriangle triangle;
    triangle.clipStatus = SoftRenderer::TriangleClipStatus::FullyInside;
    for (std::size_t index = 0; index < 3; ++index) {
        triangle.vertices[index].transformed.screen = positions[index];
        triangle.vertices[index].reciprocalW = 1.0;
    }
    return triangle;
}

std::size_t drawTriangle(
    SoftRenderer::Framebuffer& framebuffer,
    const SoftRenderer::ScreenTriangle& triangle,
    const SoftRenderer::Color& color,
    const SoftRenderer::RasterizerOptions& options = {}
) {
    const std::vector<SoftRenderer::RasterSample> samples =
        SoftRenderer::Rasterizer::rasterize(
            triangle,
            framebuffer.width(),
            framebuffer.height(),
            options
        );
    std::size_t passedSamples = 0;
    for (const SoftRenderer::RasterSample& sample : samples) {
        if (framebuffer.writeFragment(sample.x, sample.y, sample.depth, color)) {
            ++passedSamples;
        }
    }
    return passedSamples;
}

void expectSameFramebuffer(
    const SoftRenderer::Framebuffer& first,
    const SoftRenderer::Framebuffer& second
) {
    expect(first.width() == second.width() && first.height() == second.height(),
           "framebuffer dimensions differ");
    for (std::size_t y = 0; y < first.height(); ++y) {
        for (std::size_t x = 0; x < first.width(); ++x) {
            expectColor(
                "order-independent color",
                first.colorAt(x, y),
                second.colorAt(x, y)
            );
            expectNear(
                "order-independent depth",
                first.depthAt(x, y),
                second.depthAt(x, y)
            );
        }
    }
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::Color clearColor{0.02, 0.03, 0.04, 1.0};
        const SoftRenderer::Color farColor{0.10, 0.20, 0.90, 1.0};
        const SoftRenderer::Color nearColor{0.90, 0.20, 0.10, 1.0};
        const SoftRenderer::Color rejectedColor{0.10, 0.90, 0.20, 1.0};
        const SoftRenderer::ScreenTriangle farTriangle = makeTriangle(
            {Vec3(1.0, 1.0, 0.75), Vec3(5.0, 1.0, 0.75), Vec3(1.0, 5.0, 0.75)}
        );
        const SoftRenderer::ScreenTriangle nearTriangle = makeTriangle(
            {Vec3(1.0, 1.0, 0.25), Vec3(5.0, 1.0, 0.25), Vec3(1.0, 5.0, 0.25)}
        );

        SoftRenderer::Framebuffer farThenNear(8, 8);
        farThenNear.clear(clearColor, 1.0);
        expect(farThenNear.depthTest(1, 1, 0.75),
               "clear depth did not accept a nearer fragment");
        expectNear("read-only depth test", farThenNear.depthAt(1, 1), 1.0);
        expect(drawTriangle(farThenNear, farTriangle, farColor) == 6,
               "far triangle did not pass all initial depth tests");
        expect(drawTriangle(farThenNear, nearTriangle, nearColor) == 6,
               "near triangle did not replace all farther samples");

        SoftRenderer::Framebuffer nearThenFar(8, 8);
        nearThenFar.clear(clearColor, 1.0);
        expect(drawTriangle(nearThenFar, nearTriangle, nearColor) == 6,
               "near triangle did not pass all initial depth tests");
        expect(drawTriangle(nearThenFar, farTriangle, farColor) == 0,
               "far triangle incorrectly replaced nearer samples");
        expectSameFramebuffer(farThenNear, nearThenFar);

        const std::vector<SoftRenderer::RasterSample> visibleSamples =
            SoftRenderer::Rasterizer::rasterize(nearTriangle, 8, 8);
        for (const SoftRenderer::RasterSample& sample : visibleSamples) {
            expectColor(
                "visible near fragment",
                nearThenFar.colorAt(sample.x, sample.y),
                nearColor
            );
            expectNear(
                "visible near depth",
                nearThenFar.depthAt(sample.x, sample.y),
                0.25
            );
        }

        expect(!nearThenFar.depthTest(1, 1, 0.25),
               "strict Less depth test accepted equal depth");
        expect(!nearThenFar.writeFragment(1, 1, 0.25, rejectedColor),
               "equal-depth fragment was written");
        expect(!nearThenFar.writeFragment(1, 1, 0.75, rejectedColor),
               "farther fragment was written");
        expectColor(
            "rejected fragment preserved color",
            nearThenFar.colorAt(1, 1),
            nearColor
        );
        expectNear(
            "rejected fragment preserved depth",
            nearThenFar.depthAt(1, 1),
            0.25
        );

        expect(nearThenFar.writeFragment(1, 1, 0.10, rejectedColor),
               "closer fragment did not update the framebuffer");
        expectColor(
            "accepted fragment color",
            nearThenFar.colorAt(1, 1),
            rejectedColor
        );
        expectNear("accepted fragment depth", nearThenFar.depthAt(1, 1), 0.10);

        expectFailure<std::invalid_argument>(
            "negative fragment depth",
            "depth must be within [0, 1]",
            [&]() { nearThenFar.writeFragment(0, 0, -0.1, rejectedColor); }
        );
        const SoftRenderer::Color invalidColor{
            std::numeric_limits<double>::quiet_NaN(),
            0.0,
            0.0,
            1.0
        };
        expectFailure<std::invalid_argument>(
            "non-finite fragment color",
            "color must be finite",
            [&]() { nearThenFar.writeFragment(0, 0, 0.5, invalidColor); }
        );
        expectColor(
            "failed fragment preserved clear color",
            nearThenFar.colorAt(0, 0),
            clearColor
        );
        expectNear("failed fragment preserved clear depth", nearThenFar.depthAt(0, 0), 1.0);
        expectFailure<std::out_of_range>(
            "out-of-range fragment",
            "coordinates are out of range",
            [&]() { nearThenFar.writeFragment(8, 0, 0.5, rejectedColor); }
        );

        const SoftRenderer::ScreenTriangle counterClockwise = makeTriangle(
            {Vec3(1.0, 1.0, 0.5), Vec3(1.0, 5.0, 0.5), Vec3(5.0, 1.0, 0.5)}
        );
        const SoftRenderer::RasterizerOptions cullBackClockwise{
            SoftRenderer::CullMode::Back,
            SoftRenderer::FrontFace::Clockwise
        };
        expect(
            SoftRenderer::Rasterizer::rasterize(
                nearTriangle,
                8,
                8,
                cullBackClockwise
            ).size() == 6,
            "clockwise front face was culled"
        );
        expect(
            SoftRenderer::Rasterizer::rasterize(
                counterClockwise,
                8,
                8,
                cullBackClockwise
            ).empty(),
            "counter-clockwise back face was not culled"
        );
        const SoftRenderer::RasterizerOptions cullBackCounterClockwise{
            SoftRenderer::CullMode::Back,
            SoftRenderer::FrontFace::CounterClockwise
        };
        expect(
            SoftRenderer::Rasterizer::rasterize(
                counterClockwise,
                8,
                8,
                cullBackCounterClockwise
            ).size() == 6,
            "configurable counter-clockwise front face was culled"
        );
        const SoftRenderer::RasterizerOptions cullFrontClockwise{
            SoftRenderer::CullMode::Front,
            SoftRenderer::FrontFace::Clockwise
        };
        expect(
            SoftRenderer::Rasterizer::rasterize(
                nearTriangle,
                8,
                8,
                cullFrontClockwise
            ).empty(),
            "front-face culling did not reject the front face"
        );

        std::cout << "Depth compare: strict Less\n";
        std::cout << "Visible samples: " << visibleSamples.size() << '\n';
        std::cout << "Order-independent occlusion: true\n";
        std::cout << "Configurable face culling: true\n";
        std::cout << "Depth buffer acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Depth buffer acceptance failed: " << error.what() << '\n';
        return 1;
    }
}
