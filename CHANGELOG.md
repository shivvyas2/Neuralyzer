# Changelog

## iPhone 1.0.0

- First iPhone version: duplicate photos and videos, screenshots, screen recordings, bursts, blurry photos, big videos, WhatsApp media, iCloud Drive duplicates and large files, and duplicate contacts.

## 1.1.1

- A cleaner icon: three fanned cards with a check on the front one.
- Claude Code shows a terminal icon instead of a sparkle.

## 1.1.0

- New System card: system caches and logs, simulator system caches, temp files untouched for three days, Time Machine local snapshots, old macOS installers, and iPhone backups. System items are removed with one password prompt per clean.
- New look: bold outlined category cards, serif titles, and a new logo of three fanned cards.
- Dark mode uses charcoal instead of pure black.

## 1.0.1

- A simulator already removed in Xcode, or a file gone before cleaning, is skipped instead of failing.
- One stubborn Claude session file no longer stops the rest of that project.
- Read-only folders such as the Go module cache are now removed completely.
- Installers in Downloads count as junk only after a month unopened.
- Asks you to quit Docker, OrbStack, UTM, or the Claude app before cleaning their data, and notices as soon as you do.
- The clean sheet cannot be closed mid-clean.
- Hard linked files, common in pnpm stores, are counted once.
- Old Files and the Claude one hour rule always count from now, not from when the app opened.
- A new scan no longer stops the spinner of the scan it replaced.

## 1.0.0

- First release.
- Scans Xcode, Simulators, Claude Code, package caches, build folders, VMs, app caches, junk, the Trash, large files, and old files.
- First launch walkthrough for Full Disk Access.
- Rebuildable data is deleted, personal files go to the Trash, and every clean is logged.
