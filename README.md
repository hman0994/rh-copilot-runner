# rh-copilot-runner

[![Release](https://img.shields.io/github/v/release/hman0994/rh-copilot-runner)](https://github.com/hman0994/rh-copilot-runner/releases) [![Stars](https://img.shields.io/github/stars/hman0994/rh-copilot-runner?style=social)](https://github.com/hman0994/rh-copilot-runner/stargazers) [![Forks](https://img.shields.io/github/forks/hman0994/rh-copilot-runner?style=social)](https://github.com/hman0994/rh-copilot-runner/network/members) [![Issues](https://img.shields.io/github/issues/hman0994/rh-copilot-runner)](https://github.com/hman0994/rh-copilot-runner/issues) [![License](https://img.shields.io/github/license/hman0994/rh-copilot-runner)](https://github.com/hman0994/rh-copilot-runner/blob/main/LICENSE) [![Downloads](https://img.shields.io/github/downloads/hman0994/rh-copilot-runner/total)](https://github.com/hman0994/rh-copilot-runner/releases) [![ko-fi](https://img.shields.io/badge/ko--fi-buy_me_a_coffe-blue?logo=kofi&logoColor=white)](https://ko-fi.com/N6W822KKNQ)

> [!CAUTION]
> **This software can place real trades in a live brokerage account — autonomously, without confirmation prompts.**
> - It is configured with `--no-ask-user`, meaning the AI agent executes orders directly.
> - **Test exclusively with a paper/demo account or a throwaway account with only money you can afford to lose** until you fully understand every configuration option.
> - AI/LLM output is not reliable. The agent can misread market conditions, place incorrect orders, or fail silently.
> - See the [Legal Disclaimer](#legal-disclaimer) for the full risk disclosure.
> - See [CONTRIBUTING.md](CONTRIBUTING.md) before pushing any changes to avoid accidentally committing live session data.

A PowerShell-based task scheduler and prompt orchestrator for Copilot CLI in `-p` (prompt) mode. The runner automates recurring trading cycles by managing timing, scheduling, prompt composition, and CLI invocation—while trading decisions are made inside each Copilot session through the Robinhood MCP server.


## How It Works

The runner is a lightweight orchestrator that:
1. **Ticks** on a configurable interval (default: 1 second)
2. **Evaluates** schedule entries to see which prompts are due
3. **Invokes** Copilot CLI with the selected prompt and context
4. **Logs** execution details (exit code, duration, AI credit cost, next scheduled time)

All trading logic, account state management, and decision-making happens inside Copilot during each prompt execution, using the Robinhood MCP server for live account access.

## Prerequisites and Authentication Setup

Before running the scheduler you need:

1. **PowerShell 7.0+** — `winget install Microsoft.PowerShell` or download from [aka.ms/powershell](https://aka.ms/powershell).
2. **GitHub Copilot CLI** — Install via npm (`npm install -g @github/copilot`) or the GitHub CLI extension. Ensure `copilot` resolves in your `PATH`.
3. **A GitHub Copilot subscription** with access to the model(s) listed in `config/runner.config.json` (Pro, Pro+, Max, Business, or Enterprise — see the model table in the README).
4. **Robinhood Agentic Trading access** — The account must have Agentic Trading enabled. See [Robinhood's documentation](https://robinhood.com/us/en/support/articles/trading-with-your-agent/).

5. **Clone the repo and configure**:

   ```powershell
   git clone https://github.com/hman0994/rh-copilot-runner.git
   cd rh-copilot-runner
   ```
   ```
   Review and edit config/runner.config.json
   Review and edit example prompts within prompts/
   Adjust schedule, model, and thinking efforts to match your account and plan.
   ```
   ```
   pwsh -NoProfile -File .\runner.ps1 -Once -DryRun   # smoke test
   ```

   The `logs/` and `memory/` folders are created automatically by the runner and the Copilot agent on first run.
6. **Authenticate the Robinhood MCP server** with Copilot CLI:

   ```powershell
   # Open the workspace in VS Code or run the CLI once with the MCP config active.
   # Copilot CLI will prompt for OAuth authorization on first use of the robinhoodTrading tool.
   # The token is stored at: ~/.copilot/mcp-oauth-config/<server-url-hash>
   # It is NOT stored in this repo.
   copilot -p "What is my balance in robinhood? Use the robinhoodTrading MCP server." --allow-tool robinhoodTrading
   ```

   Follow the browser prompt to authorize the Robinhood connection. The OAuth token is stored locally outside the repo and is never committed.

> [!WARNING]
> **Never commit the `logs/` or `memory/` folders.** They contain live account numbers, positions, order history, and session data generated at runtime. Both folders are listed in `.gitignore`. If you accidentally stage them, run `git restore --staged logs/ memory/` before committing.

## How to Run

### Dry Run

Test the runner without executing any prompts. Pass `-Once` to exit after a single tick:

```powershell
# Single-tick check (load config, evaluate schedule, print result, exit):
pwsh -NoProfile -File .\runner.ps1 -Once -DryRun

# Continuous dry-run loop (ticks indefinitely, prints what would fire):
pwsh -NoProfile -File .\runner.ps1 -DryRun
```

### Run Once

Execute the next scheduled prompt (or start prompt if enabled) and exit:

```powershell
pwsh -NoProfile -File .\runner.ps1 -Once
```

### Continuous Mode

Run the scheduler indefinitely, executing prompts on their schedule:

```powershell
pwsh -NoProfile -File .\runner.ps1
```

Stop the process with **Ctrl+C**.

### On-Demand Account Close

Flatten all open positions and cancel open orders immediately, without the main runner loop running:

```powershell
pwsh -NoProfile -File .\closing.ps1
```

See [closing.ps1](closing.ps1) for `-Model`, `-Effort`, and `-DryRun` options.

## Project Structure

```
rh-copilot-runner/
├── runner.ps1                  # Main scheduler loop (PowerShell)
├── closing.ps1                 # On-demand account close (flatten all positions)
├── config/
│   └── runner.config.json      # Configuration file (JSON)
├── prompts/                    # Prompt templates (Markdown)
│   ├── opening_prompt.md       # Session startup (called once)
│   ├── premkt_loop_prompt.md   # Pre-market loop (recurring, 6:45–8:30 AM)
│   ├── trading_loop_prompt.md  # Main trading loop (recurring, 8:45 AM–3:00 PM)
│   ├── closing_prompt.md       # Session close (flatten account & finalize)
│   ├── daily_summary_prompt.md # End-of-day summary (daily at 4:00 PM)
│   ├── test_prompt.md          # One-off testing prompt
│   └── tool_robinhood_mcp.md   # MCP tool documentation
├── memory/                     # Local continuity files (created during sessions)
│   ├── session_memory.md
│   ├── session_plan.md
│   ├── watchlist.md
│   ├── results.md
│   └── summary.md
├── logs/                       # Execution logs and artifacts
│   ├── runner-YYYYMMDD.log
│   ├── latest-invocation.json
│   └── output-*.txt
└── README.md                   # This file
```

# Configuration (runner.config.json)

> [!TIP]
> 1. See [docs/models.md](docs/models.md) for the full model catalog, effort support per model, and availability by subscription plan.
> 2. For a description of each prompt file and what it reads/writes, see [docs/prompts.md](docs/prompts.md).

## Global Settings

```json
{
  "TickIntervalSeconds": 1,        // Scheduler loop interval in seconds (default: 1)
  "PromptsFolder": "prompts",      // Path to prompts directory (default: "prompts")
  "LogFolder": "logs",             // Path to logs directory (default: "logs")
  
  "StartPrompt": { ... },          // Optional: startup prompt (see below)
  "Schedule": [ ... ],             // Array: recurring scheduled prompts (see below)
  "CopilotCliConfig": { ... },     // Copilot CLI execution settings
  "Context": { ... }               // Context options
}
```

## StartPrompt (Top-Level, Optional)

The start prompt runs **exactly once** when the process starts. Use it for session initialization and continuity setup.

```json
{
  "StartPrompt": {
    "Enabled": true,                                    // Default: false
    "PromptFile": "opening_prompt.md",                  // Required if Enabled=true
    "PromptText": null,                                 // Optional: inline prompt text (if null, use PromptFile)
    "Model": "gpt-5.5",                                 // Optional: override CopilotCliConfig.Model
    "ThinkingEffort": "xhigh"                           // Optional: none|low|medium|high|xhigh|max
  }
}
```

## Schedule Entries (Recurring)

Schedule entries define recurring prompts. Two types are supported:

### Type 1: Interval (Every N Minutes)

Fires every `IntervalMinutes` within an optional time window and on selected days.

```json
{
  "Name": "trading-loop",                 // Unique identifier for logging
  "Enabled": true,                        // Default: false
  "Type": "interval",                     // Required: "interval"
  "IntervalMinutes": 5,                   // Required: repeat every N minutes
  "WindowStart": "08:45",                 // Optional: only fire at/after this time (HH:MM)
  "WindowEnd": "15:00",                   // Optional: only fire before this time (HH:MM)
  "Days": [                               // Optional: only fire on these weekdays
    "Monday", "Tuesday", "Wednesday", 
    "Thursday", "Friday"
  ],
  "PromptFile": "trading_loop_prompt.md", // Required: which prompt to use
  "Model": "gpt-5-mini",                  // Optional: override CopilotCliConfig.Model
  "ThinkingEffort": "high"                // Optional: none|low|medium|high|xhigh|max
}
```

**Defaults:**
- `WindowStart` and `WindowEnd`: If omitted, no time window (24/7 for interval type)
- `Days`: If omitted, all 7 days
- `Model` and `ThinkingEffort`: If omitted, use global `CopilotCliConfig` defaults

> [!NOTE]
> All times (`WindowStart`, `WindowEnd`, `Time`) are interpreted as **machine-local time**. Adjust values to match your local timezone — the runner does not convert across timezones.

### Type 2: Daily At (Once Per Day at Specific Time)

Fires once per day at or after a specified time, on selected days.

```json
{
  "Name": "daily-summary",                // Unique identifier
  "Enabled": true,                        // Default: false
  "Type": "daily-at",                     // Required: "daily-at"
  "Time": "16:00",                        // Required: fire at/after this time (HH:MM)
  "Days": [                               // Optional: only fire on these days
    "Monday", "Tuesday", "Wednesday", 
    "Thursday", "Friday"
  ],
  "PromptFile": "daily_summary_prompt.md",// Required: which prompt to use
  "Model": "gpt-5-mini",                  // Optional: override CopilotCliConfig.Model
  "ThinkingEffort": "high"                // Optional: none|low|medium|high|xhigh|max
}
```

**Defaults:**
- `Days`: If omitted, all 7 days
- `Model` and `ThinkingEffort`: If omitted, use global `CopilotCliConfig` defaults

## CopilotCliConfig (Execution Settings)

Controls how Copilot CLI is invoked.

```json
{
  "CopilotCliConfig": {
    "ExecutablePath": "copilot",          // Path to copilot CLI (default: "copilot")
    "BaseArguments": ["-p"],              // Always included (default: ["-p"])
    "Model": "gpt-5-mini",                // Default model for all prompts
    "ThinkingEffort": "medium",             // Default thinking effort
    "AdditionalArguments": [              // Extra CLI flags
      "--allow-tool", "robinhoodTrading",
      "--allow-tool", "read",
      "--allow-tool", "write",
      "--allow-tool", "web",
      "--allow-tool", "todo",
      "--no-ask-user"
    ],
    "WorkingDirectory": ".",              // CWD for CLI invocation (default: ".")
    "Environment": {}                     // Environment variables (empty by default)
  }
}
```
### Copilot CLI Models

See **[docs/models.md](docs/models.md)** for the full model catalog, effort level reference, availability by subscription plan, and long-context notes.

**Common Thinking Effort Values:**
- `none` — No extended thinking (fastest)
- `low` — Minimal thinking
- `medium` — Moderate thinking (default for fast loops)
- `high` — More extensive thinking (good for summaries)
- `xhigh` — Very extensive thinking (for complex planning)
- `max` — Maximum thinking effort

## Context (Optional)

```json
{
  "Context": {
    "IncludeRunnerContext": true,          // Include runner state in prompt context (default: true)
    "Pretext": [                          // Pretext to include
    "## Agentic Trading Session | rh-copilot-runner",
    ""
    ]
  }
}
```

# Example Prompt Responsibilities

Each prompt serves a distinct role in the session lifecycle. See **[docs/prompts.md](docs/prompts.md)** for the full reference, including responsibilities, schedule timing, files read/written, and MCP tool usage per prompt.

| Prompt file | Runs | Purpose |
|---|---|---|
| `opening_prompt.md` | Once at startup | Initialize continuity, research, and plan |
| `premkt_loop_prompt.md` | Every 30 min, 6:45–8:30 AM weekdays | Refine plan before market open |
| `trading_loop_prompt.md` | Every 5 min, 8:45 AM–3:00 PM weekdays | Execute trades and manage positions |
| `daily_summary_prompt.md` | Once daily at 4:00 PM weekdays | Log outcomes and carry-forward notes |
| `closing_prompt.md` | On-demand | Flatten account and finalize session |
| `test_prompt.md` | On-demand | Validate MCP connectivity and tooling |

# Local Session Files (memory/, logs/)

Both folders are generated at runtime and excluded by `.gitignore`. See **[docs/session-files.md](docs/session-files.md)** for a detailed description of each file, what the runner and agent write to them, and the full schema of `latest-invocation.json`.

# Tips and Best Practices

> [!TIP]
> 1. **Start with a dry run:** Test your config with `-DryRun` before enabling continuous mode.
> 2. **Use thinking effort strategically:**
>    - `xhigh` or `max` for opening/planning prompts
>    - `high` for summaries and decision points
>    - `medium` or `low` for fast-loop execution
> 3. **Keep schedule windows realistic:** Avoid overlapping windows for different prompt types (e.g., pre-market loop should end before trading loop starts).
> 4. **Monitor logs regularly:** Check `logs/runner-*.log` and `logs/latest-invocation.json` to track credit usage and execution status.
> 5. **Use local memory files for continuity:** The prompts rely on these files—do not delete them during an active session.
> 6. **Test prompts individually:** Use the `-Once` flag to execute a specific prompt before scheduling it.


# Legal Disclaimer

> [!IMPORTANT]
> **Not financial advice.** This project is an experimental software automation tool provided for educational and informational purposes only. It is not, and must not be construed as, financial, investment, trading, tax, legal, or other professional advice, nor a recommendation, solicitation, or offer to buy or sell any security, cryptocurrency, or other financial instrument.
>
> - The author is **not** a licensed financial advisor, broker-dealer, or investment professional, and no fiduciary or advisory relationship is created by using this software.
> - Trading and investing involve substantial risk, including the possible loss of all capital. Automated and AI-driven trading can amplify these risks and may execute unintended orders.
> - AI/LLM output can be inaccurate, incomplete, or wrong. Nothing produced by this tool or its prompts should be relied upon without independent verification.
> - You are solely responsible for any decisions and trades executed with this software. Test thoroughly in a non-live or paper environment before risking real funds.
> - Past performance does not guarantee future results. Consult a qualified, licensed professional before making financial decisions.
> - This project is **not affiliated with, endorsed by, or sponsored by** Robinhood Markets, Inc., GitHub, Inc., or Microsoft. "Robinhood", "GitHub", and "Copilot" are trademarks of their respective owners. Users must comply with Robinhood's Terms of Service and any applicable Agentic Trading terms.
>
> Use of this software is entirely **at your own risk**. See the warranty and liability disclaimers in the [LICENSE](LICENSE) file.

# License

> [!NOTE]
> This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.
>
> The MIT License is a permissive license that allows reuse, modification, and distribution, while providing the software "as is" without warranty of any kind and disclaiming liability for damages arising from its use.