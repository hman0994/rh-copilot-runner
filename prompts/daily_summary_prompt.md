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

# Daily Summary Prompt

You are running the end-of-day summary cycle for a small Robinhood trading account. This prompt is for logging and review, not broad replanning.

Refer to `prompts\tool_robinhood_mcp.md` for Robinhood MCP tools. Use MCP as the source of truth for account state, positions, orders, fills, and balances. Use local markdown files in `memory\` for continuity and session history.

Primary output target:
- Create or update `memory\summary.md` as the durable daily summary log.

Before writing the summary, review only the relevant local files if they exist:
- `memory\session_memory.md`
- `memory\session_plan.md`
- `memory\watchlist.md`
- `memory\results.md`
- `memory\summary.md`

Execution steps:

1. Pull final account state through Robinhood MCP:
- cash / buying power
- open positions
- open orders
- filled, canceled, or rejected orders available from today's session
- account restrictions or risk flags if tools expose them

2. Reconcile the day:
- Compare the final MCP account/order state against today's local cycle logs.
- Identify what was actually traded, held, canceled, or avoided.
- Separate verified outcomes from unknowns.
- Do not infer fills, P/L, prices, or balances unless tool/file evidence provides them.

3. Update `memory\summary.md`:
Append a new dated section for the current session with:
- date/time and session label
- final account snapshot based only on MCP output
- actions taken, including trades, order changes, watchlist/screener changes, or explicit no-action
- plan vs actual: which planned triggers fired, failed, or remained pending
- notable market context that affected decisions
- lessons learned / rule adjustments for future sessions
- open questions or unknowns
- carry-forward checklist for the next opening or premarket cycle

Output requirements:
- State that `memory\summary.md` was created or updated.
- Provide the final account snapshot based only on MCP output.
- List verified actions taken or explicitly say no verified trading action.
- List unresolved unknowns.
- End with the carry-forward checklist for the next session.

Hard rule:
- Do not invent prices, balances, fills, order states, P/L, or market data. If evidence is unavailable, write `unknown` and explain what tool/file would be needed to verify it.
