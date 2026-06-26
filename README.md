Here is a **clean, git-ready `README.md`** aligned with your script, design decisions, and engineering style.

***

# File Archiving & Retention Script

## Overview

This PowerShell script provides a **safe, deterministic, and automated method** to:

* Archive files into ZIPs grouped by time (Year/Month/Day/Hour)
* Validate archive integrity before deletion
* Apply retention policies using purge mode
* Run in **dry-run (default)** or **production mode**
* Integrate with Windows Task Scheduler

***

## Key Features

### Archiving

* Groups files based on `CreationTime`
* Creates one ZIP per period
* Validates ZIP contents before deletion
* Optional deletion of source files

### Purge (Retention Control)

* Deletes files based on age
* Uses `CreationTime` with `Mode` + `Number`
* Fully independent from archive flow

### Safety

* Dry-run by default
* ZIP validation before deletion
* Skips current active period
* Explicit logging

***

## Script Location

```
C:\GOS\Scripts\files2zip\archive2zip.ps1
```

***

## ⚙️ Parameters

### Required

```
-SourcePath <path>
```

***

### Optional Parameters

| Parameter      | Description                                               |
| -------------- | --------------------------------------------------------- |
| `-ArchiveRoot` | Destination for ZIP files (default: `SourcePath\Archive`) |
| `-LogFile`     | Custom log file                                           |
| `-Mode`        | `Year`, `Month`, `Day`, `Hour` (default: Month)           |
| `-Process`     | Execute actions (otherwise dry-run)                       |
| `-DeleteFiles` | Delete files after successful archive                     |
| `-DetailedLog` | Log individual files                                      |
| `-Purge`       | Enable purge mode (no archiving)                          |
| `-Number`      | Retention value (used with `-Purge`)                      |
| `-Recurse`     | Include subfolders                                        |

***

## Usage

### Dry-run (default)

```
.\archive2zip.ps1 -SourcePath D:\Logs
```

***

### Archive files

```
.\archive2zip.ps1 -SourcePath D:\Logs -Process
```

***

### Archive + delete source files

```
.\archive2zip.ps1 -SourcePath D:\Logs -Process -DeleteFiles
```

***

### Archive with detailed logging

```
.\archive2zip.ps1 -SourcePath D:\Logs -Process -DetailedLog
```

***

### Archive recursively

```
.\archive2zip.ps1 -SourcePath D:\Logs -Recurse -Process
```

***

### Purge (dry-run)

```
.\archive2zip.ps1 -SourcePath D:\ArchiveLogs -Purge -Number 6 -Mode Month
```

***

### Purge (execute)

```
.\archive2zip.ps1 -SourcePath D:\ArchiveLogs -Purge -Number 6 -Mode Month -Process
```

***

## Archive Behavior

### Grouping

Files are grouped based on `CreationTime`:

| Mode  | Result            |
| ----- | ----------------- |
| Year  | One ZIP per year  |
| Month | One ZIP per month |
| Day   | One ZIP per day   |
| Hour  | One ZIP per hour  |

***

### ZIP Structure

* Root of ZIP = contents of `SourcePath`
* Subfolders preserved relative to `SourcePath`

**Example:**

```
SourcePath: C:\Logs

C:\Logs\
 ├── file1.log
 ├── app1\
 │    └── file2.log
```

ZIP contents:

```
file1.log
app1\file2.log
```

***

## Purge Behavior

* Deletes files older than:
  ```
  CurrentDate - Number (based on Mode)
  ```
* Uses `CreationTime`
* Does NOT delete folders
* Works with `-Recurse`

**Example:**

```
-Purge -Number 6 -Mode Month
```

→ Deletes files older than 6 months

Output:

```
Files eligible for purge: 18 of 143
```

***

## Logging

### Default

* Timestamped log in `ArchiveRoot`
* Example:
  ```
  ArchiveLog_20260626_101530.txt
  ```

### Includes

* Start/end of run
* Groups processed
* ZIP operations
* Errors
* Deletions

### Detailed Mode

Adds per-file entries:

```
-DetailedLog
```

***

##️ Safety Mechanisms

* Dry-run by default
* Skips current period files
* Validates ZIP before deleting
* Continues safely on errors
* Explicit error logging

***

## Scheduling

Example Task Scheduler configuration:

```
Program:
  powershell.exe

Arguments:
  -NoProfile -ExecutionPolicy Bypass -File "C:\GOS\Scripts\files2zip\archive2zip.ps1" -SourcePath "D:\Logs" -DetailedLog -Mode Month -ArchiveRoot "D:\ArchiveLogs" -DeleteFiles -Process
```

***

## Notes & Known Behavior

### CreationTime dependency

* Script uses `CreationTime` for:
  * Grouping
  * Retention (purge)

⚠️ Copying files may reset this value.

***

### Mixed file types

* Script supports:
  * ZIP files
  * Log files
  * Any other file type

***

### Recursive mode

* Includes subfolders
* Preserves structure inside ZIP
* Does not create nested archive folders

***

## Best Practices

* Always validate using dry-run first
* Use separate scheduled tasks for:
  * Archiving
  * Purge (retention)
* Monitor log files after first runs
* Ensure consistent `CreationTime` if importing data
* Keep archive storage separate from source

***

## Summary

This script provides a **production-safe archiving and retention system** with:

* Explicit control over file lifecycle
* Strong safety guarantees
* Minimal operational complexity
* Deterministic behavior for automation

***

