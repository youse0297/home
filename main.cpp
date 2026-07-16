#include "Vec2.hpp"
#include "Vec3.hpp"
#include <iostream>

int main() {
    //测试 Vec2
    Vec2 a(2.0, 4.0);
    Vec2 b(4.0, -1.0);

    std::cout << "Vec2 a= " << a << std::endl;
    std::cout << "Vec2 b= " << b << std::endl;

    Vec2 c = a + b;
    std::cout << "a + b = " << c << std::endl;

    Vec2 d = a - b;
    std::cout << "a - b = " << d << std::endl;

    Vec2 e = a * 2.5;
    std::cout << "a * 2.5 = " << e << std::endl;

    Vec2 f = 3.0 * a;
    std::cout << "3.0 * a = " << f << std::endl;

    Vec2 g = a.normalized();
    std::cout << "normalized(a) = " << g << std::endl;
    std::cout << "length of normalized(a) = " << g.length() << std::endl;

    //测试 Vec3
    Vec3 p(1.0, 0.0, 0.0);
    Vec3 q(0.0, 1.0, 3.0);

    std::cout << "\nVec3 p = " << p << std::endl;
    std::cout << "vec3 q = " << q << std::endl;

    Vec3 r = p + q;
    std::cout << "p + q = " << r << std::endl;

    Vec3 s = p - q;
    std::cout << "p - q = " << s << std::endl;

    Vec3 t = p * 2.0;
    std::cout << "p * 2.0 = " << t << std::endl;

    Vec3 u = q.normalized();
    std::cout << "normalized(q) = " << u << std::endl;

    // 测试归一化后的长度
    Vec3 v(3.0, 4.0, 0.0);
    Vec3 vn = v.normalized();
    std::cout << "v = " << v << ", normalized(v) = " << vn << ",length = " << vn.length() << std::endl;

    return 0;
}