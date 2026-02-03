# Flutter Web Build Script with Vercel config
# This script builds the Flutter web app and copies vercel.json to the build folder

Write-Host "Building Flutter Web App..." -ForegroundColor Cyan

# Build Flutter web with no service worker caching
flutter build web --release --pwa-strategy=none

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!" -ForegroundColor Green
    
    # Copy vercel.json to build/web
    $sourceFile = Join-Path $PSScriptRoot "vercel.json"
    $destFolder = Join-Path $PSScriptRoot "build\web"
    
    if (Test-Path $sourceFile) {
        Copy-Item $sourceFile -Destination $destFolder -Force
        Write-Host "Copied vercel.json to build/web" -ForegroundColor Green
    } else {
        Write-Host "Warning: vercel.json not found in project root" -ForegroundColor Yellow
    }
    
    Write-Host "`nBuild complete! Ready to commit and push." -ForegroundColor Cyan
} else {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}
