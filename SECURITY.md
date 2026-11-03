# Security

## Reporting a problem

Please use **Report a vulnerability** on the [Security tab](https://github.com/sue738/notion-credits-xbar/security)
instead of opening a public issue. You will get a reply within a week.

## What the plugin does

- Reads your token from the macOS Keychain (item `notion-pat`). It is never written to a file.
- Sends `GET` requests only to `https://api.notion.com` (agent insights, and the Admin API credit usage when you add an organization token).
- `team-report` sends one `POST` to your Slack webhook. Nothing else is sent anywhere.
- Writes one cache file, `~/Library/Caches/notion-credits-xbar.json`, holding the estimated billing period dates.
- Draws the bar images with the `osascript` that ships with macOS. Nothing is downloaded or installed.
- Optional team features keep the organization bot token (`notion-admin`) and the Slack webhook URL
  (`notion-credits-slack-webhook`) in the Keychain too. The webhook must be a `hooks.slack.com` URL.
  Names sent to Slack are escaped so they cannot mention `@channel` or add links.
- Text from the API (agent names, error codes) is cleaned before it is shown,
  so it cannot add menu actions such as `bash=` or `href=`.

## How releases are protected

- Install from a [release](https://github.com/sue738/notion-credits-xbar/releases), not from `main`.
  Releases are immutable: once published, their files cannot be replaced.
- Every commit and release tag on `main` is signed and shows **Verified** on GitHub.
- `main` cannot be force-pushed or deleted, and only the maintainer can push to it.
- The repository runs no GitHub Actions, so pull requests cannot execute code here.
- Each release lists the SHA-256 of `notion-credits.15m.sh`. To check a download:
  ```sh
  shasum -a 256 notion-credits.15m.sh
  ```

Read the script before installing it. It is one file of about 300 lines.
