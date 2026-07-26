#include "SoftwareRenderer.hpp"

#include <stdexcept>

namespace SoftRenderer {

SoftwareRenderer::SoftwareRenderer(const RendererConfig& config)
    : config_(config), framebuffer_(config.width, config.height) {
    framebuffer_.clear(config_.clearColor, config_.clearDepth);
}

void SoftwareRenderer::renderFrame(const FrameCallback& callback) {
    if (!callback) {
        throw std::invalid_argument("render frame callback must be valid");
    }
    if (frameInProgress_) {
        throw std::logic_error("renderFrame cannot be called recursively");
    }

    frameInProgress_ = true;
    framebuffer_.clear(config_.clearColor, config_.clearDepth);
    FrameContext context{completedFrames_, framebuffer_};
    try {
        callback(context);
    } catch (...) {
        frameInProgress_ = false;
        throw;
    }
    frameInProgress_ = false;
    ++completedFrames_;
}

void SoftwareRenderer::run(
    std::size_t frameCount,
    const FrameCallback& callback
) {
    if (!callback) {
        throw std::invalid_argument("render loop callback must be valid");
    }
    for (std::size_t frame = 0; frame < frameCount; ++frame) {
        renderFrame(callback);
    }
}

const RendererConfig& SoftwareRenderer::config() const noexcept {
    return config_;
}

Framebuffer& SoftwareRenderer::framebuffer() noexcept {
    return framebuffer_;
}

const Framebuffer& SoftwareRenderer::framebuffer() const noexcept {
    return framebuffer_;
}

std::size_t SoftwareRenderer::completedFrames() const noexcept {
    return completedFrames_;
}

} // namespace SoftRenderer
