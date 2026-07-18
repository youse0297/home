#pragma once
#include "Mat4.hpp"
#include "Vec3.hpp"

namespace Transform {

    // 平移矩阵 （平移向量 t）
    Mat4 translation(const Vec3& t);

    // 缩放向量 （各轴缩放因子 s）
    Mat4 scaling(const Vec3& s);

    // 绕x轴旋转矩阵 （旋转角度 angle，单位为弧度）
    Mat4 rotationX(double angle);

    // 绕y轴旋转矩阵 （旋转角度 angle，单位为弧度）
    Mat4 rotationY(double angle);

    // 绕z轴旋转矩阵 （旋转角度 angle，单位为弧度）
    Mat4 rotationZ(double angle);

    // 绕任意轴旋转矩阵 （旋转角度 angle，单位为弧度，旋转轴 axis 必须是单位向量）
    Mat4 rotationAxis(const Vec3& axis, double angle);

} // namespace Transform