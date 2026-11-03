#!/bin/bash
# <xbar.title>Notion Credits</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>sue738</xbar.author>
# <xbar.author.github>sue738</xbar.author.github>
# <xbar.desc>Shows Notion AI credits used this billing period by the Custom Agents you can edit, plus your personal allowance when the workspace sets one.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>
# <xbar.abouturl>https://github.com/sue738/notion-credits-xbar</xbar.abouturl>
#
# Data: GET /v1/agents/{id}/insights (Notion API, public beta).
#   1) If your personal agent (notion_ai) has a credit limit, the menu bar shows what is left.
#   2) Otherwise it shows the sum used by the Custom Agents you can edit. Custom Agents spend
#      their owner's credits by default, so this is close to "what I am spending".
# Auth: a Notion personal access token, stored in the macOS Keychain.
#   From the menu: "Set token…"
#   From Terminal: ./notion-credits.15m.sh set-token

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

TOKEN_PAGE="https://app.notion.com/developers/tokens"
SERVICE="${NOTION_CREDITS_KEYCHAIN_SERVICE:-notion-pat}"

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

def color_for(left, limit):
    ratio = left / limit
    return "red" if ratio < 0.1 else "orange" if ratio < 0.3 else ""

# Monthly allowance per member (Business/Enterprise). Standard and Select are separate pools.
STANDARD = int(os.environ.get("NOTION_STANDARD_CREDITS", "1500"))
SELECT = int(os.environ.get("NOTION_SELECT_CREDITS", "500"))
MONO = "font=Menlo size=12"

def bar(used, cap, width=12):
    filled = round(min(used / cap, 1) * width) if cap else 0
    return "▰" * filled + "▱" * (width - filled)

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

# 1) Personal allowance
code, d = get("/agents/notion_ai/insights")
personal = None
if code == 200:
    used = d.get("total_credits_used") or 0
    limit = d.get("credit_limit")
    if isinstance(limit, (int, float)) and limit > 0:
        left = max(limit - used, 0)
        c = color_for(left, limit)
        print(f"N {fmt(left)}" + (f" | color={c}" if c else ""))
        print("---")
        print(f"Left {fmt(left)} / limit {fmt(limit)} ({left / limit:.0%})")
        print(f"{bar(used, limit)}  {fmt(used)} / {fmt(limit)} | {MONO}" + (f" color={c}" if c else ""))
        footer()
        raise SystemExit
    personal = (used, d.get("runs_completed", 0))
elif code == 403 and d.get("code") == "workspace_credits_exhausted":
    print("N 0 | color=red")
    print("---")
    print("Workspace credits are exhausted")
    footer()
    raise SystemExit
elif code != 404:
    fail("Personal agent:", code, d)

# 2) Custom Agents you can edit (view-only ones return 403 and are skipped)
agents, cursor = [], None
while True:
    code, d = get("/agents?page_size=100" + (f"&start_cursor={cursor}" if cursor else ""))
    if code != 200:
        fail("Agent list:", code, d)
    agents += d.get("results", [])
    if not d.get("has_more"):
        break
    cursor = d.get("next_cursor")

rows, total = [], 0
for a in agents:
    code, d = get(f"/agents/{a['id']}/insights")
    if code != 200:
        continue
    used = d.get("total_credits_used") or 0
    total += used
    rows.append((used, a.get("name", "?"), d.get("credit_limit"), d.get("pause_reason")))

print(f"N {fmt(total)}")
print("---")
if personal:
    used, runs = personal
    print(f"You: Notion AI {runs} runs this period")
    print(f"Standard {bar(used, STANDARD)}  {fmt(used)} / {fmt(STANDARD)} | {MONO}")
    print(f"Select   {bar(0, SELECT)}  ? / {fmt(SELECT)} | {MONO} color=gray")
    print("The API reports one total, counted against Standard here | color=gray size=11")
else:
    print("Personal usage not available via the API | color=gray")
print("---")
print(f"Custom Agents you can edit: {fmt(total)} used ({len(rows)} agents)")
for used, name, limit, pause in sorted(rows, key=lambda r: -r[0]):
    if not used:
        continue
    name = name.replace("|", "/")
    if isinstance(limit, (int, float)) and limit > 0:
        c = color_for(max(limit - used, 0), limit)
        line = f"{bar(used, limit)}  {fmt(used):>6} / {fmt(limit):<6} {name}"
    else:
        c = ""
        line = f"{'':12}  {fmt(used):>6}          {name}"
    if pause:
        line += f" ({pause})"
    print(f"{line} | {MONO}" + (f" color={c}" if c else ""))
idle = sum(1 for r in rows if not r[0])
if idle:
    print(f"{idle} agents with no usage this period | color=gray")
footer()
EOF
echo "---"
token_menu