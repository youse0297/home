#include "Vec3.hpp"
#include "Vec4.hpp"
#include "Mat4.hpp"
#include "Transform.hpp"
#include <iomanip>
#include <iostream>
#include <windows.h>
#include <vector>

int main() {
    SetConsoleOutputCP(CP_UTF8);
    
    std::cout << "\n=== 立方体变换 ===\n";

    std::vector<Vec3> cubeVertices = {
        Vec3(-1, -1, -1),
        Vec3(1, -1, -1),
        Vec3(1, 1, -1),
        Vec3(-1, 1, -1),
        Vec3(-1, -1, 1),
        Vec3(1, -1, 1),
        Vec3(1, 1, 1),
        Vec3(-1, 1, 1)
    };

    // 构建组合变换 先缩放（1.5， 1.5， 1.5），再绕 Y 轴旋转 45 度，最后平移（2, 1, 0）
    Mat4 S = Transform::scaling(Vec3(1.5f, 1.5f, 1.5f));
    Mat4 R = Transform::rotationY(45.0 * M_PI / 180.0); // 角度转弧度
    Mat4 T = Transform::translation(Vec3(2.0f, 1.0f, 0.0f));

    //  组合变换矩阵 M = T * R * S
    Mat4 M = T * R * S;

    std::cout << "变换矩阵 M:\n" << M << "\n";

    std::cout << "变换前的顶点（前四个）:\n";
    for (int i = 0; i < 4; ++i) {
        std::cout << cubeVertices[i] << "\n";
    }

    std::cout << "变换后的顶点（前四个）:\n";
    for (int i = 0; i < 4; ++i) {
        // 将 Vec3 提升为 Vec4 （w=1）
        Vec4 v4(cubeVertices[i], 1.0);
        Vec4 transformd = M * v4;
        // 齐次除法
        Vec3 result(transformd.x / transformd.w,
                    transformd.y / transformd.w,
                    transformd.z / transformd.w);
        std::cout << result << "\n";
    }

    return 0;
}
