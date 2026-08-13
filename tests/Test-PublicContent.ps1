[CmdletBinding()]
param(
    [string[]]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($null -eq $Path -or $Path.Count -eq 0) {
    $Path = @(Split-Path -Parent $PSScriptRoot)
}

$patterns = [ordered]@{
    "Windows user-home path" = "(?i)[A-Z]:\\Users\\[^\\/\r\n]+"
    "macOS user-home path" = "(?i)/" + "Users/" + "[^/\s]+"
    "Linux user-home path" = "(?i)/" + "home/" + "[^/\s]+"
    "GitHub token" = "(?i)(gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})"
    "Copilot session-state path" = "(?i)[\\/]session-state[\\/]"
    "Private key" = "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"
}

$violations = [Collections.Generic.List[string]]::new()
foreach ($root in $Path) {
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    Get-ChildItem -Recurse -File -LiteralPath $resolvedRoot |
        Where-Object { $_.FullName -notmatch "[\\/]\.git[\\/]" } |
        ForEach-Object {
            $relativePath = [IO.Path]::GetRelativePath($resolvedRoot, $_.FullName)
            $content = [IO.File]::ReadAllText($_.FullName)
            foreach ($entry in $patterns.GetEnumerator()) {
                if ($content -match $entry.Value) {
                    $violations.Add("${relativePath}: $($entry.Name)")
                }
            }
        }
}

if ($violations.Count -gt 0) {
    throw "Public-content scan failed:`n$($violations -join [Environment]::NewLine)"
}

"Public-content scan passed."
