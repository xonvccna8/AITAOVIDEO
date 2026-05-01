param(
    [switch]$Preview
)

$argsList = @("--yes", "--scope", "xonvccna8s-projects")
if (-not $Preview) {
    $argsList = @("--prod") + $argsList
}

& vercel @argsList
exit $LASTEXITCODE
