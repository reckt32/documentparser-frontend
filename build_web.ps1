# Flutter Web Build Script with Vercel config
# This script builds the Flutter web app and copies vercel.json to the build folder

Write-Host "Building Flutter Web App..." -ForegroundColor Cyan

# Build Flutter web with no service worker caching
flutter build web --release --pwa-strategy=none

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!" -ForegroundColor Green
    
    Write-Host "`nBuild complete! Ready to commit and push." -ForegroundColor Cyan
} else {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}
