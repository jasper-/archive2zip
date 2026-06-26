<#
.SYNOPSIS
    Archives files into ZIP files grouped by Year, Month, Day, or Hour.
    Default run: DRY-RUN (simulation only).
    Use -Process to execute real actions.
    Optionally delete files with -DeleteFiles.
    Optionally log each file with -DetailedLog.

.Usage
Default run: DRY-RUN (simulation)

USAGE:
  .\archive_yymm.ps1 -SourcePath <path>
  .\archive_yymm.ps1 -SourcePath <path> -Process
  .\archive_yymm.ps1 -SourcePath <path> -Process -DeleteFiles
  .\archive_yymm.ps1 -SourcePath <path> -Process -DetailedLog
  .\archive_yymm.ps1 -SourcePath <path> -Mode Year|Month|Day|Hour
# ADDITION (Purge usage kept minimal and appended)
  .\archive_yymm.ps1 -SourcePath <path> -Purge -Number <X> -Mode Year|Month|Day|Hour

.Versions
Date        |Author              |Change/ Comment
------------+--------------------+---------------------------------
2026-04-03   J. Rappard - PRS     Initial script - tested
2026-06-26   J. Rappard - PRS     Added purge functionality and recurse option
#>

param (
    [string]$SourcePath,
    [string]$ArchiveRoot,
    [string]$LogFile,
    [switch]$Process,
    [switch]$DeleteFiles,
    [switch]$DetailedLog,
# ADDITION: purge + recurse parameters
    [switch]$Purge,
    [int]$Number,
    [switch]$Recurse,
    [ValidateSet("Year","Month","Day","Hour")]
    [string]$Mode = "Month"
)

# -------------------------------------------------------
# HELP TEXT WHEN NO PARAMETERS
# -------------------------------------------------------
if (-not $PSBoundParameters.ContainsKey("SourcePath")) {
    Write-Host ""
    Write-Host "Archive Script"
    Write-Host "--------------"
    Write-Host "Default run: DRY-RUN (simulation)"
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "  .\archive_yymm.ps1 -SourcePath <path>"
    Write-Host "  .\archive_yymm.ps1 -SourcePath <path> -Process"
    Write-Host "  .\archive_yymm.ps1 -SourcePath <path> -Process -DeleteFiles"
    Write-Host "  .\archive_yymm.ps1 -SourcePath <path> -Process -DetailedLog"
    Write-Host "  .\archive_yymm.ps1 -SourcePath <path> -Mode Year|Month|Day|Hour"
    Write-Host "  .\archive_yymm.ps1 -SourcePath <path> -Purge -Number <X> -Mode Year|Month|Day|Hour"
    Write-Host ""
    exit
}

# -------------------------------------------------------
# DEFAULT PATHS
# -------------------------------------------------------
if (-not $ArchiveRoot) {
    $ArchiveRoot = Join-Path $SourcePath "Archive"
}

# -------------------------------------------------------
# SMART LOGFILE HANDLING (with timestamped default)
# -------------------------------------------------------
$runTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ($PSBoundParameters.ContainsKey("LogFile")) {

    # User supplied LogFile but did not include a path
    if (-not (Split-Path $LogFile)) {
        $LogFile = Join-Path $ArchiveRoot $LogFile
    }

} else {
    # Default: timestamped logfile
    $LogFile = Join-Path $ArchiveRoot "ArchiveLog_${runTimestamp}.txt"
}

# -------------------------------------------------------
# LOGGING FUNCTION
# -------------------------------------------------------
function Write-Log {
    param([string]$Message)

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$ts  $Message"

    if (-not $Process) {
        Write-Host "[DRY-RUN] $entry"
        return
    }

    try {
        Add-Content -Path $LogFile -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Host "WARNING: Could not write to logfile: $_"
    }
}

# -------------------------------------------------------
# ZIP VALIDATION FUNCTION (Reliable)
# -------------------------------------------------------
function Test-ZipValid {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return $false }

    # Allow time for file write to finish
    $attempts = 0
    while (((Get-Item $Path).Length -eq 0) -and ($attempts -lt 4)) {
        Start-Sleep -Milliseconds 500
        $attempts++
    }

    if ((Get-Item $Path).Length -eq 0) { return $false }

    # Try to open the ZIP with .NET
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $zip = New-Object System.IO.Compression.ZipArchive($stream)
        $zip.Dispose()
        $stream.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

