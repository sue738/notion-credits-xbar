#!/bin/bash
# <xbar.title>Notion Credits</xbar.title>
# <xbar.version>v1.3</xbar.version>
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

# Optional, for Enterprise organization owners: team usage and a Slack report.
# Needs an organization bot token with the user:read scope ("set-admin-token") and the
# workspace ID (Settings → Workspace → the ID in the URL, or ask your admin).
export NOTION_SPACE_ID="${NOTION_SPACE_ID:-}"
ADMIN_SERVICE="${NOTION_CREDITS_ADMIN_SERVICE:-notion-admin}"
WEBHOOK_SERVICE="${NOTION_CREDITS_WEBHOOK_SERVICE:-notion-credits-slack-webhook}"

# ask_secret PROMPT: read a secret from the terminal (hidden), a pipe, or a dialog when run from the menu
ask_secret() {
  local T
  if [ -t 0 ]; then
    printf '%s ' "$1" >&2
    read -rs T; echo >&2
  else
    read -r T
  fi
  if [ -z "$T" ]; then
    T=$(osascript - "$1" <<'OSA'
on run argv
  text returned of (display dialog (item 1 of argv) default answer "" with hidden answer buttons {"Cancel", "Save"} default button "Save" with title "Notion Credits")
end run
OSA
) || return 1
  fi
  printf '%s' "$T"
}

# save_secret SERVICE PATTERN VALUE: store VALUE in the Keychain if it matches the shell PATTERN
save_secret() {
  # shellcheck disable=SC2254
  case "$3" in
    *[[:space:]]*|"") echo "That is empty or has spaces in it. Copy the token again." >&2; return 1 ;;
    $2) ;;
    *) echo "That does not look right (expected $2)." >&2; return 1 ;;
  esac
  security add-generic-password -U -a "$USER" -s "$1" -w "$3" && echo "Saved to Keychain ($1)."
}

remove_secret() {
  security delete-generic-password -a "$USER" -s "$1" >/dev/null 2>&1 && echo "Removed from Keychain ($1)." || echo "Nothing in Keychain ($1)."
}

case "$1" in
  set-token)
    T=$(ask_secret "Paste your Notion personal access token:") || exit 0
    save_secret "$SERVICE" "ntn_*" "$T"
    exit
    ;;
  set-admin-token)
    T=$(ask_secret "Paste your Notion organization bot token (user:read scope):") || exit 0
    save_secret "$ADMIN_SERVICE" "????????????????????*" "$T"
    exit
    ;;
  set-slack-webhook)
    T=$(ask_secret "Paste the Slack incoming webhook URL:") || exit 0
    save_secret "$WEBHOOK_SERVICE" "https://hooks.slack.com/services/*" "$T"
    exit
    ;;
  remove-token) remove_secret "$SERVICE"; exit 0 ;;
  remove-admin-token) remove_secret "$ADMIN_SERVICE"; exit 0 ;;
  remove-slack-webhook) remove_secret "$WEBHOOK_SERVICE"; exit 0 ;;
  team-report) export NOTION_CREDITS_MODE=report ;;
  help|-h|--help)
    echo "Usage: $(basename "$0") [command]"
    echo "  (no argument)         print the xbar menu"
    echo "  set-token             save your Notion personal access token to the Keychain"
    echo "  remove-token          delete it"
    echo "  set-admin-token       save an organization bot token (Enterprise, user:read) for team usage"
    echo "  remove-admin-token    delete it"
    echo "  set-slack-webhook     save a Slack incoming webhook URL for team-report"
    echo "  remove-slack-webhook  delete it"
    echo "  team-report           post team usage to Slack (needs admin token, NOTION_SPACE_ID, webhook)"
    echo "Secrets are read from the terminal (hidden), a pipe, or a dialog."
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

NOTION_ADMIN_TOKEN=""
SLACK_WEBHOOK=""
if [ -n "$NOTION_SPACE_ID" ]; then
  NOTION_ADMIN_TOKEN=$(security find-generic-password -a "$USER" -s "$ADMIN_SERVICE" -w 2>/dev/null)
  [ "$NOTION_CREDITS_MODE" = report ] && SLACK_WEBHOOK=$(security find-generic-password -a "$USER" -s "$WEBHOOK_SERVICE" -w 2>/dev/null)
fi

