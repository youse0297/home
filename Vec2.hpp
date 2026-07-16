#pragma once
#include <cmath>
#include <iostream>

class Vec2 {
    public:
        double x, y;

        //构造函数
        Vec2(double x = 0, double y = 0) : x(x), y(y) {}

        //加法
        Vec2 operator+(const Vec2& other) const;
        Vec2& operator+=(const Vec2& other);

        //减法
        Vec2 operator-(const Vec2& other) const;
        Vec2& operator-=(const Vec2& other);

        //数乘（标量乘法）
        Vec2 operator*(double scalar) const;
        friend Vec2 operator*(double scalar, const Vec2& vec);
        Vec2& operator*=(double scalar);

        //数除（标量除法,可选）
        Vec2 operator/(double scalar) const;
        friend Vec2 operator/(double scalar, const Vec2& vec);
        Vec2& operator/=(double scalar);

        //取负
        Vec2 operator-() const;

        //点积
        double dot(const Vec2& other) const;
        double length() const;
        double lengthSquared() const;

        //归一化
        Vec2 normalized() const;
        //原地归一化
        Vec2& normalize();

        //打印
        friend std::ostream& operator<<(std::ostream& os, const Vec2& v);
};