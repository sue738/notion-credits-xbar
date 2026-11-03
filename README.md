# notion-credits-xbar

An [xbar](https://xbarapp.com) plugin that puts your Notion AI credit usage in the macOS menu bar.

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

- If your workspace sets a per-member credit limit, the menu bar shows what is left.
- Otherwise it shows the credits used this billing period by the Custom Agents you can edit.
  Custom Agents spend their owner's credits by default, so this is close to what you are spending.
- Agents turn orange below 30% of their limit and red below 10%.

## Setup

1. Create a personal access token in Notion: Developer tools → Personal access tokens → New token.
   The "Notion API" capability is enough.
2. Store it in the Keychain (you will be asked to paste it):
   ```sh
   security add-generic-password -a "$USER" -s notion-pat -w
   ```
3. Copy `notion-credits.15m.sh` into your xbar plugins folder and make it executable:
   ```sh
   cp notion-credits.15m.sh ~/Library/Application\ Support/xbar/plugins/
   chmod +x ~/Library/Application\ Support/xbar/plugins/notion-credits.15m.sh
   ```

It refreshes every 15 minutes. Rename the file (`.5m.`, `.1h.`) to change that.

## Notes

- Uses the [Retrieve agent insights](https://developers.notion.com/reference/notion-agent-apis/retrieve-agent-insights) endpoint, which is in public beta.
- Workspace owners and admins may restrict who can create personal access tokens.
- The token never leaves your Mac except in requests to `api.notion.com`.

## License

MIT
