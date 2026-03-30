# ccusage

A lightweight macOS menu bar app that shows your Claude Code API usage at a glance.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-green)

## Features

- **Menu bar indicator** with colored dot (green → blue → orange → red) and usage percentage
- **Click to expand** a popover showing:
  - Current 5-hour session usage
  - Weekly usage (all models, Sonnet, Opus)
  - Reset timers for each bucket
  - Today's message & session count
  - All-time message count
- Auto-refreshes every 60 seconds
- No dock icon, runs quietly in the background

## Prerequisites

- macOS 13+ (Apple Silicon)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and logged in (the app reads your credentials from Keychain)

## Install

### Option 1: Download the app

Grab `ccusage.app.zip` from the [latest release](https://github.com/andropar/ccusage/releases), unzip it, drop `ccusage.app` into `/Applications`, and open it. On first launch, right-click → Open to bypass Gatekeeper (the app is unsigned).

### Option 2: Build from source

```bash
git clone https://github.com/andropar/ccusage.git
cd ccusage
./build.sh
```

This creates `ccusage.app` in the repo root. Move it to `/Applications` or run it directly.

## How it works

The app reads your Claude Code OAuth token from the macOS Keychain and queries the [Anthropic usage API](https://api.anthropic.com/api/oauth/usage) for rate limit data. Local stats (today's messages, session count, all-time totals) are parsed from `~/.claude/` session files and stats cache.

## Security & privacy

This app reads your Claude Code OAuth token from the macOS Keychain — so it's fair to ask whether it's safe to use.

- **The code is fully open source** — you can audit every line
- **Release binaries are built by GitHub Actions**, not on a developer's machine. The [workflow](.github/workflows/release.yml) runs `./build.sh` on GitHub's macOS runners, so you can verify the binary matches the source
- **The token is only sent to `api.anthropic.com`** — the app makes no other network requests
- **No data leaves your machine** — local stats are read from `~/.claude/` and stay local

If you want maximum confidence, [build from source](#option-2-build-from-source).

## Usage colors

| Color | Usage |
|-------|-------|
| Green | < 20% |
| Blue | 20–50% |
| Orange | 50–80% |
| Red | > 80% |
