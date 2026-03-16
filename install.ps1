param(
    [string]$Target = "."
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$version = "4.0.0"
$base = "https://raw.githubusercontent.com/deveshd7/PowerBI-Skill/main"
$skillDir = Join-Path $Target ".claude\skills\pbi"
$cmdsDir = Join-Path $skillDir "commands"
$sharedDir = Join-Path $skillDir "shared"

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor DarkYellow
Write-Host "  ║                                                   ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██████  ██████  ██                              ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██   ██ ██   ██ ██                              ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██████  ██████  ██      Power BI DAX Co-pilot   ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██      ██   ██ ██      for Claude Code         ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██      ██████  ██                              ║" -ForegroundColor DarkYellow
Write-Host "  ║                                          v$version   ║" -ForegroundColor DarkYellow
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor DarkYellow
Write-Host ""

New-Item -ItemType Directory -Force -Path $cmdsDir | Out-Null
New-Item -ItemType Directory -Force -Path $sharedDir | Out-Null

# Download router
Write-Host "  [1/3] Downloading skill router..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "$base/.claude/skills/pbi/SKILL.md" -OutFile (Join-Path $skillDir "SKILL.md") -UseBasicParsing

# Download commands
Write-Host "  [2/3] Downloading commands..." -ForegroundColor Cyan
$commands = @(
    "explain","format","optimise","comment","error","new",
    "load","audit","diff","commit","edit","undo",
    "comment-batch","changelog","extract","help"
)
$total = $commands.Count
$i = 0
foreach ($cmd in $commands) {
    $i++
    $pct = [math]::Round(($i / $total) * 100)
    $bar = ("=" * [math]::Floor($pct / 5)) + (" " * (20 - [math]::Floor($pct / 5)))
    Write-Host "`r        [$bar] $i/$total  " -NoNewline
    Invoke-WebRequest -Uri "$base/.claude/skills/pbi/commands/$cmd.md" -OutFile (Join-Path $cmdsDir "$cmd.md") -UseBasicParsing
}
Write-Host ""

# Download shared files
Write-Host "  [3/3] Downloading shared resources..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "$base/.claude/skills/pbi/shared/api-notes.md" -OutFile (Join-Path $sharedDir "api-notes.md") -UseBasicParsing

$resolved = (Resolve-Path $skillDir).Path
Write-Host ""
Write-Host "  Installed to: $resolved" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Ready! Open Claude Code and type /pbi to get started." -ForegroundColor Green
Write-Host ""
