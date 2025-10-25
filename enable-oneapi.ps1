# Default to Intel's oneAPI environment setup script unless a custom path is provided.
param(
    [string]$Setvars = "C:\Program Files (x86)\Intel\oneAPI\setvars.bat",
    [switch]$Verify
)

# Confirm the script exists before trying to invoke it.
if (-not (Test-Path $Setvars)) {
    throw "setvars.bat missing at $Setvars."
}

# Use a scratch file to collect the environment output from cmd.exe.
$tempFile = New-TemporaryFile
try {
    # Execute setvars.bat and dump the resulting env vars to the temp file.
    $cmd = "call `"$Setvars`" && set > `"$($tempFile.FullName)`""
    cmd /c $cmd | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "setvars.bat exited with code $LASTEXITCODE."
    }

    # Session inherits each key/value pair, skipping internal pseudo variables.
    Get-Content -Path $tempFile.FullName -Encoding Default | ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') {
            $envName = $matches[1]
            if ($envName -notmatch '^=') {
                Set-Item -Path "Env:$envName" -Value $matches[2]
            }
        }
    }
} finally {
    # Always tidy up the scratch file.
    Remove-Item $tempFile -ErrorAction Ignore
}

# Optional quick verification and helpful output
if ($Verify) {
    Write-Host "oneAPI environment loaded via: $Setvars" -ForegroundColor Green
    if ($env:ONEAPI_ROOT) {
        Write-Host "ONEAPI_ROOT = $env:ONEAPI_ROOT" -ForegroundColor DarkCyan
    } else {
        Write-Warning "ONEAPI_ROOT is not set."
    }
    try {
        $ze = & where.exe ze_loader.dll 2>$null
        if ($ze) {
            Write-Host "ze_loader.dll on PATH:" -ForegroundColor DarkCyan
            $ze | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Warning "ze_loader.dll not found on PATH. Ensure Level Zero runtime is installed."
        }
    } catch {
        Write-Warning "Unable to run where.exe. In PowerShell, prefer 'where.exe' over the 'where' alias."
    }
}