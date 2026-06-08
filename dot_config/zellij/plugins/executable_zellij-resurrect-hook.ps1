$cmd = $env:RESURRECT_COMMAND

if ($cmd -notmatch '(?:^|[\\\/])claude(?:\.exe)?(?:\s|$)') {
    Write-Output $cmd
    exit 0
}

$parts = $cmd -split '\s+', 2
$binary = $parts[0]
$argsPart = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }

if (-not $argsPart) {
    Write-Output "$binary --continue"
    exit 0
}

$words = $argsPart -split '\s+'
$uuid = ''
$remaining = @()
$skipNext = $false

for ($i = 0; $i -lt $words.Count; $i++) {
    if ($skipNext) {
        $skipNext = $false
        continue
    }
    if ($words[$i] -eq '--session-id' -and ($i + 1) -lt $words.Count) {
        $uuid = $words[$i + 1]
        $skipNext = $true
    } else {
        $remaining += $words[$i]
    }
}

if ($uuid) {
    $suffix = if ($remaining.Count -gt 0) { " $($remaining -join ' ')" } else { '' }
    Write-Output "$binary --resume $uuid$suffix"
    exit 0
}

Write-Output "$binary --continue $argsPart"
