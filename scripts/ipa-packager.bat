@echo off
title BTChess IPA Packager
set ROOT_DIR=%~dp0

echo ===================================================
echo                BTCHESS IPA PACKAGER
echo ===================================================
echo. 

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop'; " ^
  "try { " ^
  "  Write-Host '1. Checking for ios-xcarchive.zip...' -ForegroundColor Cyan; " ^
  "  if (!(Test-Path 'ios-xcarchive.zip')) { throw 'ios-xcarchive.zip not found in the current folder.' } " ^
  "  Write-Host '2. Extracting ios-xcarchive.zip...' -ForegroundColor Cyan; " ^
  "  Expand-Archive -Path 'ios-xcarchive.zip' -DestinationPath 'ios-xcarchive' -Force; " ^
  "  Set-Location -Path 'ios-xcarchive'; " ^
  "  Write-Host '3. Checking for Runner.xcarchive.tar.gz...' -ForegroundColor Cyan; " ^
  "  if (!(Test-Path 'Runner.xcarchive.tar.gz')) { throw 'Runner.xcarchive.tar.gz not found inside the extracted folder.' } " ^
  "  Write-Host '4. Extracting Runner.xcarchive.tar.gz...' -ForegroundColor Cyan; " ^
  "  $null = New-Item -ItemType Directory -Force -Path 'Runner.xcarchive'; " ^
  "  tar -xzf 'Runner.xcarchive.tar.gz' -C 'Runner.xcarchive'; " ^
  "  if ($LASTEXITCODE -ne 0) { throw 'Failed to extract tar.gz archive.' } " ^
  "  $appPath = 'Runner.xcarchive\Runner.xcarchive\Products\Applications'; " ^
  "  if (!(Test-Path \"$appPath\Runner.app\")) { throw 'Runner.app not found inside the extracted tar.gz archive.' } " ^
  "  Set-Location -Path $appPath; " ^
  "  Write-Host '5. Creating Payload folder and copying Runner.app...' -ForegroundColor Cyan; " ^
  "  $null = New-Item -ItemType Directory -Force -Path 'Payload'; " ^
  "  Copy-Item -Path 'Runner.app' -Destination 'Payload\Runner.app' -Recurse -Force; " ^
  "  Write-Host '6. Compressing Payload folder (Store method)...' -ForegroundColor Cyan; " ^
  "  Compress-Archive -Path 'Payload' -DestinationPath 'Payload.zip' -CompressionLevel NoCompression -Force; " ^
  "  Write-Host '7. Renaming and moving btchess.ipa...' -ForegroundColor Cyan; " ^
  "  Rename-Item -Path 'Payload.zip' -NewName 'btchess.ipa' -Force; " ^
  "  Move-Item -Path 'btchess.ipa' -Destination '%ROOT_DIR%btchess.ipa' -Force; " ^
  "  Write-Host '8. Cleaning up temporary files...' -ForegroundColor Cyan; " ^
  "  Set-Location -Path '%ROOT_DIR%'; " ^
  "  Remove-Item -Path 'ios-xcarchive' -Recurse -Force; " ^
  "  Write-Host '==> Success! btchess.ipa is ready for deployment.' -ForegroundColor Green; " ^
  "} catch { " ^
  "  Write-Host '' ; " ^
  "  Write-Host ('==> ERROR: ' + $_.Exception.Message) -ForegroundColor Red; " ^
  "  Write-Host '==> Process aborted. Cleaning up temporary files...' -ForegroundColor Yellow; " ^
  "  Set-Location -Path '%ROOT_DIR%'; " ^
  "  if (Test-Path 'ios-xcarchive') { Remove-Item -Path 'ios-xcarchive' -Recurse -Force; } " ^
  "  exit 1; " ^
  "}"

echo.
pause