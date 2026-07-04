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

# Closing Prompt

This is end-of-session processing for a agentic trading account.

Primary requirement:
- Flatten the account for session close.

Do the following in order:

1. Pull current open positions and open orders with Robinhood MCP tools.
2. Cancel all open orders first, then close each open position. Prefer limit orders at or near the current bid/ask mark; fall back to market orders only if a limit order has no fill path and the position must be closed urgently. For options with wide spreads, use a limit near the mark and report any position that cannot be closed in `results.md` rather than chasing fills.
3. Re-check account state to confirm flat status.
4. Update `results.md` with a complete session summary section that includes:
- session start/end time
- starting and ending account snapshot from tool outputs
- orders/actions taken throughout the session (based on local files + tool state)
- realized outcomes and notable misses
- lessons and carry-forward notes for next session

Also update:
- `session_memory.md` with final state notes for next startup

Output requirements:
- Explicit confirmation whether account is flat.
- Summary of final actions taken during close.
- Confirmation that `results.md` was written/updated.

Hard rule:
- Never invent account state or execution outcomes.
