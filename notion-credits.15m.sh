#!/bin/bash
# <xbar.title>Notion Credits</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>sue738</xbar.author>
# <xbar.author.github>sue738</xbar.author.github>
# <xbar.desc>Shows your own Notion AI credits as two bars: Standard (1,500/month) and Select (500/month).</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>
# <xbar.abouturl>https://github.com/sue738/notion-credits-xbar</xbar.abouturl>
#
# Data: GET /v1/agents/{id}/insights (Notion API, public beta).
#   Standard = your personal Notion AI (agent "notion_ai").
#   Select   = Custom Agents you created (they spend their owner's Select credits by default).
# Auth: a Notion personal access token, stored in the macOS Keychain.
#   From the menu: "Set token…"
#   From Terminal: ./notion-credits.15m.sh set-token

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

TOKEN_PAGE="https://app.notion.com/developers/tokens"
SERVICE="${NOTION_CREDITS_KEYCHAIN_SERVICE:-notion-pat}"

# Monthly allowance per member. Change these if your plan differs.
export NOTION_STANDARD_CREDITS="${NOTION_STANDARD_CREDITS:-1500}"
export NOTION_SELECT_CREDITS="${NOTION_SELECT_CREDITS:-500}"

save_token() {
  case "$1" in
    ntn_*|secret_*) ;;
    *) echo "That does not look like a Notion token (it should start with ntn_)." >&2; return 1 ;;
  esac
  security add-generic-password -U -a "$USER" -s "$SERVICE" -w "$1" && echo "Saved to Keychain ($SERVICE)."
}

case "$1" in
  set-token)
    if [ -t 0 ]; then
      # Terminal: hidden prompt
      printf 'Paste your Notion personal access token: ' >&2
      read -rs T; echo >&2
    else
      # Piped in (echo ntn_... | ./notion-credits.15m.sh set-token), or empty when run from the menu
      read -r T
    fi
    if [ -z "$T" ]; then
      # Menu: ask in a dialog
      T=$(osascript -e 'text returned of (display dialog "Paste your Notion personal access token:" default answer "" with hidden answer buttons {"Cancel", "Save"} default button "Save" with title "Notion Credits")') || exit 0
    fi
    save_token "$T"
    exit
    ;;
  remove-token)
    security delete-generic-password -a "$USER" -s "$SERVICE" >/dev/null 2>&1 && echo "Removed from Keychain ($SERVICE)." || echo "No token in Keychain ($SERVICE)."
    exit 0
    ;;
  help|-h|--help)
    echo "Usage: $(basename "$0") [set-token | remove-token]"
    echo "  (no argument)  print the xbar menu"
    echo "  set-token      save your Notion token to the Keychain (prompt, or pipe it in)"
    echo "  remove-token   delete the saved token"
    exit 0
    ;;
esac

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

token_menu() {
  echo "Create a token in Notion | href=$TOKEN_PAGE"
  echo "Set token… | bash=\"$SELF\" param1=set-token terminal=false refresh=true"
}

