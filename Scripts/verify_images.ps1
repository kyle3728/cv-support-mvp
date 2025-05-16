param (
    [string]$htmFolder = 'C:\CV_Help\HTML_Extracted',
    [string]$indexFile = 'C:\CV_Help\Metadata\all_images_with_paths.txt'
)

if (-not (Test-Path $htmFolder)) { Write-Error "HTML folder not found: $htmFolder"; exit }
if (-not (Test-Path $indexFile)) { Write-Error "Index file not found: $indexFile"; exit }

$ErrorActionPreference = 'Stop'
$ciComparer = [StringComparer]::OrdinalIgnoreCase
$outs = @{ matched='matched_images.txt'; missing='missing_images.txt'; orphan='orphan_images.txt'; duplicates='duplicates_in_index.txt'; parseErrors='parse_errors.log' }
$outs.Values | ForEach-Object { Remove-Item $_ -Force -ErrorAction SilentlyContinue }

# ── 1. Build reference map ───────────────────────────────────────────
Write-Host 'Scanning HTML…'
$refMap = [Collections.Generic.Dictionary[string,Collections.Generic.List[string]]]::new($ciComparer)
$files  = Get-ChildItem -Path $htmFolder -Recurse -Include *.htm,*.html -File
$total  = $files.Count; $i = 0

foreach ($file in $files) {
    $i++
    Write-Progress -Activity 'Parsing HTML' -Status "$($file.Name) ($i/$total)" -PercentComplete ($i/$total*100)

    try {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        if ($content -match '\0') {
            "Null characters detected in $($file.FullName). Skipping." | Out-File 'parse_errors.log' -Append -Encoding UTF8
            continue
        }

        $dom = New-Object -ComObject 'HTMLfile'
        $dom.IHTMLDocument2_write($content)
        foreach ($img in $dom.getElementsByTagName('img')) {
            $name = [System.IO.Path]::GetFileName([uri]::UnescapeDataString($img.src)).ToLowerInvariant()
            if ($name) {
                if (-not $refMap.ContainsKey($name)) { $refMap[$name] = [Collections.Generic.List[string]]::new() }
                $refMap[$name].Add($file.FullName)
            }
        }
        $dom.close()
    } catch {
        # fallback regex
        $pattern = '(?i)<img[^>]+src=["'']?([^"''>]+?\.(?:png|jpe?g|gif|bmp|svg))(?:\?.*?)?["'']?'
        foreach ($m in [regex]::Matches($content, $pattern)) {
            $name = [System.IO.Path]::GetFileName([uri]::UnescapeDataString($m.Groups[1].Value)).ToLowerInvariant()
            if ($name) {
                if (-not $refMap.ContainsKey($name)) { $refMap[$name] = [Collections.Generic.List[string]]::new() }
                $refMap[$name].Add($file.FullName)
            }
        }
    }
}

# ── 2. Load index ─────────────────────────────────────────────────────
Write-Host 'Loading index… (images only)'
$index = [Hashtable]::new($ciComparer)
$dups  = [Hashtable]::new($ciComparer)
$illegalLog = 'illegal_characters.log'
Remove-Item $illegalLog -Force -ErrorAction SilentlyContinue

Get-Content $indexFile -Encoding UTF8 | ForEach-Object {
    $line = ($_ -replace '\0','').Trim()
    if (-not $line) { return }
    $parts = $line -split '\|',2
    if ($parts.Count -ne 2) {
        $line | Out-File $outs.parseErrors -Append -Encoding UTF8
        return
    }

    # take final path segment then sanitise illegal chars
    $raw   = ($parts[0] -split '[\\/]')[-1]
    $name  = [uri]::UnescapeDataString($raw).ToLowerInvariant()
    # Skip non-image rows (e.g., .htm, .css)
    if ($name -notmatch '\.(png|jpe?g|gif|bmp|svg)$') {
        "Skipped non-image row: $raw" | Out-File 'index_nonimages.log' -Append -Encoding UTF8
        return
    }
    $name  = ($name -replace '[<>:"/\\|?*]','')
    $name  = [System.IO.Path]::GetFileName($name)
    $path  = $parts[1].Trim()

    if ($index.ContainsKey($name)) {
        if (-not $dups.ContainsKey($name)) { $dups[$name] = @($index[$name]) }
        $dups[$name] += $path
    } else {
        $index[$name] = $path
    }
}

# ── 3. Compare sets ───────────────────────────────────────────────────
$matched = $refMap.Keys | Where-Object { $index.ContainsKey($_) }
$missing = $refMap.Keys | Where-Object { -not $index.ContainsKey($_) }
$orphan  = $index.Keys  | Where-Object { -not $refMap.ContainsKey($_) }

# Second-pass: confirm orphans (raw search)
Write-Host 'Second-pass orphan confirmation…'
$confirmedOrphans = New-Object System.Collections.Generic.List[string]
$regexMiss        = New-Object System.Collections.Generic.List[string]
foreach ($name in $orphan) {
    if (Select-String -Path "$htmFolder\**\*.htm*" -Pattern ([regex]::Escape($name)) -Quiet) {
        $regexMiss.Add($name)
    } else {
        $confirmedOrphans.Add($name)
    }
}

# ── 4. Write reports ─────────────────────────────────────────────────-
$confirmedOrphans | ForEach-Object { "$_|$($index[$_])" } | Out-File $outs.orphan -Encoding UTF8
$regexMiss        | Out-File 'regex_missed.txt' -Encoding UTF8
$matched          | ForEach-Object { "$_|$($refMap[$_].Count)|$([string]::Join(',', $refMap[$_]))" } | Out-File $outs.matched -Encoding UTF8
$missing          | ForEach-Object { "$_|$([string]::Join(',', $refMap[$_]))" }                    | Out-File $outs.missing -Encoding UTF8
$dups.GetEnumerator() | ForEach-Object { "$($_.Key)|$([string]::Join(',', $_.Value))" }             | Out-File $outs.duplicates -Encoding UTF8

# ── 5. Summary ───────────────────────────────────────────────────────
$summary = [pscustomobject]@{
    Index_Rows        = (Get-Content $indexFile -Encoding UTF8).Count
    Unique_In_Index   = $index.Count
    Duplicate_Count   = $dups.Count
    Referenced_Count  = $refMap.Count
    Matched_Count     = $matched.Count
    Missing_Count     = $missing.Count
    Orphan_Count      = $confirmedOrphans.Count
    True_Unique_Files = ($index.Keys + $dups.Keys | Sort-Object -Unique).Count
}
$summary | Format-Table -AutoSize

Write-Host "Verification complete."
