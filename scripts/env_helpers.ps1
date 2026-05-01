function Get-ProjectRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-DotEnvFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $values = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $values
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed.StartsWith("#")) {
            continue
        }

        $separatorIndex = $trimmed.IndexOf("=")
        if ($separatorIndex -le 0) {
            continue
        }

        $key = $trimmed.Substring(0, $separatorIndex).Trim()
        $value = $trimmed.Substring($separatorIndex + 1).Trim()

        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $values[$key] = $value
    }

    return $values
}

function Get-LocalEnv {
    $root = Get-ProjectRoot
    $envPath = Join-Path $root ".env.local"
    $values = Read-DotEnvFile -Path $envPath
    return @{
        Root = $root
        Path = $envPath
        Values = $values
    }
}

function Assert-LocalEnv {
    $local = Get-LocalEnv
    if (-not (Test-Path -LiteralPath $local.Path)) {
        Write-Host "Missing .env.local" -ForegroundColor Red
        Write-Host "Create it from .env.example and fill your API keys:" -ForegroundColor Yellow
        Write-Host "  Copy-Item .env.example .env.local" -ForegroundColor White
        exit 1
    }

    return $local
}

function Get-DartDefineArgs {
    param(
        [Parameter(Mandatory = $true)]
        $EnvValues
    )

    $keys = @(
        "AI_VIDEO_ACCESS_TOKEN",
        "AI_VIDEO_BASE_URL",
        "AI_VIDEO_DOMAIN",
        "AI_VIDEO_PROJECT_ID",
        "AI_VIDEO_MODEL",
        "AI_VIDEO_RESOLUTION",
        "OPENAI_API_KEY",
        "GEMINI_API_KEY",
        "YOUTUBE_API_KEY"
    )

    $args = @()
    foreach ($key in $keys) {
        if ($EnvValues.Contains($key) -and -not [string]::IsNullOrWhiteSpace($EnvValues[$key])) {
            $args += "--dart-define=$key=$($EnvValues[$key])"
        }
    }

    return $args
}
