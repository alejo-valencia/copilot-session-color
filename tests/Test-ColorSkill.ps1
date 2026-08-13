Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Write-TestJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 64
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText(
        $Path,
        "$json$([Environment]::NewLine)",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Renderer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string]$Payload
    )

    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh
    $startInfo.ArgumentList.Add("-NoLogo")
    $startInfo.ArgumentList.Add("-NoProfile")
    $startInfo.ArgumentList.Add("-File")
    $startInfo.ArgumentList.Add($ScriptPath)
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [Text.Encoding]::UTF8

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        $process.Start() | Out-Null
        $process.StandardInput.Write($Payload)
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            throw "Renderer failed with exit code $($process.ExitCode): $stderr"
        }

        return $stdout.TrimEnd("`r", "`n")
    }
    finally {
        $process.Dispose()
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$skillDirectory = Join-Path $repositoryRoot "skills\color"
$installScript = Join-Path $skillDirectory "install.ps1"
$uninstallScript = Join-Path $skillDirectory "uninstall.ps1"
$setColorScript = Join-Path $skillDirectory "set-session-color.ps1"
$defaultConfigPath = Join-Path $skillDirectory "default-config.json"
$configSchemaPath = Join-Path $skillDirectory "config.schema.json"
$testRoot = Join-Path (
    [IO.Path]::GetTempPath()
) "copilot-session-color-$([guid]::NewGuid().ToString('N'))"

$sessionId = "11111111-2222-4333-8444-555555555555"

try {
    $defaultConfigValid = (
        Get-Content -Raw -LiteralPath $defaultConfigPath
    ) | Test-Json -SchemaFile $configSchemaPath
    Assert-True $defaultConfigValid "Default configuration does not satisfy its schema."

    $copilotHome = Join-Path $testRoot "copilot home with spaces"
    $settingsPath = Join-Path $copilotHome "settings.json"
    Write-TestJson -Path $settingsPath -Value ([pscustomobject]@{
        model = "example-model"
        footer = [pscustomobject]@{
            showQuota = $true
        }
    })

    & $installScript -CopilotHome $copilotHome -Quiet

    $runtimeDirectory = Join-Path $copilotHome "session-color"
    $runtimeScript = Join-Path $runtimeDirectory "session-status.ps1"
    $runtimeCommand = Join-Path $runtimeDirectory "session-status.cmd"
    $configPath = Join-Path $runtimeDirectory "config.json"
    $statePath = Join-Path $runtimeDirectory "install-state.json"

    Assert-True (Test-Path -LiteralPath $runtimeScript) "Renderer was not installed."
    Assert-True (Test-Path -LiteralPath $runtimeCommand) "Command wrapper was not installed."
    Assert-True (Test-Path -LiteralPath $configPath) "Configuration was not created."
    Assert-True (Test-Path -LiteralPath $statePath) "Install state was not created."

    $settings = Get-Content -Raw $settingsPath | ConvertFrom-Json -Depth 64
    Assert-True ($settings.model -eq "example-model") "Installer changed an unrelated setting."
    Assert-True ($settings.footer.showQuota -eq $true) "Installer changed an unrelated footer setting."
    Assert-True ($settings.footer.showCustom -eq $true) "Custom footer was not enabled."
    Assert-True ($settings.statusLine.type -eq "command") "Statusline type was not configured."
    Assert-True (
        $settings.statusLine.command -eq "`"$runtimeCommand`""
    ) "Statusline command path is incorrect."
    Assert-True (
        $null -eq $settings.statusLine.PSObject.Properties["refreshInterval"]
    ) "Installer enabled timer-based statusline polling."

    & $setColorScript `
        -Color green `
        -SessionId $sessionId `
        -CopilotHome $copilotHome |
        Out-Null

    $config = Get-Content -Raw $configPath | ConvertFrom-Json -Depth 64
    $sessionStyle = $config.sessions.PSObject.Properties[$sessionId].Value
    Assert-True ($sessionStyle.ansiColor -eq 114) "Named color was not stored."

    $payload = [pscustomobject]@{
        session_id = $sessionId
        session_name = "Example Session"
        cwd = "C:\projects\sample"
    } | ConvertTo-Json -Compress

    $rendered = Invoke-Renderer -ScriptPath $runtimeScript -Payload $payload
    $plain = $rendered -replace "`e\[[0-9;]*m", ""
    Assert-True (
        $plain -eq "░░▒▒▓▓██ Example Session ██▓▓▒▒░░"
    ) "Default rendered output is incorrect: '$plain'."

    $unnamedPayload = [pscustomobject]@{
        session_id = $sessionId
        session_name = ""
        cwd = "C:\projects\sample"
    } | ConvertTo-Json -Compress
    $unnamedRendered = Invoke-Renderer -ScriptPath $runtimeScript -Payload $unnamedPayload
    $unnamedPlain = $unnamedRendered -replace "`e\[[0-9;]*m", ""
    Assert-True (
        $unnamedPlain -eq "░░▒▒▓▓██ Copilot session ██▓▓▒▒░░"
    ) "Unnamed session fallback is incorrect: '$unnamedPlain'."

    $config.theme.showDirectory = $true
    Write-TestJson -Path $configPath -Value $config
    $renderedWithDirectory = Invoke-Renderer -ScriptPath $runtimeScript -Payload $payload
    $plainWithDirectory = $renderedWithDirectory -replace "`e\[[0-9;]*m", ""
    Assert-True (
        $plainWithDirectory -eq "░░▒▒▓▓██ Example Session ██▓▓▒▒░░ · sample"
    ) "Directory rendering is incorrect: '$plainWithDirectory'."

    $unsafePayload = [pscustomobject]@{
        session_id = $sessionId
        session_name = "Example`e[31m Session`nName"
        cwd = "C:\projects\sample"
    } | ConvertTo-Json -Compress
    $safeRendered = Invoke-Renderer -ScriptPath $runtimeScript -Payload $unsafePayload
    $safePlain = $safeRendered -replace "`e\[[0-9;]*m", ""
    Assert-True (
        $safePlain -eq "░░▒▒▓▓██ Example Session Name ██▓▓▒▒░░ · sample"
    ) "Renderer did not neutralize control characters: '$safePlain'."

    & $setColorScript `
        -Color "#7C3AED" `
        -SessionId $sessionId `
        -CopilotHome $copilotHome |
        Out-Null
    $config = Get-Content -Raw $configPath | ConvertFrom-Json -Depth 64
    $hexColor = $config.sessions.PSObject.Properties[$sessionId].Value.ansiColor
    Assert-True ($hexColor -ge 0 -and $hexColor -le 255) "Hex color did not resolve to ANSI 256."

    $config.sessions.PSObject.Properties[$sessionId].Value |
        Add-Member -NotePropertyName "title" -NotePropertyValue "Local Title"
    Write-TestJson -Path $configPath -Value $config

    & $setColorScript `
        -Color automatic `
        -SessionId $sessionId `
        -CopilotHome $copilotHome |
        Out-Null
    $config = Get-Content -Raw $configPath | ConvertFrom-Json -Depth 64
    $automaticStyle = $config.sessions.PSObject.Properties[$sessionId].Value
    Assert-True (
        $null -eq $automaticStyle.PSObject.Properties["ansiColor"]
    ) "Automatic mode did not remove the color override."
    Assert-True (
        $automaticStyle.title -eq "Local Title"
    ) "Automatic mode removed the local title override."

    $config.theme.decoration = [pscustomobject]@{
        leftGlyphs = @("░", "▒", "▓", "█")
        rightGlyphs = @("█", "▓", "▒", "░")
        intensities = @(0.35, 0.55, 0.75, 1.0)
    }
    Write-TestJson -Path $configPath -Value $config
    & $installScript -CopilotHome $copilotHome -Quiet
    $configAfterUpgrade = Get-Content -Raw $configPath | ConvertFrom-Json -Depth 64
    Assert-True (
        $configAfterUpgrade.theme.showDirectory -eq $true
    ) "Reinstall replaced the user's configuration."
    Assert-True (
        @($configAfterUpgrade.theme.decoration.leftGlyphs).Count -eq 8
    ) "Reinstall did not migrate the original four-character decoration."

    $configAfterUpgrade.theme.decoration = [pscustomobject]@{
        leftGlyphs = @("[")
        rightGlyphs = @("]")
        intensities = @(1.0)
    }
    Write-TestJson -Path $configPath -Value $configAfterUpgrade
    & $installScript -CopilotHome $copilotHome -Quiet
    $configAfterCustomUpgrade = Get-Content -Raw $configPath | ConvertFrom-Json -Depth 64
    Assert-True (
        @($configAfterCustomUpgrade.theme.decoration.leftGlyphs).Count -eq 1
    ) "Reinstall replaced a custom decoration."
    & $uninstallScript -CopilotHome $copilotHome | Out-Null

    $restoredSettings = Get-Content -Raw $settingsPath | ConvertFrom-Json -Depth 64
    Assert-True (
        $null -eq $restoredSettings.PSObject.Properties["statusLine"]
    ) "Uninstall did not remove the installed statusline."
    Assert-True (
        $null -eq $restoredSettings.footer.PSObject.Properties["showCustom"]
    ) "Uninstall did not restore footer.showCustom."
    Assert-True ($restoredSettings.footer.showQuota -eq $true) "Uninstall changed unrelated footer settings."
    Assert-True (Test-Path -LiteralPath $configPath) "Uninstall removed user configuration by default."
    Assert-True (-not (Test-Path -LiteralPath $runtimeScript)) "Uninstall left the renderer installed."

    $conflictHome = Join-Path $testRoot "conflict-home"
    $conflictSettingsPath = Join-Path $conflictHome "settings.json"
    $existingCommand = "C:\tools\existing-statusline.cmd"
    Write-TestJson -Path $conflictSettingsPath -Value ([pscustomobject]@{
        statusLine = [pscustomobject]@{
            type = "command"
            command = $existingCommand
        }
    })

    $conflictRejected = $false
    try {
        & $installScript -CopilotHome $conflictHome -Quiet
    }
    catch {
        $conflictRejected = $true
    }
    Assert-True $conflictRejected "Installer replaced an existing statusline without approval."

    $conflictSettings = Get-Content -Raw $conflictSettingsPath | ConvertFrom-Json
    Assert-True (
        $conflictSettings.statusLine.command -eq $existingCommand
    ) "Conflict handling changed the existing statusline."
    Assert-True (
        -not (Test-Path -LiteralPath (Join-Path $conflictHome "session-color"))
    ) "Conflict handling created runtime files."

    & $installScript -CopilotHome $conflictHome -Force -Quiet
    & $uninstallScript -CopilotHome $conflictHome -RemoveUserData | Out-Null
    $forceRestoredSettings = Get-Content -Raw $conflictSettingsPath | ConvertFrom-Json
    Assert-True (
        $forceRestoredSettings.statusLine.command -eq $existingCommand
    ) "Forced installation did not restore the previous statusline."

    $malformedHome = Join-Path $testRoot "malformed-home"
    $malformedSettingsPath = Join-Path $malformedHome "settings.json"
    Write-TestJson -Path $malformedSettingsPath -Value ([pscustomobject]@{
        footer = "invalid"
    })
    $malformedRejected = $false
    try {
        & $installScript -CopilotHome $malformedHome -Quiet
    }
    catch {
        $malformedRejected = $true
    }
    Assert-True $malformedRejected "Installer accepted a malformed footer setting."
    Assert-True (
        -not (Test-Path -LiteralPath (Join-Path $malformedHome "session-color"))
    ) "Malformed settings caused a partial installation."

    "All Copilot Session Color tests passed."
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        [IO.Directory]::Delete($testRoot, $true)
    }
}
