# PBI Context

## Last Command
- Command: /pbi:explain
- Timestamp: 2026-03-12T10:00:00Z
- Measure: Revenue YTD
- Outcome: Success — Year-to-date revenue using DATESYTD

## Command History
| Timestamp | Command | Measure Name | Outcome |
|-----------|---------|--------------|---------|
| 2026-03-12T10:00:00Z | /pbi:explain | Revenue YTD | Success |
| 2026-03-12T09:55:00Z | /pbi:format | Revenue YTD | Success |
| 2026-03-12T09:50:00Z | /pbi:optimise | Total Cost | Success |
| 2026-03-12T09:45:00Z | /pbi:comment | Total Cost | Commented |
| 2026-03-12T09:40:00Z | /pbi:explain | Total Cost | Success |
| 2026-03-12T09:35:00Z | /pbi:format | Margin % | Success |
| 2026-03-12T09:30:00Z | /pbi:error | Error: circular | Diagnosed |
| 2026-03-12T09:25:00Z | /pbi:explain | Margin % | Success |
| 2026-03-12T09:20:00Z | /pbi:optimise | Slow Sales | Success |
| 2026-03-12T09:15:00Z | /pbi:format | Slow Sales | Success |
| 2026-03-12T09:10:00Z | /pbi:explain | Slow Sales | Success |
| 2026-03-12T09:05:00Z | /pbi:comment | Revenue | Commented |
| 2026-03-12T09:00:00Z | /pbi:explain | Revenue | Success |
| 2026-03-12T08:55:00Z | /pbi:load | 4 tables loaded | Success |
| 2026-03-12T08:50:00Z | /pbi:audit | Model | Audit complete |
| 2026-03-12T08:45:00Z | /pbi:diff | Model | Diff shown |
| 2026-03-12T08:40:00Z | /pbi:commit | Model | feat: add Revenue |
| 2026-03-12T08:35:00Z | /pbi:edit | Revenue | Expression updated |
| 2026-03-12T08:30:00Z | /pbi:format | Sales Amount | Success |
| 2026-03-12T08:25:00Z | /pbi:explain | Sales Amount | Success |

## Analyst-Reported Failures
| Timestamp | Command | Measure Name | What Failed | Notes |
|-----------|---------|--------------|-------------|-------|
| 2026-03-12T09:30:00Z | /pbi:error | Revenue YTD | Suggested removing DATESYTD | Approach was incorrect — time intel was intentional |