NOTION_CREDITS_SELF="$SELF" NOTION_TOKEN="$TOKEN" NOTION_ADMIN_TOKEN="$NOTION_ADMIN_TOKEN" SLACK_WEBHOOK="$SLACK_WEBHOOK" python3 <<'EOF'
import calendar, json, os, time, urllib.request, urllib.error
from datetime import datetime

# NOTION_API_ROOT exists only so the tests can point at a local stub
ROOT = os.environ.get("NOTION_API_ROOT", "https://api.notion.com")
if ROOT != "https://api.notion.com" and not ROOT.startswith("http://127.0.0.1:"):
    ROOT = "https://api.notion.com"
API = ROOT + "/v1"
HEADERS = {
    "Authorization": "Bearer " + os.environ["NOTION_TOKEN"],
    "Notion-Version": "2026-03-11",
}
ADMIN_TOKEN = os.environ.get("NOTION_ADMIN_TOKEN", "")
SPACE_ID = os.environ.get("NOTION_SPACE_ID", "")
MODE = os.environ.get("NOTION_CREDITS_MODE", "")
STANDARD = int(os.environ["NOTION_STANDARD_CREDITS"])
SELECT = int(os.environ["NOTION_SELECT_CREDITS"])
MONO = "font=Menlo size=12"

def get(path, admin=False):
    if admin:
        req = urllib.request.Request(ROOT + "/admin/v1" + path, headers={
            "Authorization": "Bearer " + ADMIN_TOKEN, "Notion-Version": "2026-06-01"})
    else:
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

RENDER_JS = r"""
ObjC.import("AppKit");
ObjC.import("Foundation");

// Draws AgentWatch-style quota images. Input: JSON {bars: [{label, used, elapsed, known}], rows: [...]}
// Output: JSON {title: base64png, rows: [base64png...]}
function run(argv) {
  var spec = JSON.parse(argv[0]);
  var RED = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.82, 0.23, 0.25, 1);
  var GREEN = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0.20, 0.62, 0.40, 1);

  function font(size, weight) {
    var f = $.NSFont.systemFontOfSizeWeight(size, weight);
    var d = f.fontDescriptor.fontDescriptorWithDesign($.NSFontDescriptorSystemDesignRounded);
    return d.isNil() ? f : $.NSFont.fontWithDescriptorSize(d, size);
  }
  function attrs(f, color, shadow) {
    var a = $.NSMutableDictionary.dictionary;
    a.setObjectForKey(f, $.NSFontAttributeName);
    a.setObjectForKey(color, $.NSForegroundColorAttributeName);
    if (shadow) {
      var s = $.NSShadow.alloc.init;
      s.setShadowColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(0, 0, 0, 0.55));
      s.setShadowBlurRadius(0.7);
      s.setShadowOffset($.NSMakeSize(0, 0));
      a.setObjectForKey(s, $.NSShadowAttributeName);
    }
    return a;
  }
  function str(text) { return $.NSString.alloc.initWithUTF8String(text); }
  function width(text, a) { return str(text).sizeWithAttributes(a).width; }
  function draw(text, x, y, a) { str(text).drawAtPointWithAttributes($.NSMakePoint(x, y), a); }
  function capsule(x, y, w, h, color) {
    if (w <= 0) return;
    color.setFill;
    $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(x, y, w, h), h / 2, h / 2).fill;
  }
  function rect(x, y, w, h, color) { color.setFill; $.NSRectFill($.NSMakeRect(x, y, w, h)); }
  function pct(b) { return b.known ? Math.round(b.used * 100) + "%" : "—"; }
  function color(b) { return b.used > b.elapsed ? RED : GREEN; }

  // Render at 2x into a bitmap whose point size is w x h, so the PNG carries 144 dpi
  function image(w, h, paint) {
    var rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
      null, Math.ceil(w * 2), Math.ceil(h * 2), 8, 4, true, false, $.NSCalibratedRGBColorSpace, 0, 0);
    rep.setSize($.NSMakeSize(w, h));
    $.NSGraphicsContext.saveGraphicsState;
    $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));
    paint();
    $.NSGraphicsContext.restoreGraphicsState;
    var png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $.NSDictionary.dictionary);
    return ObjC.unwrap(png.base64EncodedStringWithOptions(0));
  }

  var white = $.NSColor.whiteColor;
  var track = $.NSColor.colorWithSRGBRedGreenBlueAlpha(1, 1, 1, 0.27);

  // Menu bar: stacked NOTION/AI, then one block per allowance (label + big %, thin bar + time tick)
  var brandA = attrs(font(7, $.NSFontWeightHeavy), white, true);
  var titleA = attrs(font(9, $.NSFontWeightSemibold), white, true);
  var bigA = attrs(font(13, $.NSFontWeightBold), white, true);
  var brandW = Math.max(width("NOTION", brandA), width("AI", brandA));
  var BAR = 32, GAP = 3, H = 22;
  var blocks = spec.bars.map(function (b) {
    return Math.max(BAR, width(b.label, titleA) + 2 + width(pct(b), bigA));
  });
  var W = brandW + blocks.reduce(function (s, w) { return s + GAP + w; }, 0) + 1;
  var title = image(W, H, function () {
    draw("NOTION", (brandW - width("NOTION", brandA)) / 2, 12, brandA);
    draw("AI", (brandW - width("AI", brandA)) / 2, 3, brandA);
    var x = brandW + GAP;
    spec.bars.forEach(function (b, i) {
      draw(b.label, x, 6.5, titleA);
      draw(pct(b), x + width(b.label, titleA) + 2, 4, bigA);
      capsule(x, 2, BAR, 2, track);
      if (b.known) {
        capsule(x, 2, BAR * Math.min(b.used, 1), 2, color(b));
        rect(x + Math.min(BAR - 1.5, Math.max(0, BAR * b.elapsed - 0.75)), 0, 1.5, 6, white);
      }
      x += blocks[i] + GAP;
    });
  });

  // Dropdown rows: label | % | wide bar with a time tick, like AgentWatch's 利用枠 card
  var label = $.NSColor.labelColor;
  var rowLabelA = attrs(font(11, $.NSFontWeightMedium), label, false);
  var rowPctA = attrs(font(12, $.NSFontWeightBold), label, false);
  var rows = spec.rows.map(function (r) {
    return image(200, 16, function () {
      draw(r.label, 0, 1, rowLabelA);
      var p = pct(r);
      draw(p, 92 - width(p, rowPctA), 0, rowPctA);
      var bx = 98, bw = 200 - bx - 2;
      capsule(bx, 5.5, bw, 5, $.NSColor.labelColor.colorWithAlphaComponent(0.12));
      if (r.known) {
        capsule(bx, 5.5, bw * Math.min(r.used, 1), 5, color(r));
        rect(bx + Math.min(bw - 1.5, Math.max(0, bw * r.elapsed - 0.75)), 3, 1.5, 10, label.colorWithAlphaComponent(0.75));
      }
    });
  });
  return JSON.stringify({ title: title, rows: rows });
}
"""

