# Security Policy

## Reporting a Vulnerability

If you discover a security issue in this project — including anything that could expose credentials, enable unauthorized trade execution, or bypass intended safety controls — **please open a [GitHub Issue](https://github.com/hman0994/rh-copilot-runner/issues/new)** with the label `security`.

For issues that are particularly sensitive (e.g., a vulnerability that could be actively exploited before a fix is available), note in the issue that you would prefer to discuss details privately, and we will respond to coordinate disclosure.

**Please do not include real account numbers, tokens, or credentials in any issue or pull request.**

## Scope

This project is a local orchestration tool. The primary security concerns are:

- Unintended autonomous order placement via misconfiguration or prompt injection.
- Accidental exposure of brokerage account data through committed `logs/` or `memory/` files.
- Supply-chain or dependency tampering with the `copilot` CLI binary or the Robinhood MCP server.

Out of scope: vulnerabilities in Robinhood's own platform, GitHub Copilot, or the host OS.

## Safe Use Reminders

- Never commit `logs/` or `memory/` — they contain live account and session data.
- The `--no-ask-user` flag enables fully autonomous order execution. Test with paper accounts first.
- Review the [Legal Disclaimer](README.md#legal-disclaimer) before using this software.
