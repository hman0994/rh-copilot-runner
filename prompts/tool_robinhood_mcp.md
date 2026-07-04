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

# Robinhood MCP Tool Reference

Purpose: quick orientation for prompts that use the Robinhood MCP server in this workspace.
Source: https://robinhood.com/us/en/support/articles/trading-with-your-agent/
Last updated: 2026-07-03

## Important Notes

- Tool availability can change over time as Robinhood updates Agentic Trading.
- You are responsible for orders placed by the agent.
- Prefer read/review tools before place/cancel tools.
- Do not invent account state, prices, fills, or order status.

## Practical Flow By Cycle

Startup / Opening cycle:
1. get_accounts
2. get_portfolio
3. get_equity_positions
4. get_option_positions
5. get_equity_orders and get_option_orders (recent activity)
6. Optional market research tools (historicals, fundamentals, indicators, earnings)

Loop cycle:
1. Refresh account and positions (get_portfolio, get_equity_positions, get_option_positions)
2. Pull watchlist and market context (watchlist + market data tools)
3. Use review_*_order before any place_*_order
4. Record outcomes in local continuity files

Closing cycle:
1. Inspect open orders/positions
2. Cancel open orders as needed (cancel_equity_order, cancel_option_order)
3. Flatten remaining positions with explicit orders if required
4. Re-check account and record final results

## Full Tool Catalog

### Account, Portfolio, and Other

- get_accounts: View all Robinhood accounts.
- get_portfolio: Portfolio snapshot (total value, asset class values, real-time buying power).
- get_realized_pnl: Realized PnL over a custom window by asset class.
- search: Resolve company name/partial name to ticker.

### Watchlist

- get_watchlists: List user watchlists.
- get_watchlist_items: List symbols in a watchlist.
- get_option_watchlist: Load options watchlist.
- get_popular_watchlists: Discover Robinhood lists.
- create_watchlist: Create a custom watchlist.
- update_watchlist: Rename or update watchlist metadata.
- follow_watchlist: Follow a Robinhood list.
- unfollow_watchlist: Unfollow a Robinhood list.
- add_to_watchlist: Add stocks, crypto, or indexes.
- remove_from_watchlist: Remove stocks, crypto, or indexes.
- add_option_to_watchlist: Add an options contract.
- remove_option_from_watchlist: Remove an options contract.

### Market Data

- get_equity_historicals: OHLCV bars over a time range.
- get_equity_fundamentals: Valuation and company market data.
- get_equity_technical_indicators: Compute indicators (RSI, MACD, Bollinger, moving averages, etc.).
- get_earnings_results: Recent/upcoming earnings and EPS estimates for a symbol.
- get_earnings_calendar: Market-wide earnings schedule over a date window.
- get_indexes: Lookup market indexes by symbol.
- get_index_quotes: Real-time index values.

### Equities Trading

Agentic accounts currently support long equity orders only. Treat `get_equity_tradability` as the quick eligibility gate, then use `review_equity_order` as the source of truth for what the broker will actually accept for the specific symbol, quantity, and order shape. Cached review results for this account show these equity order types as accepted: market, limit, stop_market, and stop_limit. Do not assume every advanced retail order type is available just because a normal brokerage ticket might offer it; if the review call rejects or narrows the request, follow that result. After placement, confirm what actually happened with `get_equity_orders` and `get_equity_positions`.

- get_equity_positions: Open equity positions with quantity and cost basis.
- get_equity_quotes: Real-time quotes and prior close (up to 20 symbols).
- get_equity_orders: Equity order history/status.
- get_equity_tradability: Tradability and fractional eligibility.
- review_equity_order: Pre-trade simulation, order validation, and warnings before any placement.
- place_equity_order: Place a long equity order only after the review step passes.
- cancel_equity_order: Cancel an open equity order.

Practical order guidance:
- Market orders prioritize execution speed and price certainty is lowest.
- Limit orders cap the worst acceptable price and are the safest default when you care about execution price.
- stop_market orders trigger a market-style exit or entry once the stop is hit.
- stop_limit orders add a price cap/floor after the stop triggers, which can avoid a bad fill but may not fill at all.
- The current review call rejected trailing-style equity orders, so treat them as unsupported unless a future review says otherwise.
- Use the review response to learn which order form is supported for the current ticket.
- Prefer simple, explicit instructions over assuming an advanced order will be accepted.
- Re-query orders and positions after placing or canceling so the agent does not operate on stale state.

### Options Trading

Agentic accounts currently support long options orders only. Use the contract tools to identify a specific instrument, then rely on `review_option_order` to validate whether the requested trade structure is allowed for the account and market conditions. Cached review results for this account show these option order types as accepted on a representative single-leg contract: market, limit, stop_market, and stop_limit. The review response is the place to look for supported order structure, warnings, and any limits on leg count or contract details; do not assume spreads, rolls, or other multi-leg strategies are available unless the broker explicitly accepts them.

- get_option_level_upgrade_info: Link/info to apply for options access.
- get_option_chains: Load option chains.
- get_option_instruments: Filter contracts by expiry/strike/type.
- get_option_quotes: Real-time option quotes.
- get_option_positions: Open/closed option positions.
- get_option_orders: Options order history/status.
- review_option_order: Pre-trade simulation, contract validation, and alerts before any placement.
- cancel_option_order: Cancel an open options order.
- place_option_order: Place a long options order only after the review step passes.

Practical order guidance:
- Market orders on options trade faster but can move through wide spreads.
- Limit orders are usually the safer default for options because they put a hard bound on the fill price.
- stop_market and stop_limit are only suitable if the broker review explicitly permits them for the specific contract and account.
- Select the exact contract first, then review the order before placing it.
- Treat the review output as the broker-approved contract and order-shape check.
- Re-query orders and positions after placing or canceling so the agent reflects actual account state.

### Scanner

- get_scans: List saved scans.
- create_scan: Create scan with filters and preset.
- run_scan: Run saved scan for live results.
- update_scan_filters: Change filters on an existing scan.
- update_scan_config: Change result sorting/configuration.

## Prompt Authoring Shortcuts

- For account snapshot tasks, start with: get_accounts, get_portfolio, get_equity_positions, get_option_positions.
- For idea generation, combine: get_scans + create_scan + run_scan + create_watchlist + update_watchlist + get_watchlist_items + get_equity_historicals + get_equity_technical_indicators.
- Before placing orders, always call review_equity_order or review_option_order first.
- After placing/canceling, re-query orders and positions to confirm actual state.
