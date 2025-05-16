# Alias_Map_Generator.ps1

param (
    [string]$RootPath = "C:\CV_Help\HTML_Extracted",
    [string]$ImageIndexPath = "C:\CV_Help\Metadata\all_images_with_paths.txt",
    [string]$MissingFilePath = "C:\CV_Help\Scripts\missing_images.txt",
    [string]$OutputAliasMap = "C:\CV_Help\Metadata\alias_map.csv",
    [switch]$Debug = $false
)

# Load master image index
$ImageIndex = @{}
Get-Content $ImageIndexPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -match "^[^|]+\|.+$") {
        $parts = $line -split '\|'
        $filename = $parts[0].ToLower()
        $filepath = $parts[1]
        if (!$ImageIndex.ContainsKey($filename)) {
            $ImageIndex[$filename] = $filepath
        }
    } else {
        if ($Debug) { Write-Host "[WARNING] Malformed line in index: $_" }
    }
}

# Process missing files
$AliasMap = @{}
Get-Content $MissingFilePath | ForEach-Object {
    try {
        # Strip URL parameters and normalize the name
        $line = $_.Trim()
        $parts = $line -split '\|'
        $filenames = ($parts[0].Split('?')[0]).Trim().ToLower()
        $filenameList = $filenames -split ","
        
        foreach ($filenameOnly in $filenameList) {
            $filenameOnly = $filenameOnly.Trim()
            if ($filenameOnly -eq "") { throw "Empty filename extracted from line: $line" }
            $basename = [System.IO.Path]::GetFileNameWithoutExtension($filenameOnly)
            $basenameClean = $basename -replace "[^a-z0-9_]+", ""
            
            # Attempt exact and loose matches
            $foundMatches = Get-ChildItem -Recurse -File -Path $RootPath -Filter "$basename.*" | Where-Object {
                $_.Name.ToLower() -eq $filenameOnly -or ($_.Name.ToLower() -replace "[^a-z0-9_]+", "") -eq $basenameClean
            }
            
            if ($foundMatches.Count -gt 0) {
                # Choose the shortest path (closest match)
                $bestMatch = ($foundMatches | Sort-Object FullName | Select-Object -First 1).FullName
                $AliasMap[$filenameOnly] = $bestMatch
                if ($Debug) { Write-Host "[INFO] Matched $filenameOnly -> $bestMatch" }
            } else {
                if ($Debug) { Write-Host "[WARNING] No match found for $filenameOnly" }
            }
        }
    } catch {
        Write-Host "[ERROR] Failed to process line: $line - Exception: $($_.Exception.Message)"
    }
}

# Write the alias map to CSV
$AliasMap.GetEnumerator() | ForEach-Object {
    "$($_.Key),$($_.Value)" | Out-File -Append -Encoding UTF8 $OutputAliasMap
}

Write-Host "[DONE] Alias map written to $OutputAliasMap"
