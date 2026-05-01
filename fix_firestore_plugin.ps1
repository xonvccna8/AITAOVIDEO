# Fix Cloud Firestore Plugin
Write-Host "=== Fixing Cloud Firestore Plugin ===" -ForegroundColor Cyan

$pluginPath = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\cloud_firestore-5.4.4\android"

if (Test-Path $pluginPath) {
    Write-Host "Found cloud_firestore plugin at: $pluginPath" -ForegroundColor Green
    
    # Fix build.gradle
    $buildGradlePath = "$pluginPath\build.gradle"
    if (Test-Path $buildGradlePath) {
        Write-Host "Fixing build.gradle..." -ForegroundColor Yellow
        
        $content = Get-Content $buildGradlePath -Raw
        
        # Add namespace if missing
        if ($content -notmatch "namespace") {
            $content = $content -replace "android \{", "android {`n    namespace 'io.flutter.plugins.firebase.firestore'"
        }
        
        Set-Content -Path $buildGradlePath -Value $content
        Write-Host "✅ Fixed build.gradle" -ForegroundColor Green
    }
    
    # Check for main class
    $mainClassPath = "$pluginPath\src\main\java\io\flutter\plugins\firebase\firestore\FlutterFirebaseFirestorePlugin.java"
    if (Test-Path $mainClassPath) {
        Write-Host "✅ Main class exists" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Main class not found at expected location" -ForegroundColor Yellow
        Write-Host "Searching for main class..." -ForegroundColor Yellow
        
        $javaFiles = Get-ChildItem -Path "$pluginPath\src" -Filter "*.java" -Recurse
        if ($javaFiles) {
            Write-Host "Found Java files:" -ForegroundColor Green
            $javaFiles | ForEach-Object { Write-Host "  - $($_.FullName)" -ForegroundColor White }
        }
    }
} else {
    Write-Host "⚠️ Plugin not found. Running flutter pub get..." -ForegroundColor Yellow
    flutter pub get
}

Write-Host "`n=== Done! ===" -ForegroundColor Green
Write-Host "Now run: flutter clean && flutter pub get && flutter run" -ForegroundColor Cyan
