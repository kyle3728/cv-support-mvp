# Set the path to the master image list
$MasterImageList = "C:\CV_Help\Metadata\all_images_with_paths.txt"
$ErrorLog = "C:\CV_Help\Verification_Reports\Illegal_Paths.txt"

# Prepare the error log file
"" | Set-Content $ErrorLog

# Check each image path for illegal characters
Get-Content $MasterImageList | ForEach-Object {
    try {
        # Attempt to extract the filename
        $filename = [System.IO.Path]::GetFileName($_)
    } catch {
        # Log the problematic path
        Write-Host "Illegal path detected:" $_
        Add-Content $ErrorLog $_
    }
}

Write-Host "Path check complete. Review the Illegal_Paths.txt for details."
