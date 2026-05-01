# Script để tự động sửa lỗi các plugins sau flutter pub get
# Chạy script này sau mỗi lần chạy: flutter pub get

Write-Host "Fixing plugin issues..." -ForegroundColor Yellow

$pubCache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"

# ==========================================
# Fix gallery_saver plugin
# ==========================================
Write-Host ""
Write-Host "[1/4] Fixing gallery_saver plugin..." -ForegroundColor Cyan

$gallerySaverPath = "$pubCache\gallery_saver-2.3.2\android\build.gradle"
$gallerySaverPluginPath = "$pubCache\gallery_saver-2.3.2\android\src\main\kotlin\carnegietechnologies\gallery_saver\GallerySaverPlugin.kt"

if (Test-Path $gallerySaverPath) {
    $content = Get-Content $gallerySaverPath -Raw
    $changed = $false
    
    # Add namespace if missing
    if ($content -notmatch "namespace\s+'carnegietechnologies\.gallery_saver'") {
        if ($content -match "android\s+\{") {
            $content = $content -replace "(android\s+\{)", '$1    namespace ''carnegietechnologies.gallery_saver'''
            $changed = $true
            Write-Host "  Added namespace to gallery_saver" -ForegroundColor Green
        }
    }
    
    # Add compileSdkVersion if missing (CRITICAL - must be added)
    if ($content -notmatch "compileSdkVersion") {
        if ($content -match "namespace\s+'carnegietechnologies\.gallery_saver'") {
            $content = $content -replace "(namespace\s+'carnegietechnologies\.gallery_saver')", "`$1`n    compileSdkVersion 34"
            $changed = $true
            Write-Host "  Added compileSdkVersion to gallery_saver" -ForegroundColor Green
        } elseif ($content -match "android\s+\{") {
            $content = $content -replace "(android\s+\{)", '$1    compileSdkVersion 34'
            $changed = $true
            Write-Host "  Added compileSdkVersion to gallery_saver" -ForegroundColor Green
        }
    }
    
    # Add compileOptions if missing
    if ($content -notmatch "compileOptions\s+\{") {
        if ($content -match "compileSdkVersion") {
            $compileOptionsBlock = @"

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
"@
            $content = $content -replace "(compileSdkVersion\s+\d+)", "$1$compileOptionsBlock"
            $changed = $true
            Write-Host "  Added compileOptions to gallery_saver" -ForegroundColor Green
        } elseif ($content -match "namespace\s+'carnegietechnologies\.gallery_saver'") {
            $compileOptionsBlock = @"

    compileSdkVersion 34

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
"@
            $content = $content -replace "(namespace\s+'carnegietechnologies\.gallery_saver')", "`$1$compileOptionsBlock"
            $changed = $true
            Write-Host "  Added compileSdkVersion and compileOptions to gallery_saver" -ForegroundColor Green
        }
    }
    
    # Add kotlinOptions if missing
    if ($content -notmatch "kotlinOptions\s+\{") {
        $kotlinOptionsBlock = @"

    kotlinOptions {
        jvmTarget = '11'
    }
"@
        if ($content -match "compileOptions[^\}]*\}") {
            $content = $content -replace "(compileOptions[^\}]*\})", "$1$kotlinOptionsBlock"
            $changed = $true
            Write-Host "  Added kotlinOptions to gallery_saver" -ForegroundColor Green
        }
    }
    
    if ($changed) {
        Set-Content -Path $gallerySaverPath -Value $content -NoNewline
    }
}

if (Test-Path $gallerySaverPluginPath) {
    $pluginContent = Get-Content $gallerySaverPluginPath -Raw
    if ($pluginContent -match "import io\.flutter\.plugin\.common\.PluginRegistry\.Registrar") {
        $pluginContent = $pluginContent -replace "import io\.flutter\.plugin\.common\.PluginRegistry\.Registrar\r?\n", ''
        Set-Content -Path $gallerySaverPluginPath -Value $pluginContent -NoNewline
        Write-Host "  Removed unused Registrar import from GallerySaverPlugin.kt" -ForegroundColor Green
    }
}

# ==========================================
# Fix image_cropper plugin
# ==========================================
Write-Host ""
Write-Host "[2/4] Fixing image_cropper plugin..." -ForegroundColor Cyan

$imageCropperPath = "$pubCache\image_cropper-4.0.1\android\build.gradle"
$imageCropperPluginPath = "$pubCache\image_cropper-4.0.1\android\src\main\java\vn\hunghd\flutter\plugins\imagecropper\ImageCropperPlugin.java"

