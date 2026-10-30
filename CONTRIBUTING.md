# Contributing to Neuralyzer

Neuralyzer deletes files. The rules below exist so it only ever deletes the right ones.

## Before you start

- **Open an issue first for anything bigger than a fix.** Say what you want to change and why.
- **Set up as in the README.** `xcodegen generate`, then build.

## How the repo works

**One branch per change.** Never commit to `main`. Branch from it, open a pull request, and let CI run.

**Conventional commits.** `feat(scan): ...`, `fix(clean): ...`, `docs(readme): ...`, `test(...)`, `refactor(...)`, `chore(...)`. The scope is the area: `scan`, `clean`, `safety`, `app`, `onboarding`, `home`. The subject says what changed for the user.

**No em dashes.** In code comments, commit messages, docs, and UI strings. Use a comma, a period, or a colon.

**Logic lives in NeuralyzerKit.** Rules, sizing, safety, and cleaning go in the package with a test beside them. The app target holds views and the store only.

**The safety guard is the boundary.** Every row a rule returns must pass `SafetyGuard`. Adding a new root, or anything under `~/.claude`, needs a test that proves what it refuses.

**Personal files go to the Trash.** Only data that rebuilds itself is deleted outright or preselected.

**The interface stays plain.** Names, sizes, and buttons. No subtext, no dot menus, no badges, no counts, no charts. If a screen seems to need more, open an issue.

## Tests

Run before you push. CI runs the same.

```sh
cd NeuralyzerKit && swift test
xcodegen generate && xcodebuild -scheme Neuralyzer build CODE_SIGNING_ALLOWED=NO
```

Write the failing test first. Tests use `FakeHome`, never your real home folder.

## Pull requests

- One change per pull request.
- Fill in the template: what changed, why, how you verified it. A screenshot for anything visual, with nothing personal in it.

## Code of conduct

Be kind and be direct. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
