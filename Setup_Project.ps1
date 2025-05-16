# Set the root project directory
$ProjectRoot = "C:\CV_Help"

# Define the main subdirectories we need
$Subdirectories = @(
    "\CHM_Source",
    "\HTML_Extracted\Images",
    "\HTML_Extracted\HTML",
    "\Processed_Text",
    "\Metadata",
    "\Logs"
)

# Remove old files and directories (if any)
foreach ($subdir in $Subdirectories) {
    $fullPath = $ProjectRoot + $subdir
    if (Test-Path $fullPath) {
        Remove-Item -Path $fullPath -Recurse -Force
        Write-Host "Cleared directory:" $fullPath
    } else {
        Write-Host "Directory not found, skipping:" $fullPath
    }
}

# Recreate the cleaned directory structure
foreach ($subdir in $Subdirectories) {
    $fullPath = $ProjectRoot + $subdir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath
        Write-Host "Created directory:" $fullPath
    } else {
        Write-Host "Directory already exists:" $fullPath
    }
}

# Move CHM, HLP, HM, and HTB files to the CHM_Source directory
$sourceDirs = @("\CV 2024 Help", "\S2M 2024 Help")
$extensions = @("*.chm", "*.hlp", "*.hm", "*.htb")

foreach ($sourceDir in $sourceDirs) {
    $sourcePath = $ProjectRoot + $sourceDir
    if (Test-Path $sourcePath) {
        foreach ($ext in $extensions) {
            Get-ChildItem -Path $sourcePath -Filter $ext -Recurse | ForEach-Object {
                $destinationPath = "$ProjectRoot\CHM_Source\$($_.Name)"
                Move-Item $_.FullName $destinationPath
                Write-Host "Moved:" $_.FullName "->" $destinationPath
            }
        }
    } else {
        Write-Host "Source directory not found, skipping:" $sourcePath
    }
}

Write-Host "Project directory setup complete."
