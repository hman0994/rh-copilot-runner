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

# Prompt Responsibilities

Each prompt file in `prompts/` serves a distinct role in the session lifecycle. The runner selects and invokes them according to `config/runner.config.json`. All prompt files read from and write to the `memory/` folder to maintain continuity across loop cycles.

---

## 1. Opening Prompt (`opening_prompt.md`)

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

---

## 2. Pre-Market Loop Prompt (`premkt_loop_prompt.md`)

**Runs:** Every 30 minutes, 6:45 AM–8:30 AM, weekdays only  
**Purpose:** Prepare for market open and refine plan.

Responsibilities:
- Update account state and quote data via Robinhood MCP
- Refine triggers and watchlist based on overnight news, gaps, or overseas moves
- Prepare entry/exit checklist for market open

---

## 3. Trading Loop Prompt (`trading_loop_prompt.md`)

**Runs:** Every 5 minutes, 8:45 AM–3:00 PM, weekdays only  
**Purpose:** Execute trades and manage active positions.

Responsibilities:
- Check account state and current positions via Robinhood MCP
- Compare real prices and fills to the stored plan
- Decide: ACT (trade), HOLD (wait), DE-RISK (close/cancel), or PLAN-UPDATE (refine without trading)
- Update local files minimally with material changes
- Never improvise trades — only execute stored plans with fresh evidence

---

## 4. Daily Summary Prompt (`daily_summary_prompt.md`)

**Runs:** Once daily at 4:00 PM, weekdays only  
**Purpose:** Review and reflect on daily outcomes.

Responsibilities:
- Pull final account state via Robinhood MCP
- Summarize trades executed and outcomes
- Document lessons learned and carry-forward insights

---

## 5. Closing Prompt (`closing_prompt.md`)

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

---

## 6. Test Prompt (`test_prompt.md`)

**Runs:** On-demand for testing (not scheduled by default)  
**Purpose:** Validate setup and tooling.

Use this prompt to test Robinhood MCP connectivity, verify account access, or validate new trading ideas before scheduling them.

---

## 7. Robinhood MCP Tool Reference (`tool_robinhood_mcp.md`)

Not a runnable prompt — this is a reference document included in the `prompts/` folder so the Copilot agent can read it during sessions. It lists all available Robinhood MCP tools, practical usage flows for startup/loop/closing cycles, and order guidance for equities and options.
