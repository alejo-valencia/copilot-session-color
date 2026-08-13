Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-CopilotHome {
    param(
        [string]$Override
    )

    $path = if (-not [string]::IsNullOrWhiteSpace($Override)) {
        $Override
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:COPILOT_HOME)) {
        $env:COPILOT_HOME
    }
    else {
        Join-Path $HOME ".copilot"
    }

    return [IO.Path]::GetFullPath($path)
}

function Read-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$AllowMissing
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        if ($AllowMissing) {
            return [pscustomobject]@{}
        }

        throw "Required JSON file not found: '$Path'."
    }

    $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 64
    if ($null -eq $value -or $value -is [array]) {
        throw "'$Path' must contain a JSON object."
    }

    return $value
}

function Write-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null

    $temporaryPath = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $json = $Value | ConvertTo-Json -Depth 64
        [IO.File]::WriteAllText(
            $temporaryPath,
            "$json$([Environment]::NewLine)",
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Copy-FileAtomically {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required source file not found: '$Source'."
    }

    $directory = Split-Path -Parent $Destination
    [IO.Directory]::CreateDirectory($directory) | Out-Null

    $temporaryPath = "$Destination.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::Copy($Source, $temporaryPath, $true)
        [IO.File]::Move($temporaryPath, $Destination, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

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

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
        $property.Value = $Value
    }
}

function Remove-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -ne $Object.PSObject.Properties[$Name]) {
        $Object.PSObject.Properties.Remove($Name)
    }
}

function Test-PathEqual {
    param(
        [string]$Left,
        [string]$Right
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }

    try {
        $leftPath = [IO.Path]::GetFullPath($Left.Trim().Trim('"')).TrimEnd("\", "/")
        $rightPath = [IO.Path]::GetFullPath($Right.Trim().Trim('"')).TrimEnd("\", "/")
        return $leftPath.Equals($rightPath, [StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

function Invoke-WithSessionColorLock {
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^[A-Za-z0-9-]+$")]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    $mutex = [Threading.Mutex]::new($false, "Local\CopilotSessionColor-$Name")
    $hasLock = $false
    try {
        try {
            $hasLock = $mutex.WaitOne([TimeSpan]::FromSeconds(10))
        }
        catch [Threading.AbandonedMutexException] {
            $hasLock = $true
        }

        if (-not $hasLock) {
            throw "Timed out waiting for another session-color operation."
        }

        & $Action
    }
    finally {
        if ($hasLock) {
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
    }
}
