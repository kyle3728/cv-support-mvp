# Set the root project directory
$ProjectRoot = "C:\CV_Help"
$SourceDir = "$ProjectRoot\CHM_Source"
$ExtractDir = "$ProjectRoot\HTML_Extracted"

# Ensure the output directories exist
$subdirs = @("HTM", "Images", "CSS", "Scripts", "Misc")
foreach ($subdir in $subdirs) {
    $fullPath = "$ExtractDir\$subdir"
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath
        Write-Host "Created directory:" $fullPath
    }
}

# Set the log files for tracking extraction progress and errors
$LogFile = "$ProjectRoot\Logs\CHM_Extraction_Log.txt"
$ErrorLogFile = "$ProjectRoot\Logs\CHM_Extraction_Errors.txt"
"" | Set-Content $LogFile
"" | Set-Content $ErrorLogFile

# Extract each CHM file
Get-ChildItem -Path $SourceDir -Filter *.chm | ForEach-Object {
    $chmFile = $_.FullName
    $outputDir = "$ExtractDir\HTM\$($_.BaseName)"
    mkdir $outputDir | Out-Null

    # Use hh.exe to decompile the CHM
    try {
        & "hh.exe" -decompile $outputDir $chmFile
        Add-Content -Path $LogFile -Value "Extracted: $chmFile -> $outputDir"
        Write-Host "Extracted:" $chmFile "->" $outputDir
    } catch {
        Add-Content -Path $ErrorLogFile -Value "Failed to extract: $chmFile - $_"
        Write-Host "Failed to extract:" $chmFile "- $_"
        return  # Skip to the next file if extraction fails
    }

    # Move extracted assets to their respective folders
    Get-ChildItem -Path $outputDir -Recurse | ForEach-Object {
        # Ensure the file actually exists, is not a directory, and has a valid name
        if ($_.PSIsContainer -eq $false -and $_.FullName -ne $null -and $_.FullName -ne "") {
            $ext = $_.Extension.ToLower()

            try {
                switch ($ext) {
                    ".htm" {
                        # Leave .htm files in their original directories
                        Add-Content -Path $LogFile -Value "Preserved HTM: $($_.FullName)"
                    }
                    ".css" {
                        Move-Item $_.FullName "$ExtractDir\CSS\" -Force
                        Add-Content -Path $LogFile -Value "Moved CSS: $($_.FullName)"
                    }
                    ".js" {
                        Move-Item $_.FullName "$ExtractDir\Scripts\" -Force
                        Add-Content -Path $LogFile -Value "Moved JS: $($_.FullName)"
                    }
                    ".png" {
                        Move-Item $_.FullName "$ExtractDir\Images\" -Force
                        Add-Content -Path $LogFile -Value "Moved Image: $($_.FullName)"
                    }
                    ".jpg" {
                        Move-Item $_.FullName "$ExtractDir\Images\" -Force
                        Add-Content -Path $LogFile -Value "Moved Image: $($_.FullName)"
                    }
                    ".jpeg" {
                        Move-Item $_.FullName "$ExtractDir\Images\" -Force
                        Add-Content -Path $LogFile -Value "Moved Image: $($_.FullName)"
                    }
                    ".gif" {
                        Move-Item $_.FullName "$ExtractDir\Images\" -Force
                        Add-Content -Path $LogFile -Value "Moved Image: $($_.FullName)"
                    }
                    ".svg" {
                        Move-Item $_.FullName "$ExtractDir\Images\" -Force
                        Add-Content -Path $LogFile -Value "Moved Image: $($_.FullName)"
                    }
                    default {
                        Move-Item $_.FullName "$ExtractDir\Misc\" -Force
                        Add-Content -Path $LogFile -Value "Moved Misc File: $($_.FullName)"
                    }
                }
            } catch {
                Add-Content -Path $ErrorLogFile -Value "Failed to move file: $($_.FullName) - $_"
                Write-Host "Failed to move file:" $($_.FullName) "- $_"
            }
        }
    }
}

Write-Host "CHM Extraction Complete. Logs available at $LogFile and $ErrorLogFile"
