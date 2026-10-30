# Neuralyzer design

Date: 2026-10-29
Owner: Shiv Vyas

## Why

Every time the disk fills up, Shiv asks Claude to find what is taking space and clean it: Xcode DerivedData, simulator data, package caches, Claude Code data, old downloads, junk. Neuralyzer turns that repeated chore into a Mac app he opens, scans, and cleans in a few clicks. It is a personal tool first, shipped as a notarized DMG.

On 2026-10-29 the disk had 12 GB free of 460 GB. A read-only scan found:

| Area | Size |
|---|---|
| Downloads (mostly one folder) | 26 GB |
| Simulator runtimes (iOS 27.0, iOS 27.1, watchOS 27.0) | 18 GB |
| Simulator devices | 14 GB |
| Xcode DerivedData | 8.6 GB |
| Xcode iOS DeviceSupport | 6.8 GB |
| ~/Library/Caches | 5.3 GB |
| Xcode Archives | 4.3 GB |
| Claude Code (~/.claude) and Claude app support | 4.3 GB |
| npm, ~/.cache, pnpm, CocoaPods | 4.6 GB |

## Goals

- Find what takes space and group it by type, so the answer to "what is eating my disk" is one screen.
- Clean selected items safely, with rebuildable data removed outright and personal files sent to the Trash.
- Ask for every permission it needs on first launch, with a short tutorial, so cleaning never fails on access.
- A clean interface in the spirit of the reference images: soft cards, generous space, plain list rows.

## Anti-goals (failure even if it works)

- Clutter. No subtext under titles, no dot menus, no badges, no stats beyond name and size, no charts, no tips, no "last updated" lines. Shiv said: "clean, no subtext, no dots, no over information".
- Bloat. No third-party dependencies, no analytics, no network calls, no updater framework, no background agent, no menu bar item.
- Deleting something that cannot come back without the user having chosen it. Nothing is preselected for deletion in the personal files categories.

## Non-goals

- Mac App Store distribution (the app cannot be sandboxed and still do this job).
- Scheduled or automatic cleaning.
- Duplicate file finding, app uninstalling, memory or RAM "boosting".

## Platform and stack (builder's call, stated to Shiv)

- Native macOS app in SwiftUI, Swift 6, minimum macOS 15. No third-party packages.
- Not sandboxed. Hardened runtime. Signed with Developer ID Application: Shiv Vyas (Z42YU5W6WY), notarized with the `notary` keychain profile, shipped as a DMG with an Applications symlink, attached to a GitHub release.
- Scanning and cleaning logic lives in a Swift package `NeuralyzerKit` with unit tests. The app target holds views only.

## Screens

### 1. First launch: permissions tutorial

A short walkthrough, one step per screen, each with a large picture and one line of text.

1. Welcome: app name and a Continue button.
2. Full Disk Access: an image of the System Settings Privacy and Security, Full Disk Access list with the Neuralyzer switch highlighted, and a button "Open System Settings" that opens `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`. The app polls (about once a second) by trying to read a protected path such as `~/Library/Safari` or `~/Library/Mail`; when it succeeds, the step marks itself done and advances. A secondary "Add Neuralyzer" hint explains the plus button if the app is not listed.
3. Done: a Start Scan button.