# -------------------------------------------------------
# VALIDATE SOURCE PATH
# -------------------------------------------------------
if (!(Test-Path $SourcePath)) {
    Write-Host "ERROR: Source path does not exist: $SourcePath"
    exit
}

# -------------------------------------------------------
# PREPARE DIRECTORIES (ONLY REAL RUN)
# -------------------------------------------------------
if ($Process) {
    try {
        if (!(Test-Path $ArchiveRoot)) {
            New-Item -ItemType Directory -Path $ArchiveRoot -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Host "ERROR: Cannot create archive directory: $_"
        exit
    }

    try {
        if (!(Test-Path $LogFile)) {
            New-Item -ItemType File -Path $LogFile -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Host "ERROR: Cannot create logfile: $_"
        exit
    }
}

# -------------------------------------------------------
# PURGE MODE (ISOLATED ADDITION)
# -------------------------------------------------------
if ($Purge) {

    if (-not $Number -or $Number -le 0) {
        Write-Host "ERROR: -Number must be greater than 0 when using -Purge"
        exit
    }

    Write-Log "=== Purge run started (Process=$Process Number=$Number Mode=$Mode) ==="

    try {
        if ($Recurse) {
            $files = Get-ChildItem -Path $SourcePath -File -Recurse -ErrorAction Stop
        } else {
            $files = Get-ChildItem -Path $SourcePath -File -ErrorAction Stop
        }
    }
    catch {
        Write-Log "ERROR: Cannot read directory: $_"
        exit
    }

    if (-not $files) {
        Write-Log "No files found."
        exit
    }

    $cutoff = Get-Date

    switch ($Mode) {
        "Year"  { $cutoff = $cutoff.AddYears(-$Number) }
        "Month" { $cutoff = $cutoff.AddMonths(-$Number) }
        "Day"   { $cutoff = $cutoff.AddDays(-$Number) }
        "Hour"  { $cutoff = $cutoff.AddHours(-$Number) }
    }

    $filesToDelete = $files | Where-Object {
        $_.CreationTime -lt $cutoff
    }

    Write-Log "Files eligible for purge: $($filesToDelete.Count) of $($files.Count)"

    foreach ($file in $filesToDelete) {

        if ($DetailedLog) {
            Write-Log "Candidate: $($file.FullName)"
        }

        if ($Process) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Write-Log "Deleted: $($file.FullName)"
            }
            catch {
                Write-Log "ERROR deleting file $($file.FullName): $_"
            }
        }
        else {
            Write-Host "[DRY-RUN] Would delete: $($file.FullName)"
        }
    }

    Write-Log "=== Purge run completed ==="
    exit
}

Write-Log "=== Archive run started (Process=$Process DeleteFiles=$DeleteFiles DetailedLog=$DetailedLog Mode=$Mode) ==="

# -------------------------------------------------------
# GET FILES
# -------------------------------------------------------
try {
    if ($Recurse) {
        $files = Get-ChildItem -Path $SourcePath -File -Recurse -ErrorAction Stop
    } else {
        $files = Get-ChildItem -Path $SourcePath -File -ErrorAction Stop
    }
}
catch {
    Write-Log "ERROR: Cannot read directory: $_"
    exit
}

if (-not $files) {
    Write-Log "No files found."
    exit
}

# -------------------------------------------------------
# FILTER OUT CURRENT PERIOD
# -------------------------------------------------------
$current = Get-Date

switch ($Mode) {

    "Year" {
        $files = $files | Where-Object { $_.CreationTime.Year -ne $current.Year }
    }

    "Month" {
        $files = $files | Where-Object {
            $_.CreationTime.Year  -ne $current.Year -or
            $_.CreationTime.Month -ne $current.Month
        }
    }

    "Day" {
        $today = $current.ToString("yyyy-MM-dd")
        $files = $files | Where-Object {
            $_.CreationTime.ToString("yyyy-MM-dd") -ne $today
        }
    }

    "Hour" {
        $thisHour = $current.ToString("yyyy-MM-dd HH")
        $files = $files | Where-Object {
            $_.CreationTime.ToString("yyyy-MM-dd HH") -ne $thisHour
        }
    }
}

if (-not $files) {
    Write-Log "No files to archive after skipping current $Mode."
    exit
}

