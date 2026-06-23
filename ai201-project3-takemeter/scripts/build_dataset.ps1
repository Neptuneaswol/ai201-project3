<#
TakeMeter — builds the final labeled dataset from the raw HN candidate pools.
Applies manual label decisions (made by reading every candidate against the
definitions in planning.md) for hype/dismissive examples, since those labels
are comparatively rare in this corpus, and a length-based rule for the
substantive majority (validated by spot-reading during collection).
#>

$dataDir = Join-Path $PSScriptRoot "..\data"
$raw1 = Import-Csv (Join-Path $dataDir "hn_raw_candidates.csv")
$raw2 = Import-Csv (Join-Path $dataDir "hn_extra_show.csv")
$all = @($raw1) + @($raw2)

# IDs I read and labeled "hype" — enthusiastic, low-substance boosterism
# about a product/company, no checkable claim.
$hypeIds = @(
    48638594,48632836,48636149,48632402,48630322,48630236,48630407,48626422,
    48624800,48634712,48613634,48628762,48637003,48633758,48633105,
    48636455,48587406,48622471,48592903,48590830,48613542,48612259,48614287,
    48615345,48612741,48615399,48612206,48612370,48612209,48598075,48628718,
    48624748,48618523,48613230,48573061,48613428,48619458,48604266,48614322,
    48613529,48625498,48585163
) | ForEach-Object { [string]$_ }

# IDs labeled "dismissive" — low-effort negativity/snark with no supporting
# reasoning or evidence.
$dismissiveIds = @(
    48638705,48638262,48637067,48634998,48637949,48631393,48636097,48633590,
    48637166,48636539,48637499,48632392,48634885,48638183,48637846,48622463,
    48628479,48627117,48634175,48638347,48638770,48623730,48626941,48614268,
    48611148,48613282,48638449,48633072,48636279,
    48600268,48597658,48625672,48630778,48606260,48618048,
    48627602,48632253,48636984
) | ForEach-Object { [string]$_ }

# IDs that didn't fit cleanly into any of the 3 labels and were excluded
# rather than forced — documented as hard/ambiguous cases in planning.md.
$excludedIds = @(
    48614715,48638703,48638056,48636316,48633065,48635792,48606118
) | ForEach-Object { [string]$_ }

$labeled = New-Object System.Collections.Generic.List[object]
$substantiveCandidates = New-Object System.Collections.Generic.List[object]

foreach ($row in $all) {
    $id = [string]$row.comment_id
    if ($excludedIds -contains $id) { continue }
    $wordCount = ($row.text -split '\s+' | Where-Object { $_ -ne '' }).Count

    if ($hypeIds -contains $id) {
        $labeled.Add([PSCustomObject]@{ text = $row.text; label = "hype"; notes = "" })
    }
    elseif ($dismissiveIds -contains $id) {
        $labeled.Add([PSCustomObject]@{ text = $row.text; label = "dismissive"; notes = "" })
    }
    elseif ($wordCount -ge 25) {
        # Candidate pool for substantive — sampled below to control final size.
        $substantiveCandidates.Add([PSCustomObject]@{ text = $row.text; label = "substantive"; notes = "" })
    }
}

# Target ~175 substantive examples so substantive stays under 70% of the
# final dataset (hype=42, dismissive=38 -> need substantive <= ~187 for a
# ~265-row dataset to stay under 70%, and we deliberately undershoot that
# ceiling for a healthier margin). Sample evenly across the candidate pool
# rather than taking the first N (which would skew toward 'top' stories).
$rnd = [System.Random]::new(42)
$shuffled = $substantiveCandidates | Sort-Object { $rnd.Next() }
$substantiveSample = $shuffled | Select-Object -First 175

try {
    $combined = [System.Collections.Generic.List[object]]::new()
    foreach ($x in $labeled) { $combined.Add($x) }
    foreach ($x in $substantiveSample) { $combined.Add($x) }
    $final = $combined | Sort-Object { $rnd.Next() }
} catch {
    Write-Host "COMBINE ERROR: $($_.Exception | Format-List * -Force | Out-String)"
    throw
}

$outPath = Join-Path $dataDir "takemeter_dataset.csv"
$final | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8

Write-Host "Final dataset rows: $($final.Count)"
Write-Host "Label distribution:"
$final | Group-Object label | Sort-Object Count -Descending | ForEach-Object {
    $pct = [Math]::Round(100 * $_.Count / $final.Count, 1)
    Write-Host "  $($_.Name): $($_.Count) ($pct%)"
}
