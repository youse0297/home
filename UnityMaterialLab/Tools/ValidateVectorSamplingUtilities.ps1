param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\VectorSamplingUtilities.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\VectorSamplingUtilitiesValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Convert-ToVector {
    param($Value)
    return @($Value | ForEach-Object { [double]$_ })
}

function Get-Dot {
    param([double[]]$Left, [double[]]$Right)
    return ($Left[0] * $Right[0]) + ($Left[1] * $Right[1]) + ($Left[2] * $Right[2])
}

function Get-Cross {
    param([double[]]$Left, [double[]]$Right)
    return @(
        ($Left[1] * $Right[2] - $Left[2] * $Right[1]),
        ($Left[2] * $Right[0] - $Left[0] * $Right[2]),
        ($Left[0] * $Right[1] - $Left[1] * $Right[0])
    )
}

function Get-SafeNormalize {
    param([double[]]$Value)
    $lengthSquared = Get-Dot -Left $Value -Right $Value
    $inverseLength = 1.0 / [Math]::Sqrt([Math]::Max($lengthSquared, 0.0001))
    return @(
        ($Value[0] * $inverseLength),
        ($Value[1] * $inverseLength),
        ($Value[2] * $inverseLength)
    )
}

function Add-Check {
    param(
        [string]$Id,
        [bool]$Pass,
        [string]$Detail,
        [double]$MaximumError = 0.0
    )
    $checks.Add([ordered]@{
        id = $Id
        pass = $Pass
        detail = $Detail
        maximumError = $MaximumError
    })
}

function Add-NumericCheck {
    param(
        [string]$Id,
        [double[]]$Actual,
        [double[]]$Expected
    )
    $maximumError = 0.0
    if ($Actual.Count -ne $Expected.Count) {
        $maximumError = [double]::PositiveInfinity
    } else {
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $maximumError = [Math]::Max(
                $maximumError,
                [Math]::Abs($Actual[$index] - $Expected[$index])
            )
        }
    }
    Add-Check -Id $Id -Pass ($maximumError -le $tolerance) `
        -Detail ('actual=' + ($Actual -join ', ')) -MaximumError $maximumError
}

foreach ($fixture in @($manifest.fixtures)) {
    switch ($fixture.function) {
        'TA_SafeNormalize' {
            $actual = Get-SafeNormalize -Value (Convert-ToVector $fixture.input.value)
        }
        'TA_EncodeNormalWS' {
            $normal = Get-SafeNormalize -Value (Convert-ToVector $fixture.input.normal)
            $actual = @(
                ($normal[0] * 0.5 + 0.5),
                ($normal[1] * 0.5 + 0.5),
                ($normal[2] * 0.5 + 0.5)
            )
        }
        'TA_BuildBitangentWS' {
            $normal = Convert-ToVector $fixture.input.normal
            $tangent = Convert-ToVector $fixture.input.tangent
            $sign = [double]$fixture.input.sign
            $cross = Get-Cross -Left $normal -Right $tangent
            $actual = @($cross | ForEach-Object { $_ * $sign })
        }
        'TA_BuildTangentToWorld' {
            $normal = Convert-ToVector $fixture.input.normal
            $tangent = Convert-ToVector $fixture.input.tangent
            $cross = Get-Cross -Left $normal -Right @($tangent[0], $tangent[1], $tangent[2])
            $bitangent = @($cross | ForEach-Object { $_ * $tangent[3] })
            $actual = @(
                $tangent[0], $tangent[1], $tangent[2],
                $bitangent[0], $bitangent[1], $bitangent[2],
                $normal[0], $normal[1], $normal[2]
            )
        }
        'TA_TransformTangentToWorld' {
            $vector = Convert-ToVector $fixture.input.vector
            $normal = Convert-ToVector $fixture.input.normal
            $tangent = Convert-ToVector $fixture.input.tangent
            $cross = Get-Cross -Left $normal -Right @($tangent[0], $tangent[1], $tangent[2])
            $bitangent = @($cross | ForEach-Object { $_ * $tangent[3] })
            $transformed = @(
                ($vector[0] * $tangent[0] + $vector[1] * $bitangent[0] + $vector[2] * $normal[0]),
                ($vector[0] * $tangent[1] + $vector[1] * $bitangent[1] + $vector[2] * $normal[1]),
                ($vector[0] * $tangent[2] + $vector[1] * $bitangent[2] + $vector[2] * $normal[2])
            )
            $actual = Get-SafeNormalize -Value $transformed
        }
        'TA_TransformUV' {
            $uv = Convert-ToVector $fixture.input.uv
            $scaleOffset = Convert-ToVector $fixture.input.scaleOffset
            $actual = @(
                ($uv[0] * $scaleOffset[0] + $scaleOffset[2]),
                ($uv[1] * $scaleOffset[1] + $scaleOffset[3])
            )
        }
        'TA_SampleORM' {
            $sample = Convert-ToVector $fixture.input.sample
            $actual = @(
                [Math]::Max(0.0, [Math]::Min(1.0, $sample[0])),
                [Math]::Max(0.0, [Math]::Min(1.0, $sample[1])),
                [Math]::Max(0.0, [Math]::Min(1.0, $sample[2]))
            )
        }
        default {
            throw "Unknown vector or sampling fixture: $($fixture.function)"
        }
    }

    Add-NumericCheck -Id $fixture.id -Actual $actual `
        -Expected (Convert-ToVector $fixture.expected)
}

