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

# Copilot CLI Model Reference

Model availability changes often. This document was last checked against GitHub's Copilot model docs and the installed local CLI (`GitHub Copilot CLI 1.0.68`) on 2026-07-03.

Configure models in `config/runner.config.json` using either the global `CopilotCliConfig.Model` default or a per-entry `Model` override. Per-entry values take precedence.

---

## Thinking Effort Levels

The `--effort` flag controls how much reasoning the model applies before responding. Set it globally via `CopilotCliConfig.ThinkingEffort` or per schedule entry via `ThinkingEffort`.

| Effort level | Use when |
|---|---|
| `none` | Lowest latency and lowest reasoning overhead |
| `low` | Simple checks, small edits, fast recurring loops |
| `medium` | Default for ordinary loop prompts |
| `high` | Planning, summaries, multi-step decisions |
| `xhigh` | Heavier planning and complex debugging |
| `max` | Highest reasoning spend for the hardest sessions |

---

## Model Catalog

Free and Student users have access to models through `auto` model selection only. Named model selection requires one of the paid plans shown below, and organization or enterprise admins can further restrict available models.

| Config value | Model name | Provider | Status | Minimum plan / availability | Configurable effort |
|---|---|---|---|---|---|
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

---

## Notes

- `gpt-5.4 nano`, `gemini-2.5-pro`, `gemini-3-flash`, and `raptor-mini` appear in GitHub's broader Copilot model catalog, but GitHub's client table does not list them as Copilot CLI models.
- Long context can be selected with `--context long_context` or `ContextTier` if the runner later adds that setting. GitHub currently documents long-context support for `claude-sonnet-4.6`, `claude-opus-4.6`, `claude-opus-4.7`, `claude-opus-4.8`, `claude-sonnet-5`, `claude-fable-5`, `gpt-5.3-codex`, `gpt-5.4`, and `gpt-5.5`; `claude-opus-4.8-fast` supports configurable reasoning but not long context.
- Model interactions consume GitHub AI Credits based on model and token usage. Individual monthly allowances are currently 1,500 credits for Copilot Pro, 7,000 for Pro+, and 20,000 for Max; Free and Student also include allowances but only expose named models through auto selection.
