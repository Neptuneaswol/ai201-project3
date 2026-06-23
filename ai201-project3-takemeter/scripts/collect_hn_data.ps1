<#
TakeMeter — Hacker News data collection script.

Pulls comments from a mix of front-page, Show HN, and Ask HN threads via
HN's public Firebase API (no auth required), decodes HTML entities, filters
out deleted/dead/too-short fragments, and writes a raw candidate pool CSV
for manual labeling against the definitions in planning.md.

Usage: powershell -ExecutionPolicy Bypass -File collect_hn_data.ps1
#>

$ErrorActionPreference = "Stop"
$base = "https://hacker-news.firebaseio.com/v0"
$outPath = Join-Path $PSScriptRoot "..\data\hn_raw_candidates.csv"

function Get-Json($url) {
    Invoke-RestMethod -Uri $url -TimeoutSec 20
}

function Clean-Text($raw) {
    if (-not $raw) { return $null }
    $t = $raw
    $t = $t -replace '<p>', "`n"
    $t = $t -replace '<[^>]+>', ''
    $t = $t -replace '&#x2F;', '/'
    $t = $t -replace '&#x27;', "'"
    $t = $t -replace '&quot;', '"'
    $t = $t -replace '&gt;', '>'
    $t = $t -replace '&lt;', '<'
    $t = $t -replace '&amp;', '&'
    $t = $t.Trim()
    return $t
}

Write-Host "Fetching story pools..."
$topIds  = Get-Json "$base/topstories.json"
$showIds = Get-Json "$base/showstories.json"
$askIds  = Get-Json "$base/askstories.json"

# Sample a mix of each pool: front-page (general), Show HN (hype-dense),
# Ask HN (substantive-dense). More front-page stories since that pool is
# largest and most varied; fewer Show/Ask needed since they're more
# concentrated toward specific labels.
$storyPlan = @(
    @{ Ids = $topIds[0..39];  Type = "top" },
    @{ Ids = $showIds[0..19]; Type = "show" },
    @{ Ids = $askIds[0..19];  Type = "ask" }
)

$rows = New-Object System.Collections.Generic.List[object]
$seenIds = New-Object System.Collections.Generic.HashSet[string]

foreach ($pool in $storyPlan) {
    foreach ($storyId in $pool.Ids) {
        try {
            $story = Get-Json "$base/item/$storyId.json"
        } catch {
            continue
        }
        if (-not $story -or -not $story.kids) { continue }

        $title = $story.title
        # Take up to 12 top-level comments per story for thread diversity
        # without over-sampling any single thread.
        $kidSample = $story.kids[0..([Math]::Min(11, $story.kids.Count - 1))]

        foreach ($kidId in $kidSample) {
            if ($seenIds.Contains([string]$kidId)) { continue }
            $seenIds.Add([string]$kidId) | Out-Null

            try {
                $comment = Get-Json "$base/item/$kidId.json"
            } catch {
                continue
            }
            if (-not $comment) { continue }
            if ($comment.deleted -or $comment.dead) { continue }
            if (-not $comment.text) { continue }

            $clean = Clean-Text $comment.text
            if (-not $clean) { continue }
            $wordCount = ($clean -split '\s+' | Where-Object { $_ -ne '' }).Count
            if ($wordCount -lt 10) { continue }

            $rows.Add([PSCustomObject]@{
                comment_id  = $comment.id
                story_title = $title
                story_type  = $pool.Type
                text        = $clean
                label       = ""
                notes       = ""
            })
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host "  Pool '$($pool.Type)' done. Rows so far: $($rows.Count)"
}

$rows | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
Write-Host "`nWrote $($rows.Count) raw candidate comments to $outPath"
Write-Host "Breakdown by story_type:"
$rows | Group-Object story_type | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
