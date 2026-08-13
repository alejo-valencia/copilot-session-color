[CmdletBinding()]
param(
    [string]$CopilotHome,
    [switch]$Force,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "skill-lib.ps1")

function Convert-ArrayToCompactJson {
    param(
        [object[]]$Value
    )

    return ConvertTo-Json -InputObject @($Value) -Compress
}

function Update-ConfigDefaults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true)]
        [string]$DefaultConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return
    }

    $config = Read-JsonObject -Path $ConfigPath
    $theme = Get-ObjectProperty -Object $config -Name "theme"
    $decoration = Get-ObjectProperty -Object $theme -Name "decoration"
    $changed = $false
    $usesLegacyDefault = $false
    if ($null -ne $decoration) {
        $leftGlyphs = @(Get-ObjectProperty -Object $decoration -Name "leftGlyphs" -Default @())
        $rightGlyphs = @(Get-ObjectProperty -Object $decoration -Name "rightGlyphs" -Default @())
        $intensities = @(Get-ObjectProperty -Object $decoration -Name "intensities" -Default @())
        $usesLegacyDefault = (
            (Convert-ArrayToCompactJson $leftGlyphs) -eq
                (Convert-ArrayToCompactJson @("░", "▒", "▓", "█")) -and
            (Convert-ArrayToCompactJson $rightGlyphs) -eq
                (Convert-ArrayToCompactJson @("█", "▓", "▒", "░")) -and
            (Convert-ArrayToCompactJson $intensities) -eq
                (Convert-ArrayToCompactJson @(0.35, 0.55, 0.75, 1.0))
        )
    }
    $defaults = Read-JsonObject -Path $DefaultConfigPath
    $defaultTheme = Get-ObjectProperty -Object $defaults -Name "theme"
    if ($usesLegacyDefault) {
        $defaultDecoration = Get-ObjectProperty -Object $defaultTheme -Name "decoration"
        Set-ObjectProperty -Object $theme -Name "decoration" -Value $defaultDecoration
        $changed = $true
    }

    if ($null -eq $theme.PSObject.Properties["titleWidth"]) {
        Set-ObjectProperty `
            -Object $theme `
            -Name "titleWidth" `
            -Value (Get-ObjectProperty -Object $defaultTheme -Name "titleWidth" -Default 35)
        $changed = $true
    }

    if ($null -eq $theme.PSObject.Properties["titleBackground"]) {
        Set-ObjectProperty `
            -Object $theme `
            -Name "titleBackground" `
            -Value (Get-ObjectProperty -Object $defaultTheme -Name "titleBackground" -Default "solid")
        $changed = $true
    }

    if ($changed) {
        Write-JsonObject -Path $ConfigPath -Value $config
    }
}

$resolvedHome = Resolve-CopilotHome -Override $CopilotHome
$runtimeDirectory = Join-Path $resolvedHome "session-color"
$settingsPath = Join-Path $resolvedHome "settings.json"
$statePath = Join-Path $runtimeDirectory "install-state.json"
$runtimeCommand = Join-Path $runtimeDirectory "session-status.cmd"
$configuredCommand = "`"$runtimeCommand`""

Invoke-WithSessionColorLock -Name "state" -Action {
    [IO.Directory]::CreateDirectory($resolvedHome) | Out-Null

    $settings = Read-JsonObject -Path $settingsPath -AllowMissing
    $statusLineProperty = $settings.PSObject.Properties["statusLine"]
    $existingStatusLine = if ($null -eq $statusLineProperty) {
        $null
    }
    else {
        $statusLineProperty.Value
    }
    $existingCommand = [string](Get-ObjectProperty -Object $existingStatusLine -Name "command" -Default "")
    $isCurrentInstall = Test-PathEqual -Left $existingCommand -Right $runtimeCommand
    $footerProperty = $settings.PSObject.Properties["footer"]
    $existingFooter = if ($null -eq $footerProperty) {
        $null
    }
    else {
        $footerProperty.Value
    }
    if ($null -ne $existingFooter -and $existingFooter -isnot [pscustomobject]) {
        throw "The footer setting must be a JSON object."
    }
    $showCustomProperty = if ($null -eq $existingFooter) {
        $null
    }
    else {
        $existingFooter.PSObject.Properties["showCustom"]
    }

    if ($null -ne $existingStatusLine -and -not $isCurrentInstall -and -not $Force) {
        throw "Another Copilot statusline is already configured. Re-run with -Force only if you intend to replace it."
    }

    [IO.Directory]::CreateDirectory($runtimeDirectory) | Out-Null

    if (-not $isCurrentInstall) {
        $state = [pscustomobject]@{
            schemaVersion = 1
            hadStatusLine = $null -ne $statusLineProperty
            statusLine = $existingStatusLine
            hadFooter = $null -ne $footerProperty
            hadFooterShowCustom = $null -ne $showCustomProperty
            footerShowCustom = if ($null -eq $showCustomProperty) {
                $null
            }
            else {
                $showCustomProperty.Value
            }
        }
        Write-JsonObject -Path $statePath -Value $state
    }
    elseif (-not (Test-Path -LiteralPath $statePath)) {
        if (-not $Force) {
            throw "The statusline points to session-color, but its install state is missing. Use -Force to adopt the current configuration."
        }

        $state = [pscustomobject]@{
            schemaVersion = 1
            hadStatusLine = $false
            statusLine = $null
            hadFooter = $null -ne $footerProperty
            hadFooterShowCustom = $false
            footerShowCustom = $null
        }
        Write-JsonObject -Path $statePath -Value $state
    }

    $runtimeFiles = @(
        "session-status.ps1",
        "session-status.cmd",
        "default-config.json",
        "config.schema.json"
    )
    foreach ($fileName in $runtimeFiles) {
        Copy-FileAtomically `
            -Source (Join-Path $PSScriptRoot $fileName) `
            -Destination (Join-Path $runtimeDirectory $fileName)
    }

    $configPath = Join-Path $runtimeDirectory "config.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        Copy-FileAtomically `
            -Source (Join-Path $PSScriptRoot "default-config.json") `
            -Destination $configPath
    }
    Update-ConfigDefaults `
        -ConfigPath $configPath `
        -DefaultConfigPath (Join-Path $PSScriptRoot "default-config.json")

    $footer = Get-ObjectProperty -Object $settings -Name "footer"
    if ($null -eq $footer) {
        $footer = [pscustomobject]@{}
        Set-ObjectProperty -Object $settings -Name "footer" -Value $footer
    }
    Set-ObjectProperty -Object $footer -Name "showCustom" -Value $true

    $statusLine = [pscustomobject]@{
        type = "command"
        command = $configuredCommand
        padding = 1
    }
    Set-ObjectProperty -Object $settings -Name "statusLine" -Value $statusLine
    Write-JsonObject -Path $settingsPath -Value $settings
}

if (-not $Quiet) {
    "Installed Copilot Session Color in '$runtimeDirectory'."
    "Run /restart if the statusline does not appear automatically."
}
