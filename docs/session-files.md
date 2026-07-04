<!--
Copyright (c) 2026 hman0994
Licensed under the MIT License.

NOT FINANCIAL ADVICE. This project is an experimental software automation tool
provided for educational and informational purposes only. It is not, and must
not be construed as, financial, investment, trading, tax, legal, or other
professional advice, nor a recommendation, solicitation, or offer to buy or
sell any security, cryptocurrency, or other financial instrument. The author is
not a licensed financial advisor, broker-dealer, or investment professional.
Trading and investing involve substantial risk, including the possible loss of
all capital; automated and AI-driven trading can amplify these risks and may
execute unintended orders. AI/LLM output can be inaccurate, incomplete, or wrong
and should not be relied upon without independent verification. You are solely
responsible for any decisions and trades executed with this software.
-->

# Local Session Files (`memory/`, `logs/`)

Both folders are generated at runtime and are **excluded by `.gitignore`**. They are never committed to the repo. Do not delete `memory/` files during an active session — prompts depend on them for continuity.

---

## `memory/`

Markdown files created and maintained by prompts during a trading session. They carry state across loop cycles so later invocations do not repeat research already done.

### `session_memory.md`

Cross-cycle context and account state. Updated by the opening, trading loop, and closing prompts.

- Account snapshot (cash, positions, buying power, restrictions)
- Session start time and key assumptions
- Overnight market context (gaps, news, macro events)
- MCP tools used and what each call changed
- Material changes flagged by each trading loop cycle

### `session_plan.md`

The main decision-ready trading plan. Built by the opening prompt and refined during trading loops.

- Ranked candidate setups with thesis, entry triggers, invalidation conditions, sizing, and exit rules
- No-trade conditions (when to hold fire)
- Asset class comparison (equities vs. options vs. crypto vs. cash)
- Order tactics and preferred order types
- Explicit evidence and exclusion reasoning

### `watchlist.md`

Ranked set of tradable candidates. Built by the opening prompt and updated during loops.

- Symbol, asset class, current price context, thesis (1–2 sentences)
- Entry trigger and invalidation
- Position size and holding period expectation
- Robinhood watchlist/screener placement (for quick MCP reference)
- Why candidates are included or explicitly rejected

### `results.md`

Session outcomes and reflection. Updated throughout the session; finalized at close.

- Timestamped cycle log (decision, action, evidence for each loop)
- Final session summary (start/end time, starting/ending account, all trades, realized outcomes, lessons)

### `summary.md`

Durable daily summary log written by the daily summary prompt (`daily_summary_prompt.md`). New dated sections are appended each session.

- Final MCP account snapshot for the day
- Actions taken and plan vs. actual comparison
- Notable market context affecting decisions
- Lessons and carry-forward checklist for the next session

---

## `logs/`

Created by the runner at startup. Contains raw execution artifacts from each Copilot CLI invocation.

> [!WARNING]
> Log files can contain live account numbers and raw MCP API responses captured from Copilot CLI output. Keep `logs/` gitignored at all times.

### `runner-YYYYMMDD.log`

Timestamped plain-text log of all scheduler activity: startup, each prompt invocation, exit codes, durations, AI credit costs, and next scheduled time.

### `latest-invocation.json`

JSON snapshot of the most recent Copilot CLI invocation. Fields include:

| Field | Description |
|---|---|
| `entry` | Schedule entry name that fired |
| `startedAt` / `endedAt` | ISO 8601 timestamps |
| `durationSeconds` | Wall-clock execution time |
| `exitCode` | Copilot CLI exit code (`0` = success) |
| `dryRun` | `true` if invoked with `-DryRun` |
| `commandPreview` | Truncated CLI argument preview |
| `promptChars` | Total character count of the assembled prompt |
| `aiCredits` | AI credits consumed (parsed from CLI output) |
| `nextScheduled` | Name and fire time of the next scheduled entry |
| `outputFile` | Path to the corresponding `output-*.txt` file |
| `outputTail` | Last 4,000 characters of CLI output |

### `output-YYYYMMDD-HHmmss-<name>.txt`

Raw stdout/stderr captured from each Copilot CLI invocation. Useful for debugging prompt behaviour, reviewing MCP tool calls made by the agent, and auditing what actions were taken during a session.
