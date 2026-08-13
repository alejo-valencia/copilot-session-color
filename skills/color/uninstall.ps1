[CmdletBinding()]
param(
    [string]$CopilotHome,
    [switch]$RemoveUserData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "skill-lib.ps1")

$resolvedHome = Resolve-CopilotHome -Override $CopilotHome
$runtimeDirectory = Join-Path $resolvedHome "session-color"
$settingsPath = Join-Path $resolvedHome "settings.json"
$statePath = Join-Path $runtimeDirectory "install-state.json"
$runtimeCommand = Join-Path $runtimeDirectory "session-status.cmd"
$restoredSettings = $false

Invoke-WithSessionColorLock -Name "state" -Action {
    if (-not (Test-Path -LiteralPath $statePath)) {
        throw "Session-color install state was not found. No settings were changed."
    }

    $state = Read-JsonObject -Path $statePath
    if ([int](Get-ObjectProperty -Object $state -Name "schemaVersion" -Default 0) -ne 1) {
        throw "Unsupported install-state schema version."
    }

    $settings = Read-JsonObject -Path $settingsPath -AllowMissing
    $currentStatusLine = Get-ObjectProperty -Object $settings -Name "statusLine"
    $currentCommand = [string](Get-ObjectProperty -Object $currentStatusLine -Name "command" -Default "")

    if (Test-PathEqual -Left $currentCommand -Right $runtimeCommand) {
        if ([bool](Get-ObjectProperty -Object $state -Name "hadStatusLine" -Default $false)) {
            Set-ObjectProperty `
                -Object $settings `
                -Name "statusLine" `
                -Value (Get-ObjectProperty -Object $state -Name "statusLine")
        }
        else {
            Remove-ObjectProperty -Object $settings -Name "statusLine"
        }

        $footer = Get-ObjectProperty -Object $settings -Name "footer"
        if ($null -ne $footer) {
            if ([bool](Get-ObjectProperty -Object $state -Name "hadFooterShowCustom" -Default $false)) {
                Set-ObjectProperty `
                    -Object $footer `
                    -Name "showCustom" `
                    -Value (Get-ObjectProperty -Object $state -Name "footerShowCustom")
            }
            else {
                Remove-ObjectProperty -Object $footer -Name "showCustom"
            }

            if (-not [bool](Get-ObjectProperty -Object $state -Name "hadFooter" -Default $false) -and
                @($footer.PSObject.Properties).Count -eq 0) {
                Remove-ObjectProperty -Object $settings -Name "footer"
            }
        }

        Write-JsonObject -Path $settingsPath -Value $settings
        $restoredSettings = $true
    }

    $runtimeFiles = @(
        "session-status.ps1",
        "session-status.cmd",
        "default-config.json",
        "config.schema.json",
        "install-state.json"
    )
    if ($RemoveUserData) {
        $runtimeFiles += "config.json"
    }

    foreach ($fileName in $runtimeFiles) {
        $path = Join-Path $runtimeDirectory $fileName
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    if (Test-Path -LiteralPath $runtimeDirectory) {
        $remaining = @(Get-ChildItem -Force -LiteralPath $runtimeDirectory)
        if ($remaining.Count -eq 0) {
            [IO.Directory]::Delete($runtimeDirectory)
        }
    }
}

if ($restoredSettings) {
    "Removed Copilot Session Color and restored the previous statusline settings."
}
else {
    "Removed Copilot Session Color files. Settings were unchanged because another statusline is active."
}

if (-not $RemoveUserData -and (Test-Path -LiteralPath (Join-Path $runtimeDirectory "config.json"))) {
    "Kept the local color configuration. Use -RemoveUserData for complete removal."
}
