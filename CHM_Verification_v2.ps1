# Set the root project directory
$ProjectRoot = "C:\CV_Help"
$ExtractDir = "$ProjectRoot\HTML_Extracted"
$LogFile = "$ProjectRoot\Logs\Verification_Report.txt"
$ErrorFile = "$ProjectRoot\Logs\Verification_Errors.txt"
$ImageIndexFile = "$ProjectRoot\Metadata\all_images_with_paths.txt"

# Prepare clean log files
"" | Set-Content $LogFile
"" | Set-Content $ErrorFile

# Build a known image index for fast lookup
$ImageIndex = @{}
Get-Content $ImageIndexFile | ForEach-Object {
    $filename = [System.IO.Path]::GetFileName($_)
    $ImageIndex[$filename] = $_
}

# Check each HTM directory for empty folders and missing files
Get-ChildItem -Path "$ExtractDir\HTM" -Directory | ForEach-Object {
    $htmDir = $_.FullName
    $files = Get-ChildItem -Path $htmDir -File -Recurse

    # Check for empty directories
    if ($files.Count -eq 0) {
        Add-Content -Path $ErrorFile -Value "Empty Directory: $htmDir"
        Write-Host "Empty Directory:" $htmDir
    }

    # Check for broken internal links
    $files | Where-Object { $_.Extension -eq ".htm" } | ForEach-Object {
        $content = Get-Content $_.FullName -Raw

        # Check for image references
        [regex]::Matches($content, "<img.*?src=[""'](.*?)[""']").ForEach({
            $src = $_.Groups[1].Value
            $filename = [System.IO.Path]::GetFileName($src)

            if ($ImageIndex.ContainsKey($filename)) {
                # Image found in our known index
                Add-Content -Path $LogFile -Value "Resolved Image: $filename (Found in: $($_.FullName))"
            } else {
                # Image not found
                Add-Content -Path $ErrorFile -Value "Missing Image: $filename (Referenced in: $($_.FullName))"
                Write-Host "Missing Image:" $filename
            }
        })

        # Check for CSS references
        [regex]::Matches($content, "<link.*?href=[""'](.*?)[""']").ForEach({
            $cssPath = Join-Path "$ExtractDir\CSS" $_.Groups[1].Value
            if (!(Test-Path $cssPath)) {
                Add-Content -Path $ErrorFile -Value "Missing CSS: $_ (Referenced in: $($_.FullName))"
                Write-Host "Missing CSS:" $_
            }
        })

        # Check for script references
        [regex]::Matches($content, "<script.*?src=[""'](.*?)[""']").ForEach({
            $jsPath = Join-Path "$ExtractDir\Scripts" $_.Groups[1].Value
            if (!(Test-Path $jsPath)) {
                Add-Content -Path $ErrorFile -Value "Missing Script: $_ (Referenced in: $($_.FullName))"
                Write-Host "Missing Script:" $_
            }
        })
    }

    # Log directory verification
    Add-Content -Path $LogFile -Value "Verified Directory: $htmDir - Files Found: $($files.Count)"
}

Write-Host "Directory verification complete. Logs available at $LogFile and $ErrorFile"
