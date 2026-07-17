#pragma once
#include "Vec3.hpp"
#include <iostream>

class Vec4 {
public:
    double x, y, z, w;

    // 构造函数，默认 w 为 1.0（表示齐次坐标）
    Vec4(double x = 0.0, double y = 0.0, double z = 0.0, double w = 1.0);
    
    // 从 Vec3 转换为 Vec4，默认 w 为 1.0
    explicit Vec4(const Vec3& vec3, double w = 1.0);

    // 基础运算符重载
    Vec4 operator+(const Vec4& other) const;
    Vec4 operator-(const Vec4& other) const;
    Vec4 operator*(double scalar) const;
    Vec4 operator/(double scalar) const;
    Vec4& operator+=(const Vec4& other);
    Vec4& operator-=(const Vec4& other);
    Vec4& operator*=(double scalar);
    Vec4& operator/=(double scalar);

    // 点积
    double dot(const Vec4& other) const;

    // 长度归一化
    double length() const;
    Vec4 normalize() const;

    // 输出向量信息
    friend std::ostream& operator<<(std::ostream& os, const Vec4& v);
};
