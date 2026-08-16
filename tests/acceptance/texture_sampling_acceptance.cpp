#include "Framebuffer.hpp"
#include "Rasterizer.hpp"
#include "Texture2D.hpp"

#include <array>
#include <cmath>
#include <functional>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

#ifndef TEXTURE_FIXTURE_PATH
#define TEXTURE_FIXTURE_PATH "tests/data/checker.ppm"
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

SoftRenderer::Texture2D parseTexture(
    const std::string& data,
    const std::string& sourceName
) {
    std::istringstream input(data, std::ios::in | std::ios::binary);
    return SoftRenderer::Texture2D::parsePpm(input, sourceName);
}

SoftRenderer::ScreenTriangle makeTexturedTriangle() {
    SoftRenderer::ScreenTriangle triangle;
    triangle.clipStatus = SoftRenderer::TriangleClipStatus::FullyInside;
    const std::array<Vec3, 3> positions{
        Vec3(1.0, 1.0, 0.5),
        Vec3(5.0, 1.0, 0.5),
        Vec3(1.0, 5.0, 0.5)
    };
    const std::array<double, 3> reciprocalW{1.0, 0.1, 0.1};
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
    throw std::runtime_error("expected textured raster sample was not generated");
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::Color red{1.0, 0.0, 0.0, 1.0};
        const SoftRenderer::Color green{0.0, 1.0, 0.0, 1.0};
        const SoftRenderer::Color blue{0.0, 0.0, 1.0, 1.0};
        const SoftRenderer::Color white{1.0, 1.0, 1.0, 1.0};
        const SoftRenderer::Color black{0.0, 0.0, 0.0, 1.0};
        const SoftRenderer::Color magenta{1.0, 0.0, 1.0, 1.0};

        const SoftRenderer::Texture2D texture =
            SoftRenderer::Texture2D::loadPpm(TEXTURE_FIXTURE_PATH);
        expect(texture.width() == 2 && texture.height() == 2,
               "PPM fixture dimensions are incorrect");
        expect(texture.texelCount() == 4, "PPM fixture texel count is incorrect");
        expectColor("top-left texel", texture.texelAt(0, 0), red);
        expectColor("top-right texel", texture.texelAt(1, 0), green);
        expectColor("bottom-left texel", texture.texelAt(0, 1), blue);
        expectColor("bottom-right texel", texture.texelAt(1, 1), white);

        expectColor(
            "bottom-left UV sample",
            texture.sampleNearest(Vec2(0.25, 0.25)),
            blue
        );
        expectColor(
            "bottom-right UV sample",
            texture.sampleNearest(Vec2(0.75, 0.25)),
            white
        );
        expectColor(
            "top-left UV sample",
            texture.sampleNearest(Vec2(0.25, 0.75)),
            red
        );
        expectColor(
            "top-right UV sample",
            texture.sampleNearest(Vec2(0.75, 0.75)),
            green
        );
        expectColor("clamped UV boundary", texture.sampleNearest(Vec2(1.0, 1.0)), green);

        const SoftRenderer::SamplerState repeatSampler{
            SoftRenderer::TextureAddressMode::Repeat,
            SoftRenderer::TextureAddressMode::Repeat,
            SoftRenderer::TextureUvOrigin::BottomLeft
        };
        expectColor(
            "repeated UV sample",
            texture.sampleNearest(Vec2(1.25, -0.25), repeatSampler),
            red
        );
        expectColor(
            "clamped out-of-range UV sample",
            texture.sampleNearest(Vec2(-4.0, 3.0)),
            red
        );
        const SoftRenderer::SamplerState topLeftSampler{
            SoftRenderer::TextureAddressMode::Clamp,
            SoftRenderer::TextureAddressMode::Clamp,
            SoftRenderer::TextureUvOrigin::TopLeft
        };
        expectColor(
            "top-left-origin UV sample",
            texture.sampleNearest(Vec2(0.25, 0.25), topLeftSampler),
            red
        );

        std::string binary8 = "P6\n2 1\n255\n";
        const unsigned char binary8Pixels[] = {0, 0, 0, 255, 0, 255};
        binary8.append(
            reinterpret_cast<const char*>(binary8Pixels),
            sizeof(binary8Pixels)
        );
        const SoftRenderer::Texture2D binary8Texture =
            parseTexture(binary8, "binary8.ppm");
        expectColor("8-bit binary first texel", binary8Texture.texelAt(0, 0), black);
        expectColor("8-bit binary second texel", binary8Texture.texelAt(1, 0), magenta);

        std::string binary16 = "P6\n1 1\n1023\n";
        const unsigned char binary16Pixels[] = {0x03, 0xFF, 0x02, 0x00, 0x00, 0x00};
        binary16.append(
            reinterpret_cast<const char*>(binary16Pixels),
            sizeof(binary16Pixels)
        );
        const SoftRenderer::Texture2D binary16Texture =
            parseTexture(binary16, "binary16.ppm");
        expectNear("16-bit binary red", binary16Texture.texelAt(0, 0).r, 1.0);
        expectNear(
            "16-bit binary green",
            binary16Texture.texelAt(0, 0).g,
            512.0 / 1023.0
        );
        expectNear("16-bit binary blue", binary16Texture.texelAt(0, 0).b, 0.0);

        const SoftRenderer::ScreenTriangle triangle = makeTexturedTriangle();
        const std::vector<SoftRenderer::RasterSample> samples =
            SoftRenderer::Rasterizer::rasterize(triangle, 8, 8);
        const std::array<Vec2, 3> triangleUvs{
            Vec2(0.0, 0.0),
            Vec2(1.0, 0.0),
            Vec2(0.0, 1.0)
        };
        const SoftRenderer::RasterSample& perspectiveSample =
            findSample(samples, 3, 1);
        const Vec2 perspectiveUv =
            perspectiveSample.interpolatePerspective<Vec2>(triangleUvs);
        expectNear("perspective UV.x", perspectiveUv.x, 5.0 / 26.0);
        expectNear("perspective UV.y", perspectiveUv.y, 1.0 / 26.0);
        expectColor(
            "perspective-correct texture lookup",
            texture.sampleNearest(perspectiveUv),
            blue
        );

        SoftRenderer::Framebuffer framebuffer(8, 8);
        framebuffer.clear(black, 1.0);
        std::size_t writtenSamples = 0;
        for (const SoftRenderer::RasterSample& sample : samples) {
            const Vec2 uv = sample.interpolatePerspective<Vec2>(triangleUvs);
            const SoftRenderer::Color color = texture.sampleNearest(uv);
            if (framebuffer.writeFragment(sample.x, sample.y, sample.depth, color)) {
                ++writtenSamples;
            }
        }
        expect(writtenSamples == samples.size(),
               "textured triangle did not write every visible sample");
        expectColor(
            "textured framebuffer sample",
            framebuffer.colorAt(3, 1),
            blue
        );
        expectNear("textured framebuffer depth", framebuffer.depthAt(3, 1), 0.5);

        expectFailure<SoftRenderer::TextureLoadError>(
            "invalid PPM magic",
            "magic must be P3 or P6",
            [&]() { parseTexture("P2\n1 1\n255\n0", "magic.ppm"); }
        );
        expectFailure<SoftRenderer::TextureLoadError>(
            "zero PPM width",
            "must fit a non-zero size",
            [&]() { parseTexture("P3\n0 1\n255\n", "width.ppm"); }
        );
        expectFailure<SoftRenderer::TextureLoadError>(
            "invalid PPM max value",
            "max value must be within",
            [&]() { parseTexture("P3\n1 1\n0\n", "max.ppm"); }
        );
        expectFailure<SoftRenderer::TextureLoadError>(
            "out-of-range PPM channel",
            "channel exceeds max value",
            [&]() { parseTexture("P3\n1 1\n255\n256 0 0", "channel.ppm"); }
        );

        std::string truncated = "P6\n1 1\n255\n";
        const unsigned char truncatedPixels[] = {255, 0};
        truncated.append(
            reinterpret_cast<const char*>(truncatedPixels),
            sizeof(truncatedPixels)
        );
        expectFailure<SoftRenderer::TextureLoadError>(
            "truncated binary PPM",
            "pixel data is truncated",
            [&]() { parseTexture(truncated, "truncated.ppm"); }
        );
        expectFailure<SoftRenderer::TextureLoadError>(
            "missing texture file",
            "could not open texture file",
            [&]() { SoftRenderer::Texture2D::loadPpm("missing-texture.ppm"); }
        );
        expectFailure<std::out_of_range>(
            "out-of-range texel",
            "texture coordinates are out of range",
            [&]() { texture.texelAt(2, 0); }
        );
        expectFailure<std::invalid_argument>(
            "non-finite UV",
            "texture coordinates must be finite",
            [&]() {
                texture.sampleNearest(Vec2(
                    std::numeric_limits<double>::quiet_NaN(),
                    0.5
                ));
            }
        );
        expectFailure<std::invalid_argument>(
            "invalid texture dimensions",
            "dimensions must be non-zero",
            [&]() { SoftRenderer::Texture2D(0, 1, {}); }
        );
        expectFailure<std::invalid_argument>(
            "mismatched texture data",
            "texel count does not match",
            [&]() { SoftRenderer::Texture2D(1, 1, {}); }
        );
        const SoftRenderer::Color invalidTextureColor{
            std::numeric_limits<double>::infinity(),
            0.0,
            0.0,
            1.0
        };
        expectFailure<std::invalid_argument>(
            "non-finite texture channel",
            "color channels must be within [0, 1]",
            [&]() {
                SoftRenderer::Texture2D(
                    1,
                    1,
                    std::vector<SoftRenderer::Color>{invalidTextureColor}
                );
            }
        );

        std::cout << "Texture: " << texture.width() << 'x' << texture.height() << '\n';
        std::cout << "PPM variants: P3 / P6 8-bit / P6 16-bit\n";
        std::cout << "Perspective UV: ("
                  << perspectiveUv.x << ", " << perspectiveUv.y << ")\n";
        std::cout << "Textured samples: " << writtenSamples << '\n';
        std::cout << "Texture loading and UV sampling acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Texture loading and UV sampling acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