def render(spec):
    # Draw the AgentWatch-style images with AppKit through JavaScript for Automation (built into macOS)
    import subprocess
    try:
        out = subprocess.run(["osascript", "-l", "JavaScript", "-e", RENDER_JS, json.dumps(spec)],
                             capture_output=True, text=True, timeout=15)
        data = json.loads(out.stdout)
        return data if data.get("title") else None
    except Exception:
        return None

def is_id(v):
    return isinstance(v, str) and 0 < len(v) <= 64 and all(ch.isalnum() or ch == "-" for ch in v)

def paged(path):
    items, cursor = [], None
    for _ in range(50):
        sep = "&" if "?" in path else "?"
        code, d = get(path + sep + "page_size=100" + (f"&start_cursor={cursor}" if cursor else ""), admin=True)
        if code != 200:
            return None, code, d
        items += d.get("results", [])
        cursor = d.get("next_cursor")
        if not d.get("has_more") or not is_id(cursor):
            break
    return items, 200, {}

def fetch_team():
    """Per-member Standard / Select / Notion credits for this period (Admin API, Enterprise only)."""
    if not (ADMIN_TOKEN and is_id(SPACE_ID)):
        return None
    usage, code, d = paged(f"/spaces/{SPACE_ID}/users/credit_usage")
    if usage is None:
        return {"error": f"HTTP {code} {clean(d.get('code', ''), 40)}"}
    people, _, _ = paged(f"/spaces/{SPACE_ID}/users")
    names = {}
    for u in people or []:
        names[u.get("id")] = clean(u.get("name") or (u.get("person") or {}).get("email") or "?", 40)
    rows, start, end = [], None, None
    for u in usage:
        t = u.get("credits_used_by_type") or {}
        rows.append({
            "id": u.get("id"), "name": names.get(u.get("id"), "(unknown)"),
            "standard": num(t.get("standard_credits")), "select": num(t.get("select_credits")),
            "notion": num(t.get("notion_credits")),
        })
        start = start or num(u.get("metrics_period_start_ms")) / 1000 or None
        end = end or num(u.get("metrics_period_end_ms")) / 1000 or None
    rows.sort(key=lambda r: -(r["standard"] / STANDARD + r["select"] / SELECT + r["notion"] / 1000))
    return {"rows": rows, "start": start, "end": end}

