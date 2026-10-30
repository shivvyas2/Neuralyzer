# Security

Neuralyzer runs with Full Disk Access and deletes files, so a bug in what it chooses to delete is a security issue.

## Reporting

Use GitHub's private vulnerability reporting: open the **Security** tab of this repository and choose **Report a vulnerability**. Do not open a public issue.

Include what you found and how to reproduce it. You will get an acknowledgement within a few days.

## What counts

- Any way to make the app delete or trash a path outside its category roots, including through symlinks.
- Any way for it to touch Claude Code memory, settings, skills, agents, commands, or credentials.
- Anything that sends data off the machine. The app makes no network calls.

## Supported versions

Only the latest release receives fixes.
