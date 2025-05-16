# Define the root directory for the extracted HTM files and master image list
$HTMRootDir = "C:\CV_Help\HTML_Extracted\HTM"
$MasterImageList = "C:\CV_Help\Metadata\all_images_with_paths.txt"
$OutputDir = "C:\CV_Help\Verification_Reports"
$MissingImagesReport = "$OutputDir\Missing_Images.txt"
$UnreferencedImagesReport = "$OutputDir\Unreferenced_Images.txt"
$MatchedImagesReport = "$OutputDir\Matched_Images.txt"
$SkippedLinesReport = "$OutputDir\Skipped_Lines.txt"
$SummaryReport = "$OutputDir\Verification_Summary.txt"

# Create the output directory if it doesn't exist
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir
}

# Prepare log files
"" | Set-Content $MissingImagesReport
"" | Set-Content $UnreferencedImagesReport
"" | Set-Content $MatchedImagesReport
"" | Set-Content $SkippedLinesReport
"" | Set-Content $SummaryReport

# Load the master image list
$MasterImages = @{}
Get-Content $MasterImageList | ForEach-Object {
    try {
        # Split on the pipe separator and strip any surrounding whitespace
        $parts = $_ -split "\|"
        if ($parts.Length -eq 2) {
            # Store the filename and full path for later lookup
            $filename = [System.IO.Path]::GetFileName($parts[0]).Trim()
            $fullPath = $parts[1].Replace("\", "/").Trim()
            $MasterImages[$filename] = $fullPath
        } else {
            Add-Content $SkippedLinesReport "Malformed line: $_"
        }
    } catch {
        Add-Content $SkippedLinesReport "Illegal path: $_"
    }
}

# Scan all HTM files for image references
$HTMFiles = Get-ChildItem -Path $HTMRootDir -Filter *.htm -Recurse
$ReferencedImages = @{}
$MatchedCount = 0
$MissingCount = 0

foreach ($file in $HTMFiles) {
    $content = Get-Content $file.FullName -Raw

    # Extract all image references
    $images = Select-String -InputObject $content -Pattern '(?<=src="|href=").*?(?=")' -AllMatches | 
              ForEach-Object { 
                  try {
                      # Extract just the filename
                      $img = [System.IO.Path]::GetFileName($_.Value).Trim()
                      $img
                  } catch {
                      Add-Content $SkippedLinesReport "Illegal image reference: $_"
                      $null
                  }
              }

    foreach ($image in $images) {
        # Record the reference
        if ($ReferencedImages[$image]) {
            $ReferencedImages[$image] += 1
        } else {
            $ReferencedImages[$image] = 1
        }

        # Check if the image exists in the master list
        if ($MasterImages.ContainsKey($image)) {
            Add-Content $MatchedImagesReport "$image|$($MasterImages[$image])"
            $MatchedCount++
        } else {
            Add-Content $MissingImagesReport "$image (Referenced in: $($file.FullName))"
            $MissingCount++
        }
    }
}

# Find unreferenced images
$UnusedImages = $MasterImages.Keys | Where-Object { -not $ReferencedImages[$_] }
$UnusedImages | ForEach-Object { 
    Add-Content $UnreferencedImagesReport "$_|$($MasterImages[$_])"
}

# Write summary report
$TotalImages = $MasterImages.Count
$TotalReferenced = $ReferencedImages.Count
$TotalUnreferenced = $TotalImages - $MatchedCount
$Summary = @"
Verification Summary:
---------------------
Total Images in Master List: $TotalImages
Total Referenced Images: $TotalReferenced
Total Matched Images: $MatchedCount
Total Missing Images: $MissingCount
Total Unreferenced Images: $TotalUnreferenced
"@
$Summary | Set-Content $SummaryReport

Write-Host "Verification complete. Reports generated in $OutputDir"
