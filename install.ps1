param(
    [string]$Target = "."
)

$ErrorActionPreference = "Stop"

$base = "https://raw.githubusercontent.com/deveshd7/PowerBI-Skill/main"
$skillDir = Join-Path $Target ".claude\skills\pbi"
$cmdsDir = Join-Path $skillDir "commands"
$sharedDir = Join-Path $skillDir "shared"

New-Item -ItemType Directory -Force -Path $cmdsDir | Out-Null
New-Item -ItemType Directory -Force -Path $sharedDir | Out-Null

Write-Host "Installing PBI-SKILL v3.0..." -ForegroundColor Cyan

Invoke-WebRequest -Uri "$base/.claude/skills/pbi/SKILL.md" -OutFile (Join-Path $skillDir "SKILL.md") -UseBasicParsing

$commands = @("explain","format","optimise","comment","error","new","load","audit","diff","commit","edit","undo","comment-batch","changelog")
foreach ($cmd in $commands) {
    Invoke-WebRequest -Uri "$base/.claude/skills/pbi/commands/$cmd.md" -OutFile (Join-Path $cmdsDir "$cmd.md") -UseBasicParsing
}

Invoke-WebRequest -Uri "$base/.claude/skills/pbi/shared/api-notes.md" -OutFile (Join-Path $sharedDir "api-notes.md") -UseBasicParsing

Write-Host "Done! Type /pbi in Claude Code to get started." -ForegroundColor Green
