#include "Camera.hpp"
#include "Fresnel.hpp"
#include "Mat3.hpp"
#include "Pipeline.hpp"
#include "Projection.hpp"
#include "TangentSpace.hpp"
#include "Transform.hpp"
#include "Vec2.hpp"

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
constexpr int kAcceptanceSuiteCount = 4;

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

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        int passedAcceptanceSuites = 0;

        const Vec2 vector2A(3.0, 4.0);
        const Vec2 vector2B(-4.0, 3.0);
        const Vec3 axisX(1.0, 0.0, 0.0);
        const Vec3 axisY(0.0, 1.0, 0.0);
        const Vec3 axisZ = axisX.cross(axisY);
        const double matrix3Data[9] = {
            2.0, 0.0, 0.0,
            0.0, 3.0, 0.0,
            0.0, 0.0, 4.0
        };
        const Mat3 inverseMatrix3 = Mat3(matrix3Data).inverse();
        const Vec3 inverseResult = inverseMatrix3 * Vec3(2.0, 3.0, 4.0);
        const Mat4 composedTransform =
            Transform::translation(Vec3(3.0, -2.0, 5.0)) *
            Transform::rotationZ(kPi * 0.5) *
            Transform::scaling(Vec3(2.0, 3.0, 4.0));
        const Vec4 transformedPoint = composedTransform * Vec4(1.0, 0.0, 0.0, 1.0);

        expectNear("Vec2 length", vector2A.length(), 5.0);
        expectNear("Vec2 perpendicular dot", vector2A.dot(vector2B), 0.0);
        expectNear("Vec2 cross", vector2A.cross(vector2B), 25.0);
        expectNear("Vec3 cross.x", axisZ.x, 0.0);
        expectNear("Vec3 cross.y", axisZ.y, 0.0);
        expectNear("Vec3 cross.z", axisZ.z, 1.0);
        expectNear("Mat3 inverse result.x", inverseResult.x, 1.0);
        expectNear("Mat3 inverse result.y", inverseResult.y, 1.0);
        expectNear("Mat3 inverse result.z", inverseResult.z, 1.0);
        expectNear("composed transform.x", transformedPoint.x, 3.0);
        expectNear("composed transform.y", transformedPoint.y, 0.0);
        expectNear("composed transform.z", transformedPoint.z, 5.0);
        expectNear("composed transform.w", transformedPoint.w, 1.0);
        ++passedAcceptanceSuites;

        std::cout << std::fixed << std::setprecision(4) << std::boolalpha;
        std::cout << "\n=== 向量、矩阵与组合变换 ===\n";
        std::cout << "Vec2 长度/垂直关系: " << vector2A.length()
                  << " / " << vector2A.dot(vector2B) << '\n';
        std::cout << "右手系 X×Y: " << axisZ << '\n';
        std::cout << "Mat3 逆矩阵基准: " << inverseResult << '\n';
        std::cout << "T*R*S 组合变换结果: " << transformedPoint << '\n';
        std::cout << "向量/矩阵/变换固定数值验证: PASS\n";

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
        ++passedAcceptanceSuites;

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
        ++passedAcceptanceSuites;

        const double glassF0 = Fresnel::dielectricF0(1.0, 1.5);
        const double glassFacing = Fresnel::schlick(1.0, glassF0);
        const double glassAtSixtyDegrees = Fresnel::schlick(0.5, glassF0);
        const double glassGrazing = Fresnel::schlick(0.0, glassF0);
        const Vec3 copperF0(0.95, 0.64, 0.54);
        const Vec3 copperAtSixtyDegrees = Fresnel::schlick(0.5, copperF0);

        expectNear("glass F0", glassF0, 0.04);
        expectNear("glass facing reflectance", glassFacing, 0.04);
        expectNear("glass 60 degree reflectance", glassAtSixtyDegrees, 0.07);
        expectNear("glass grazing reflectance", glassGrazing, 1.0);
        expectNear("copper 60 degree reflectance.r", copperAtSixtyDegrees.x, 0.9515625);
        expectNear("copper 60 degree reflectance.g", copperAtSixtyDegrees.y, 0.65125);
        expectNear("copper 60 degree reflectance.b", copperAtSixtyDegrees.z, 0.554375);

        bool invalidIorRejected = false;
        try {
            Fresnel::dielectricF0(1.0, 0.0);
        } catch (const std::invalid_argument&) {
            invalidIorRejected = true;
        }
        if (!invalidIorRejected) {
            throw std::runtime_error("invalid index of refraction was not rejected");
        }

        bool invalidF0Rejected = false;
        try {
            Fresnel::schlick(0.5, 1.1);
        } catch (const std::invalid_argument&) {
            invalidF0Rejected = true;
        }
        if (!invalidF0Rejected) {
            throw std::runtime_error("invalid F0 was not rejected");
        }

        std::cout << "\n=== Fresnel 基础 ===\n";
        std::cout << "空气到玻璃 F0: " << glassF0 << '\n';
        std::cout << "正视反射率: " << glassFacing << '\n';
        std::cout << "60 度反射率: " << glassAtSixtyDegrees << '\n';
        std::cout << "掠射反射率: " << glassGrazing << '\n';
        std::cout << "铜色 F0: " << copperF0 << '\n';
        std::cout << "铜色 60 度反射率: " << copperAtSixtyDegrees << '\n';
        std::cout << "无效折射率/F0 保护: "
                  << (invalidIorRejected && invalidF0Rejected) << '\n';
        std::cout << "Fresnel 固定数值验证: PASS\n";
        ++passedAcceptanceSuites;

        if (passedAcceptanceSuites != kAcceptanceSuiteCount) {
            throw std::runtime_error("not all graphics math acceptance suites ran");
        }
        std::cout << "\n=== 图形数学阶段验收 ===\n";
        std::cout << "通过套件: " << passedAcceptanceSuites
                  << '/' << kAcceptanceSuiteCount << '\n';
        std::cout << "覆盖范围: 向量/矩阵/变换、MVP/视口、法线/TBN、Fresnel\n";
        std::cout << "图形数学阶段验收: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "图形数学验证失败: " << error.what() << '\n';
        return 1;
    }
}
