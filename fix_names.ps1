$files = Get-ChildItem -Path . -Recurse -File | Where-Object { $_.Extension -match "\.(dart|yaml|xml|plist|kt|txt|md|json|gradle|kts)" }
foreach ($file in $files) {
    if ($file.FullName -notmatch '\\\.git|\\build|\\\.dart_tool') {
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $newContent = $content -replace "package:ChemiVision", "package:chemivision" -replace "name: histovision", "name: chemivision" -replace "package:histovision", "package:chemivision"
            if ($newContent -cne $content) {
                Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
                Write-Host "Updated $($file.FullName)"
            }
        } catch {}
    }
}