The tutorial has no skip: the app does not scan without Full Disk Access (builder's call, so every scan is complete and no category needs a partial-access state). The tutorial reappears automatically on launch if Full Disk Access is later turned off. macOS does not allow an app to grant itself access, so a button that opens the right pane is the most it can do.

Admin rights are not requested up front. Operations that need them (removing simulator runtimes owned by the system) go through Apple's own tools and macOS shows its standard password prompt at that moment.

### 2. Home

- Top: the app name, total used and free space as one plain line such as "448 GB used of 460 GB". A Scan button.
- A grid of category cards in the folder-card style of the references: soft tinted card, an icon, the category name, and the size. Nothing else on the card.
- Categories with nothing found are hidden.
- Cards sort by size, largest first.

### 3. Category detail

- Title and total size.
- A plain list: checkbox, icon, item name, size. Sorted by size. No second line.
- At the bottom, one button: "Clean 8.6 GB" reflecting the current selection.
- A small, quiet "Show in Finder" on row hover or right click. No three-dot menus.
- Back to home.

### 4. Clean confirmation

A single sheet: "Clean 8.6 GB?" and two buttons. If the selection includes Trash-bound items, the sheet says once that those go to the Trash, and after the clean a second button "Empty Trash" is offered so that space actually frees (builder's call). The Trash card shows what is sitting in the Trash. After cleaning, the card sizes update and the header shows the new free space.

## Categories and what they contain

Each category has a kind: **rebuildable** (deleted permanently, preselected) or **personal** (moved to Trash, never preselected).

| Category | Paths and sources | Kind |
|---|---|---|
| Xcode | DerivedData (each project folder is a row), Archives (each archive a row), iOS/watchOS DeviceSupport (each version a row), Previews, module caches | rebuildable, except Archives which are personal |
| Simulators | Devices via `xcrun simctl list devices -j` (each device a row, unavailable devices preselected), runtimes via `xcrun simctl runtime list -j` (each runtime a row) | rebuildable; runtimes and devices are not preselected, unavailable devices are |
| Claude Code | `~/.claude/projects` session logs (only `*.jsonl` files and session-UUID folders inside each project folder; each project is a row summing those; the `memory` folder inside each project is never touched; sessions modified in the last hour are skipped so running sessions survive), `~/.claude/shell-snapshots`, `~/.claude/todos`, `~/.claude/statsig`, plugin caches under `~/.claude/plugins/cache`, Claude app caches under `~/Library/Application Support/Claude` (Cache, Code Cache, GPUCache, logs) | rebuildable, but session logs are not preselected. Never touch `~/.claude/settings*.json`, `CLAUDE.md`, `memory`, `skills`, `agents`, `commands`, credentials. |
| Package caches | npm (`~/.npm/_cacache`), pnpm store, Yarn, Bun, pip, Homebrew cache, CocoaPods cache, Gradle caches, Cargo registry, Go module cache, SwiftPM caches | rebuildable |
| Project build folders | `node_modules`, `.build`, `.next`, `build`, `DerivedData` inside `~/Projects` only for v1 (builder's call; no settings screen) | rebuildable, not preselected |
| VMs and containers | Docker data, UTM, Parallels, VMware Fusion, OrbStack, Tart, Ollama models | personal |
| App caches | `~/Library/Caches` per app (each app a row), `~/Library/Logs` | rebuildable |
| Junk | Crash reports under `~/Library/Logs/DiagnosticReports`, old installer `.dmg` and `.pkg` files in Downloads | rebuildable for logs and reports; installers personal |
| Trash | Contents of `~/.Trash`, one row per item | permanent delete, never preselected (builder's call, so a default clean never destroys what an earlier clean trashed) |
| Large files | Every file or top-level folder over 500 MB in Downloads, Desktop, Documents, and Movies, whatever its age. Each item is a row with its size. | personal |
| Old files | Files or top-level folders over 50 MB in the same four folders not opened in 90 days (Spotlight last used date, falling back to modification date; for a folder, the newest date of anything inside). Items already listed under Large files are left out here (builder's call on the 50 MB floor and the de-duplication). | personal |

Removing a simulator device or runtime uses `xcrun simctl delete` and `xcrun simctl runtime delete`, never raw file deletion. Emptying the Trash uses FileManager on `~/.Trash` contents.

## Safety rules

- A hard allowlist of roots. Nothing outside the listed paths is ever deleted. Paths are resolved (symlinks followed and rejected if they leave the root) before deletion.
- If the selection touches Xcode or Simulators data and Xcode or Simulator is running, the clean sheet asks to quit them first.
- Personal items go to the Trash via `FileManager.trashItem`.
- Every clean writes a one line entry to `~/Library/Logs/Neuralyzer/clean.log` with time, path, size, and action.

## Scanning

- Scan runs on launch after permissions, and when Scan is pressed.
- Sizes use allocated size (`totalFileAllocatedSizeKey`) so numbers match what frees up.
- Scanning runs concurrently per category and cards fill in as each finishes. A full scan of the categories above should take under about 30 seconds on this machine.

## Visual direction

- Light and dark appearance following the system.
- Soft background with a gentle gradient, large rounded cards (corner radius around 20), subtle shadow, one tint per category from a small palette.
- System font only. Title large and bold, everything else regular.
- SF Symbols for icons.
- No subtext, no dots, no badges, no counts other than sizes.

## Repository

- Location: `~/Projects/macOS/Neuralyzer`, GitHub repo `shivvyas2/Neuralyzer`, public.
- Follows the LifeOS repo conventions: one branch per change, never commit to `main`, conventional commits (`feat(scan): ...`), no em dashes anywhere, README, CONTRIBUTING, CHANGELOG, LICENSE, SECURITY, CODE_OF_CONDUCT, PR template, bug and feature issue templates, a CI workflow that builds the app and runs `swift test` for `NeuralyzerKit`.
- Commits authored as shivvyas2 / shivvyas0209@gmail.com, no Claude co-author trailer.
- Design notes in `docs/superpowers/specs/`.
- `scripts/release.sh` builds, signs, notarizes, staples, and produces `Neuralyzer.dmg`.

## Left to the builder

- Exact card palette, icon choices, spacing.
- Project generation approach (plain Xcode project or XcodeGen) and folder layout inside the app target.
- Whether the tutorial images are screenshots or drawn illustrations.