TOKEN=$(security find-generic-password -a "$USER" -s "$SERVICE" -w 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "N ?"
  echo "---"
  echo "Set up in two steps:"
  echo "1. Create a personal access token in Notion"
  echo "2. Click \"Set token…\" and paste it"
  echo "---"
  token_menu
  exit 0
fi

NOTION_TOKEN="$TOKEN" python3 <<'EOF'
import json, os, urllib.request, urllib.error

API = "https://api.notion.com/v1"
HEADERS = {
    "Authorization": "Bearer " + os.environ["NOTION_TOKEN"],
    "Notion-Version": "2026-03-11",
}
STANDARD = int(os.environ["NOTION_STANDARD_CREDITS"])
SELECT = int(os.environ["NOTION_SELECT_CREDITS"])
MONO = "font=Menlo size=12"

def get(path):
    req = urllib.request.Request(API + path, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.load(e)
        except Exception:
            return e.code, {}
    except Exception as e:
        return 0, {"code": type(e).__name__}

def fmt(n):
    return f"{n:,.0f}"

def bar(used, cap, width):
    filled = round(min(used / cap, 1) * width) if cap else 0
    return "▰" * filled + "▱" * (width - filled)

def color_for(used, cap):
    left = max(cap - used, 0) / cap if cap else 1
    return "red" if left < 0.1 else "orange" if left < 0.3 else ""

def with_color(line, c, extra=MONO):
    return f"{line} | {extra}" + (f" color={c}" if c else "")

def footer():
    print("---")
    print("Open Notion | href=https://www.notion.so")
    print("Refresh | refresh=true")

def fail(label, code, d):
    print("N ! | color=orange")
    print("---")
    print(label, "HTTP", code, d.get("code", ""))
    footer()
    raise SystemExit

# Standard: your personal Notion AI
code, d = get("/agents/notion_ai/insights")
if code == 403 and d.get("code") == "workspace_credits_exhausted":
    print("N 0 | color=red")
    print("---")
    print("Workspace credits are exhausted")
    footer()
    raise SystemExit
if code != 200:
    fail("Personal Notion AI:", code, d)
me = (d.get("created_by") or {}).get("id")
std_used = d.get("total_credits_used") or 0
std_runs = d.get("runs_completed") or 0

# Select: Custom Agents you created. Others' agents spend their owner's credits, not yours.
agents, cursor = [], None
while True:
    code, d = get("/agents?page_size=100" + (f"&start_cursor={cursor}" if cursor else ""))
    if code != 200:
        fail("Agent list:", code, d)
    agents += d.get("results", [])
    if not d.get("has_more"):
        break
    cursor = d.get("next_cursor")

mine, others = [], []
for a in agents:
    code, d = get(f"/agents/{a['id']}/insights")
    if code != 200:
        continue  # view-only agents return 403
    row = (d.get("total_credits_used") or 0, a.get("name", "?").replace("|", "/"), d.get("credit_limit"), d.get("pause_reason"))
    (mine if (d.get("created_by") or {}).get("id") == me else others).append(row)
sel_used = sum(r[0] for r in mine)

# Menu bar: two bars, colored by whichever is closer to running out
c = color_for(std_used, STANDARD) or color_for(sel_used, SELECT)
print(with_color(f"S{bar(std_used, STANDARD, 5)} X{bar(sel_used, SELECT, 5)}", c, "font=Menlo size=11"))
print("---")
print(with_color(f"Standard {bar(std_used, STANDARD, 12)} {fmt(std_used):>6} / {fmt(STANDARD)}", color_for(std_used, STANDARD)))
print(f"  Notion AI · {std_runs} runs this period | color=gray size=11")
print(with_color(f"Select   {bar(sel_used, SELECT, 12)} {fmt(sel_used):>6} / {fmt(SELECT)}", color_for(sel_used, SELECT)))
print(f"  Custom Agents you created · {len(mine)} agents | color=gray size=11")
for used, name, limit, pause in sorted(mine, key=lambda r: -r[0]):
    if used:
        print(f"--{name}  {fmt(used)}" + (f" ({pause})" if pause else ""))
print("The API gives one total for Notion AI, so it is shown as Standard | color=gray size=11")

# Agents others own but you can edit: not your credits, shown for reference
active = [r for r in others if r[0]]
if active:
    print("---")
    print(f"Other agents you can edit ({fmt(sum(r[0] for r in others))} used, not your credits) | color=gray")
    for used, name, limit, pause in sorted(active, key=lambda r: -r[0]):
        if isinstance(limit, (int, float)) and limit > 0:
            line = f"{bar(used, limit, 12)} {fmt(used):>6} / {fmt(limit):<6} {name}"
            c = color_for(used, limit)
        else:
            line = f"{'':12} {fmt(used):>6}          {name}"
            c = ""
        if pause:
            line += f" ({pause})"
        print("--" + with_color(line, c))
footer()
EOF
echo "---"
token_menu