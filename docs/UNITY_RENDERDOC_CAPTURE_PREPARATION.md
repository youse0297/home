# Unity RenderDoc 截帧准备

本日程项交付的是可重复的捕获准备层，不把静态预览图或不存在的二进制冒充 `.rdc`。实际捕获需要本机安装 RenderDoc，并需要 Unity `2022.3.62f3c1` 的有效许可证。

## 固定输入

- 场景：`Assets/_TA/Scenes/SCN_MaterialImportLab.unity`
- URP Pipeline：`Assets/_TA/Settings/RP_MaterialLab_URP.asset`
- Forward Renderer：`Assets/_TA/Settings/RD_MaterialLab_Forward.asset`
- 捕获分辨率：`1280x720`
- VSync：关闭；目标帧率：`30`
- Render Scale：`1.0`；MSAA：`1x`；HDR：开启

## GPU 事件书签

`RenderDocCaptureFeature` 通过 URP `ScriptableRendererFeature` 注入六个 GPU marker：

`RD/Frame/Begin` → `RD/Opaque/Boundary` → `RD/Lighting/Forward` → `RD/Transparent/Boundary` → `RD/PostFX/Boundary` → `RD/Frame/End`

这些名称会出现在 RenderDoc 的 Event Browser 中，便于快速定位 Opaque、Lighting、Transparent 和 PostFX 边界。完整事件点、数值和操作步骤记录在 `Assets/_TA/Documentation/RenderDocCaptureManifest.json`。

## 操作步骤

1. 安装 RenderDoc，并确认 `Tools/RenderDocCaptureCheck.ps1` 输出 `READY_TO_CAPTURE`。
2. 激活 Unity 许可证，打开项目并运行 `TA/Material Lab/Prepare RenderDoc Capture`。
3. 进入 `SCN_MaterialImportLab`，固定 `1280x720` 窗口，等待画面稳定后只捕获一帧。
4. 将文件保存为 `Reports/RenderDoc/MaterialLab_Frame_0001.rdc`。
5. 在 Event Browser 中检查六个 `RD/*` 书签，重点查看 Opaque/Lighting/Transparent/PostFX 的输入输出和资源状态。

## 当前状态

本机当前没有 RenderDoc 可执行文件，因此 `Reports/RenderDocCaptureReadiness.json` 会记录 `BLOCKED_TOOLING`，`RenderDocCaptureManifest.json` 保持 `PENDING_CAPTURE`，`Reports/RenderDoc/` 只保留归档说明，不生成空的或伪造的 `.rdc`。Unity Editor 运行时还受本机许可证状态限制；静态工程验收仍会检查源码、清单、事件书签和 URP 配置契约。

## 常见失败点

- 用不同分辨率、VSync 或 Render Scale 捕获，导致资源尺寸和时间线不可比。
- 只设置 CPU `Profiler.BeginSample`，没有通过 URP render pass 写入 GPU marker。
- 捕获发生在场景尚未稳定、Shader 尚未编译完成或相机仍在移动的帧。
- 修改 Renderer Feature 顺序后没有重新保存 renderer asset，导致 marker 不在预期边界。
- 将 RenderDoc 未安装或 Unity 无许可证误判为渲染代码失败；先查看 readiness JSON 和 Editor 日志。
