#Requires -Version 7.0

# Copyright (c) 2026 hman0994
# Licensed under the MIT License.
#
# NOT FINANCIAL ADVICE. This project is an experimental software automation tool
# provided for educational and informational purposes only. It is not, and must
# not be construed as, financial, investment, trading, tax, legal, or other
# professional advice, nor a recommendation, solicitation, or offer to buy or
# sell any security, cryptocurrency, or other financial instrument. The author
# is not a licensed financial advisor, broker-dealer, or investment
# professional. Trading and investing involve substantial risk, including the
# possible loss of all capital; automated and AI-driven trading can amplify
# these risks and may execute unintended orders. AI/LLM output can be
# inaccurate, incomplete, or wrong and should not be relied upon without
# independent verification. You are solely responsible for any decisions and
# trades executed with this software.

<#
.SYNOPSIS
    Configurable prompt looping machine for Copilot CLI in -p mode.

.DESCRIPTION
    Orchestration only: reads config/runner.config.json, runs a continuous tick
    loop, tracks time and schedule state, selects the right prompt, and invokes
    Copilot CLI with -p plus a runner-context block. All trading decisions are
    made by the model inside each Copilot CLI session (via the Robinhood MCP
    server configured in Copilot CLI itself).

.PARAMETER ConfigPath
    Path to the JSON config file. Defaults to config/runner.config.json next to
    this script.

.PARAMETER Once
    Invoke the loop prompt exactly once, ignoring the schedule, then exit with
    the Copilot CLI exit code. Useful as a smoke test.

.PARAMETER DryRun
    Build and log the Copilot CLI command without executing it.

.EXAMPLE
    pwsh -File .\runner.ps1

.EXAMPLE
    pwsh -File .\runner.ps1 -Once -DryRun
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Once,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Force UTF-8 for external-process output capture. Without this, PowerShell
# decodes subprocess stdout through the Windows OEM code page (typically CP437),
# which corrupts the Unicode box-drawing and emoji characters that Copilot CLI
# emits in its -p session output.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$script:RepoRoot = $PSScriptRoot
$script:AllDays  = @('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

function Get-ConfigValue {
    # Safe property lookup on a PSCustomObject with a default fallback.
    param($Object, [string]$Name, $Default = $null)
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property -and $null -ne $property.Value) { return $property.Value }
    }
    return $Default
}

