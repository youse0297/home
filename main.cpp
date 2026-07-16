#include "Vec2.hpp"
#include "Vec3.hpp"
#include "VectorUtils.hpp"
#include <iostream>
#include <iomanip>
#include <windows.h>

int main() {
    SetConsoleOutputCP(CP_UTF8);
    std::cout << std::fixed << std::setprecision(4);

    // 设置坐标系为右手系 （默认）
    g_handedness = Handedness::Right;

    // 测试 Vec2
    Vec2 a(1.0, 0.0);
    Vec2 b(0.0, 1.0);
    Vec2 c(2.0, 2.0);

    std::cout << "=== Vec2 工具函数 ===" << "\n";
    std::cout << "a = " << a << ", b = " << b << ", c = " << c << std::endl;
    std::cout << "夹角 a - b (rad) = " << Vec2Utils::angle(a, b) << std::endl;
    std::cout << "c 在 a 上的投影 = " << Vec2Utils::project(c, a) << std::endl;
    std::cout << "a 相对于 b 的侧向符号 = " << Vec2Utils::side(a, b) << std::endl;

    // 切换到左手系
    g_handedness = Handedness::Left;
    std::cout << "切换到左手系,侧向符号 = " << Vec2Utils::side(a, b) << std::endl;

    // 测试 Vec3
    Vec3 u(1.0, 0.0, 0.0);
    Vec3 v(0.0, 1.0, 0.0);
    Vec3 w(1.0, 1.0, 1.0);
    Vec3 up(0.0, 0.0, 1.0);

    std::cout << "\n=== Vec3 工具函数 ===" << std::endl;
    std::cout << "u = " << u << ", v = " << v << ", w = " << w << std::endl;
    std::cout << "夹角 u - v (rad) = " << Vec3Utils::angle(u, v) << std::endl;
    std::cout << "w 在 u 上的投影 = " << Vec3Utils::project(w, u) << std::endl;

    // 朝向判断 （右手系）
    g_handedness = Handedness::Right;
    Vec3 w2(1.0, -1.0, 0.0);
    double side1 = Vec3Utils::side(u, w, up);
    double side2 = Vec3Utils::side(u, w2, up);
    std::cout << "w 相对于 u 的侧向符号 (右手系) = " << side1 << std::endl;
    std::cout << "w2 相对于 u 的侧向符号 (右手系) = " << side2 << std::endl;

    // 切换到左手系
    Vec3 vLeft = Vec3Utils::toHandedness(v, Handedness::Left);
    std::cout << "切换到左手系, v = " << vLeft << std::endl;

    return 0;
}