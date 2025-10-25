# Set the root path of miniconda3.
param(
    [string]$CondaRoot = "$env:USERPROFILE\app\miniconda3"
)

# Ensure the expected conda.exe is present before attempting to load the hook
$condaExe = Join-Path $CondaRoot "Scripts\conda.exe"
if (-not (Test-Path $condaExe)) {
    throw "conda.exe not found at $condaExe. Update CondaRoot."
}

# Load Conda hook into current PowerShell session
(& $condaExe 'shell.powershell' 'hook') | Out-String | Invoke-Expression

# If the hook failed to load, reminder to dot-source the script
if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    Write-Warning "Conda command did not load. Dot-source this script: . $PSCommandPath"
    return
}

# Ensure the base environment is active for the caller's session
if ($env:CONDA_DEFAULT_ENV -ne 'base') {
    conda activate base
}