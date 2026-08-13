Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$utf8 = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

function Get-ObjectProperty {
    param(
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function ConvertTo-SafeStatusText {
    param(
        [AllowNull()]
        [string]$Value,

        [ValidateRange(1, 500)]
        [int]$MaximumLength = 120
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $withoutAnsi = $Value -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
    $characters = foreach ($character in $withoutAnsi.ToCharArray()) {
        if ([char]::IsControl($character)) {
            " "
        }
        else {
            $character
        }
    }
    $safeValue = ((-join $characters) -replace "\s+", " ").Trim()
    if ($safeValue.Length -gt $MaximumLength) {
        return $safeValue.Substring(0, $MaximumLength)
    }

    return $safeValue
}

function ConvertFrom-Ansi256Color {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 255)]
        [int]$Color
    )

    $standardColors = @(
        @(0, 0, 0),
        @(128, 0, 0),
        @(0, 128, 0),
        @(128, 128, 0),
        @(0, 0, 128),
        @(128, 0, 128),
        @(0, 128, 128),
        @(192, 192, 192),
        @(128, 128, 128),
        @(255, 0, 0),
        @(0, 255, 0),
        @(255, 255, 0),
        @(0, 0, 255),
        @(255, 0, 255),
        @(0, 255, 255),
        @(255, 255, 255)
    )

    if ($Color -lt 16) {
        return $standardColors[$Color]
    }

    if ($Color -lt 232) {
        $levels = @(0, 95, 135, 175, 215, 255)
        $cubeIndex = $Color - 16
        $redIndex = [math]::Floor($cubeIndex / 36)
        $greenIndex = [math]::Floor(($cubeIndex % 36) / 6)
        $blueIndex = $cubeIndex % 6
        return @(
            $levels[$redIndex],
            $levels[$greenIndex],
            $levels[$blueIndex]
        )
    }

    $gray = 8 + (10 * ($Color - 232))
    return @($gray, $gray, $gray)
}

function Get-GradientBar {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 255)]
        [int]$Color,

        [Parameter(Mandatory = $true)]
        [string[]]$Glyphs,

        [Parameter(Mandatory = $true)]
        [double[]]$Intensities
    )

    if ($Glyphs.Count -ne $Intensities.Count) {
        throw "Gradient glyph and intensity counts must match."
    }

    $rgb = ConvertFrom-Ansi256Color -Color $Color
    $escape = [char]27
    $segments = for ($index = 0; $index -lt $Glyphs.Count; $index++) {
        if ([string]::IsNullOrEmpty($Glyphs[$index]) -or
            $Glyphs[$index].Length -gt 2 -or
            $Glyphs[$index].ToCharArray().Where({ [char]::IsControl($_) }).Count -gt 0) {
            throw "Decoration glyphs must contain one printable character."
        }

        $intensity = $Intensities[$index]
        if ($intensity -lt 0 -or $intensity -gt 1) {
            throw "Gradient intensity must be between 0 and 1."
        }

        $red = [math]::Round($rgb[0] * $intensity)
        $green = [math]::Round($rgb[1] * $intensity)
        $blue = [math]::Round($rgb[2] * $intensity)
        "$escape[38;2;$red;$green;$blue" + "m$($Glyphs[$index])"
    }

    return $segments -join ""
}

function Write-ConfigurationError {
    $escape = [char]27
    "$escape[31m[session-color configuration error]$escape[0m"
}

$payloadText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($payloadText)) {
    exit 0
}

try {
    $payload = $payloadText | ConvertFrom-Json -Depth 32
}
catch {
    exit 0
}

