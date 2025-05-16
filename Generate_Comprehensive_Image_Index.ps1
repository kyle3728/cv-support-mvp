# Set the project directories
$ProjectRoot = "C:\CV_Help"
$ExtractDir = "$ProjectRoot\HTML_Extracted\HTM"
$IndexFile = "$ProjectRoot\Metadata\all_images_with_paths.txt"

# Prepare the index file
"" | Set-Content $IndexFile

# Scan for all known image types within HTM subdirectories
Get-ChildItem -Path $ExtractDir -Recurse -Include *.png, *.jpg, *.jpeg, *.gif, *.svg | ForEach-Object {
    # Capture the full relative path
    $fullPath = $_.FullName
    # Extract just the filename for easy matching
    $filename = $_.Name
    # Store the full path for later reference
    Add-Content -Path $IndexFile -Value "$filename|$fullPath"
    Write-Host "Indexed:" $filename
}

Write-Host "Comprehensive image index complete. Master list saved to $IndexFile"
