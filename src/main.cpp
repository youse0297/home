#include "Camera.hpp"
#include "Pipeline.hpp"
#include "Projection.hpp"
#include "TangentSpace.hpp"
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
        std::cout << "MVP 固定数值验证: PASS\n";

        const Mat4 nonUniformScale = Transform::scaling(Vec3(2.0, 1.0, 0.5));
        const Vec3 objectTangent = Vec3(1.0, 0.0, 1.0).normalized();
        const Vec3 objectNormal = Vec3(1.0, 0.0, -1.0).normalized();
        const Mat3 normalMatrix = TangentSpace::makeNormalMatrix(nonUniformScale);
        const Vec3 worldTangent = TangentSpace::transformDirection(
            nonUniformScale,
            objectTangent
        ).normalized();
        const Vec3 worldNormal = TangentSpace::transformNormal(
            normalMatrix,
            objectNormal
        );
        const Vec3 naiveNormal = TangentSpace::transformDirection(
            nonUniformScale,
            objectNormal
        ).normalized();
        const double correctDot = worldTangent.dot(worldNormal);
        const double naiveDot = worldTangent.dot(naiveNormal);
        const Mat3 tbn = TangentSpace::buildTBN(worldNormal, worldTangent);
        const Vec3 mappedNormal = TangentSpace::tangentToWorld(
            tbn,
            Vec3(0.0, 0.0, 1.0)
        );
        const Vec3 roundTripNormal = TangentSpace::worldToTangent(tbn, mappedNormal);

        expectNear("normal matrix m00", normalMatrix.m[0], 0.5);
        expectNear("normal matrix m11", normalMatrix.m[4], 1.0);
        expectNear("normal matrix m22", normalMatrix.m[8], 2.0);
        expectNear("world tangent.x", worldTangent.x, 0.9701425001);
        expectNear("world tangent.z", worldTangent.z, 0.2425356250);
        expectNear("world normal.x", worldNormal.x, 0.2425356250);
        expectNear("world normal.z", worldNormal.z, -0.9701425001);
        expectNear("correct tangent-normal dot", correctDot, 0.0);
        expectNear("naive tangent-normal dot", naiveDot, 15.0 / 17.0);
        expectNear("TBN determinant", tbn.determinant(), 1.0);
        expectNear("mapped normal.x", mappedNormal.x, worldNormal.x);
        expectNear("mapped normal.y", mappedNormal.y, worldNormal.y);
        expectNear("mapped normal.z", mappedNormal.z, worldNormal.z);
        expectNear("round trip normal.x", roundTripNormal.x, 0.0);
        expectNear("round trip normal.y", roundTripNormal.y, 0.0);
        expectNear("round trip normal.z", roundTripNormal.z, 1.0);

        bool singularMatrixRejected = false;
        try {
            TangentSpace::makeNormalMatrix(
                Transform::scaling(Vec3(1.0, 1.0, 0.0))
            );
        } catch (const std::domain_error&) {
            singularMatrixRejected = true;
        }
        if (!singularMatrixRejected) {
            throw std::runtime_error("singular normal matrix was not rejected");
        }

        std::cout << "\n=== 法线矩阵与切线空间 ===\n";
        std::cout << "非均匀缩放矩阵: (2.0000, 1.0000, 0.5000)\n";
        std::cout << "法线矩阵:\n" << normalMatrix << '\n';
        std::cout << "世界切线 T: " << worldTangent << '\n';
        std::cout << "正确世界法线 N: " << worldNormal << '\n';
        std::cout << "错误法线（直接乘模型矩阵）: " << naiveNormal << '\n';
        std::cout << "正确 T·N: " << correctDot << '\n';
        std::cout << "错误 T·N: " << naiveDot << '\n';
        std::cout << "TBN 矩阵:\n" << tbn << '\n';
        std::cout << "切线空间 +Z 映射到世界空间: " << mappedNormal << '\n';
        std::cout << "奇异缩放保护: " << singularMatrixRejected << '\n';
        std::cout << "法线/TBN 固定数值验证: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "图形数学验证失败: " << error.what() << '\n';
        return 1;
    }
}
