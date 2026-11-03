# notion-credits-xbar

Shows how many Notion AI credits you are using, right in the Mac menu bar.

```
N 2,060
---
Used this period 2,060 (19 agents you can edit)
Personal Notion AI: 182 runs, 0 credits (no limit)
---
Ticket triage agent  1,043 / limit 3,000
Post-mortem manager  378 / limit 3,750
...
```

- If your workspace gives each member a credit limit, the menu bar shows what is left.
- Otherwise it shows the credits used this month by the Custom Agents you can edit.
  Custom Agents spend their owner's credits by default, so this is close to what you are spending.
- An agent turns orange below 30% of its limit and red below 10%.

## Setup (about 5 minutes, no Terminal needed)

1. **Install xbar.** Download it from [xbarapp.com](https://xbarapp.com) and open it once.
2. **Add this plugin.** Download [`notion-credits.15m.sh`](notion-credits.15m.sh) (Download raw file).
   In the xbar menu choose **Open plugin folder**, and drag the file into that folder.
   Then choose **Refresh all**. You will see **N ?** in the menu bar.
3. **Create a token.** Click **N ?** → **Create a token in Notion**.
   Click **New token**, give it any name, keep **Notion API** checked, and create it. Copy the token.
4. **Paste it.** Click **N ?** → **Set token…**, paste, and press **Save**.

The number appears within a few seconds and refreshes every 15 minutes.
The token is kept in your Mac's Keychain and is only sent to `api.notion.com`.

If step 3 has no **New token** button, your workspace admin has limited who can create tokens.

## Notes

- Uses the [Retrieve agent insights](https://developers.notion.com/reference/notion-agent-apis/retrieve-agent-insights) endpoint, which is in public beta.
- To refresh more or less often, rename the file (`.5m.`, `.1h.`).
- To remove it, delete the file from the plugin folder, and delete `notion-pat` in Keychain Access.

## License

MIT
