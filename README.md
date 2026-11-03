# Notion Credits for the Mac menu bar

See how many Notion AI credits you are using, without opening Notion.

[日本語の説明はこちら](README.ja.md)

```
N 2,060                                              ← menu bar
──────────────────────────────────────────────
You: Notion AI 183 runs this period
Standard ▱▱▱▱▱▱▱▱▱▱▱▱      0 / 1,500
Select   ▱▱▱▱▱▱▱▱▱▱▱▱      ? / 500
──────────────────────────────────────────────
Custom Agents you can edit: 2,060 used (19 agents)
▰▰▰▰▱▱▱▱▱▱▱▱   1,043 / 3,000  Ticket triage agent
▰▱▱▱▱▱▱▱▱▱▱▱     378 / 3,750  Post-mortem manager
▰▱▱▱▱▱▱▱▱▱▱▱     332 / 7,500  Spec writer
14 agents with no usage this period
──────────────────────────────────────────────
Open Notion · Refresh · Create a token in Notion · Set token…
```

## What the numbers mean

Each member of a Business or Enterprise workspace gets two separate monthly allowances.
They reset every month and cannot be combined.

| Allowance | Used by |
| --- | --- |
| **Standard** 1,500 | Notion Agent on Auto, AI editing, AI blocks, translation |
| **Select** 500 | Notion Agent with a model you pick, and Custom Agents you own (by default) |

- **Menu bar:** if your workspace sets a per-member limit, credits **left**. Otherwise, credits **used** this month by the Custom Agents you can edit.
- **You:** your personal usage as a bar. The API reports one total without splitting Standard and Select, so it is drawn against Standard.
- **Custom Agents:** each agent's usage against its own limit. A bar turns **orange** below 30% left and **red** below 10%.

If your plan has different amounts, set `NOTION_STANDARD_CREDITS` / `NOTION_SELECT_CREDITS` at the top of the file.

## Install (5 minutes)

You need a Mac and a Notion Business or Enterprise workspace.

1. **Install xbar.** Download it from [xbarapp.com](https://xbarapp.com) and open it.
   Or, with Homebrew: `brew install --cask xbar`
2. **Add the plugin.** Download [`notion-credits.15m.sh`](https://raw.githubusercontent.com/sue738/notion-credits-xbar/main/notion-credits.15m.sh)
   (right-click → Save Link As…).
   In the xbar menu choose **Open plugin folder** and move the file there. Then choose **Refresh all**.
   **N ?** appears in the menu bar.
3. **Create a token.** Click **N ?** → **Create a token in Notion** → **New token**.
   Give it any name, keep **Notion API** checked, and create it. Copy the token (it starts with `ntn_`).
4. **Save the token.** Pick one:
   - **From the menu:** click **N ?** → **Set token…**, paste, and press **Save**.
   - **From Terminal:**
     ```sh
     ~/Library/Application\ Support/xbar/plugins/notion-credits.15m.sh set-token
     ```
     Paste when asked (nothing is shown while you paste). Then choose **Refresh all** in xbar.

The number appears and updates every 15 minutes.

<details>
<summary>Install from Terminal in one go</summary>

```sh
brew install --cask xbar
open -a xbar
PLUGINS=~/Library/Application\ Support/xbar/plugins
mkdir -p "$PLUGINS"
curl -fsSL https://raw.githubusercontent.com/sue738/notion-credits-xbar/main/notion-credits.15m.sh -o "$PLUGINS/notion-credits.15m.sh"
chmod +x "$PLUGINS/notion-credits.15m.sh"
"$PLUGINS/notion-credits.15m.sh" set-token
```

</details>

## Commands

| Command | What it does |
| --- | --- |
| `notion-credits.15m.sh set-token` | Save your token to the Keychain. Asks for it, or reads it from a pipe |
| `notion-credits.15m.sh remove-token` | Delete the saved token |
| `notion-credits.15m.sh` | Print the menu once (handy for checking it works) |

## Questions

**Is my token safe?**
It is stored in your Mac's Keychain (item name `notion-pat`) and only sent to `api.notion.com`. The token can read what you can read in Notion, so do not share it.

**There is no "New token" button.**
Your workspace admin has limited who can create tokens. Ask them, or ask to be added to a group that can.

**The menu bar shows `N !`.**
Open the menu to see the error. `401` means the token is wrong or expired: create a new one and use **Set token…** again.

**How do I refresh more or less often?**
Rename the file: `notion-credits.5m.sh` (every 5 minutes) or `notion-credits.1h.sh` (every hour).

**How do I remove it?**
Run `notion-credits.15m.sh remove-token`, then delete the file from the plugin folder. You can also revoke the token in Notion.

## How it works

It calls the [Retrieve agent insights](https://developers.notion.com/reference/notion-agent-apis/retrieve-agent-insights) endpoint of the Notion API (public beta):
first for your personal agent (`notion_ai`), then for each Custom Agent you can edit.
Agents you can only view are skipped. Nothing else is read.

## License

MIT
