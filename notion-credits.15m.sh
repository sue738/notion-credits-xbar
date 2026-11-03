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
# Day of the month your credits reset (1-28), as shown in Settings → Notion AI → Usage.
# Leave empty to estimate it from your usage history.
export NOTION_RESET_DAY="${NOTION_RESET_DAY:-}"

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
import calendar, json, os, time, urllib.request, urllib.error
from datetime import datetime

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

def clean(text, limit=80):
    # Text from the API goes into xbar menu lines, where "|" starts parameters (bash=, href=)
    # and a newline starts a new item. Strip both so a crafted agent name cannot add actions.
    text = "".join(ch if ch.isprintable() else " " for ch in str(text))
    return text.replace("|", "/").lstrip("-")[:limit]

def num(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else 0

def fmt(n):
    return f"{n:,.0f}"

def bar(used, cap, width, elapsed=None):
    # Like AgentWatch: filled = credits used, "│" = how far into the period we are
    filled = round(min(used / cap, 1) * width) if cap else 0
    cells = ["▰"] * filled + ["▱"] * (width - filled)
    if elapsed is not None:
        cells[min(int(elapsed * width), width - 1)] = "│"
    return "".join(cells)

def pct(used, cap):
    return f"{min(used / cap, 9.99):.0%}" if cap else "-"

def add_month(ts):
    t = datetime.fromtimestamp(ts)
    y, m = (t.year + 1, 1) if t.month == 12 else (t.year, t.month + 1)
    return t.replace(year=y, month=m, day=min(t.day, calendar.monthrange(y, m)[1])).timestamp()

CACHE = os.path.expanduser("~/Library/Caches/notion-credits-xbar.json")

def billing_period(runs_now):
    """Estimate (start, reset) of the current billing period.

    The API counts usage in the current period but does not say when it began.
    Runs in [s, now] shrink as s moves forward, so a binary search finds the gap
    between the last run before the period and the first run in it; the start is
    inside that gap. Cached until the estimated reset passes.
    """
    now = time.time()
    day = os.environ.get("NOTION_RESET_DAY", "")
    if day.isdigit() and 1 <= int(day) <= 28:
        t = datetime.fromtimestamp(now)
        start = t.replace(day=int(day), hour=0, minute=0, second=0, microsecond=0)
        if start.timestamp() > now:
            y, m = (t.year - 1, 12) if t.month == 1 else (t.year, t.month - 1)
            start = start.replace(year=y, month=m)
        return start.timestamp(), add_month(start.timestamp()), True
    try:
        with open(CACHE) as f:
            c = json.load(f)
        if c["reset"] > now:
            return c["start"], c["reset"], False
    except Exception:
        pass
    if not runs_now:
        return None

    def runs_since(s):
        code, d = get(f"/agents/notion_ai/insights?start_time={int(s)}&end_time={int(now)}")
        if code != 200:
            raise RuntimeError
        return num(d.get("runs_completed"))

    def last_time(pred, lo, hi):
        # latest s in [lo, hi] where pred(runs_since(s)) still holds, to 10 minutes
        while hi - lo > 600:
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if pred(runs_since(mid)) else (lo, mid)
        return lo

    try:
        lo = now - 62 * 86400
        if runs_since(lo) <= runs_now:
            return None  # no run before this period in the last two months
        last_out = last_time(lambda r: r > runs_now, lo, now)
        first_in = last_time(lambda r: r >= runs_now, last_out, now)
    except RuntimeError:
        return None
    start = (last_out + first_in) / 2
    reset = add_month(start)
    try:
        with open(CACHE, "w") as f:
            json.dump({"start": start, "reset": reset, "range": [last_out, first_in]}, f)
    except OSError:
        pass
    return start, reset, False

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
    print(label, "HTTP", code, clean(d.get("code", ""), 40))
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
std_used = num(d.get("total_credits_used"))
std_runs = num(d.get("runs_completed"))

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
    if not isinstance(cursor, str) or not all(ch.isalnum() or ch == "-" for ch in cursor):
        break

mine, others = [], []
for a in agents:
    agent_id = str(a.get("id", ""))
    if not agent_id or not all(ch.isalnum() or ch == "-" for ch in agent_id):
        continue
    code, d = get(f"/agents/{agent_id}/insights")
    if code != 200:
        continue  # view-only agents return 403
    pause = d.get("pause_reason")
    row = (num(d.get("total_credits_used")), clean(a.get("name", "?")), d.get("credit_limit"), clean(pause, 40) if pause else None)
    (mine if (d.get("created_by") or {}).get("id") == me else others).append(row)
sel_used = sum(r[0] for r in mine)

# Menu bar: two bars, colored by whichever is closer to running out
period = billing_period(std_runs)
elapsed = None
if period:
    start, reset, exact = period
    elapsed = min(max((time.time() - start) / (reset - start), 0), 1)
c = color_for(std_used, STANDARD) or color_for(sel_used, SELECT)
print(with_color(f"S{bar(std_used, STANDARD, 5)} X{bar(sel_used, SELECT, 5)}", c, "font=Menlo size=11"))
print("---")
print(with_color(f"Standard {pct(std_used, STANDARD):>4} {bar(std_used, STANDARD, 14, elapsed)} {fmt(std_used):>6} / {fmt(STANDARD)}", color_for(std_used, STANDARD)))
print(f"  Notion AI · {fmt(std_runs)} runs this period | color=gray size=11")
print(with_color(f"Select   {pct(sel_used, SELECT):>4} {bar(sel_used, SELECT, 14, elapsed)} {fmt(sel_used):>6} / {fmt(SELECT)}", color_for(sel_used, SELECT)))
print(f"  Custom Agents you created · {len(mine)} agents | color=gray size=11")
for used, name, limit, pause in sorted(mine, key=lambda r: -r[0]):
    if used:
        print(f"--{name}  {fmt(used)}" + (f" ({pause})" if pause else ""))
if period:
    days = max((reset - time.time()) / 86400, 0)
    when = datetime.fromtimestamp(reset).strftime("%b %-d")
    print(f"Resets {'on' if exact else 'around'} {when} (in {days:.0f} days) · │ = time elapsed | color=gray size=11")
else:
    print("Reset date unknown yet (needs some Notion AI use) | color=gray size=11")
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