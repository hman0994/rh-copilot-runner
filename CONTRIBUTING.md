# Contributing to rh-copilot-runner

Thanks for your interest in contributing. Before you open a PR, please read these guidelines.

## The Most Important Rule: Never Commit Runtime Data

The `logs/` and `memory/` directories are **excluded by `.gitignore`** for a critical reason:

> These folders contain live brokerage account numbers, positions, order history, session plans, and trade logs generated at runtime by the Copilot agent.

**Before every commit, verify:**

```powershell
git status        # logs/ and memory/ must NOT appear as staged or modified
git ls-files logs/ memory/   # must return empty
```

If either folder appears staged, unstage immediately:

```powershell
git restore --staged logs/ memory/
```

If they were already committed by mistake, remove them from tracking:

```powershell
git rm -r --cached logs/ memory/
git commit -m "Remove accidentally tracked runtime data"
```

Never push to a public remote while these folders are tracked. If account numbers or session data were committed, treat it as a **credential leak**: rewrite history (see `git filter-repo` or BFG Repo Cleaner), rotate any exposed identifiers at the brokerage, and open a security issue.

## Development Setup

See [Prerequisites and Authentication Setup](README.md#prerequisites-and-authentication-setup) in the README for the full setup steps.

```powershell
git clone https://github.com/hman0994/rh-copilot-runner.git
cd rh-copilot-runner
# Edit config/runner.config.json for your account and schedule
pwsh -NoProfile -File .\runner.ps1 -Once -DryRun   # smoke test without invoking Copilot CLI
```

## What to Contribute

- Bug fixes and robustness improvements to `runner.ps1`.
- New schedule types or config options with corresponding tests/validation.
- Improved prompt templates under `prompts/` (do not include personal account context).
- Documentation improvements to `README.md` or `prompts/tool_robinhood_mcp.md`.

## Pull Request Guidelines

1. Keep PRs focused. One logical change per PR.
2. Test locally with `-DryRun` before submitting.
3. Do not change `config/runner.config.json` (it is user-specific config, not a source file).
4. Do not include any file from `logs/` or `memory/` under any circumstances.
5. Do not include API keys, account numbers, tokens, or any personal financial data.

## Reporting Issues

Open a [GitHub Issue](https://github.com/hman0994/rh-copilot-runner/issues/new) for bugs, feature requests, or questions. For security concerns see [SECURITY.md](SECURITY.md).
