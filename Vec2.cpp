#include "Vec2.hpp"
#include <cmath>
#include <stdexcept>

Vec2 Vec2::operator+(const Vec2& other) const {
    return Vec2(x + other.x, y + other.y);
}

Vec2& Vec2::operator+=(const Vec2& other) {
    x += other.x;
    y += other.y;
    return *this;
}

Vec2 Vec2::operator-(const Vec2& other) const {
    return Vec2(x - other.x, y - other.y);
}

Vec2& Vec2::operator-=(const Vec2& other) {
    x -= other.x;
    y -= other.y;
    return *this;
}

Vec2 Vec2::operator*(double scalar) const {
    return Vec2(x * scalar, y * scalar);
}

Vec2 operator*(double scalar, const Vec2& vec) {
    return vec * scalar;
}

Vec2& Vec2::operator*=(double scalar) {
    x *= scalar;
    y *= scalar;
    return *this;
}

Vec2 Vec2::operator/(double scalar) const {
    if (scalar == 0.0) throw std::runtime_error("Division by zero");
    return Vec2(x / scalar, y / scalar);
}

Vec2& Vec2::operator/=(double scalar) {
    if (scalar == 0.0) throw std::runtime_error("Division by zero");
    x /= scalar;
    y /= scalar;
    return *this;
}

Vec2 Vec2::operator-() const {
    return Vec2(-x, -y);
}

double Vec2::dot(const Vec2& other) const {
    return x * other.x + y * other.y;
}

double Vec2::lengthSquared() const {
    return dot(*this);
}

double Vec2::length() const {
    return std::sqrt(lengthSquared());
}

Vec2 Vec2::normalized() const {
    double len = length();
    if (len == 0.0) return Vec2(0, 0);  // 零向量归一化返回零向量
    return *this / len;
}

Vec2& Vec2::normalize() {
    double len = length();
    if (len != 0.0) {
        *this /= len;
    }
    return *this;
}

std::ostream& operator<<(std::ostream& os, const Vec2& v) {
    os << "(" << v.x << ", " << v.y << ")";
    return os;
}

double Vec2::cross(const Vec2& other) const {
    return x * other.y - y * other.x;
}