def share(r):
    return max(r["standard"] / STANDARD, r["select"] / SELECT)

if MODE == "report":
    import sys
    webhook = os.environ.get("SLACK_WEBHOOK", "")
    local_test = ROOT != "https://api.notion.com" and webhook == ROOT + "/slack"
    if not (webhook.startswith("https://hooks.slack.com/services/") or local_test):
        sys.exit("No Slack webhook. Run: notion-credits.15m.sh set-slack-webhook")
    team = fetch_team()
    if not team or "error" in team:
        sys.exit("Team usage unavailable: " + (team or {}).get("error", "set NOTION_SPACE_ID and set-admin-token"))
    rows, start, end = team["rows"], team["start"], team["end"]
    for r in rows:
        # Slack reads <...> as mentions and links, so a name like "<!channel>" must not get through
        r["name"] = r["name"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("`", "'")
    elapsed_r = min(max((time.time() - start) / (end - start), 0), 1) if start and end else None
    head = "Notion AI credits"
    if start and end:
        head += f" · {datetime.fromtimestamp(start):%b %-d} – {datetime.fromtimestamp(end - 1):%b %-d}"
        head += f" ({elapsed_r:.0%} of the month)"
    active = [r for r in rows if r["standard"] or r["select"] or r["notion"]]
    lines = [f"*{head}*",
             f"{len(active)} of {len(rows)} members used AI · Standard {fmt(sum(r['standard'] for r in rows))}"
             f" · Select {fmt(sum(r['select'] for r in rows))} · Notion credits {fmt(sum(r['notion'] for r in rows))}"]
    ahead = [r for r in rows if elapsed_r is not None and share(r) > max(elapsed_r, 0.5)]
    if ahead:
        lines.append(f":warning: Ahead of pace: " + ", ".join(f"{r['name']} ({share(r):.0%})" for r in ahead[:10]))
    lines.append("```")
    lines.append(f"{'':24} {'Standard':>13} {'Select':>11} {'Notion':>7}")
    for r in active[:15]:
        lines.append(f"{r['name'][:24]:24} {fmt(r['standard']):>6} / {fmt(STANDARD):<5}"
                     f" {fmt(r['select']):>4} / {fmt(SELECT):<4} {fmt(r['notion']):>7}")
    lines.append("```")
    body = json.dumps({"text": "\n".join(lines)}).encode()
    req = urllib.request.Request(webhook, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        print("Posted to Slack:", r.status)
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
# The insights API counts premium AI credits only. Notion AI on Auto spends Standard credits,
# which the API does not report, so Standard is shown as unknown. Premium use of your Notion AI
# (a model you picked) and Custom Agents you created both spend Select credits.
agents_used = sum(r[0] for r in mine)
sel_used = std_used + agents_used
std_known, std_val = False, 0

team = fetch_team()
me_row = next((r for r in (team or {}).get("rows", []) if r["id"] == me), None)
if me_row:
    # The Admin API splits your usage by type, so both bars are exact
    std_known, std_val, sel_used = True, me_row["standard"], me_row["select"]

if team and team.get("start") and team.get("end"):
    period = (team["start"], team["end"], True)
else:
    period = billing_period(std_runs)
elapsed = None
if period:
    start, reset, exact = period
    elapsed = min(max((time.time() - start) / (reset - start), 0), 1)

def gauge(label, used, cap, known=True):
    return {"label": label, "used": used / cap if cap else 0, "elapsed": elapsed if elapsed is not None else 1, "known": known and bool(cap)}

images = render({
    "bars": [gauge("Std", std_val, STANDARD, std_known), gauge("Sel", sel_used, SELECT)],
    "rows": [gauge("Standard", std_val, STANDARD, std_known), gauge("Select", sel_used, SELECT)],
})

# Menu bar, drawn like AgentWatch: bar = credits used, white tick = time elapsed, red = using faster than time
if images:
    print(f"| image={images['title']}")
else:
    std_txt = bar(std_val, STANDARD, 5) if std_known else "—"
    print(with_color(f"S{std_txt} X{bar(sel_used, SELECT, 5)}", color_for(sel_used, SELECT), "font=Menlo size=11"))
print("---")
if images:
    print(f"| image={images['rows'][0]}")
else:
    print(f"Standard {pct(std_val, STANDARD) if std_known else '—'}")
if std_known:
    print(f"{fmt(std_val)} / {fmt(STANDARD)} used · Notion AI {fmt(std_runs)} runs | color=gray size=11")
else:
    print(f"Not reported by the API · Notion AI {fmt(std_runs)} runs | color=gray size=11")
if images:
    print(f"| image={images['rows'][1]}")
else:
    print(with_color(f"Select   {pct(sel_used, SELECT):>4} {bar(sel_used, SELECT, 14, elapsed)}", color_for(sel_used, SELECT)))
if me_row:
    print(f"{fmt(sel_used)} / {fmt(SELECT)} used · incl. your agents {fmt(agents_used)} | color=gray size=11")
else:
    print(f"{fmt(sel_used)} / {fmt(SELECT)} used · picked models {fmt(std_used)} + your agents {fmt(agents_used)} | color=gray size=11")
for used, name, limit, pause in sorted(mine, key=lambda r: -r[0]):
    if used:
        print(f"--{name}  {fmt(used)}" + (f" ({pause})" if pause else ""))
if period:
    days = max((reset - time.time()) / 86400, 0)
    when = datetime.fromtimestamp(reset).strftime("%b %-d")
    print(f"Resets {'on' if exact else 'around'} {when} · in {days:.0f} days | size=11")
else:
    print("Reset date not known yet | color=gray size=11")

print("---")
print("About these numbers | color=gray size=11")
print("--Bar = credits used · white line = time elapsed")
print("--Red = using credits faster than the month is passing")
if not std_known:
    print("--Standard (Notion AI on Auto) is not in the API. See Settings → Notion AI → Usage")
print("--Select = Notion AI with a model you picked + Custom Agents you created")
if not (period and exact):
    print("--Reset date is estimated. Set NOTION_RESET_DAY for the exact day")

# Team usage (organization owners with an admin token)
if team and "error" in team:
    print(f"Team usage: {team['error']} | color=orange size=11")
elif team:
    rows = team["rows"]
    active_people = [r for r in rows if r["standard"] or r["select"] or r["notion"]]
    print(f"Team usage · {len(active_people)} of {len(rows)} members | size=11")
    print(f"--{'':22} {'Std':>11} {'Sel':>9} {'Notion':>6} | {MONO} color=gray")
    for r in active_people[:40]:
        c = ""
        if elapsed is not None and share(r) > max(elapsed, 0.5):
            c = "red"
        line = (f"{r['name'][:22]:22} {fmt(r['standard']):>5}/{fmt(STANDARD):<5}"
                f" {fmt(r['select']):>4}/{fmt(SELECT):<4} {fmt(r['notion']):>6}")
        print("--" + with_color(line, c))
    if len(active_people) > 40:
        print(f"--…and {len(active_people) - 40} more | color=gray")
    print(f"--Post to Slack now | bash=\"{os.environ.get('NOTION_CREDITS_SELF', '')}\" param1=team-report terminal=false")

# Agents others own but you can edit: not your credits, shown for reference
active = [r for r in others if r[0]]
if active:
    print(f"Other agents you can edit (not your credits) | color=gray size=11")
    for used, name, limit, pause in sorted(active, key=lambda r: -r[0]):
        cap = f" / {fmt(limit)}" if isinstance(limit, (int, float)) and limit > 0 else ""
        print(f"--{name}  {fmt(used)}{cap}" + (f" ({pause})" if pause else ""))
footer()
EOF
rc=$?
[ "$NOTION_CREDITS_MODE" = report ] && exit $rc
echo "---"
token_menu