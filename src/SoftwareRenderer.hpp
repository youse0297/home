#pragma once

#include "Framebuffer.hpp"

#include <cstddef>
#include <functional>

namespace SoftRenderer {

struct RendererConfig {
    std::size_t width = 640;
    std::size_t height = 480;
    Color clearColor{};
    double clearDepth = 1.0;
};

struct FrameContext {
    std::size_t frameIndex;
    Framebuffer& framebuffer;
};

class SoftwareRenderer {
public:
    using FrameCallback = std::function<void(FrameContext&)>;

    explicit SoftwareRenderer(const RendererConfig& config);

    void renderFrame(const FrameCallback& callback);
    void run(std::size_t frameCount, const FrameCallback& callback);

    const RendererConfig& config() const noexcept;
    Framebuffer& framebuffer() noexcept;
    const Framebuffer& framebuffer() const noexcept;
    std::size_t completedFrames() const noexcept;

private:
    RendererConfig config_;
    Framebuffer framebuffer_;
    std::size_t completedFrames_ = 0;
    bool frameInProgress_ = false;
};

} // namespace SoftRenderer
