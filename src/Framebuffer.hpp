#pragma once

#include <cstddef>
#include <vector>

namespace SoftRenderer {

struct Color {
    double r = 0.0;
    double g = 0.0;
    double b = 0.0;
    double a = 1.0;
};

class Framebuffer {
public:
    Framebuffer(std::size_t width, std::size_t height);

    void resize(std::size_t width, std::size_t height);
    void clear(const Color& color, double depth);
    void clearColor(const Color& color);
    void clearDepth(double depth);

    void setColor(std::size_t x, std::size_t y, const Color& color);
    void setDepth(std::size_t x, std::size_t y, double depth);
    bool depthTest(std::size_t x, std::size_t y, double depth) const;
    bool writeFragment(
        std::size_t x,
        std::size_t y,
        double depth,
        const Color& color
    );

    const Color& colorAt(std::size_t x, std::size_t y) const;
    double depthAt(std::size_t x, std::size_t y) const;

    std::size_t width() const noexcept;
    std::size_t height() const noexcept;
    std::size_t pixelCount() const noexcept;
    const std::vector<Color>& colorBuffer() const noexcept;
    const std::vector<double>& depthBuffer() const noexcept;

private:
    std::size_t indexOf(std::size_t x, std::size_t y) const;

    std::size_t width_ = 0;
    std::size_t height_ = 0;
    std::vector<Color> colorBuffer_;
    std::vector<double> depthBuffer_;
};

} // namespace SoftRenderer
