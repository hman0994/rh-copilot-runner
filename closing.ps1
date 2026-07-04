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
    On-demand emergency account close — runs closing_prompt.md immediately.

.DESCRIPTION
    Reads config/runner.config.json for CLI settings, then invokes Copilot CLI
    with the closing prompt to flatten all positions and cancel all open orders.

    Intended for use when the main runner loop is not active and the account
    needs to be closed manually (end of session, emergency stop, or testing).

    Executes immediately with no confirmation prompt.

.PARAMETER ConfigPath
    Path to runner.config.json. Defaults to config/runner.config.json next to
    this script.

.PARAMETER Model
    Copilot CLI model to use. Overrides the config default.
    Recommended: a capable model such as gpt-5.5 or claude-sonnet-5.
    Defaults to the StartPrompt model in the config, then CopilotCliConfig.Model.

.PARAMETER Effort
    Thinking effort level: none | low | medium | high | xhigh | max.
    Defaults to 'high' (closing requires careful account inspection).

.PARAMETER DryRun
    Print the assembled command without executing it. No trades are placed.

.EXAMPLE
    pwsh -File .\closing.ps1

.EXAMPLE
    pwsh -File .\closing.ps1 -Model gpt-5.5 -Effort xhigh

.EXAMPLE
    pwsh -File .\closing.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$Model,
    [ValidateSet('none','low','medium','high','xhigh','max')]
    [string]$Effort = 'high',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$RepoRoot = $PSScriptRoot

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-ConfigValue {
    param($Object, [string]$Name, $Default = $null)
    if ($null -ne $Object) {
        $prop = $Object.PSObject.Properties[$Name]
        if ($null -ne $prop -and $null -ne $prop.Value) { return $prop.Value }
    }
    return $Default
}

function Resolve-RunnerPath {
    param([string]$Base, [string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $Base $Path)
}

function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line -ForegroundColor $Color
}

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------

if (-not $ConfigPath) { $ConfigPath = Join-Path $RepoRoot 'config\runner.config.json' }
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

$json      = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cli       = Get-ConfigValue $json 'CopilotCliConfig'
$startPr   = Get-ConfigValue $json 'StartPrompt'

$executable    = [string](Get-ConfigValue $cli 'ExecutablePath' 'copilot')
$baseArgs      = @(Get-ConfigValue $cli 'BaseArguments' @('-p'))
$additionalArgs = @(Get-ConfigValue $cli 'AdditionalArguments' @())
$workingDir    = Resolve-RunnerPath $RepoRoot ([string](Get-ConfigValue $cli 'WorkingDirectory' '.'))
$promptsFolder = Resolve-RunnerPath $RepoRoot ([string](Get-ConfigValue $json 'PromptsFolder' 'prompts'))
$logFolder     = Resolve-RunnerPath $RepoRoot ([string](Get-ConfigValue $json 'LogFolder' 'logs'))

# Model resolution: CLI param > StartPrompt.Model > CopilotCliConfig.Model > 'auto'
if (-not $Model) {
    $Model = [string](Get-ConfigValue $startPr 'Model' (Get-ConfigValue $cli 'Model' 'auto'))
}

# ---------------------------------------------------------------------------
# Read closing prompt
# ---------------------------------------------------------------------------

$promptFile = Join-Path $promptsFolder 'closing_prompt.md'
if (-not (Test-Path -LiteralPath $promptFile)) {
    Write-Error "Closing prompt not found: $promptFile"
    exit 1
}
$promptBody = Get-Content -LiteralPath $promptFile -Raw -Encoding UTF8

# Prepend a minimal context block so the agent knows this is a manual invocation.
$contextBlock = @"
## Runner Context
- Current time  : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) local ($((Get-Date).DayOfWeek))
- Fired entry   : closing (type: manual)
- Session start : n/a (on-demand close script)
- Invocation #  : 1 this session
- Last invocation: none this session
- Schedule (enabled entries):
  - [closing] manual on-demand
"@

$prompt = $contextBlock + "`n`n" + $promptBody

# ---------------------------------------------------------------------------
# Build argument list
# ---------------------------------------------------------------------------

$argList = @()
$argList += $baseArgs
$argList += $prompt
$argList += @('--model', $Model)
$argList += @('--effort', $Effort)
$argList += $additionalArgs

# Preview (truncated) for logging
$preview = ($argList | ForEach-Object {
    $t = ([string]$_) -replace '\r?\n', ' '
    if ($t.Length -gt 120) { $t = $t.Substring(0, 117) + '...' }
    if ($t -match '\s') { '"{0}"' -f $t } else { $t }
}) -join ' '

Write-Log ('Invoking [closing]: {0} {1}' -f $executable, $preview) Cyan

if ($DryRun) {
    Write-Log '[dry-run] Skipped execution.' Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Invoke
# ---------------------------------------------------------------------------

$null = New-Item -ItemType Directory -Force -Path $logFolder
$outputFile = Join-Path $logFolder ('output-{0:yyyyMMdd-HHmmss}-closing.txt' -f (Get-Date))

Push-Location -LiteralPath $workingDir
$prevPref = $ErrorActionPreference
$exitCode = 0
$outputText = ''

try {
    $ErrorActionPreference = 'Continue'
    $output = & $executable @argList 2>&1
    if ($null -ne $LASTEXITCODE) { $exitCode = $LASTEXITCODE }
    if ($null -ne $output) {
        $outputText = (@($output) | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    }
}
finally {
    $ErrorActionPreference = $prevPref
    Pop-Location
}

Set-Content -LiteralPath $outputFile -Value $outputText -Encoding UTF8
Write-Log ('Completed [closing]: exit={0} output -> {1}' -f $exitCode, $outputFile) $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })

if ($exitCode -ne 0) {
    Write-Log ('WARNING: Copilot CLI returned non-zero exit code {0}. Review {1} for details.' -f $exitCode, $outputFile) Red
}

exit $exitCode
