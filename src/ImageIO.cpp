#include "ImageIO.hpp"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>

namespace SoftRenderer {
namespace ImageIO {

namespace {

unsigned char quantizeChannel(double value) {
    if (!std::isfinite(value)) {
        throw std::invalid_argument("PPM color channels must be finite");
    }
    const double normalized = std::clamp(value, 0.0, 1.0);
    return static_cast<unsigned char>(std::lround(normalized * 255.0));
}

} // namespace

std::vector<unsigned char> encodePpmRgb8(const Framebuffer& framebuffer) {
    if (framebuffer.pixelCount() >
        (std::numeric_limits<std::size_t>::max() - 64U) / 3U) {
        throw std::length_error("PPM byte count overflowed");
    }
    const std::string header =
        "P6\n" + std::to_string(framebuffer.width()) + " " +
        std::to_string(framebuffer.height()) + "\n255\n";
    std::vector<unsigned char> bytes;
    bytes.reserve(header.size() + framebuffer.pixelCount() * 3U);
    bytes.insert(bytes.end(), header.begin(), header.end());
    for (const Color& color : framebuffer.colorBuffer()) {
        bytes.push_back(quantizeChannel(color.r));
        bytes.push_back(quantizeChannel(color.g));
        bytes.push_back(quantizeChannel(color.b));
    }
    return bytes;
}

void writePpmRgb8(const Framebuffer& framebuffer, const std::string& path) {
    if (path.empty()) {
        throw std::invalid_argument("PPM output path must not be empty");
    }
    const std::vector<unsigned char> bytes = encodePpmRgb8(framebuffer);
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output.is_open()) {
        throw std::runtime_error("could not open PPM output: " + path);
    }
    output.write(
        reinterpret_cast<const char*>(bytes.data()),
        static_cast<std::streamsize>(bytes.size())
    );
    if (!output) {
        throw std::runtime_error("failed to write PPM output: " + path);
    }
}

} // namespace ImageIO
} // namespace SoftRenderer
