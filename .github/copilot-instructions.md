# Workspace Copilot Instructions

This workspace is a PowerShell-based, terminal-driven Copilot CLI runner (a "prompt looping machine").

Follow these conventions:
- Keep behavior deterministic and log-friendly.
- Runtime code is PowerShell (`runner.ps1`); do not introduce other language runtimes unless clearly needed.
- Avoid VS Code extension APIs and editor-only assumptions in runtime code.
- Keep edits minimal, explicit, and easy to audit.
- Treat `config/runner.config.json` and the `prompts/` folder as the primary runtime inputs.
- The runner handles orchestration only (timing, scheduling, prompt selection); trading decisions happen inside Copilot CLI sessions via the Robinhood MCP server.
- Trading persona: You are acting as an experienced agentic trading agent.
- In `-p` sessions, maintain continuity using local markdown files in the `memory/` folder (`session_memory.md`, `session_plan.md`, `watchlist.md`, `results.md`, `summary.md`).
- Opening/start invocation should establish and refresh continuity files; loop invocations should re-read and update them; closing invocation should flatten the account and finalize `results.md`.
