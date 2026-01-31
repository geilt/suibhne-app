# Suibhne.app

> *The bridge between worlds*

A macOS companion app for [OpenClaw](https://github.com/openclaw/openclaw) that holds TCC permissions and exposes protected system resources to headless AI agents.

## The Problem

macOS privacy controls (TCC) require user consent for accessing Contacts, Calendar, Reminders, and other sensitive data. When AI agents run headlessly (as daemons or background processes), they can't click permission dialogs.

## The Solution

Suibhne.app runs as a menu bar application that:

1. **Holds TCC permissions** — Request once, use forever
2. **Exposes a Unix socket API** — Fast, secure IPC for local processes
3. **Provides a CLI wrapper** — `suibhne contacts search "john"`
4. **Logs everything** — Debug and audit trail
5. **Manages OpenClaw** — Edit config, install skills, view status

## Installation

```bash
# From Homebrew (coming soon)
brew install --cask suibhne

# Or download the DMG from releases
```

## Usage

```bash
# Contacts
suibhne contacts search "john smith"
suibhne contacts get <id>
suibhne contacts create --name "John Doe" --phone "+1234567890"
suibhne contacts update <id> --add-email "john@example.com"

# Calendar
suibhne calendar events --today
suibhne calendar create "Meeting" --at "2pm" --duration "1h"

# Reminders
suibhne reminders list
suibhne reminders add "Buy milk" --list "Shopping"

# OpenClaw integration
suibhne config get
suibhne config edit
suibhne skills list
suibhne skills install <url>

# Meta
suibhne status
suibhne permissions
suibhne logs --tail
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Suibhne.app (Menu Bar)                         │
│  - Holds TCC permissions                        │
│  - Listens on ~/.suibhne/suibhne.sock           │
│  - SwiftUI settings & status                    │
└──────────────────────┬──────────────────────────┘
                       │ Unix Socket (JSON-RPC)
        ┌──────────────┴──────────────┐
        │                             │
   ┌────▼────┐                 ┌──────▼──────┐
   │ CLI     │                 │ OpenClaw    │
   │ suibhne │                 │ (Node.js)   │
   └─────────┘                 └─────────────┘
```

## Building

Requires Xcode 15+ and macOS 14+.

```bash
# Open in Xcode
open Suibhne.xcodeproj

# Or build from command line
xcodebuild -project Suibhne.xcodeproj -scheme Suibhne -configuration Release
```

## The Name

Named for **Suibhne Geilt** (swee-nee gyelt), the legendary wild king of Irish mythology. Cursed to wander between worlds, he became a bridge between the tame and the wild.

This app serves the same purpose — bridging the gap between macOS's protected resources and headless AI agents that need access to them.

## License

MIT — free as the wind through the hazel trees.

---

*Part of the [Suibhne](https://suibhne.bot) project* 🪶
