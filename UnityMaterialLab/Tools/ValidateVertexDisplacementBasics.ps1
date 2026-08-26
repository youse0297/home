param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\VertexDisplacementBasics.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\VertexDisplacementBasicsValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$tolerance = 0.000001

function Clamp01 {
    param([double]$Value)
    return [Math]::Max([double]0.0, [Math]::Min([double]1.0, $Value))
}

function Get-DecodedDisplacement {
    param([double]$HeightSample, [double]$Amplitude, [double]$Center)
    $sanitizedHeight = Clamp01 $HeightSample
    $sanitizedAmplitude = [Math]::Max([double]-1.0, [Math]::Min([double]1.0, $Amplitude))
    $sanitizedCenter = Clamp01 $Center
    return ($sanitizedHeight - $sanitizedCenter) * $sanitizedAmplitude
}

function Get-DisplacedPosition {
    param([double[]]$Position, [double[]]$Normal, [double]$Displacement)
    $lengthSquared = $Normal[0] * $Normal[0] + $Normal[1] * $Normal[1] + $Normal[2] * $Normal[2]
    $inverseLength = 1.0 / [Math]::Sqrt([Math]::Max($lengthSquared, 0.0001))
    return @(
        ($Position[0] + $Normal[0] * $inverseLength * $Displacement),
        ($Position[1] + $Normal[1] * $inverseLength * $Displacement),
        ($Position[2] + $Normal[2] * $inverseLength * $Displacement)
    )
}

function Add-Check {
    param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0)
    $checks.Add([ordered]@{
        id = $Id
        pass = $Pass
        detail = $Detail
        maximumError = $MaximumError
    })
    if (-not $Pass) { $failures.Add($Id) }
}

function Add-ScalarCheck {
    param([string]$Id, [double]$Actual, [double]$Expected)
    $error = [Math]::Abs($Actual - $Expected)
    Add-Check -Id $Id -Pass ($error -le $tolerance) `
        -Detail "actual=$Actual expected=$Expected" -MaximumError $error
}

function Add-VectorCheck {
    param([string]$Id, [double[]]$Actual, [double[]]$Expected)
    $error = 0.0
    if ($Actual.Count -ne $Expected.Count) {
        $error = [double]::PositiveInfinity
    } else {
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $error = [Math]::Max($error, [Math]::Abs($Actual[$index] - $Expected[$index]))
        }
    }
    Add-Check -Id $Id -Pass ($error -le $tolerance) `
        -Detail "actual=$($Actual -join ', ') expected=$($Expected -join ', ')" `
        -MaximumError $error
}

foreach ($fixture in @($manifest.fixtures)) {
    switch ($fixture.function) {
        'TA_DecodeVertexDisplacement' {
            $actual = Get-DecodedDisplacement `
                ([double]$fixture.input.heightSample) `
                ([double]$fixture.input.amplitude) `
                ([double]$fixture.input.center)
            Add-ScalarCheck -Id $fixture.id -Actual $actual -Expected ([double]$fixture.expected)
        }
        'TA_ApplyVertexDisplacementOS' {
            $actual = Get-DisplacedPosition `
                ([double[]]$fixture.input.positionOS) `
                ([double[]]$fixture.input.normalOS) `
                ([double]$fixture.input.displacement)
            Add-VectorCheck -Id $fixture.id -Actual $actual `
                -Expected @($fixture.expected | ForEach-Object { [double]$_ })
        }
        default { throw "Unknown vertex-displacement fixture function: $($fixture.function)" }
    }
}

$sourcePath = Join-Path $projectPath ($manifest.source -replace '/', '\')
$consumerPath = Join-Path $projectPath ($manifest.consumer -replace '/', '\')
$orchestratorPath = Join-Path $projectPath ($manifest.orchestrator -replace '/', '\')
$source = Get-Content -LiteralPath $sourcePath -Raw
$consumer = Get-Content -LiteralPath $consumerPath -Raw
$orchestrator = Get-Content -LiteralPath $orchestratorPath -Raw
foreach ($symbol in @($manifest.publicSymbols)) {
    Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) `
        -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) `
        -Detail ([string]$symbol)
}
Add-Check -Id 'DECODE_POLICY' `
    -Pass ($source -match 'saturate\(heightSample\)' -and
        $source -match 'clamp\(amplitude, -1\.0h, 1\.0h\)' -and
        $source -match 'saturate\(center\)' -and
        $source -match '\(sanitizedHeight - sanitizedCenter\) \* sanitizedAmplitude') `
    -Detail $manifest.policies.decode
Add-Check -Id 'OBJECT_SPACE_NORMAL_POLICY' `
    -Pass ($source -match 'TA_SafeNormalize\(normalOS\)' -and
        $source -match 'positionOS \+ \(float3\)normalDirectionOS \* displacement') `
    -Detail $manifest.policies.application
Add-Check -Id 'VERTEX_TEXTURE_LOD0' `
    -Pass ($consumer -match 'TA_SampleTexture2DLod\s*\(' -and
        $consumer -match 'TEXTURE2D_ARGS\(_DisplacementMap, sampler_DisplacementMap\)' -and
        $consumer -match 'displacementUV,\s*\r?\n\s*0\.0') `
    -Detail $manifest.policies.sampling
Add-Check -Id 'DEFAULT_PRESERVES_BASELINE' `
    -Pass ($consumer -match '_DisplacementAmplitude\("Displacement Amplitude", Range\(-1, 1\)\) = 0' -and
        $consumer -match '_DisplacementCenter\("Displacement Center", Range\(0, 1\)\) = 0\.5') `
    -Detail $manifest.policies.default
Add-Check -Id 'TRANSFORM_ORDER' `
    -Pass ($orchestrator -match 'TA_DecodeVertexDisplacement\s*\([\s\S]*?TA_ApplyVertexDisplacementOS\s*\([\s\S]*?TA_ApplyWaveWindAnimationOS\s*\(' -and
        $consumer -match 'deformationInput\.heightSample = displacementHeight' -and
        $consumer -match 'TA_EvaluateVertexDeformationOS\s*\([\s\S]*?GetVertexPositionInputs\(deformation\.positionOS\)') `
    -Detail 'High-level orchestration applies object-space height displacement before animation and Unity transforms'

$maximumError = 0.0
foreach ($check in $checks) {
    if ([double]$check.maximumError -gt $maximumError) { $maximumError = [double]$check.maximumError }
}
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    functionCount = @($manifest.publicSymbols).Count
    fixtureCount = @($manifest.fixtures).Count
    invariantCount = @($manifest.invariants).Count
    limitationCount = @($manifest.limitations).Count
    tolerance = $tolerance
    maximumError = $maximumError
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = $failures
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('Vertex displacement basics validation failed: ' + ($failures -join ', '))
}

Write-Output 'UNITY_VERTEX_DISPLACEMENT_BASICS: PASS'
Write-Output "Report: $ReportPath"
