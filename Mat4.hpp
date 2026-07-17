#pragma once
#include "Vec4.hpp"
#include <array>

class Mat4 {
public:
    // 存储 16 个double元素的数组，按列主序存储（m[col*4 + row]）
    // 即 m[0..3] 第一列为 (x, y, z, w)
    double m[16];

    // 默认构造函数，初始化为零矩阵
    Mat4();

    // 从数组构造 （按列主序）
    explicit Mat4(const double data[16]);

    // 静态工厂：单位矩阵
    static Mat4 identity();

    // 矩阵乘法：this * other
    Mat4 operator*(const Mat4& other) const;

    // 矩阵 x 向量(4D)
    Vec4 operator*(const Vec4& vec) const;

    // 向量 x 矩阵（左乘），已友元函数形式实现
    friend Vec4 operator*(const Vec4& vec, const Mat4& mat);

    // 获取第 i 列（0~3）
    Vec4 getColumn(int col) const;

    friend std::ostream& operator<<(std::ostream& os, const Mat4& mat);
};