try {
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Configuration file is missing."
    }

    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json -Depth 64
    if ($null -eq $config -or $config -is [array]) {
        throw "Configuration root must be an object."
    }
    if ([int](Get-ObjectProperty -Object $config -Name "schemaVersion" -Default 0) -ne 1) {
        throw "Unsupported configuration schema version."
    }

    $theme = Get-ObjectProperty -Object $config -Name "theme"
    if ($null -eq $theme) {
        throw "Theme configuration is missing."
    }

    $palette = @(
        Get-ObjectProperty -Object $theme -Name "palette" -Default @()
    )
    if ($palette.Count -eq 0) {
        throw "The automatic color palette cannot be empty."
    }
    foreach ($paletteColor in $palette) {
        $value = [int]$paletteColor
        if ($value -lt 0 -or $value -gt 255) {
            throw "Palette colors must be between 0 and 255."
        }
    }

    $decoration = Get-ObjectProperty -Object $theme -Name "decoration"
    if ($null -eq $decoration) {
        throw "Decoration configuration is missing."
    }
    $leftGlyphs = @(
        Get-ObjectProperty -Object $decoration -Name "leftGlyphs" -Default @()
    )
    $rightGlyphs = @(
        Get-ObjectProperty -Object $decoration -Name "rightGlyphs" -Default @()
    )
    $intensities = @(
        Get-ObjectProperty -Object $decoration -Name "intensities" -Default @()
    )
    if ($leftGlyphs.Count -ne $rightGlyphs.Count -or
        $leftGlyphs.Count -ne $intensities.Count) {
        throw "Left glyph, right glyph, and intensity counts must match."
    }

    $sessionId = [string](Get-ObjectProperty -Object $payload -Name "session_id" -Default "")
    $sessionName = ConvertTo-SafeStatusText -Value (
        [string](Get-ObjectProperty -Object $payload -Name "session_name" -Default "")
    )
    if ([string]::IsNullOrWhiteSpace($sessionName)) {
        $sessionName = ConvertTo-SafeStatusText -Value (
            [string](
                Get-ObjectProperty `
                    -Object $theme `
                    -Name "fallbackSessionName" `
                    -Default "Copilot session"
            )
        )
    }
    if ([string]::IsNullOrWhiteSpace($sessionName)) {
        throw "The fallback session name cannot be empty."
    }

    $color = $null
    $sessions = Get-ObjectProperty -Object $config -Name "sessions"
    $sessionStyle = if ($null -eq $sessions -or [string]::IsNullOrWhiteSpace($sessionId)) {
        $null
    }
    else {
        $property = $sessions.PSObject.Properties[$sessionId]
        if ($null -eq $property) {
            $null
        }
        else {
            $property.Value
        }
    }

    if ($null -ne $sessionStyle) {
        $configuredColor = Get-ObjectProperty -Object $sessionStyle -Name "ansiColor"
        if ($null -ne $configuredColor) {
            $color = [int]$configuredColor
        }

        $configuredTitle = [string](
            Get-ObjectProperty -Object $sessionStyle -Name "title" -Default ""
        )
        if (-not [string]::IsNullOrWhiteSpace($configuredTitle)) {
            $sessionName = ConvertTo-SafeStatusText -Value $configuredTitle
        }
    }

    if ($null -eq $color) {
        $hashSource = if (-not [string]::IsNullOrWhiteSpace($sessionId)) {
            $sessionId
        }
        else {
            $sessionName
        }

        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($hashSource)
            $hash = $sha.ComputeHash($bytes)
            $color = [int]$palette[$hash[0] % $palette.Count]
        }
        finally {
            $sha.Dispose()
        }
    }

    if ($color -lt 0 -or $color -gt 255) {
        throw "Session color must be between 0 and 255."
    }

    $leftGradient = Get-GradientBar `
        -Color $color `
        -Glyphs $leftGlyphs `
        -Intensities $intensities

    $rightIntensities = [double[]]@($intensities)
    [array]::Reverse($rightIntensities)
    $rightGradient = Get-GradientBar `
        -Color $color `
        -Glyphs $rightGlyphs `
        -Intensities $rightIntensities

    $escape = [char]27
    $reset = "$escape[0m"
    $titlePrefix = if ([bool](
        Get-ObjectProperty -Object $theme -Name "boldTitle" -Default $true
    )) {
        "$escape[1;38;5;$($color)m"
    }
    else {
        "$escape[38;5;$($color)m"
    }

    $titleSegment = "$titlePrefix$sessionName$reset"
    $sessionSegment = if ($leftGlyphs.Count -eq 0) {
        $titleSegment
    }
    else {
        "$leftGradient $titleSegment $rightGradient$reset"
    }

    $showDirectory = [bool](
        Get-ObjectProperty -Object $theme -Name "showDirectory" -Default $false
    )
    $workingDirectory = [string](
        Get-ObjectProperty -Object $payload -Name "cwd" -Default ""
    )
    if (-not $showDirectory -or [string]::IsNullOrWhiteSpace($workingDirectory)) {
        $sessionSegment
        exit 0
    }

    $folder = ConvertTo-SafeStatusText `
        -Value (Split-Path -Leaf $workingDirectory) `
        -MaximumLength 80
    $separator = ConvertTo-SafeStatusText -Value (
        [string](
            Get-ObjectProperty -Object $theme -Name "directorySeparator" -Default "·"
        )
    )
    "$sessionSegment $escape[2m$separator $folder$reset"
}
catch {
    Write-ConfigurationError
}
