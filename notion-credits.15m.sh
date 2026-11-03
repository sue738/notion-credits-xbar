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
# Auth: a Notion personal access token, stored in the macOS Keychain (service "notion-pat").
#   Use "Set token…" in the menu, or: security add-generic-password -a "$USER" -s notion-pat -w

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

TOKEN_PAGE="https://app.notion.com/developers/tokens"

# Called from the "Set token…" menu item: ask for the token in a dialog and save it
if [ "$1" = "set-token" ]; then
  T=$(osascript -e 'text returned of (display dialog "Paste your Notion personal access token:" default answer "" with hidden answer buttons {"Cancel", "Save"} default button "Save" with title "Notion Credits")') || exit 0
  [ -n "$T" ] && security add-generic-password -U -a "$USER" -s notion-pat -w "$T"
  exit 0
fi

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

token_menu() {
  echo "Create a token in Notion | href=$TOKEN_PAGE"
  echo "Set token… | bash=\"$SELF\" param1=set-token terminal=false refresh=true"
}

TOKEN=$(security find-generic-password -a "$USER" -s notion-pat -w 2>/dev/null)
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
        print(f"Used this period {fmt(used)}")
        footer()
        raise SystemExit
    personal = f"Personal Notion AI: {d.get('runs_completed', 0)} runs, {fmt(used)} credits (no limit)"
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
print(f"Used this period {fmt(total)} ({len(rows)} agents you can edit)")
print((personal or "Personal allowance not available via API") + " | color=gray")
print("---")
for used, name, limit, pause in sorted(rows, key=lambda r: -r[0]):
    if not used:
        continue
    cap = f" / limit {fmt(limit)}" if isinstance(limit, (int, float)) else ""
    c = ""
    if isinstance(limit, (int, float)) and limit > 0:
        c = color_for(max(limit - used, 0), limit)
    line = f"{name.replace('|', '/')}  {fmt(used)}{cap}"
    if pause:
        line += f" ({pause})"
    print(line + (f" | color={c}" if c else ""))
idle = sum(1 for r in rows if not r[0])
if idle:
    print(f"{idle} agents with no usage this period | color=gray")
footer()
EOF
echo "---"
token_menu