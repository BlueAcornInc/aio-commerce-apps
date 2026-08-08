#!/usr/bin/env python3
"""Assert that the URLs in critical-urls.txt still resolve.

Runs in two modes against the same contract file, which is the point -- a
single list guards both sides of a deploy:

  --site _site   check the built output before it is published. A failure here
                 fails the build, so a missing URL never reaches production.
  --host URL     check production after deploying. Catches what a file check
                 cannot: a bad Pages upload, a redirect rule, a DNS or CDN
                 problem.

A redirect stub counts as present. It returns 200 and carries a canonical link
rather than content, so the check also resolves that canonical target and fails
if the target is missing -- a stub pointing at nothing is still a dead end.

No third-party imports: this runs on a bare CI runner.
"""

import argparse
import os
import re
import sys
import time
import urllib.error
import urllib.request

CANONICAL_RE = re.compile(
    r'<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)["\']', re.I
)
REFRESH_RE = re.compile(r'<meta[^>]+http-equiv=["\']refresh["\']', re.I)

USER_AGENT = "aio-commerce-apps-url-check"


def read_contract(path):
    urls = []
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.split("#", 1)[0].strip()
            if line:
                urls.append(line)
    return urls


# --- fetching --------------------------------------------------------------

def fetch_local(site_dir, url):
    """Resolve a URL to a file in the built site. Returns (ok, detail, html)."""
    rel = url.split("#", 1)[0].split("?", 1)[0].lstrip("/")
    candidates = []
    if rel == "" or rel.endswith("/"):
        candidates.append(os.path.join(site_dir, rel, "index.html"))
    else:
        candidates.append(os.path.join(site_dir, rel))
        # Jekyll may publish /a/b as /a/b/index.html when permalinks are pretty
        candidates.append(os.path.join(site_dir, rel, "index.html"))

    for path in candidates:
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as handle:
                return True, path, handle.read()
    return False, "no file at %s" % " or ".join(candidates), ""


def fetch_live(host, url, attempts=6, delay=15):
    """GET a URL, retrying while Pages propagates. Returns (ok, detail, html)."""
    full = host.rstrip("/") + url
    last = "unknown error"
    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(full, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8", "replace")
                return True, "HTTP %d" % response.status, body
        except urllib.error.HTTPError as exc:
            last = "HTTP %d" % exc.code
            # A 404 right after deploy is usually propagation, so still retry.
        except Exception as exc:  # noqa: BLE001 - network flake, retry
            last = str(exc)
        if attempt < attempts:
            print("      %s (attempt %d/%d), retrying in %ds"
                  % (last, attempt, attempts, delay))
            time.sleep(delay)
    return False, last, ""


def canonical_target(html):
    """The canonical URL of a redirect stub, or None for a normal page."""
    if not REFRESH_RE.search(html):
        return None
    match = CANONICAL_RE.search(html)
    return match.group(1) if match else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", default="critical-urls.txt")
    parser.add_argument("--site", help="check a built site directory")
    parser.add_argument("--host", help="check a live host, e.g. https://example.com")
    args = parser.parse_args()

    if bool(args.site) == bool(args.host):
        parser.error("pass exactly one of --site or --host")

    urls = read_contract(args.contract)
    where = args.site if args.site else args.host
    print("Checking %d URL(s) against %s\n" % (len(urls), where))

    def fetch(url):
        if args.site:
            return fetch_local(args.site, url)
        return fetch_live(args.host, url)

    failures = []
    for url in urls:
        ok, detail, html = fetch(url)
        if not ok:
            print("  FAIL  %-50s %s" % (url, detail))
            failures.append(url)
            continue

        target = canonical_target(html)
        if target:
            # Compare on path so the same check works locally and live.
            target_path = re.sub(r"^https?://[^/]+", "", target)
            ok2, detail2, _ = fetch(target_path)
            if not ok2:
                print("  FAIL  %-50s redirects to missing %s (%s)"
                      % (url, target_path, detail2))
                failures.append(url)
                continue
            print("  ok    %-50s -> %s" % (url, target_path))
        else:
            print("  ok    %-50s" % url)

    print("")
    if failures:
        print("%d of %d URL(s) FAILED:" % (len(failures), len(urls)))
        for url in failures:
            print("  %s" % url)
        print("\nThese URLs are linked from places we do not control "
              "(Adobe Exchange listings, released apps).")
        print("Fix the build or add a redirect -- do not delete the line.")
        return 1

    print("All %d URL(s) resolve." % len(urls))
    return 0


if __name__ == "__main__":
    sys.exit(main())
