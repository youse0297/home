# Unity 程序化遮罩

`TA_ProceduralMask.hlsl` 为 Renderer 侧提供无纹理依赖的程序化遮罩。输入为 Base UV、显式时间、二维缩放/偏移、旋转、相位、对比度和强度；输出始终位于 `[0,1]`。

## 约定

- `TA_EvaluateProceduralMask` 使用有界正弦场生成遮罩，`_Time.y` 由 BasePass 显式传入，不读取隐藏的全局资源。
- `strength=0` 与恒等遮罩 `1` 等价，因此未启用遮罩时不会改变既有材质基线。
- `TA_ApplyProceduralMask` 先夹取层权重和遮罩，再相乘；当前 BasePass 将同一遮罩作用于 detail 与 macro 切线空间法线层。
- `MaterialInputProfile` 对缩放、旋转、时间速度、相位、对比度和强度执行有限值及范围保护。

## 验收

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File UnityMaterialLab/Tools/ValidateProceduralMask.ps1
```

脚本固定身份遮罩、正弦波峰/波谷、部分强度、零对比度和层权重夹取共 8 组夹具，并验证 `MAT_LayeredNormal` / `MI_LayeredNormal` 的参数接线。报告写入 `UnityMaterialLab/Reports/ProceduralMaskValidation.json`，契约位于 `UnityMaterialLab/Assets/_TA/Documentation/ProceduralMask.json`。

## 边界

该模块刻意保持为轻量正弦场，不替代蓝噪声或纹理噪声；当前示例只调制多层法线权重，若要驱动颜色、粗糙度或透明度，必须在对应材质消费端显式接线。运行时视觉确认仍需要已授权的 Unity Editor。