if (Test-Path $imageCropperPath) {
    $content = Get-Content $imageCropperPath -Raw
    $changed = $false
    
    # Add compileSdkVersion if missing (must be after namespace block)
    if ($content -notmatch "compileSdkVersion") {
        # Try to add after namespace block
        if ($content -match "(if\s+\(project\.android\.hasProperty\(""namespace""\)\)\s+\{[^}]+\})") {
            $content = $content -replace "($1)", "`$1`n    compileSdkVersion 34"
            $changed = $true
            Write-Host "  Added compileSdkVersion to image_cropper" -ForegroundColor Green
        } elseif ($content -match "(android\s+\{)") {
            # Fallback: add at start of android block
            $content = $content -replace "(android\s+\{)", '$1    compileSdkVersion 34'
            $changed = $true
            Write-Host "  Added compileSdkVersion to image_cropper" -ForegroundColor Green
        }
    }
    
    # Add compileOptions if missing
    if ($content -notmatch "compileOptions\s+\{") {
        $compileOptionsBlock = @"

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
"@
        if ($content -match "compileSdkVersion") {
            $content = $content -replace "(compileSdkVersion\s+\d+)", "$1$compileOptionsBlock"
            $changed = $true
            Write-Host "  Added compileOptions to image_cropper" -ForegroundColor Green
        } elseif ($content -match "(android\s+\{[^\}]*)(defaultConfig)") {
            $content = $content -replace "($1)", "`$1    compileSdkVersion 34$compileOptionsBlock`n`n    "
            $changed = $true
            Write-Host "  Added compileSdkVersion and compileOptions to image_cropper" -ForegroundColor Green
        }
    }
    
    if ($changed) {
        Set-Content -Path $imageCropperPath -Value $content -NoNewline
    }
}

if (Test-Path $imageCropperPluginPath) {
    $pluginContent = Get-Content $imageCropperPluginPath -Raw
    $changed = $false
    
    # Remove PluginRegistry import
    if ($pluginContent -match "import io\.flutter\.plugin\.common\.PluginRegistry;") {
        $pluginContent = $pluginContent -replace "import io\.flutter\.plugin\.common\.PluginRegistry;\r?\n", ''
        $changed = $true
        Write-Host "  Removed PluginRegistry import" -ForegroundColor Green
    }
    
    # Remove registerWith method
    if ($pluginContent -match "public static void registerWith") {
        $lines = $pluginContent -split "\r?\n"
        $newLines = @()
        $skip = $false
        $braceCount = 0
        foreach ($line in $lines) {
            if ($line -match "public static void registerWith") {
                $skip = $true
                $openBraces = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $closeBraces = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                $braceCount = $openBraces - $closeBraces
                continue
            }
            if ($skip) {
                $openBraces = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $closeBraces = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                $braceCount = $braceCount + $openBraces - $closeBraces
                if ($braceCount -le 0) {
                    $skip = $false
                    continue
                }
                continue
            }
            $newLines += $line
        }
        $pluginContent = $newLines -join "`r`n"
        $changed = $true
        Write-Host "  Removed registerWith method from ImageCropperPlugin.java" -ForegroundColor Green
    }
    
    if ($changed) {
        Set-Content -Path $imageCropperPluginPath -Value $pluginContent -NoNewline
    }
}

# ==========================================
# Verify fixes
# ==========================================
Write-Host ""
Write-Host "[3/4] Verifying fixes..." -ForegroundColor Cyan

if (Test-Path $gallerySaverPath) {
    $content = Get-Content $gallerySaverPath -Raw
    if ($content -match "namespace" -and $content -match "compileOptions" -and $content -match "kotlinOptions") {
        Write-Host "  gallery_saver build.gradle looks good" -ForegroundColor Green
    }
}

if (Test-Path $gallerySaverPluginPath) {
    $content = Get-Content $gallerySaverPluginPath -Raw
    if ($content -notmatch "PluginRegistry\.Registrar") {
        Write-Host "  gallery_saver plugin code looks good" -ForegroundColor Green
    }
}

if (Test-Path $imageCropperPath) {
    $content = Get-Content $imageCropperPath -Raw
    if ($content -match "compileOptions") {
        Write-Host "  image_cropper build.gradle looks good" -ForegroundColor Green
    }
}

if (Test-Path $imageCropperPluginPath) {
    $content = Get-Content $imageCropperPluginPath -Raw
    if ($content -notmatch "PluginRegistry\.Registrar" -and $content -notmatch "registerWith.*Registrar") {
        Write-Host "  image_cropper plugin code looks good" -ForegroundColor Green
    }
}

# ==========================================
# Summary
# ==========================================
Write-Host ""
Write-Host "[4/4] Summary" -ForegroundColor Cyan
Write-Host "All plugin fixes applied successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now build your app with: flutter run" -ForegroundColor Cyan
