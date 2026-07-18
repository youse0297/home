#pragma once
#include "Vec2.hpp"
#include "Vec3.hpp"

// 坐标系约定
enum class Handedness {
    Right, // 右手系 （默认）
    Left   // 左手系 （z 轴反向）
};

// 全局设置 （可在运行时修改，或编译期指定）
extern Handedness g_handedness;

// Vec2 辅助函数
namespace Vec2Utils{
    // 夹角 （弧度） [0, π]
    double angle(const Vec2& a, const Vec2& b);

    // 投影向量：a 在 b 上的投影
    Vec2 project(const Vec2& a, const Vec2& b);

    // 朝向判定：在右手系下，返回 >0 表示 b 在 a 逆时针方向 （左）， <0 为顺时针 （右边）
    // 在左手系下符号相反
    double side(const Vec2& a, const Vec2& b);
}

// Vec3 辅助函数
namespace Vec3Utils{
    // 夹角（弧度）
    double angle(const Vec3& a, const Vec3& b);

    // 投影向量
    Vec3 project(const Vec3& a, const Vec3& b);

    // 侧向判断：给定方向向量 dir 和向上向量 up （通常为 （0,0,1） 或 (0,0,-1))
    // 返回 （dir x point) · up 的符号 （受坐标系影响）
    double side(const Vec3& dir, const Vec3& point, const Vec3& up);

    //坐标系转换：将向量从当前坐标系转换到目标坐标系
    Vec3 toHandedness(const Vec3& v, Handedness target);
}
