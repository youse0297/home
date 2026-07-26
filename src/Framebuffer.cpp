#include "Framebuffer.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>

namespace SoftRenderer {

namespace {

void requireColor(const Color& color) {
    if (!std::isfinite(color.r) || !std::isfinite(color.g) ||
        !std::isfinite(color.b) || !std::isfinite(color.a)) {
        throw std::invalid_argument("framebuffer color must be finite");
    }
}

void requireDepth(double depth) {
    if (!std::isfinite(depth) || depth < 0.0 || depth > 1.0) {
        throw std::invalid_argument("framebuffer depth must be within [0, 1]");
    }
}

std::size_t requirePixelCount(std::size_t width, std::size_t height) {
    if (width == 0 || height == 0) {
        throw std::invalid_argument("framebuffer dimensions must be non-zero");
    }
    if (width > std::numeric_limits<std::size_t>::max() / height) {
        throw std::length_error("framebuffer dimensions overflow pixel count");
    }
    return width * height;
}

} // namespace

Framebuffer::Framebuffer(std::size_t width, std::size_t height) {
    resize(width, height);
}

void Framebuffer::resize(std::size_t width, std::size_t height) {
    const std::size_t count = requirePixelCount(width, height);
    std::vector<Color> newColors(count, Color{});
    std::vector<double> newDepths(count, 1.0);

    width_ = width;
    height_ = height;
    colorBuffer_.swap(newColors);
    depthBuffer_.swap(newDepths);
}

void Framebuffer::clear(const Color& color, double depth) {
    requireColor(color);
    requireDepth(depth);
    std::fill(colorBuffer_.begin(), colorBuffer_.end(), color);
    std::fill(depthBuffer_.begin(), depthBuffer_.end(), depth);
}

void Framebuffer::clearColor(const Color& color) {
    requireColor(color);
    std::fill(colorBuffer_.begin(), colorBuffer_.end(), color);
}

void Framebuffer::clearDepth(double depth) {
    requireDepth(depth);
    std::fill(depthBuffer_.begin(), depthBuffer_.end(), depth);
}

void Framebuffer::setColor(std::size_t x, std::size_t y, const Color& color) {
    requireColor(color);
    colorBuffer_[indexOf(x, y)] = color;
}

void Framebuffer::setDepth(std::size_t x, std::size_t y, double depth) {
    requireDepth(depth);
    depthBuffer_[indexOf(x, y)] = depth;
}

const Color& Framebuffer::colorAt(std::size_t x, std::size_t y) const {
    return colorBuffer_[indexOf(x, y)];
}

double Framebuffer::depthAt(std::size_t x, std::size_t y) const {
    return depthBuffer_[indexOf(x, y)];
}

std::size_t Framebuffer::width() const noexcept {
    return width_;
}

std::size_t Framebuffer::height() const noexcept {
    return height_;
}

std::size_t Framebuffer::pixelCount() const noexcept {
    return colorBuffer_.size();
}

const std::vector<Color>& Framebuffer::colorBuffer() const noexcept {
    return colorBuffer_;
}

const std::vector<double>& Framebuffer::depthBuffer() const noexcept {
    return depthBuffer_;
}

std::size_t Framebuffer::indexOf(std::size_t x, std::size_t y) const {
    if (x >= width_ || y >= height_) {
        throw std::out_of_range("framebuffer coordinates are out of range");
    }
    return y * width_ + x;
}

} // namespace SoftRenderer
