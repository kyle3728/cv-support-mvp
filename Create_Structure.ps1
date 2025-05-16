# Set the root directory for the project
$ProjectRoot = "C:\CV_Help"

# Define the required subdirectories
$Subdirectories = @(
    "\CHM_Source",
    "\HTML_Extracted\Images",
    "\HTML_Extracted\HTML",
    "\Processed_Text",
    "\Metadata",
    "\Logs"
)

# Create the required directories if they don't exist
foreach ($subdir in $Subdirectories) {
    $fullPath = $ProjectRoot + $subdir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath
        Write-Host "Created directory:" $fullPath
    } else {
        Write-Host "Directory already exists:" $fullPath
    }
}

# Generate a directory structure log
$LogFile = "$ProjectRoot\directory_structure.txt"
Get-ChildItem -Path $ProjectRoot -Recurse | 
    Select-Object FullName, Name, PSIsContainer |
    Format-Table -AutoSize | Out-File $LogFile

Write-Host "Directory structure logged to:" $LogFile