function Resolve-RunnerPath {
    param([string]$BasePath, [string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $BasePath $Path)
}

function Get-TimeOfDay {
    # Parses "HH:mm" (or "H:mm" / "HH:mm:ss") into a TimeSpan.
    param([string]$Value)
    $parsed = [datetime]::MinValue
    foreach ($format in @('HH\:mm', 'H\:mm', 'HH\:mm\:ss')) {
        $ok = [datetime]::TryParseExact(
            $Value, $format, [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None, [ref]$parsed)
        if ($ok) { return $parsed.TimeOfDay }
    }
    throw "Invalid time value '$Value'. Expected HH:mm."
}

function Get-ThinkingEffort {
    param($Value, [string]$Scope)
    if (-not $Value) { return $null }
    $effort = ([string]$Value).Trim().ToLowerInvariant()
    if ($effort -notin @('none', 'low', 'medium', 'high', 'xhigh', 'max')) {
        throw "$Scope ThinkingEffort '$Value' is invalid. Allowed values: none, low, medium, high, xhigh, max."
    }
    return $effort
}

function ConvertTo-MultilineText {
    # Accepts either a single string or an array of lines and returns one text block.
    param($Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }

    $lines = @($Value | ForEach-Object { [string]$_ })
    return ($lines -join "`n")
}

function Get-ScheduleEntry {
    # Validates and normalizes one entry from the Schedule JSON array.
    param($Entry, [int]$Index)
    $name    = [string](Get-ConfigValue $Entry 'Name' "entry-$Index")
    $enabled = [bool](Get-ConfigValue $Entry 'Enabled' $true)
    $type    = [string](Get-ConfigValue $Entry 'Type' 'daily-at')

    if ($type -notin @('daily-at', 'interval')) {
        throw "Schedule entry '$name': unsupported Type '$type'. Allowed: 'daily-at', 'interval'."
    }

    $promptFile = Get-ConfigValue $Entry 'PromptFile'
    $promptText = Get-ConfigValue $Entry 'PromptText'
    if (-not $promptFile -and -not $promptText) {
        throw "Schedule entry '$name': requires PromptFile or PromptText."
    }

    $daysRaw = Get-ConfigValue $Entry 'Days'
    $days    = if ($null -eq $daysRaw) { $script:AllDays } else { @($daysRaw | ForEach-Object { [string]$_ }) }

    $props = [ordered]@{
        Name           = $name
        Enabled        = $enabled
        Type           = $type
        Days           = $days
        PromptFile     = $promptFile
        PromptText     = $promptText
        Model          = Get-ConfigValue $Entry 'Model'
        ThinkingEffort = Get-ThinkingEffort (Get-ConfigValue $Entry 'ThinkingEffort') "Schedule entry '$name'"
    }

    if ($type -eq 'daily-at') {
        $time = Get-ConfigValue $Entry 'Time'
        if (-not $time) { throw "Schedule entry '$name': 'daily-at' requires Time (e.g. '09:30')." }
        $null = Get-TimeOfDay ([string]$time)   # validate format
        $props['Time'] = [string]$time
    }
    elseif ($type -eq 'interval') {
        $intervalMinutes = [double](Get-ConfigValue $Entry 'IntervalMinutes' 5)
        if ($intervalMinutes -le 0) { throw "Schedule entry '$name': IntervalMinutes must be > 0." }
        $windowStart = Get-ConfigValue $Entry 'WindowStart'
        $windowEnd   = Get-ConfigValue $Entry 'WindowEnd'
        if ($windowStart) { $null = Get-TimeOfDay ([string]$windowStart) }
        if ($windowEnd)   { $null = Get-TimeOfDay ([string]$windowEnd) }
        $props['IntervalMinutes'] = $intervalMinutes
        $props['WindowStart']     = $windowStart
        $props['WindowEnd']       = $windowEnd
    }

    return [pscustomobject]$props
}

function Get-RunnerConfig {
    param([string]$Path, [string]$RepoRoot)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Config file not found: $Path" }
    $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json

    $cli     = Get-ConfigValue $json 'CopilotCliConfig'
    $context = Get-ConfigValue $json 'Context'

    $rawSchedule = @(Get-ConfigValue $json 'Schedule' @())
    $schedule = @()
    for ($i = 0; $i -lt $rawSchedule.Count; $i++) {
        $schedule += Get-ScheduleEntry -Entry $rawSchedule[$i] -Index $i
    }

    $startPromptRaw = Get-ConfigValue $json 'StartPrompt'
    $startPrompt = [pscustomobject]@{
        Enabled        = [bool](Get-ConfigValue $startPromptRaw 'Enabled' $false)
        PromptFile     = Get-ConfigValue $startPromptRaw 'PromptFile'
        PromptText     = Get-ConfigValue $startPromptRaw 'PromptText'
        Model          = Get-ConfigValue $startPromptRaw 'Model'
        ThinkingEffort = Get-ThinkingEffort (Get-ConfigValue $startPromptRaw 'ThinkingEffort') 'StartPrompt'
    }

    $config = [pscustomobject]@{
        TickIntervalSeconds    = [int](Get-ConfigValue $json 'TickIntervalSeconds' 1)
        PromptsFolder          = Resolve-RunnerPath $RepoRoot ([string](Get-ConfigValue $json 'PromptsFolder' 'prompts'))
        LogFolder              = Resolve-RunnerPath $RepoRoot ([string](Get-ConfigValue $json 'LogFolder' 'logs'))
        StartPrompt            = $startPrompt
        Schedule               = $schedule
        CliExecutablePath      = [string](Get-ConfigValue $cli 'ExecutablePath' 'copilot')
        CliBaseArguments       = @(Get-ConfigValue $cli 'BaseArguments' @('-p'))
        CliModel               = Get-ConfigValue $cli 'Model'
        CliThinkingEffort      = Get-ThinkingEffort (Get-ConfigValue $cli 'ThinkingEffort') 'CopilotCliConfig'
        CliAdditionalArguments = @(Get-ConfigValue $cli 'AdditionalArguments' @())
        CliWorkingDirectory    = Resolve-RunnerPath $RepoRoot ([string](Get-ConfigValue $cli 'WorkingDirectory' '.'))
        CliEnvironment         = Get-ConfigValue $cli 'Environment'
        IncludeContext         = [bool](Get-ConfigValue $context 'IncludeRunnerContext' $true)
        ContextPretext         = ConvertTo-MultilineText (Get-ConfigValue $context 'Pretext' '')
    }

    if ($config.TickIntervalSeconds -lt 1) { throw 'TickIntervalSeconds must be >= 1.' }
    if ($config.StartPrompt.Enabled -and -not $config.StartPrompt.PromptFile -and -not $config.StartPrompt.PromptText) {
        throw 'StartPrompt is enabled but no PromptFile or PromptText was provided.'
    }
    if ($config.Schedule.Count -eq 0) { Write-Warning 'No Schedule entries defined. Runner will tick but never invoke Copilot CLI.' }

    return $config
}

function Set-CliEnvironment {
    # Applies CopilotCliConfig.Environment entries to this process (e.g. for MCP).
    param($Config)
    if ($null -eq $Config.CliEnvironment) { return }
    foreach ($property in $Config.CliEnvironment.PSObject.Properties) {
        Set-Item -Path ('env:{0}' -f $property.Name) -Value ([string]$property.Value)
    }
}

# ---------------------------------------------------------------------------
# Schedule
# ---------------------------------------------------------------------------

function Test-DayAllowed {
    param([string[]]$Days, [datetime]$Now)
    return ($Days -contains $Now.DayOfWeek.ToString())
}

function New-RunnerState {
    param([datetime]$SessionStart)
    return [pscustomobject]@{
        SessionStart       = $SessionStart
        CycleCount         = 0
        InvocationCount    = 0
        LastTrigger        = $null
        LastInvocationTime = $null
        FiredDates         = @{}    # Name -> Date      (daily-at: prevent same-day re-fire)
        LastFiredAt        = @{}    # Name -> DateTime  (interval: last invocation time)
    }
}

function Get-DueEntries {
    # Pure decision function: returns the ordered list of schedule entries that
    # should fire on this tick. Callers must wrap the result in @().
    param($Config, $State, [datetime]$Now)

    $due = @()

    foreach ($entry in $Config.Schedule) {
        if (-not $entry.Enabled) { continue }
        if (-not (Test-DayAllowed -Days $entry.Days -Now $Now)) { continue }

        if ($entry.Type -eq 'daily-at') {
            # Fire once per calendar day at or after the configured time.
            if ($State.FiredDates.ContainsKey($entry.Name) -and
                $State.FiredDates[$entry.Name] -eq $Now.Date) { continue }
            $fireAt = $Now.Date + (Get-TimeOfDay $entry.Time)
            if ($Now -ge $fireAt) { $due += $entry }
        }
        elseif ($entry.Type -eq 'interval') {
            # Check optional time window.
            if ($entry.WindowStart) {
                if ($Now -lt ($Now.Date + (Get-TimeOfDay ([string]$entry.WindowStart)))) { continue }
            }
            if ($entry.WindowEnd) {
                if ($Now -ge ($Now.Date + (Get-TimeOfDay ([string]$entry.WindowEnd)))) { continue }
            }
            # Determine effective last-fire reference:
            #   Already fired this session  -> use actual last fire time.
            #   Never fired, window defined -> use WindowStart today (first fire is
            #     IntervalMinutes after the window opened, not on the first tick).
            #   Never fired, no window      -> use SessionStart (same logic for 24/7).
            if ($State.LastFiredAt.ContainsKey($entry.Name)) {
                $effectiveLast = $State.LastFiredAt[$entry.Name]
            } elseif ($entry.WindowStart) {
                $effectiveLast = $Now.Date + (Get-TimeOfDay ([string]$entry.WindowStart))
            } else {
                $effectiveLast = $State.SessionStart
            }
            if (($Now - $effectiveLast).TotalMinutes -ge $entry.IntervalMinutes) { $due += $entry }
        }
    }

    return $due
}

function Test-EntryAlreadyFiredOnDate {
    param($State, $Entry, [datetime]$Date, $FiredEntry, [datetime]$FiredAt)

    if ($null -ne $FiredEntry -and $FiredEntry.Name -eq $Entry.Name -and $FiredEntry.Type -eq 'daily-at' -and $FiredAt.Date -eq $Date.Date) {
        return $true
    }
    return ($State.FiredDates.ContainsKey($Entry.Name) -and $State.FiredDates[$Entry.Name] -eq $Date.Date)
}

function Get-LastFiredAtForEntry {
    param($State, $Entry, $FiredEntry, [datetime]$FiredAt)

    if ($null -ne $FiredEntry -and $FiredEntry.Name -eq $Entry.Name -and $FiredEntry.Type -eq 'interval') {
        return $FiredAt
    }
    if ($State.LastFiredAt.ContainsKey($Entry.Name)) {
        return $State.LastFiredAt[$Entry.Name]
    }
    return $null
}

function Get-NextFireTimeForEntry {
    param($Entry, $State, [datetime]$Now, $FiredEntry = $null, [datetime]$FiredAt = [datetime]::MinValue)

    if (-not $Entry.Enabled) { return $null }

    if ($Entry.Type -eq 'daily-at') {
        for ($offset = 0; $offset -lt 14; $offset++) {
            $date = $Now.Date.AddDays($offset)
            if (-not (Test-DayAllowed -Days $Entry.Days -Now $date)) { continue }
            if (Test-EntryAlreadyFiredOnDate -State $State -Entry $Entry -Date $date -FiredEntry $FiredEntry -FiredAt $FiredAt) { continue }

            $candidate = $date + (Get-TimeOfDay ([string]$Entry.Time))
            if ($candidate -ge $Now) { return $candidate }
        }
        return $null
    }

    if ($Entry.Type -ne 'interval') { return $null }

    $interval = [timespan]::FromMinutes([double]$Entry.IntervalMinutes)
    $lastFiredAt = Get-LastFiredAtForEntry -State $State -Entry $Entry -FiredEntry $FiredEntry -FiredAt $FiredAt
    $hasWindow = [bool]($Entry.WindowStart -or $Entry.WindowEnd)

    if (-not $hasWindow) {
        $candidate = if ($null -ne $lastFiredAt) { $lastFiredAt + $interval } else { $State.SessionStart + $interval }
        while ($candidate -lt $Now) { $candidate += $interval }

        for ($i = 0; $i -lt 14 * 24 * 60; $i++) {
            if (Test-DayAllowed -Days $Entry.Days -Now $candidate) { return $candidate }
            $candidate += $interval
        }
        return $null
    }

    for ($offset = 0; $offset -lt 14; $offset++) {
        $date = $Now.Date.AddDays($offset)
        if (-not (Test-DayAllowed -Days $Entry.Days -Now $date)) { continue }

        $windowStart = if ($Entry.WindowStart) { $date + (Get-TimeOfDay ([string]$Entry.WindowStart)) } else { $date }
        $windowEnd = if ($Entry.WindowEnd) { $date + (Get-TimeOfDay ([string]$Entry.WindowEnd)) } else { $date.AddDays(1) }
        if ($windowEnd -le $windowStart) { continue }

        if ($null -ne $lastFiredAt) {
            $candidate = if ($lastFiredAt -lt $windowStart) { $windowStart } else { $lastFiredAt + $interval }
        }
        else {
            $candidate = $windowStart + $interval
        }

        while ($candidate -lt $Now) { $candidate += $interval }
        if ($candidate -ge $windowStart -and $candidate -lt $windowEnd) { return $candidate }
    }

    return $null
}

function Get-NextScheduledPrompt {
    param($Config, $State, [datetime]$Now, $FiredEntry = $null, [datetime]$FiredAt = [datetime]::MinValue)

    $next = $null
    foreach ($entry in $Config.Schedule) {
        $fireAt = Get-NextFireTimeForEntry -Entry $entry -State $State -Now $Now -FiredEntry $FiredEntry -FiredAt $FiredAt
        if ($null -eq $fireAt) { continue }
        if ($null -eq $next -or $fireAt -lt $next.FireAt) {
            $next = [pscustomobject]@{
                Name   = $entry.Name
                Type   = $entry.Type
                FireAt = $fireAt
            }
        }
    }
    return $next
}

# ---------------------------------------------------------------------------
# Prompts and context
# ---------------------------------------------------------------------------

function Get-PromptText {
    # PromptFile (resolved relative to PromptsFolder, re-read fresh each invocation)
    # takes precedence over inline PromptText.
    param($Config, $Entry)
    if ($Entry.PromptFile) {
        $path = Resolve-RunnerPath $Config.PromptsFolder ([string]$Entry.PromptFile)
        if (-not (Test-Path -LiteralPath $path)) { throw "Prompt file for '$($Entry.Name)' not found: $path" }
        return (Get-Content -LiteralPath $path -Raw -Encoding UTF8)
    }
    if ($Entry.PromptText) { return [string]$Entry.PromptText }
    throw "No prompt configured for entry '$($Entry.Name)' (set PromptFile or PromptText)."
}

function Build-ContextBlock {
    # Prepended to every prompt so the model knows the time, which entry fired,
    # and the full active schedule. Optionally includes Context.Pretext first.
    param($Config, $State, [datetime]$Now, $Entry)

    $lastInvocation = 'none this session'
    if ($null -ne $State.LastInvocationTime) {
        $lastInvocation = '{0:yyyy-MM-dd HH:mm:ss} (entry: {1})' -f $State.LastInvocationTime, $State.LastTrigger
    }

    $scheduleLines = foreach ($e in $Config.Schedule) {
        if (-not $e.Enabled) { continue }
        if ($e.Type -eq 'daily-at') {
            '  - [{0}] daily-at {1} | days: {2}' -f $e.Name, $e.Time, ($e.Days -join '/')
        } elseif ($e.Type -eq 'interval') {
            $window = if ($e.WindowStart -or $e.WindowEnd) { '{0}-{1}' -f ($e.WindowStart ?? 'start'), ($e.WindowEnd ?? 'end') } else { 'always' }
            '  - [{0}] every {1}m | window: {2} | days: {3}' -f $e.Name, $e.IntervalMinutes, $window, ($e.Days -join '/')
        }
    }

    $lines = @(
        '## Runner Context'
        ('- Current time  : {0:yyyy-MM-dd HH:mm:ss} local ({1})' -f $Now, $Now.DayOfWeek)
        ('- Fired entry   : {0} (type: {1})' -f $Entry.Name, $Entry.Type)
        ('- Session start : {0:yyyy-MM-dd HH:mm:ss}' -f $State.SessionStart)
        ('- Invocation #  : {0} this session' -f ($State.InvocationCount + 1))
        ('- Last invocation: {0}' -f $lastInvocation)
        '- Schedule (enabled entries):'
    ) + @($scheduleLines)

    $contextText = $lines -join "`n"
    if (-not [string]::IsNullOrWhiteSpace($Config.ContextPretext)) {
        return ($Config.ContextPretext.TrimEnd() + "`n`n" + $contextText)
    }

    return $contextText
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

function Write-RunnerLog {
    param($Config, [string]$Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    $logFile = Join-Path $Config.LogFolder ('runner-{0:yyyyMMdd}.log' -f (Get-Date))
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Write-InvocationSummary {
    param($Config, $Summary)
    $path = Join-Path $Config.LogFolder 'latest-invocation.json'
    $Summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Format-ArgPreview {
    # One-line, truncated preview of the argument list for log readability.
    param([object[]]$ArgumentList)
    $parts = foreach ($argument in $ArgumentList) {
        $text = ([string]$argument) -replace '\r?\n', ' '
        if ($text.Length -gt 120) { $text = $text.Substring(0, 117) + '...' }
        if ($text -match '\s') { '"{0}"' -f $text } else { $text }
    }
    return ($parts -join ' ')
}

function Get-CopilotAiCredits {
    param([string]$OutputText)

    if ($OutputText -match '(?m)^\s*AI Credits\s+([0-9]+(?:\.[0-9]+)?)\b') {
        return $matches[1]
    }
    return $null
}

function Format-NextScheduledPrompt {
    param($NextScheduled)

    if ($null -eq $NextScheduled) { return 'next=none' }
    return 'next=[{0}] {1:yyyy-MM-dd HH:mm:ss} local ({2})' -f $NextScheduled.Name, $NextScheduled.FireAt, $NextScheduled.FireAt.DayOfWeek
}

# ---------------------------------------------------------------------------
# Copilot CLI invocation
# ---------------------------------------------------------------------------

function Invoke-CopilotEntry {
    param($Config, $State, $Entry, [datetime]$Now, [switch]$DryRun)

    $promptBody = Get-PromptText -Config $Config -Entry $Entry
    if ($Config.IncludeContext) {
        $prompt = (Build-ContextBlock -Config $Config -State $State -Now $Now -Entry $Entry) + "`n`n" + $promptBody
    }
    else {
        $prompt = $promptBody
    }

    $argList = @()
    $argList += @($Config.CliBaseArguments)
    $argList += $prompt
    $modelToUse = Get-ConfigValue $Entry 'Model' $Config.CliModel
    if ($modelToUse) { $argList += @('--model', [string]$modelToUse) }
    $thinkingEffortToUse = Get-ConfigValue $Entry 'ThinkingEffort' $Config.CliThinkingEffort
    if ($thinkingEffortToUse) { $argList += @('--effort', [string]$thinkingEffortToUse) }
    $argList += @($Config.CliAdditionalArguments)

    Write-RunnerLog $Config ('Invoking [{0}]: {1} {2}' -f $Entry.Name, $Config.CliExecutablePath, (Format-ArgPreview -ArgumentList $argList))

    $started = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = 0
    $outputText = ''

    if ($DryRun) {
        Write-RunnerLog $Config ('[dry-run] Skipped execution for [{0}]' -f $Entry.Name)
    }
    else {
        Push-Location -LiteralPath $Config.CliWorkingDirectory
        $previousPreference = $ErrorActionPreference
        try {
            # Native stderr must not be promoted to terminating errors.
            $ErrorActionPreference = 'Continue'
            $output = & $Config.CliExecutablePath @argList 2>&1
            if ($null -ne $LASTEXITCODE) { $exitCode = $LASTEXITCODE }
            if ($null -ne $output) {
                $outputText = (@($output) | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
            }
        }
        finally {
            $ErrorActionPreference = $previousPreference
            Pop-Location
        }
    }

    $stopwatch.Stop()
    $ended = Get-Date

    $outputFile = $null
    if (-not $DryRun) {
        $outputFile = Join-Path $Config.LogFolder ('output-{0:yyyyMMdd-HHmmss}-{1}.txt' -f $started, $Entry.Name)
        Set-Content -LiteralPath $outputFile -Value $outputText -Encoding UTF8
    }

    $tail = $outputText
    if ($tail.Length -gt 4000) { $tail = $tail.Substring($tail.Length - 4000) }

    $aiCredits = Get-CopilotAiCredits -OutputText $outputText
    $nextScheduled = Get-NextScheduledPrompt -Config $Config -State $State -Now $ended -FiredEntry $Entry -FiredAt $ended

    $summary = [pscustomobject]@{
        entry           = $Entry.Name
        type            = $Entry.Type
        startedAt       = $started.ToString('o')
        endedAt         = $ended.ToString('o')
        durationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        exitCode        = $exitCode
        dryRun          = [bool]$DryRun
        executable      = $Config.CliExecutablePath
        commandPreview  = Format-ArgPreview -ArgumentList $argList
        promptChars     = $prompt.Length
        aiCredits       = $aiCredits
        nextScheduled   = $nextScheduled
        outputFile      = $outputFile
        outputTail      = $tail
    }
    Write-InvocationSummary -Config $Config -Summary $summary
    $creditText = if ($null -ne $aiCredits) { 'credits={0}' -f $aiCredits } else { 'credits=n/a' }
    Write-RunnerLog $Config ('Completed [{0}]: exit={1} duration={2}s {3} {4}' -f $Entry.Name, $exitCode, $summary.durationSeconds, $creditText, (Format-NextScheduledPrompt -NextScheduled $nextScheduled))
    if ($exitCode -ne 0) {
        Write-RunnerLog $Config ('WARNING [{0}] returned non-zero exit code {1}' -f $Entry.Name, $exitCode)
    }
    return $exitCode
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

function Start-Runner {
    param([string]$ConfigPath, [switch]$Once, [switch]$DryRun)

    if (-not $ConfigPath) { $ConfigPath = Join-Path $script:RepoRoot 'config\runner.config.json' }
    $config = Get-RunnerConfig -Path $ConfigPath -RepoRoot $script:RepoRoot
    $null = New-Item -ItemType Directory -Force -Path $config.LogFolder
    Set-CliEnvironment -Config $config

    $sessionStart = Get-Date
    $state = New-RunnerState -SessionStart $sessionStart

    Write-RunnerLog $config ('Runner starting (config: {0})' -f $ConfigPath)
    Write-RunnerLog $config ('Tick: {0}s | Schedule entries: {1} enabled' -f $config.TickIntervalSeconds, (@($config.Schedule | Where-Object Enabled).Count))
    foreach ($entry in $config.Schedule) {
        $status = if ($entry.Enabled) { 'ON' } else { 'OFF' }
        if ($entry.Type -eq 'daily-at') {
            Write-RunnerLog $config ('  [{0}] {1} daily-at {2} | days: {3}' -f $entry.Name, $status, $entry.Time, ($entry.Days -join ','))
        } elseif ($entry.Type -eq 'interval') {
            $window = if ($entry.WindowStart -or $entry.WindowEnd) { '{0}-{1}' -f ($entry.WindowStart ?? 'start'), ($entry.WindowEnd ?? 'end') } else { 'always' }
            Write-RunnerLog $config ('  [{0}] {1} interval {2}m | window: {3} | days: {4}' -f $entry.Name, $status, $entry.IntervalMinutes, $window, ($entry.Days -join ','))
        }
    }
    Write-RunnerLog $config ('StartPrompt: {0}' -f $(if ($config.StartPrompt.Enabled) { 'ON' } else { 'OFF' }))
    Write-RunnerLog $config ('DryRun: {0} | Once: {1}' -f [bool]$DryRun, [bool]$Once)

    if ($config.StartPrompt.Enabled) {
        $startEntry = [pscustomobject]@{
            Name           = 'startprompt'
            Type           = 'startup'
            PromptFile     = $config.StartPrompt.PromptFile
            PromptText     = $config.StartPrompt.PromptText
            Model          = $config.StartPrompt.Model
            ThinkingEffort = $config.StartPrompt.ThinkingEffort
        }
        try {
            $null = Invoke-CopilotEntry -Config $config -State $state -Entry $startEntry -Now (Get-Date) -DryRun:$DryRun
        }
        catch {
            Write-RunnerLog $config ('ERROR during [startprompt]: {0}' -f $_.Exception.Message)
        }
        $invokedAt = Get-Date
        $state.InvocationCount++
        $state.LastInvocationTime = $invokedAt
        $state.LastTrigger = $startEntry.Name
    }

    if ($Once) {
        # Pick the first enabled interval entry, falling back to the first enabled entry of any type.
        $onceEntry = $config.Schedule | Where-Object { $_.Type -eq 'interval' -and $_.Enabled } | Select-Object -First 1
        if (-not $onceEntry) { $onceEntry = $config.Schedule | Where-Object { $_.Enabled } | Select-Object -First 1 }
        if (-not $onceEntry) { throw 'No enabled schedule entries found for -Once mode.' }
        try {
            return (Invoke-CopilotEntry -Config $config -State $state -Entry $onceEntry -Now (Get-Date) -DryRun:$DryRun)
        }
        catch {
            Write-RunnerLog $config ('ERROR during once invocation: {0}' -f $_.Exception.Message)
            return 1
        }
    }

    while ($true) {
        $now = Get-Date
        $state.CycleCount++
        $due = @(Get-DueEntries -Config $config -State $state -Now $now)

        foreach ($entry in $due) {
            try {
                $null = Invoke-CopilotEntry -Config $config -State $state -Entry $entry -Now $now -DryRun:$DryRun
            }
            catch {
                Write-RunnerLog $config ('ERROR during [{0}]: {1}' -f $entry.Name, $_.Exception.Message)
            }
            # Update state even on error so a broken entry cannot re-fire every tick.
            $invokedAt = Get-Date
            $state.InvocationCount++
            $state.LastInvocationTime = $invokedAt
            $state.LastTrigger = $entry.Name
            if ($entry.Type -eq 'daily-at')  { $state.FiredDates[$entry.Name]  = $now.Date }
            if ($entry.Type -eq 'interval')  { $state.LastFiredAt[$entry.Name] = $invokedAt }
        }

        Start-Sleep -Seconds $config.TickIntervalSeconds
    }
}

# Skip main when dot-sourced (enables testing the functions in isolation).
if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-Runner -ConfigPath $ConfigPath -Once:$Once -DryRun:$DryRun
    if ($null -ne $result) { exit ([int]$result) }
    exit 0
}
