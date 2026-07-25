#include "Camera.hpp"
#include "Pipeline.hpp"
#include "Projection.hpp"
#include "Transform.hpp"

#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

#ifdef _WIN32
#include <windows.h>
#endif

namespace {

constexpr double kPi = 3.14159265358979323846;

void expectNear(const std::string& label, double actual, double expected) {
    constexpr double tolerance = 1e-6;
    if (std::abs(actual - expected) > tolerance) {
        throw std::runtime_error(
            label + " expected " + std::to_string(expected) +
            ", got " + std::to_string(actual)
        );
    }
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const Mat4 model = Transform::translation(Vec3(1.0, 0.0, 0.0));
        const Mat4 view = Camera::lookAt(
            Vec3(0.0, 0.0, 5.0),
            Vec3(0.0, 0.0, 0.0),
            Vec3(0.0, 1.0, 0.0)
        );
        const Mat4 projection = Camera::perspective(
            90.0 * kPi / 180.0,
            16.0 / 9.0,
            1.0,
            10.0
        );
        const Pipeline::Viewport viewport{
            0.0,
            0.0,
            1280.0,
            720.0,
            0.0,
            1.0,
            Pipeline::ViewportOrigin::TopLeft
        };
        const Vec4 objectPosition(0.0, 0.0, 0.0, 1.0);

        const Pipeline::VertexResult result = Pipeline::transformVertex(
            objectPosition,
            model,
            view,
            projection,
            viewport
        );
        const Mat4 mvp = Pipeline::composeMVP(model, view, projection);
        const Vec4 combinedClip = mvp * objectPosition;

        expectNear("world.x", result.world.x, 1.0);
        expectNear("view.x", result.view.x, 1.0);
        expectNear("view.z", result.view.z, -5.0);
        expectNear("ndc.x", result.ndc.x, 0.1125);
        expectNear("ndc.y", result.ndc.y, 0.0);
        expectNear("ndc.z", result.ndc.z, 7.0 / 9.0);
        expectNear("screen.x", result.screen.x, 712.0);
        expectNear("screen.y", result.screen.y, 360.0);
        expectNear("screen.z", result.screen.z, 8.0 / 9.0);
        expectNear("combined clip.x", combinedClip.x, result.clip.x);
        expectNear("combined clip.y", combinedClip.y, result.clip.y);
        expectNear("combined clip.z", combinedClip.z, result.clip.z);
        expectNear("combined clip.w", combinedClip.w, result.clip.w);

        const Vec3 viewportTopLeft = Pipeline::mapToViewport(
            Vec3(-1.0, 1.0, -1.0),
            viewport
        );
        const Vec3 viewportBottomRight = Pipeline::mapToViewport(
            Vec3(1.0, -1.0, 1.0),
            viewport
        );
        expectNear("viewport top-left x", viewportTopLeft.x, 0.0);
        expectNear("viewport top-left y", viewportTopLeft.y, 0.0);
        expectNear("viewport top-left z", viewportTopLeft.z, 0.0);
        expectNear("viewport bottom-right x", viewportBottomRight.x, 1280.0);
        expectNear("viewport bottom-right y", viewportBottomRight.y, 720.0);
        expectNear("viewport bottom-right z", viewportBottomRight.z, 1.0);

        std::cout << std::fixed << std::setprecision(4) << std::boolalpha;
        std::cout << "\n=== MVP 与视口映射 ===\n";
        std::cout << "对象坐标: " << objectPosition << '\n';
        std::cout << "世界坐标: " << result.world << '\n';
        std::cout << "观察坐标: " << result.view << '\n';
        std::cout << "裁剪坐标: " << result.clip << '\n';
        std::cout << "NDC 坐标: " << result.ndc << '\n';
        std::cout << "屏幕坐标: " << result.screen << '\n';
        std::cout << "位于裁剪体内: " << result.insideClipVolume << '\n';
        std::cout << "视口左上角基准: " << viewportTopLeft << '\n';
        std::cout << "视口右下角基准: " << viewportBottomRight << '\n';
        std::cout << "固定数值验证: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "MVP 验证失败: " << error.what() << '\n';
        return 1;
    }
}
