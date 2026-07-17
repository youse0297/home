#include "Vec3.hpp"
#include "Vec4.hpp"
#include "Mat4.hpp"
#include <iomanip>
#include <iostream>
#include <windows.h>

int main() {
    SetConsoleOutputCP(CP_UTF8);
    std::cout << std::fixed << std::setprecision(4);

    std::cout << "=== Vec4 与 Mat4 测试 ===\n\n";

    Vec3 position3D(1.0, 2.0, 3.0);
    Vec4 position(position3D);
    Vec4 direction(position3D, 0.0);
    std::cout << "三维向量      = " << position3D << '\n';
    std::cout << "齐次坐标点    = " << position << '\n';
    std::cout << "齐次方向向量  = " << direction << "\n\n";

    Mat4 identity = Mat4::identity();
    std::cout << "单位矩阵 I:\n" << identity << '\n';

    const double matrixData[16] = {
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16
    };
    Mat4 matrix(matrixData);
    std::cout << "矩阵 A（列主序存储）:\n" << matrix << '\n';
    std::cout << "A * I:\n" << matrix * identity << '\n';
    std::cout << "A * position = " << matrix * position << '\n';
    std::cout << "position * A = " << position * matrix << '\n';

    return 0;
}
