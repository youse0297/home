#include "VectorUtils.hpp"
#include <cmath>
#include <stdexcept>

Handedness g_handedness = Handedness::Right; // 默认右手系

// Vec2 实现
namespace Vec2Utils {
    double angle(const Vec2& a, const Vec2& b) {
        double lenA = a.length();
        double lenB = b.length();
        if (lenA == 0.0 || lenB == 0.0)
            return 0.0;
        double cosTheta = a.dot(b) / (lenA * lenB);
        if (cosTheta < -1.0)
            cosTheta = -1.0;
        if (cosTheta > 1.0)
            cosTheta = 1.0;
        return std::acos(cosTheta);
    }

    Vec2 project(const Vec2& a, const Vec2& b){
        double lenSq = b.lengthSquared();
        if (lenSq == 0.0)
            return Vec2(0.0, 0.0);
        return b * (a.dot(b) / lenSq);
    }

    double side(const Vec2& a, const Vec2& b){
        double cross = a.cross(b); // a.x*b.y - a.y*b.x
        // 根据坐标系调整符号
        if (g_handedness == Handedness::Left)
            cross = -cross;
        return cross;
    }
}// namespace Vec2Utils

// Vec3 实现
namespace Vec3Utils {
    double angle(const Vec3& a, const Vec3& b) {
        double lenA = a.length();
        double lenB = b.length();
        if (lenA == 0.0 || lenB == 0.0)
            return 0.0;
        double cosTheta = a.dot(b) / (lenA * lenB);
        if (cosTheta < -1.0)
            cosTheta = -1.0;
        if (cosTheta > 1.0)
            cosTheta = 1.0;
        return std::acos(cosTheta);
    }

    Vec3 project(const Vec3& a, const Vec3& b) {
        double lenSq = b.lengthSquared();
        if (lenSq == 0.0)
            return Vec3(0.0, 0.0, 0.0);
            return b * (a.dot(b) / lenSq);
    }

    double side(const Vec3& dir, const Vec3& point, const Vec3& up){
        // 计算 (dir x point) · up
        Vec3 cross = dir.cross(point);
        double value = cross.dot(up);
        // 根据坐标系调整 （如果左手系，Z 轴反向，则符号取反）
        if (g_handedness == Handedness::Left)
            value = -value;
        return value;
    }

    Vec3 toHandedness(const Vec3& v, Handedness target) {
        // 从当前坐标系转换到目标坐标系
        // 默认右手系 -> 左手系： Z 取反；左手系 -> 右手系： Z 取反
        if (g_handedness == target)
            return v;
        // 否则，反转 Z 分量
        return Vec3(v.x, v.y, -v.z);
    }
} // namespace Vec3Utils   
