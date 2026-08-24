[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Color,

    [string]$SessionId = $env:COPILOT_AGENT_SESSION_ID,

    [string]$CopilotHome
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "skill-lib.ps1")

function Get-NearestAnsiColor {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Red,

        [Parameter(Mandatory = $true)]
        [int]$Green,

        [Parameter(Mandatory = $true)]
        [int]$Blue
    )

    $levels = @(0, 95, 135, 175, 215, 255)
    $bestColor = 16
    $bestDistance = [double]::PositiveInfinity

    for ($redIndex = 0; $redIndex -lt $levels.Count; $redIndex++) {
        for ($greenIndex = 0; $greenIndex -lt $levels.Count; $greenIndex++) {
            for ($blueIndex = 0; $blueIndex -lt $levels.Count; $blueIndex++) {
                $redDelta = $Red - $levels[$redIndex]
                $greenDelta = $Green - $levels[$greenIndex]
                $blueDelta = $Blue - $levels[$blueIndex]
                $distance = ($redDelta * $redDelta) +
                    ($greenDelta * $greenDelta) +
                    ($blueDelta * $blueDelta)

                if ($distance -lt $bestDistance) {
                    $bestDistance = $distance
                    $bestColor = 16 + (36 * $redIndex) + (6 * $greenIndex) + $blueIndex
                }
            }
        }
    }

    for ($grayIndex = 0; $grayIndex -lt 24; $grayIndex++) {
        $grayLevel = 8 + (10 * $grayIndex)
        $redDelta = $Red - $grayLevel
        $greenDelta = $Green - $grayLevel
        $blueDelta = $Blue - $grayLevel
        $distance = ($redDelta * $redDelta) +
            ($greenDelta * $greenDelta) +
            ($blueDelta * $blueDelta)

        if ($distance -lt $bestDistance) {
            $bestDistance = $distance
            $bestColor = 232 + $grayIndex
        }
    }

    return $bestColor
}

function Resolve-RequestedColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [object]$NamedColors
    )

    $normalized = $Value.Trim().ToLowerInvariant()
    if ($normalized -eq "grey") {
        $normalized = "gray"
    }

    if ($normalized -in @("automatic", "auto", "default")) {
        return [pscustomobject]@{
            IsAutomatic = $true
            Name = "automatic"
            AnsiColor = $null
        }
    }

    $namedProperty = $NamedColors.PSObject.Properties[$normalized]
    if ($null -ne $namedProperty) {
        $ansiColor = [int]$namedProperty.Value
        if ($ansiColor -lt 0 -or $ansiColor -gt 255) {
            throw "Named color '$normalized' must map to an ANSI value from 0 to 255."
        }

        return [pscustomobject]@{
            IsAutomatic = $false
            Name = $normalized
            AnsiColor = $ansiColor
        }
    }

    $numericColor = 0
    if ([int]::TryParse($normalized, [ref]$numericColor)) {
        if ($numericColor -lt 0 -or $numericColor -gt 255) {
            throw "ANSI color must be between 0 and 255."
        }

        return [pscustomobject]@{
            IsAutomatic = $false
            Name = "ANSI $numericColor"
            AnsiColor = $numericColor
        }
    }

    if ($normalized -match "^#?([0-9a-f]{6})$") {
        $hex = $Matches[1]
        $red = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        $green = [Convert]::ToInt32($hex.Substring(2, 2), 16)
        $blue = [Convert]::ToInt32($hex.Substring(4, 2), 16)
        $ansiColor = Get-NearestAnsiColor -Red $red -Green $green -Blue $blue

        return [pscustomobject]@{
            IsAutomatic = $false
            Name = "#$($hex.ToUpperInvariant())"
            AnsiColor = $ansiColor
        }
    }

    $supported = ($NamedColors.PSObject.Properties.Name | Sort-Object) -join ", "
    throw "Unknown color '$Value'. Use one of: $supported; a hex color; an ANSI value from 0 to 255; or automatic."
}

$resolvedHome = Resolve-CopilotHome -Override $CopilotHome
$configPath = Join-Path (Join-Path $resolvedHome "session-color") "config.json"
$config = Read-JsonObject -Path $configPath
if ([int](Get-ObjectProperty -Object $config -Name "schemaVersion" -Default 0) -ne 1) {
    throw "Unsupported configuration schema version."
}
$prompts = Get-ObjectProperty -Object $config -Name "prompts"
$restartNotice = [string](
    Get-ObjectProperty `
        -Object $prompts `
        -Name "restartNotice" `
        -Default "If this is your first /color command in this session and the color is not visible yet, run /restart once to apply the statusline."
)
$theme = Get-ObjectProperty -Object $config -Name "theme"
$namedColors = Get-ObjectProperty -Object $theme -Name "namedColors"
if ($null -eq $namedColors -or $namedColors -isnot [pscustomobject]) {
    throw "The configuration must define theme.namedColors."
}

$normalizedRequest = $Color.Trim().ToLowerInvariant()
if ($normalizedRequest -in @("list", "colors")) {
    $namedColors.PSObject.Properties |
        Sort-Object Name |
        ForEach-Object { "$($_.Name): $($_.Value)" }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($SessionId)) {
    throw "The current Copilot session ID is unavailable. Run this from GitHub Copilot CLI or pass -SessionId explicitly."
}

$resolvedColor = Resolve-RequestedColor -Value $Color -NamedColors $namedColors

Invoke-WithSessionColorLock -Name "state" -Action {
    $currentConfig = Read-JsonObject -Path $configPath
    $sessions = Get-ObjectProperty -Object $currentConfig -Name "sessions"
    if ($null -eq $sessions) {
        $sessions = [pscustomobject]@{}
        Set-ObjectProperty -Object $currentConfig -Name "sessions" -Value $sessions
    }
    elseif ($sessions -isnot [pscustomobject]) {
        throw "The sessions configuration must be a JSON object."
    }

    $sessionProperty = $sessions.PSObject.Properties[$SessionId]
    if ($resolvedColor.IsAutomatic) {
        if ($null -ne $sessionProperty) {
            $sessionStyle = $sessionProperty.Value
            if ($null -eq $sessionStyle -or $sessionStyle -isnot [pscustomobject]) {
                $sessions.PSObject.Properties.Remove($SessionId)
            }
            else {
                Remove-ObjectProperty -Object $sessionStyle -Name "ansiColor"
                if (@($sessionStyle.PSObject.Properties).Count -eq 0) {
                    $sessions.PSObject.Properties.Remove($SessionId)
                }
            }
        }
    }
    elseif ($null -eq $sessionProperty) {
        $sessions | Add-Member -NotePropertyName $SessionId -NotePropertyValue (
            [pscustomobject]@{ ansiColor = $resolvedColor.AnsiColor }
        )
    }
    else {
        $sessionStyle = $sessionProperty.Value
        if ($null -eq $sessionStyle -or $sessionStyle -isnot [pscustomobject]) {
            $sessionStyle = [pscustomobject]@{}
            $sessionProperty.Value = $sessionStyle
        }
        Set-ObjectProperty `
            -Object $sessionStyle `
            -Name "ansiColor" `
            -Value $resolvedColor.AnsiColor
    }

    Write-JsonObject -Path $configPath -Value $currentConfig
}

if ($resolvedColor.IsAutomatic) {
    "Set Copilot session $SessionId to automatic color selection."
}
else {
    "Set Copilot session $SessionId to $($resolvedColor.Name) (ANSI $($resolvedColor.AnsiColor))."
}
if (-not [string]::IsNullOrWhiteSpace($restartNotice)) {
    $restartNotice
}
