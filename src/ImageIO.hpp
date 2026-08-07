#pragma once

#include "Framebuffer.hpp"

#include <string>
#include <vector>

namespace SoftRenderer {
namespace ImageIO {

std::vector<unsigned char> encodePpmRgb8(const Framebuffer& framebuffer);
void writePpmRgb8(const Framebuffer& framebuffer, const std::string& path);

} // namespace ImageIO
} // namespace SoftRenderer
