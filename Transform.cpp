#include "Transform.hpp"
#include <cmath>

namespace Transform {

    Mat4 translation(const Vec3& t) {
        Mat4 m = Mat4::identity();
        // 列主序，平移量放在第4列 （索引 12，13，14）
        m.m[12] = t.x;
        m.m[13] = t.y;
        m.m[14] = t.z;
        return m;
    }

    Mat4 scaling(const Vec3& s) {
        Mat4 m = Mat4::identity();
        // 列主序，缩放因子放在对角线
        m.m[0] = s.x; // 第 0 列第 0 行
        m.m[5] = s.y; // 第 1 列第 1 行
        m.m[10] = s.z; // 第 2 列第 2 行
        return m;
    }

    Mat4 rotationX(double angle) {
        double c = std::cos(angle);
        double s = std::sin(angle);
        Mat4 m = Mat4::identity();
        // 列主序
        // 第 1 列：[0, c, s, 0] (列0=0, 列1=1, 列2=s, 列3=0)
        // 第 2 列：[0, -s, c, 0]
        m.m[4] = 0;
        m.m[5] = c;
        m.m[6] = s;
        m.m[7] = 0;
        m.m[8] = 0;
        m.m[9] = -s;
        m.m[10] = c;
        m.m[11] = 0;
        return m;
    }

    Mat4 rotationY(double angle) {
        double c = std::cos(angle);
        double s = std::sin(angle);
        Mat4 m = Mat4::identity();
        // 列主序
        // 第 0 列：[c, 0, -s, 0]
        // 第 2 列：[s, 0, c, 0]
        m.m[0] = c;
        m.m[2] = -s;
        m.m[8] = s;
        m.m[10] = c;
        return m;
    }

    Mat4 rotationZ(double angle) {
        double c = std::cos(angle);
        double s = std::sin(angle);
        Mat4 m = Mat4::identity();
        // 绕 z 轴旋转矩阵
        m.m[0] = c;
        m.m[1] = s;
        m.m[4] = -s;
        m.m[5] = c;
        return m;
    }

    Mat4 rotationAxis(const Vec3& axis, double angle) {
        double c = std::cos(angle);
        double s = std::sin(angle);
        double t = 1.0 - c;
        double x = axis.x, y = axis.y, z = axis.z;

        Mat4 m = Mat4::identity();
        // 列主序，使用罗德里格斯旋转公式

        m.m[0] = t*x*x + c;
        m.m[1] = t*x*y + s*z;
        m.m[2] = t*x*z - s*y;

        m.m[4] = t*x*y - s*z;
        m.m[5] = t*y*y + c;
        m.m[6] = t*y*z + s*x;

        m.m[8] = t*x*z + s*y;
        m.m[9] = t*y*z - s*x;
        m.m[10] = t*z*z + c;

        return m;
    }

} // namespace Transform