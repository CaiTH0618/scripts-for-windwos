<#
    sym-link.ps1 — Create a Windows symbolic link safely

    Usage:
      sym-link.ps1 <linkPath> <targetPath>

    Safety guarantees:
      - Requires target to already exist (prevents accidental dangling links)
      - Refuses to overwrite an existing path at linkPath
      - Creates the link's parent directory if it doesn't exist
            - If not already elevated, prompts for Administrator (UAC) and re-runs
                itself before attempting to create the link.

    Requirements:
      - PowerShell 5.1 or newer
      - On Windows, creating symlinks may require Administrator privileges
        or Windows Developer Mode to be enabled.

    Example:
      sym-link.ps1 "C:\path\to\link\file.txt" "D:\path\to\target\file.txt"
#>

# Requires -Version 5.1
param(
    [Parameter(Position = 0)]
    [string]$LinkPath,
    [Parameter(Position = 1)]
    [string]$TargetPath
)

# Print a minimal usage message
function Show-Usage {
    Write-Host "Create a symbolic link (file or directory)." -ForegroundColor Cyan
    Write-Host "" 
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  sym-link.ps1 <linkPath> <targetPath>"
    Write-Host "" 
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host "  sym-link.ps1 'C:\\path\\to\\link\\file.txt' 'C:\\path\\to\\target\\file.txt'"
    Write-Host ""
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p  = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Restart-AsAdmin {
    param(
        [Parameter(Mandatory)] [string]$LinkArg,
        [Parameter(Mandatory)] [string]$TargetArg
    )
    # Determine the current shell executable path (pwsh or powershell)
    $shellPath = $null
    try { $shellPath = (Get-Process -Id $PID).Path } catch { }
    if (-not $shellPath -or -not (Test-Path -LiteralPath $shellPath)) {
        $shellPath = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }
    }

    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-File', $PSCommandPath,
        $LinkArg,
        $TargetArg
    )

    try {
        Write-Host 'Requesting elevation (UAC prompt)...' -ForegroundColor Yellow
        $proc = Start-Process -FilePath $shellPath -ArgumentList $argList -Verb RunAs -WorkingDirectory (Get-Location).Path -PassThru -Wait
        exit $proc.ExitCode
    } catch {
        Write-Error "Elevation was cancelled or failed. $_"
        exit 1
    }
}

# Require exactly two arguments
if (-not $LinkPath -or -not $TargetPath) {
    Show-Usage
    exit 2
}

# Proactively elevate before doing any work
if (-not (Test-IsAdmin)) {
    Restart-AsAdmin -LinkArg $LinkPath -TargetArg $TargetPath
}

# Normalize input to absolute paths (even if link doesn't exist yet)
try {
    $LinkFull   = [System.IO.Path]::GetFullPath($LinkPath)
} catch {
    Write-Error "Invalid link path: $LinkPath. $_"
    exit 1
}

try {
    $TargetFull = [System.IO.Path]::GetFullPath($TargetPath)
} catch {
    Write-Error "Invalid target path: $TargetPath. $_"
    exit 1
}

# Safety checks: target must exist; link path must not exist
if (-not (Test-Path -LiteralPath $TargetFull)) {
    Write-Error "Target does not exist: $TargetFull"
    exit 1
}

# If the provided link path points to a directory (or ends with a path separator),
# place the link inside that directory using the target's leaf name.
# Example: sym-link.ps1 "C:\linkDir" "D:\target\file.txt" -> C:\linkDir\file.txt
$linkLooksLikeDirectory = $false
if (Test-Path -LiteralPath $LinkFull) {
    try {
        $linkItem = Get-Item -LiteralPath $LinkFull -ErrorAction Stop
        $linkLooksLikeDirectory = $linkItem.PSIsContainer
    } catch { $linkLooksLikeDirectory = $false }
} else {
    # Treat paths ending with a slash or backslash as a directory intent
    if ($LinkPath -match "[\\/]\s*$") { $linkLooksLikeDirectory = $true }
}

if ($linkLooksLikeDirectory) {
    $linkDir = $LinkFull
    # Ensure the directory exists so we can place the link inside it
    if (-not (Test-Path -LiteralPath $linkDir)) {
        try { New-Item -ItemType Directory -Path $linkDir -Force | Out-Null } catch {
            Write-Error "Failed to create link directory: $linkDir. $_"
            exit 1
        }
    }
    $linkName = Split-Path -Leaf -Path $TargetFull
    $LinkFull = Join-Path -Path $linkDir -ChildPath $linkName
}

if (Test-Path -LiteralPath $LinkFull) {
    Write-Error "Link path already exists: $LinkFull"
    exit 1
}

# Ensure the parent directory for the link exists (create if missing)
$linkParent = Split-Path -Parent -Path $LinkFull
if ($linkParent -and -not (Test-Path -LiteralPath $linkParent)) {
    try {
        New-Item -ItemType Directory -Path $linkParent -Force | Out-Null
    } catch {
        Write-Error "Failed to create parent directory: $linkParent. $_"
        exit 1
    }
}

# Create the symbolic link
try {
    $null = New-Item -ItemType SymbolicLink -Path $LinkFull -Target $TargetFull -ErrorAction Stop
    Write-Host "Created symbolic link:" -ForegroundColor Green
    Write-Host "  $LinkFull -> $TargetFull"
    exit 0
} catch {
    # Common failure: insufficient privileges when Developer Mode is disabled
    Write-Error "Failed to create symbolic link. $_ (tip: run PowerShell as Administrator or enable Windows Developer Mode)"
    exit 1
}
