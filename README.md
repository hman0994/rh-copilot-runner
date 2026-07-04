# rh-copilot-runner

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
2. **GitHub Copilot CLI** — Install via npm (`npm install -g @githubnext/github-copilot-cli`) or the GitHub CLI extension. Ensure `copilot` resolves in your `PATH`.
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

### Dry Run (Test Once)

Test the scheduler without executing any prompts and exit after one cycle:

```powershell
pwsh -NoProfile -File .\runner.ps1 -Once -DryRun
```

This will:
- Load the config
- Check which prompts are due
- Print the next scheduled prompt
- Exit without invoking Copilot CLI

### Dry Run

Test the runner without executing any prompts:

```powershell
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

## Project Structure

```
rh-copilot-runner/
├── runner.ps1                  # Main scheduler loop (PowerShell)
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
│   └── results.md
├── logs/                       # Execution logs and artifacts
│   ├── runner-YYYYMMDD.log
│   ├── latest-invocation.json
│   └── output-*.txt
└── README.md                   # This file
```

# Configuration (runner.config.json)

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

Each prompt has a clear role in the trading lifecycle:

### 1. Opening Prompt (`opening_prompt.md`)
**Runs:** Once, at session startup (if `StartPrompt.Enabled = true`)  
**Purpose:** Initialize session continuity and planning.

Responsibilities:
- Pull fresh account snapshot via Robinhood MCP (cash, positions, orders, restrictions)
- Build discovery surfaces (Robinhood watchlists, screeners for candidates across asset classes)
- Create/refresh local session files:
  - `memory/session_memory.md` (cross-cycle context)
  - `memory/session_plan.md` (comprehensive, decision-ready plan)
  - `memory/watchlist.md` (ranked candidates with thesis and evidence)
  - `memory/results.md` (initialized, not finalized yet)
- Research current market conditions (price action, macro events, catalysts, regime assessment)
- Compare candidate opportunities across equities, ETFs, options, crypto, and cash

### 2. Pre-Market Loop Prompt (`premkt_loop_prompt.md`)
**Runs:** Every 30 minutes, 6:45 AM–8:30 AM, weekdays only  
**Purpose:** Prepare for market open and refine plan.

Responsibilities:
- Update account state and quote data via Robinhood MCP
- Refine triggers and watchlist based on overnight news, gaps, or overseas moves
- Prepare entry/exit checklist for market open

### 3. Trading Loop Prompt (`trading_loop_prompt.md`)
**Runs:** Every 5 minutes, 8:45 AM–3:00 PM, weekdays only  
**Purpose:** Execute trades and manage active positions.

Responsibilities:
- Check account state and current positions via Robinhood MCP
- Compare real prices and fills to the stored plan
- Decide: ACT (trade), HOLD (wait), DE-RISK (close/cancel), or PLAN-UPDATE (refine without trading)
- Update local files minimally with material changes
- Never improvise trades—only execute stored plans with fresh evidence

### 4. Daily Summary Prompt (`daily_summary_prompt.md`)
**Runs:** Once daily at 4:00 PM, weekdays only  
**Purpose:** Review and reflect on daily outcomes.

Responsibilities:
- Pull final account state via Robinhood MCP
- Summarize trades executed and outcomes
- Document lessons learned and carry-forward insights

### 5. Closing Prompt (`closing_prompt.md`)
**Runs:** On-demand or end-of-session (not scheduled by default)  
**Purpose:** Flatten the account and finalize session.

Responsibilities:
- Close all open positions via Robinhood MCP
- Cancel all open orders
- Confirm flat account state
- Write complete session summary to `memory/results.md` with:
  - Session start/end times
  - Starting and ending account snapshots
  - All orders and actions taken
  - Realized outcomes and lessons
- Update `memory/session_memory.md` with final state notes for next startup

### 6. Test Prompt (`test_prompt.md`)
**Runs:** On-demand for testing (not scheduled by default)  
**Purpose:** Validate setup and tooling.

Use this prompt to test Robinhood MCP connectivity, verify account access, or validate new trading ideas before scheduling them.

# Local Session Files (memory/, logs/)

## Memory/

These markdown files are created and maintained by prompts during a trading session. They preserve continuity across loop iterations.

### `session_memory.md`
Cross-cycle context and account state. Updated by opening, trading, and closing prompts.
- Account snapshot (cash, positions, buying power, restrictions)
- Session start time and key assumptions
- Overnight market context (gaps, news, macro events)
- Material changes flagged by each trading loop

### `session_plan.md`
The main decision-ready trading plan. Updated by opening prompt and refined during trading loops.
- Candidate watchlist with thesis, entry triggers, invalidation conditions, sizing, and exit rules
- No-trade conditions (when to hold fire)
- Asset class comparison (equities vs. options vs. crypto vs. cash)
- Explicit evidence and exclusion reasoning

### `watchlist.md`
Ranked set of tradable candidates. Updated by opening prompt and refined during loops.
- Symbol, current price, thesis (1–2 sentences)
- Entry trigger and invalidation
- Position size and holding period expectation
- Robinhood watchlist/screener placement (for quick MCP reference)
- Why candidates are included or explicitly rejected

### `results.md`
Session outcomes and reflection. Updated throughout the session and finalized at close.
- Timestamped cycle log (decision, action, evidence for each loop)
- Final session summary (start/end time, starting/ending account, all trades, realized outcomes, lessons)

## Logs/

The runner creates detailed logs in the `logs/` folder:

- **runner-YYYYMMDD.log** — Timestamped log of all scheduler ticks, prompt executions, and outcomes
- **latest-invocation.json** — JSON snapshot of the most recent Copilot CLI invocation (args, exit code, duration, credits used)
- **output-*.txt** — Raw stdout/stderr from each Copilot CLI invocation

Review logs to troubleshoot scheduling issues, verify prompt execution, and track AI credit usage.

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

## Copilot CLI Models

Model availability changes often. This section was checked against GitHub's current Copilot model docs and the installed local CLI (`GitHub Copilot CLI 1.0.68`) on 2026-07-03.

Configure models in `runner.config.json` with either the global `CopilotCliConfig.Model` default or a per-prompt `Model` override.

The configuration accepts `--model <model>` and `--effort <level>` values:

| Effort level | Use when |
| --- | --- |
| `none` | Lowest latency and lowest reasoning overhead |
| `low` | Simple checks, small edits, fast recurring loops |
| `medium` | Default for ordinary loop prompts |
| `high` | Planning, summaries, multi-step decisions |
| `xhigh` | Heavier planning and complex debugging |
| `max` | Highest reasoning spend for the hardest sessions |

### CLI Model Catalog

Free and Student users have access to models through `auto` model selection only. Named model selection requires one of the paid plans shown below, and organization or enterprise admins can further restrict available models.

| Config value | Model name | Provider | Status | Minimum plan / availability | Configurable effort |
| --- | --- | --- | --- | --- | --- |
| `auto` | Auto model selection | GitHub routing | GA for Copilot CLI | Available subject to subscription and policy; paid plans receive a 10% model-cost discount for auto selection | Use CLI `--effort` only when the routed model supports it |
| `claude-haiku-4.5` | Claude Haiku 4.5 | Anthropic | GA | Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |
| `claude-opus-4.5` | Claude Opus 4.5 | Anthropic | GA | Copilot Business or Enterprise | Not documented as configurable |
| `claude-opus-4.6` | Claude Opus 4.6 | Anthropic | GA | Copilot Business or Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `claude-opus-4.7` | Claude Opus 4.7 | Anthropic | GA | Copilot Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `claude-opus-4.8` | Claude Opus 4.8 | Anthropic | GA | Copilot Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `claude-opus-4.8-fast` | Claude Opus 4.8 fast mode preview | Anthropic | GA model, preview fast mode | Copilot Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `claude-fable-5` | Claude Fable 5 | Anthropic | GA | Copilot Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `claude-sonnet-4.5` | Claude Sonnet 4.5 | Anthropic | GA | Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |
| `claude-sonnet-4.6` | Claude Sonnet 4.6 | Anthropic | GA | Copilot Pro, Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `claude-sonnet-5` | Claude Sonnet 5 | Anthropic | GA | Copilot Pro, Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `gpt-5-mini` | GPT-5 mini | OpenAI | GA | Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |
| `gpt-5.3-codex` | GPT-5.3-Codex | OpenAI | GA | Copilot Pro, Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `gpt-5.4` | GPT-5.4 | OpenAI | GA | Copilot Pro, Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `gpt-5.4-mini` | GPT-5.4 mini | OpenAI | GA | Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |
| `gpt-5.5` | GPT-5.5 | OpenAI | GA | Copilot Pro+, Max, Business, Enterprise | `none`, `low`, `medium`, `high`, `xhigh`, `max` |
| `gemini-3.1-pro-preview` | Gemini 3.1 Pro | Google | Public preview | Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |
| `gemini-3.5-flash` | Gemini 3.5 Flash | Google | GA | Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |
| `kimi-k2.7-code` | Kimi-K2.7-Code | Moonshot AI | GA | Copilot Pro, Pro+, Max | Not documented as configurable |
| Not listed by local CLI 1.0.68 help | MAI-Code-1-Flash | Microsoft | GA | GitHub Docs list it as Copilot CLI supported for Copilot Pro, Pro+, Max, Business, Enterprise | Not documented as configurable |

### Notes:
- `gpt-5.4 nano`, `gemini-2.5-pro`, `gemini-3-flash`, and `raptor-mini` appear in GitHub's broader Copilot model catalog, but GitHub's client table does not list them as Copilot CLI models.
- Long context can be selected with `--context long_context` or `ContextTier` if the runner later adds that setting. GitHub currently documents long-context support for `claude-sonnet-4.6`, `claude-opus-4.6`, `claude-opus-4.7`, `claude-opus-4.8`, `claude-sonnet-5`, `claude-fable-5`, `gpt-5.3-codex`, `gpt-5.4`, and `gpt-5.5`; `claude-opus-4.8-fast` supports configurable reasoning but not long context.
- Model interactions consume GitHub AI Credits based on model and token usage. Individual monthly allowances are currently 1,500 credits for Copilot Pro, 7,000 for Pro+, and 20,000 for Max; Free and Student also include allowances but only expose named models through auto selection.

# Legal Disclaimer

> [!IMPORTANT]
> **Not financial advice.** This project is an experimental software automation tool provided for educational and informational purposes only. It is not, and must not be construed as, financial, investment, trading, tax, legal, or other professional advice, nor a recommendation, solicitation, or offer to buy or sell any security, cryptocurrency, or other financial instrument.
>
> - The author is **not** a licensed financial advisor, broker-dealer, or investment professional, and no fiduciary or advisory relationship is created by using this software.
> - Trading and investing involve substantial risk, including the possible loss of all capital. Automated and AI-driven trading can amplify these risks and may execute unintended orders.
> - AI/LLM output can be inaccurate, incomplete, or wrong. Nothing produced by this tool or its prompts should be relied upon without independent verification.
> - You are solely responsible for any decisions and trades executed with this software. Test thoroughly in a non-live or paper environment before risking real funds.
> - Past performance does not guarantee future results. Consult a qualified, licensed professional before making financial decisions.
>
> Use of this software is entirely **at your own risk**. See the warranty and liability disclaimers in the [MIT License](https://tlo.mit.edu/understand-ip/exploring-mit-open-source-license-comprehensive-guide) and the [LICENSE](LICENSE) file.

# License

> [!NOTE]
> This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.
>
> The MIT License is a permissive license that allows reuse, modification, and distribution, while providing the software "as is" without warranty of any kind and disclaiming liability for damages arising from its use.