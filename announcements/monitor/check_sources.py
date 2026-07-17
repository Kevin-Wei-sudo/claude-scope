#!/usr/bin/env python3
"""Watch Anthropic pages for usage-limit policy changes.

Fetches each source, extracts limit-relevant text, and diffs it against the
snapshot committed under snapshots/. On change, writes a markdown report (for
the workflow to open an issue with) and updates the snapshot. First run for a
source just records a baseline without reporting.

Stdlib only — no dependencies.
"""
import argparse
import difflib
import html
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
SNAPSHOT_DIR = ROOT / "snapshots"

SOURCES = [
    {
        "slug": "anthropic-news",
        "url": "https://www.anthropic.com/sitemap.xml",
        "mode": "sitemap",
    },
    {
        "slug": "support-usage-limit-best-practices",
        "url": "https://support.claude.com/en/articles/9797557-usage-limit-best-practices",
        "mode": "full",
    },
    {
        "slug": "support-what-is-the-max-plan",
        "url": "https://support.claude.com/en/articles/11049741-what-is-the-max-plan",
        "mode": "full",
    },
]

KEYWORDS = [
    "usage limit", "rate limit", "usage cap", "weekly limit", "weekly cap",
    "5-hour", "five-hour", "higher limits", "peak hour", "peak-hour",
    "throttl", "usage quota",
]

# Conservative slug keywords: "plan"/"rate" alone match unrelated slugs
# (hiring-plans, st*rate*gic), so only clearly limit-shaped words.
SLUG_KEYWORDS = ["limit", "usage", "quota", "throttl"]

WINDOW = 140  # chars of context kept around each keyword hit


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (ClaudeScope monitor)"})
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read().decode("utf-8", errors="replace")
    raw = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", raw, flags=re.S | re.I)
    raw = re.sub(r"<[^>]+>", " ", raw)
    return re.sub(r"\s+", " ", html.unescape(raw)).strip()


def keyword_windows(text: str) -> str:
    lower = text.lower()
    seen = set()
    windows = []
    for keyword in KEYWORDS:
        start = 0
        while (hit := lower.find(keyword, start)) != -1:
            window = text[max(0, hit - WINDOW):hit + len(keyword) + WINDOW].strip()
            if window not in seen:
                seen.add(window)
                windows.append(window)
            start = hit + len(keyword)
    # Sort for stable snapshots regardless of page ordering churn.
    return "\n".join(sorted(windows))


def news_slugs_from_sitemap(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (ClaudeScope monitor)"})
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read().decode("utf-8", errors="replace")
    locs = re.findall(r"<loc>([^<]+)</loc>", raw)
    matched = {
        loc for loc in locs
        if "/news/" in loc and any(k in loc.rsplit("/", 1)[-1].lower() for k in SLUG_KEYWORDS)
    }
    return "\n".join(sorted(matched))


def extract(source: dict) -> str:
    if source["mode"] == "sitemap":
        return news_slugs_from_sitemap(source["url"])
    text = fetch_text(source["url"])
    if source["mode"] == "keywords":
        return keyword_windows(text)
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, help="write markdown report here when changes are found")
    args = parser.parse_args()

    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    sections = []

    for source in SOURCES:
        snapshot_path = SNAPSHOT_DIR / f"{source['slug']}.txt"
        try:
            current = extract(source)
        except Exception as error:  # network hiccup: keep old snapshot, no alert
            print(f"[skip] {source['slug']}: fetch failed: {error}", file=sys.stderr)
            continue

        if not current:
            print(f"[skip] {source['slug']}: extracted empty text", file=sys.stderr)
            continue

        if not snapshot_path.exists():
            snapshot_path.write_text(current, encoding="utf-8")
            print(f"[baseline] {source['slug']}")
            continue

        previous = snapshot_path.read_text(encoding="utf-8")
        if previous == current:
            print(f"[unchanged] {source['slug']}")
            continue

        diff = list(difflib.unified_diff(
            previous.splitlines(), current.splitlines(),
            fromfile="before", tofile="after", lineterm="",
        ))[:80]
        sections.append(
            f"### {source['slug']}\n\n{source['url']}\n\n```diff\n" + "\n".join(diff) + "\n```"
        )
        snapshot_path.write_text(current, encoding="utf-8")
        print(f"[changed] {source['slug']}")

    if sections:
        report = (
            "One or more monitored Anthropic pages changed in a way that may be "
            "usage-limit news. Review the diffs below; if this is a real policy "
            "change, add an entry to `announcements/announcements.json` and push "
            "— clients pick it up within 6 hours.\n\n" + "\n\n".join(sections)
        )
        pathlib.Path(args.report).write_text(report, encoding="utf-8")

    return 0


if __name__ == "__main__":
    sys.exit(main())
