param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\MaterialFunctionLibraryV1.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\MaterialFunctionLibraryValidation.json')
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Add-NumericCheck {
    param(
        [string]$Id,
        [double[]]$Actual,
        [double[]]$Expected
    )
    $maximumError = 0.0
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        $maximumError = [Math]::Max($maximumError, [Math]::Abs($Actual[$index] - $Expected[$index]))
    }
    $checks.Add([ordered]@{
        id = $Id
        actual = $Actual
        expected = $Expected
        maximumError = $maximumError
        pass = $maximumError -le $tolerance
    })
}

foreach ($fixture in $manifest.fixtures) {
    switch ($fixture.function) {
        'TA_TransformUV' {
            $uv = @($fixture.input.uv | ForEach-Object { [double]$_ })
            $tiling = @($fixture.input.tiling | ForEach-Object { [double]$_ })
            $offset = @($fixture.input.offset | ForEach-Object { [double]$_ })
            $actual = @(
                (($uv[0] * $tiling[0]) + $offset[0]),
                (($uv[1] * $tiling[1]) + $offset[1])
            )
        }
        'TA_RotateUV' {
            $uv = @($fixture.input.uv | ForEach-Object { [double]$_ })
            $center = @($fixture.input.center | ForEach-Object { [double]$_ })
            $radians = [double]$fixture.input.degrees * [Math]::PI / 180.0
            $centeredX = $uv[0] - $center[0]
            $centeredY = $uv[1] - $center[1]
            $actual = @(
                (($centeredX * [Math]::Cos($radians)) - ($centeredY * [Math]::Sin($radians)) + $center[0]),
                (($centeredX * [Math]::Sin($radians)) + ($centeredY * [Math]::Cos($radians) + $center[1]))
            )
        }
        'TA_NormalStrength' {
            $normal = @($fixture.input.normal | ForEach-Object { [double]$_ })
            $strength = [Math]::Max(0.0, [Math]::Min(2.0, [double]$fixture.input.strength))
            $normalX = [double]$normal[0]
            $normalY = [double]$normal[1]
            $normalZ = [double]$normal[2]
            $scaledX = $normalX * $strength
            $scaledY = $normalY * $strength
            $scaledZ = $normalZ
            $scaled = @(
                $scaledX,
                $scaledY,
                $scaledZ
            )
            $lengthSquared = ($scaledX * $scaledX) + ($scaledY * $scaledY) + ($scaledZ * $scaledZ)
            $length = [Math]::Sqrt($lengthSquared)
            $actual = if ($length -gt 0.0001) {
                $outputX = $scaledX / $length
                $outputY = $scaledY / $length
                $outputZ = $scaledZ / $length
                @($outputX, $outputY, $outputZ)
            } else {
                @(0.0, 0.0, 1.0)
            }
        }
        'TA_UnpackORM' {
            $packed = @($fixture.input.packed | ForEach-Object { [double]$_ })
            $packedR = [double]$packed[0]
            $packedG = [double]$packed[1]
            $packedB = [double]$packed[2]
            $actual = @(
                [Math]::Max(0.0, [Math]::Min(1.0, $packedR)),
                [Math]::Max(0.0, [Math]::Min(1.0, $packedG)),
                [Math]::Max(0.0, [Math]::Min(1.0, $packedB))
            )
        }
        'TA_UnpackRGBA' {
            $actual = @($fixture.input.packed | ForEach-Object { [double]$_ })
        }
        'TA_AdjustColor' {
            $color = @($fixture.input.color | ForEach-Object { [double]$_ })
            $colorR = [double]$color[0]
            $colorG = [double]$color[1]
            $colorB = [double]$color[2]
            $luminance = ($colorR * 0.2126) + ($colorG * 0.7152) + ($colorB * 0.0722)
            $saturation = [Math]::Max(0.0, [double]$fixture.input.saturation)
            $contrast = [Math]::Max(0.0, [double]$fixture.input.contrast)
            $brightness = [Math]::Max(0.0, [double]$fixture.input.brightness)
            $actual = @(0..2 | ForEach-Object {
                $saturated = $luminance + ($color[$_] - $luminance) * $saturation
                [Math]::Max((($saturated - 0.5) * $contrast + 0.5) * $brightness, 0.0)
            })
        }
        default {
            throw "Unknown material function fixture: $($fixture.function)"
        }
    }

    Add-NumericCheck -Id $fixture.id -Actual $actual -Expected @($fixture.expected | ForEach-Object { [double]$_ })
}

$failed = @($checks | Where-Object { -not $_.pass })
$report = [ordered]@{
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    functionCount = @($manifest.functions).Count
    fixtureCount = @($manifest.fixtures).Count
    tolerance = $tolerance
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failed.Count -gt 0) {
    throw ('Material function library validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', '))
}

Write-Output 'UNITY_MATERIAL_FUNCTION_LIBRARY_V1: PASS'
Write-Output "Report: $ReportPath"