$vectorPath = Join-Path $projectPath ($manifest.modules.vector -replace '/', '\')
$samplingPath = Join-Path $projectPath ($manifest.modules.sampling -replace '/', '\')
$consumerPath = Join-Path $projectPath ($manifest.consumer -replace '/', '\')
$integrationConsumerPath = Join-Path $projectPath ($manifest.integrationConsumer -replace '/', '\')
$vectorSource = Get-Content -LiteralPath $vectorPath -Raw
$samplingSource = Get-Content -LiteralPath $samplingPath -Raw
$consumerSource = Get-Content -LiteralPath $consumerPath -Raw
$integrationConsumerSource = Get-Content -LiteralPath $integrationConsumerPath -Raw

$vectorSymbols = @($manifest.functions | Where-Object category -eq 'Vector' | ForEach-Object name)
$samplingSymbols = @($manifest.functions | Where-Object category -eq 'Sampling' | ForEach-Object name)
Add-Check -Id 'VECTOR_PUBLIC_SYMBOLS' `
    -Pass ((@($vectorSymbols | Where-Object { $vectorSource -notmatch ('\b' + [Regex]::Escape($_) + '\b') })).Count -eq 0) `
    -Detail ($vectorSymbols -join ', ')
Add-Check -Id 'SAMPLING_PUBLIC_SYMBOLS' `
    -Pass ((@($samplingSymbols | Where-Object { $samplingSource -notmatch ('\b' + [Regex]::Escape($_) + '\b') })).Count -eq 0) `
    -Detail ($samplingSymbols -join ', ')
Add-Check -Id 'UNITY_TEXTURE_MACRO_DELEGATION' `
    -Pass ($samplingSource -match 'TEXTURE2D_PARAM' -and
        $samplingSource -match 'TEXTURE2D_ARGS' -and
        $samplingSource -match 'SAMPLE_TEXTURE2D\(' -and
        $samplingSource -match 'SAMPLE_TEXTURE2D_LOD\(') `
    -Detail 'Unity texture declaration, argument and sample macros'
Add-Check -Id 'UNITY_NORMAL_UNPACK_DELEGATION' `
    -Pass ($samplingSource -match 'UnpackNormalScale\(packedNormal, normalScale\)') `
    -Detail 'Unity platform normal unpacking remains authoritative'
Add-Check -Id 'PBR_INPUT_SAMPLING_WIRING' `
    -Pass ($consumerSource -match 'TA_SampleTexture2D\(' -and
        $consumerSource -match 'TA_SampleNormalTS\(' -and
        $consumerSource -match 'TA_SampleORM\(') `
    -Detail $manifest.consumer
Add-Check -Id 'BASEPASS_VECTOR_INTEGRATION' `
    -Pass ($integrationConsumerSource -match 'TA_TransformUV\(' -and
        $integrationConsumerSource -match 'TA_TransformTangentToWorld\(' -and
        $integrationConsumerSource -match 'TA_SamplePBRInput\(') `
    -Detail $manifest.integrationConsumer

$failed = @($checks | Where-Object { -not $_.pass })
$maximumError = 0.0
foreach ($check in $checks) {
    if ([double]$check.maximumError -gt $maximumError) {
        $maximumError = [double]$check.maximumError
    }
}
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    functionCount = @($manifest.functions).Count
    fixtureCount = @($manifest.fixtures).Count
    tolerance = $tolerance
    maximumError = $maximumError
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = @($failed | ForEach-Object { $_.id })
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failed.Count -gt 0) {
    throw ('Vector and sampling validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', '))
}

Write-Output 'UNITY_VECTOR_SAMPLING_UTILITIES: PASS'
Write-Output "Report: $ReportPath"
