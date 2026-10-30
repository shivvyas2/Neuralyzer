# Changelog

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
