#include "Vec3.hpp"
#include "Vec4.hpp"
#include "Mat4.hpp"
#include "Transform.hpp"
#include "Camera.hpp"
#include "Projection.hpp"
#include <iomanip>
#include <iostream>
#include <windows.h>
#include <vector>

int main() {
    SetConsoleOutputCP(CP_UTF8);
    
    std::cout << "\n=== 透视投影 测试 ===\n";

    // 参数：垂直FOV = 60°，宽高比 = 16：9，近平面0.1，远平面100.0
    const double fov = 60.0 * M_PI / 180.0;
    const double aspect = 16.0 / 9.0;
    const double zNear = 0.1;
    const double zFar = 100.0;

    Mat4 proj = Camera::perspective(fov, aspect, zNear, zFar);
    std::cout << "投影矩阵 （FOV=60°，16：9，near=0.1，far=100）:\n" << proj << "\n";

    // 验证点1：近平面中心（0.0，-zNear，1）
    Vec4 pNear(0, 0, -zNear, 1);
    Vec4 clipNear = proj * pNear;
    Vec4 ndcNear = clipNear / clipNear.w;
    std::cout << "点(0,0," << -zNear << ",1) -> clip = " << clipNear << " -> NDC = " << ndcNear << "\n";
    // 预期：ndc = （0，0，-1，1）或近似

    // 验证点2：远平面中心 (0,0,-far,1)
    Vec4 pFar(0, 0, -zFar, 1);
    Vec4 clipFar = proj * pFar;
    Vec4 ndcFar = clipFar / clipFar.w;
    std::cout << "点 (0,0," << -zFar << ",1) -> clip = " << clipFar
          << " -> NDC = " << ndcFar << "\n";
    // 预期：ndc = (0, 0, 1, 1)

    // 验证点3：近平面右上角 (根据 fov 和 aspect 计算)
    double top = zNear * tan(fov/2.0);
    double right = top * aspect;
    Vec4 pCorner(right, top, -zNear, 1);
    Vec4 clipCorner = proj * pCorner;
    Vec4 ndcCorner = clipCorner / clipCorner.w;
    std::cout << "近平面右上角 (" << right << ", " << top << ", " << -zNear << ",1) -> NDC = " << ndcCorner << "\n";
    // 预期：ndc 约等于 (1, 1, -1, 1)

    // 验证点4：远平面右上角 (透视缩放)
    double topFar = zFar * tan(fov/2.0);
    double rightFar = topFar * aspect;
    Vec4 pFarCorner(rightFar, topFar, -zFar, 1);
    Vec4 clipFarCorner = proj * pFarCorner;
    Vec4 ndcFarCorner = clipFarCorner / clipFarCorner.w;
    std::cout << "远平面右上角 (" << rightFar << ", " << topFar << ", " << -zFar << ",1) -> NDC = " << ndcFarCorner << "\n";
    // 预期：ndc 约等于 (1, 1, 1, 1)

    return 0;
}
