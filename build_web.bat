@echo off
REM Flutter Web Build Script with Vercel config
REM This script builds the Flutter web app and copies vercel.json to the build folder

echo Building Flutter Web App...

flutter build web --release --pwa-strategy=none

if %ERRORLEVEL% EQU 0 (
    echo Build successful!
    
    REM Copy vercel.json to build/web
    if exist "%~dp0vercel.json" (
        copy /Y "%~dp0vercel.json" "%~dp0build\web\vercel.json"
        echo Copied vercel.json to build/web
    ) else (
        echo Warning: vercel.json not found in project root
    )
    
    echo.
    echo Build complete! Ready to commit and push.
) else (
    echo Build failed!
    exit /b 1
)
