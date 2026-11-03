# Notion Credits for the Mac menu bar

See how many Notion AI credits you are using, without opening Notion.

[日本語の説明はこちら](README.ja.md)

```
N 2,060                                           ← menu bar
───────────────────────────────────────────
Used this period 2,060 (19 agents you can edit)
Personal Notion AI: 182 runs, 0 credits (no limit)
───────────────────────────────────────────
Ticket triage agent    1,043 / limit 3,000
Post-mortem manager      378 / limit 3,750
Spec writer              332 / limit 7,500
16 agents with no usage this period
───────────────────────────────────────────
Open Notion
Refresh
───────────────────────────────────────────
Create a token in Notion
Set token…
```

## What the number means

| Your workspace | The menu bar shows |
| --- | --- |
| Gives each member a credit limit | Credits **left** this period, e.g. `N 680` |
| Has no per-member limit | Credits **used** this period by the Custom Agents you can edit, e.g. `N 2,060` |

Custom Agents spend their owner's credits by default, so the second number is close to "what I am spending".
An agent turns **orange** below 30% of its limit and **red** below 10%.

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
