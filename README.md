# usagebar

See how much of your AI coding subscriptions you have used, and when each limit resets, from the
macOS menu bar. One small Python script (standard library only) plus a two-line
[SwiftBar](https://github.com/swiftbar/SwiftBar) plugin.

It covers:

- **Claude Code**: 5-hour and 7-day usage % for one or more Claude accounts (each with its own
  Claude Code login), plus local token totals.
- **Codex CLI**: the 5-hour and weekly rate-limit % that Codex writes to its own session logs, and
  your credit balance.
- **Grok CLI**: billing-period usage %, when the endpoint reports it.

The menu bar title shows the highest 5-hour % across accounts and the weekly % of your first Claude
account, for example `◔ 42% · wk 18%`. It turns orange at 75% and red at 90%. The menu has one block
per account, with a 10-cell bar per window: `5h ████░░░░░░ 42% used · 58% left · resets in 2h 31m`.

## Requirements

- macOS (Keychain lookup uses `/usr/bin/security`). The terminal and `--json` modes also run on
  Linux, reading `.credentials.json` instead of the Keychain.
- Python 3.9 or newer. The `python3` that ships with Apple's Command Line Tools works
  (`xcode-select --install`). No pip packages.
- [SwiftBar](https://github.com/swiftbar/SwiftBar) for the menu bar (`brew install --cask swiftbar`).
  Optional: the script also prints a terminal table and JSON.
- Logged in to whichever tools you want to track: Claude Code, Codex CLI, Grok CLI. Anything not
  installed is skipped.

## Install

```sh
git clone https://github.com/ShiftedReality12/usagebar.git
cd usagebar
mkdir -p ~/bin
cp bin/usage ~/bin/usage
~/bin/usage            # check it prints a table
```

Then add the plugin to your SwiftBar plugin folder (SwiftBar asks for one on first launch; find it
under SwiftBar's Preferences):

```sh
cp swiftbar/usage.15m.sh "<your SwiftBar plugin folder>/"
```

Pick **Refresh All** in SwiftBar's menu. The `15m` in the file name sets the refresh interval;
rename it (for example `usage.5m.sh`) to change it. If the script is not at `~/bin/usage`, set
`USAGEBAR_BIN` in the plugin or edit its last line.

## Configuration

Without a config file, usagebar tracks one Claude account in `~/.claude`, and Codex and Grok if
their local files exist. To track several Claude accounts, rename them, or turn a provider off,
create `~/.config/usagebar/config.json` (start from `config.example.json`):

```json
{
  "claude_accounts": [
    {"label": "Claude personal", "dir": "~/.claude"},
    {"label": "Claude work", "dir": "~/.claude-work", "color": "#2878B5"}
  ],
  "codex": "auto",
  "grok": "auto"
}
```

- `claude_accounts`: one entry per Claude Code config directory (the `CLAUDE_CONFIG_DIR` you log in
  with). `label` is shown in the menu; `color` (optional) is the block header color. The first entry
  supplies the weekly % in the title.
- `codex`, `grok`: `"auto"` (on if the local files exist), `true`, or `false`.

Environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `USAGEBAR_CONFIG` | `~/.config/usagebar/config.json` | Config file path |
| `USAGEBAR_CACHE` | `~/.cache/usagebar` | Where results are cached |
| `CODEX_HOME` | `~/.codex` | Codex data directory |
| `USAGEBAR_BIN` | `~/bin/usage` | Script path used by the SwiftBar plugin |

## Usage

```sh
usage              # terminal table
usage --json       # JSON: used_pct, left_pct and resets_at per window
usage --swiftbar   # SwiftBar menu text (what the plugin runs)
```

## How it works

| Provider | Source | Network |
| --- | --- | --- |
| Claude | Reads the account's existing Claude Code OAuth token (Keychain item `Claude Code-credentials`, or `.credentials.json` in the config dir) in memory and calls `GET https://api.anthropic.com/api/oauth/usage`. Token totals come from the local `projects/**/*.jsonl` logs. | One request per account per 15 min |
| Codex | Reads the latest `rate_limits` event from `$CODEX_HOME/sessions/**/*.jsonl`. | None |
| Grok | Reads the token in `~/.grok/auth.json` and calls `GET https://cli-chat-proxy.grok.com/v1/billing` (the same endpoint CodexBar uses). | One request per 15 min |

Only results (percentages and reset times) are cached, in `~/.cache/usagebar/`, for 15 minutes.
Tokens are never written to disk, logged, or refreshed. An expired token shows `login needed`;
run the provider's CLI once to log in again. usagebar installs no hooks and changes no settings
in Claude Code, Codex or Grok.

## Compared with CodexBar

[CodexBar](https://github.com/steipete/CodexBar) (MIT) is the full-featured option: a native app
with many more providers, charts, cost tracking and settings UI. usagebar does much less: three
providers, no UI beyond the menu. In exchange it is much lighter.

Measured on 2026-10-20, 13:22 to 13:27 PDT, MacBook Pro (Apple M5, 16 GB), macOS 26.2, CodexBar
0.62.0 with its existing settings on that Mac, SwiftBar 2.1.1, and usagebar at this commit configured
for 5 Claude accounts, Codex and Grok:

| | usagebar + SwiftBar | CodexBar 0.62.0 |
| --- | --- | --- |
| Size on disk (`du -sh`) | script 16 KB + SwiftBar.app 7.1 MB | CodexBar.app 169 MB |
| Resident between refreshes | SwiftBar only: 12 to 31 MB RSS (`ps`), 25 MB (`top` MEM) | 34 to 383 MB RSS (`ps`), 214 to 781 MB (`top` MEM) |
| CPU between refreshes | 0.0% in every sample; 0.02 s CPU time in 4.7 min | 0 to 156% per sample; 145.5 s CPU time in its first 4 min 40 s (about 52% of one core on average) |
| Cost of one refresh | usagebar runs for 0.13 to 0.16 s (cached) or 2.3 s (network), peak RSS 18 to 23 MB, then exits | n/a (stays resident) |
| Third-party dependencies | none (Python standard library); SwiftBar bundles Sparkle | Sparkle.framework, plus 2 helper executables (CodexBarCLI, CodexBarClaudeWatchdog) |
| Minimum macOS | SwiftBar: 12.0 (`LSMinimumSystemVersion` in its Info.plist) | 14 (published in CodexBar's README; same in its Info.plist) |

Method: CodexBar was not running before the test. It was started with `open -g -a CodexBar`, then
`ps -o rss,%cpu` was sampled every 5 s for 60 s after a 30 s warm-up, and `top -l 13 -s 5 -stats
cpu,mem` for 65 s starting 2.5 min after launch; CPU time is from `ps -o cputime`. SwiftBar had been
running for about 24 h and was sampled at the same times. usagebar per-refresh numbers are from
`/usr/bin/time -l usage --swiftbar` (one cold run, three cached runs). Caveat: CodexBar was measured
only in its first 5 minutes, which may include start-up scanning; its long-run steady state was not
measured.

## Limitations

- The Claude usage endpoint (`/api/oauth/usage`) and the Grok billing endpoint are undocumented and
  can change or break without notice. usagebar sends a Claude Code-style `User-Agent` because the
  endpoint expects Claude Code's OAuth client.
- Codex numbers are only as fresh as your last Codex session; usagebar never calls OpenAI.
- Claude team seats usually report only a 5-hour window, so their blocks show one bar.
- Grok shows `usage % not reported` when the billing response has no percentage.
- Claude token totals count input, output and cache-write tokens; cache reads are left out.
- Tested on macOS 26 (Apple silicon) with Apple's Python 3.9.6, and the terminal/JSON modes on Linux
  with Python 3.13. Not tested on Intel Macs.

## License

MIT, see [LICENSE](LICENSE).
