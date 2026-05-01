param()

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$asciiBase = Join-Path $env:LOCALAPPDATA 'HistovisionAsciiWorkspace'
$junctionPath = Join-Path $asciiBase 'Histovision'

New-Item -ItemType Directory -Path $asciiBase -Force | Out-Null

if (Test-Path -LiteralPath $junctionPath) {
    $item = Get-Item -LiteralPath $junctionPath -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "ASCII workspace path already exists and is not a junction: $junctionPath"
    }
} else {
    New-Item -ItemType Junction -Path $junctionPath -Target $projectRoot | Out-Null
}

Write-Output $junctionPath
