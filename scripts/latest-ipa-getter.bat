@echo off
title Fetch and package the latest BTChess IPA
set ROOT_DIR=%~dp0

echo ===================================================
echo                BTCHESS IPA GETTER
echo ===================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop'; " ^
  "try { " ^
  "  Write-Host '1. Detecting default branch and latest run ID...' -ForegroundColor Cyan; " ^
  "  if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is not installed or not added to PATH. Please install it first.' } " ^
  "  $defaultBranch = gh repo view KaitoJD/btchess --json defaultBranchRef --jq '.defaultBranchRef.name'; " ^
  "  if ([string]::IsNullOrWhiteSpace($defaultBranch)) { throw 'Failed to get default branch. Make sure you are logged in (run: gh auth login).' } " ^
  "  Write-Host ('   -> Default branch: ' + $defaultBranch) -ForegroundColor DarkGray; " ^
  "  $runId = gh run list --repo KaitoJD/btchess --branch $defaultBranch --limit 1 --json databaseId --jq '.[0].databaseId'; " ^
  "  if ([string]::IsNullOrWhiteSpace($runId)) { throw ('No workflow runs found on branch: ' + $defaultBranch) } " ^
  "  Write-Host ('   -> Latest Run ID: ' + $runId) -ForegroundColor DarkGray; " ^
  "  Write-Host '2. Downloading artifact from GitHub Actions...' -ForegroundColor Cyan; " ^
  "  gh run download $runId --name ios-xcarchive --repo KaitoJD/btchess --dir . ; " ^
  "  if ($LASTEXITCODE -ne 0) { throw 'Failed to download artifact.' } " ^
  "  Write-Host '3. Checking for Runner.xcarchive.tar.gz...' -ForegroundColor Cyan; " ^
  "  if (!(Test-Path 'Runner.xcarchive.tar.gz')) { throw 'Runner.xcarchive.tar.gz not found after download.' } " ^
  "  Write-Host '4. Extracting Runner.xcarchive.tar.gz...' -ForegroundColor Cyan; " ^
  "  $null = New-Item -ItemType Directory -Force -Path 'Runner.xcarchive'; " ^
  "  tar -xzf 'Runner.xcarchive.tar.gz' -C 'Runner.xcarchive'; " ^
  "  if ($LASTEXITCODE -ne 0) { throw 'Failed to extract tar.gz archive.' } " ^
  "  $appPath = 'Runner.xcarchive\Runner.xcarchive\Products\Applications'; " ^
  "  if (!(Test-Path ($appPath + '\Runner.app'))) { throw 'Runner.app not found inside the extracted tar.gz archive.' } " ^
  "  Set-Location -Path $appPath; " ^
  "  Write-Host '5. Creating Payload folder and copying Runner.app...' -ForegroundColor Cyan; " ^
  "  $null = New-Item -ItemType Directory -Force -Path 'Payload'; " ^
  "  Copy-Item -Path 'Runner.app' -Destination 'Payload\Runner.app' -Recurse -Force; " ^
  "  Write-Host '6. Compressing Payload folder (Store method)...' -ForegroundColor Cyan; " ^
  "  Compress-Archive -Path 'Payload' -DestinationPath 'Payload.zip' -CompressionLevel NoCompression -Force; " ^
  "  Write-Host '7. Renaming and moving btchess.ipa...' -ForegroundColor Cyan; " ^
  "  Rename-Item -Path 'Payload.zip' -NewName 'btchess.ipa' -Force; " ^
  "  Move-Item -Path 'btchess.ipa' -Destination '%ROOT_DIR%btchess.ipa' -Force; " ^
  "  Write-Host '8. Cleaning up temporary files and source archives...' -ForegroundColor Cyan; " ^
  "  Set-Location -Path '%ROOT_DIR%'; " ^
  "  Remove-Item -Path 'Runner.xcarchive' -Recurse -Force; " ^
  "  Remove-Item -Path 'Runner.xcarchive.tar.gz' -Force; " ^
  "  Write-Host '==> Success! btchess.ipa is downloaded and ready for deployment.' -ForegroundColor Green; " ^
  "} catch { " ^
  "  Write-Host '' ; " ^
  "  Write-Host ('==> ERROR: ' + $_.Exception.Message) -ForegroundColor Red; " ^
  "  Write-Host '==> Process aborted. Cleaning up temporary folders...' -ForegroundColor Yellow; " ^
  "  Set-Location -Path '%ROOT_DIR%'; " ^
  "  if (Test-Path 'Runner.xcarchive') { Remove-Item -Path 'Runner.xcarchive' -Recurse -Force; } " ^
  "  exit 1; " ^
  "}"

echo.
pause