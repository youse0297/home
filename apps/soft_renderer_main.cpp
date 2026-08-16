#include "SoftwareRenderer.hpp"

#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

#ifdef _WIN32
#include <windows.h>
#endif

namespace {

void expectNear(const std::string& label, double actual, double expected) {
    constexpr double tolerance = 1e-6;
    if (!std::isfinite(actual) || !std::isfinite(expected) ||
        std::abs(actual - expected) > tolerance) {
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

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::Color clearColor{0.05, 0.10, 0.15, 1.0};
        const SoftRenderer::Color markerColor{0.80, 0.20, 0.10, 1.0};
        const SoftRenderer::RendererConfig config{
            4,
            3,
            clearColor,
            1.0
        };
        SoftRenderer::SoftwareRenderer renderer(config);

        std::size_t callbackCount = 0;
        renderer.run(3, [&](SoftRenderer::FrameContext& context) {
            if (context.frameIndex != callbackCount) {
                throw std::runtime_error("frame index did not advance monotonically");
            }
            for (std::size_t y = 0; y < context.framebuffer.height(); ++y) {
                for (std::size_t x = 0; x < context.framebuffer.width(); ++x) {
                    expectColor("frame clear color", context.framebuffer.colorAt(x, y), clearColor);
                    expectNear("frame clear depth", context.framebuffer.depthAt(x, y), 1.0);
                }
            }

            const std::size_t x = context.frameIndex % context.framebuffer.width();
            context.framebuffer.setColor(x, 1, markerColor);
            context.framebuffer.setDepth(x, 1, 0.25);
            ++callbackCount;
        });

        if (renderer.completedFrames() != 3 || callbackCount != 3) {
            throw std::runtime_error("render loop did not complete three frames");
        }
        if (renderer.framebuffer().pixelCount() != 12) {
            throw std::runtime_error("framebuffer pixel count is incorrect");
        }
        expectColor("last frame marker", renderer.framebuffer().colorAt(2, 1), markerColor);
        expectNear("last frame marker depth", renderer.framebuffer().depthAt(2, 1), 0.25);
        expectColor("previous frame was cleared", renderer.framebuffer().colorAt(1, 1), clearColor);
        expectNear("previous frame depth was cleared", renderer.framebuffer().depthAt(1, 1), 1.0);

        bool invalidSizeRejected = false;
        try {
            SoftRenderer::Framebuffer invalidFramebuffer(0, 3);
        } catch (const std::invalid_argument&) {
            invalidSizeRejected = true;
        }

        bool invalidDepthRejected = false;
        try {
            renderer.framebuffer().setDepth(0, 0, 1.5);
        } catch (const std::invalid_argument&) {
            invalidDepthRejected = true;
        }

        bool outOfBoundsRejected = false;
        try {
            renderer.framebuffer().colorAt(4, 0);
        } catch (const std::out_of_range&) {
            outOfBoundsRejected = true;
        }

        if (!invalidSizeRejected || !invalidDepthRejected || !outOfBoundsRejected) {
            throw std::runtime_error("framebuffer input validation is incomplete");
        }

        const SoftRenderer::Color finalColor = renderer.framebuffer().colorAt(2, 1);
        const double finalDepth = renderer.framebuffer().depthAt(2, 1);

        std::cout << std::fixed << std::setprecision(4) << std::boolalpha;
        std::cout << "\n=== 软渲染器骨架与范围冻结 ===\n";
        std::cout << "Framebuffer: " << renderer.framebuffer().width()
                  << 'x' << renderer.framebuffer().height()
                  << "，像素数 " << renderer.framebuffer().pixelCount() << '\n';
        std::cout << "渲染循环完成帧数: " << renderer.completedFrames() << '\n';
        std::cout << "最后一帧标记颜色: ("
                  << finalColor.r << ", " << finalColor.g << ", "
                  << finalColor.b << ", " << finalColor.a << ")\n";
        std::cout << "最后一帧标记深度: " << finalDepth << '\n';
        std::cout << "逐帧颜色/深度清屏: true\n";
        std::cout << "非法尺寸/深度/坐标保护: true\n";
        std::cout << "冻结排除项: 阴影、抗锯齿、次表面散射\n";
        std::cout << "软渲染器骨架验收: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "软渲染器骨架验收失败: " << error.what() << '\n';
        return 1;
    }
}
