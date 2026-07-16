#pragma once
#include <cmath>
#include <iostream>

class Vec3 {
    public:
        double x, y, z;

        //构造函数
        Vec3(double x = 0, double y = 0, double z = 0) : x(x), y(y), z(z) {}

        //加法
        Vec3 operator+(const Vec3& other) const;
        Vec3& operator+=(const Vec3& other);

        //减法
        Vec3 operator-(const Vec3& other) const;
        Vec3& operator-=(const Vec3& other);

        //数乘（标量乘法）
        Vec3 operator*(double scalar) const;
        friend Vec3 operator*(double scalar, const Vec3& vec);
        Vec3& operator*=(double scalar);

        //数除（标量除法,可选）
        Vec3 operator/(double scalar) const;
        friend Vec3 operator/(double scalar, const Vec3& vec);
        Vec3& operator/=(double scalar);

        //取负
        Vec3 operator-() const;

        //点积
        double dot(const Vec3& other) const;
        double length() const;
        double lengthSquared() const;

        //归一化
        Vec3 normalized() const;
        //原地归一化
        Vec3& normalize();

        //打印
        friend std::ostream& operator<<(std::ostream& os, const Vec3& v);
};