# -------------------------------------------------------
# GROUP FILES BY MODE
# -------------------------------------------------------
switch ($Mode) {

    "Year" {
        $groups = $files | Group-Object {
            "{0:D4}" -f $_.CreationTime.Year
        }
    }

    "Month" {
        $groups = $files | Group-Object {
            "{0}-{1:D2} {2}" -f $_.CreationTime.Year,
                               $_.CreationTime.Month,
                               $_.CreationTime.ToString("MMMM")
        }
    }

    "Day" {
        $groups = $files | Group-Object {
            $_.CreationTime.ToString("yyyy-MM-dd")
        }
    }

    "Hour" {
        $groups = $files | Group-Object {
            $_.CreationTime.ToString("yyyy-MM-dd HH'h'")
        }
    }
}

# -------------------------------------------------------
# PROCESS GROUPS
# -------------------------------------------------------
foreach ($group in $groups) {

    $groupName = $group.Name
    $zipPath = Join-Path $ArchiveRoot "${groupName}.zip"

    Write-Log "Processing group: ${groupName}"

    if ($DetailedLog) {
        Write-Log "Files included in ${groupName}:"
        foreach ($file in $group.Group) {
            Write-Log "  - $($file.FullName)"
        }
    }
    else {
        Write-Log "Use -DetailedLog to show file list."
    }

    # -----------------------------------------------
    # REMOVE EXISTING ZIP
    # -----------------------------------------------
    if (Test-Path $zipPath) {
        if (-not $Process) {
            Write-Host "[DRY-RUN] Would remove existing ZIP: $zipPath"
        }
        else {
            try {
                Remove-Item -Path $zipPath -Force -ErrorAction Stop
                Write-Log "Removed existing ZIP: $zipPath"
            }
            catch {
                Write-Log "ERROR removing ZIP: $_"
                continue
            }
        }
    }

    # -----------------------------------------------
    # CREATE ZIP
    # -----------------------------------------------
    if (-not $Process) {
        Write-Host "[DRY-RUN] Would create ZIP: $zipPath"
        $zipValid = $true
    }
    else {
        try {
            Compress-Archive -Path $group.Group.FullName -DestinationPath $zipPath -ErrorAction Stop
            Write-Log "ZIP created: $zipPath"
        }
        catch {
            Write-Log "ERROR creating ZIP for ${groupName}: $_"
            continue
        }

        # Validate the ZIP
        $zipValid = Test-ZipValid -Path $zipPath

        # Additional: Ensure all files are present inside ZIP
        if ($zipValid) {
            #$zipEntries = Get-ZipEntries -ZipPath $zipPath
            $zipEntries = tar -tf $zipPath
            Write-Log "follwing files found: $zipEntries"
            $sourceNames = $group.Group.Name

            foreach ($n in $sourceNames) {
                if ($zipEntries -notcontains $n) {
                    Write-Log "ERROR: Missing file in ZIP: $n"
                    $allPresent = $false
                }
                else {
                    $allPresent = $true
                }
            }

            if (-not $allPresent) {
                Write-Log "ERROR: ZIP incomplete! Aborting deletion for group ${groupName}"
                $zipValid = $false
            }
        }
    }

    if (-not $zipValid) {
        Write-Log "ERROR: ZIP validation failed for ${groupName}"
        continue
    }

    Write-Log "ZIP validated OK."

    # -----------------------------------------------
    # DELETE SOURCE FILES?
    # -----------------------------------------------
    if ($DeleteFiles -and $Process -and $zipValid) {
        Write-Log "Deleting files for ${groupName}..."
        foreach ($file in $group.Group) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Write-Log "Deleted: $($file.FullName)"
            }
            catch {
                Write-Log "ERROR deleting file $($file.FullName): $_"
            }
        }
    }
    elseif ($DeleteFiles -and -not $Process) {
        Write-Host "[DRY-RUN] Would delete files for ${groupName}"
    }
    else {
        Write-Log "Keeping original files for ${groupName}."
    }

    Write-Log "Completed group: ${groupName}"
}

Write-Log "=== Archive run completed ==="
Write-Host "Archive completed. Process=$Process DeleteFiles=$DeleteFiles Mode=$Mode DetailedLog=$DetailedLog"
Write-Host "Log file location: $LogFile"