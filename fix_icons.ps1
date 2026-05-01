$files = Get-ChildItem -Path lib -Recurse -File | Where-Object { $_.Extension -eq '.dart' }
foreach ($file in $files) {
    if ($file.FullName -notmatch '\\build|\\\.dart_tool') {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $newContent = $content -replace "Icons\.chemistry_edu", "Icons.science" -replace "Icons\.Chemistry_edu", "Icons.science" -replace "Icons\.chemistry", "Icons.science" -replace "Icons\.Chemistry", "Icons.science" -replace "register_screen_mock\.dart", "register_screen_local.dart" -replace "RegisterScreenMock", "RegisterScreenLocal"
        if ($newContent -cne $content) {
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
            Write-Host "Fixed in $($file.FullName)"
        }
    }
}
