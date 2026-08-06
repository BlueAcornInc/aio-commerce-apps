#!/usr/bin/env python3
"""Post-process the generated docs tree.

Two passes, both of which need the same source-path -> published-URL rule, which
is why they live together:

1. rewrite relative markdown links so they point at the pages build-docs.sh
   actually produced (an author writing [x](EDS.md) should not ship a dead link)
2. derive redirects from the git history of each source repo, so renaming a doc
   in an app repo automatically leaves a working URL behind

Pass 2 is deliberately conservative: a redirect is only emitted when the old URL
is absent from this build and the new one is present. A file that was renamed and
later restored, or whose old name still resolves to a live page, is skipped
rather than allowed to shadow real content.

Deletions are reported but never redirected -- there is no defensible automatic
target for a page that simply went away, so those belong in the overrides file.

Outputs, both derived from one mapping:
  - a redirect stub page at each stale URL (canonical + meta refresh + JS)
  - cloudflare-redirects.csv, ready to import as a Bulk Redirect list

No third-party imports: this runs on a bare CI runner.
"""

import argparse
import os
import posixpath
import re
import subprocess
import sys

MD_EXTS = (".md", ".markdown")


# --- the shared rule -------------------------------------------------------
# Mirrors build-docs.sh: <app>/<dir>/<name>.md -> apps/<app>/<dir>/docs/<name>.html
# with README.md renamed to its containing directory (or the app, at the root).

def published_path(app, relpath):
    """Map a path relative to an app repo root to its built site path."""
    relpath = posixpath.normpath(relpath)
    directory = posixpath.dirname(relpath)
    base = posixpath.basename(relpath)
    stem, ext = posixpath.splitext(base)
    if ext.lower() not in MD_EXTS:
        return None
    parent = posixpath.join("apps", app, directory) if directory else posixpath.join("apps", app)
    if base == "README.md":
        stem = posixpath.basename(directory) if directory else app
    return posixpath.join(parent, "docs", stem + ".html")


def published_url(app, relpath):
    path = published_path(app, relpath)
    return "/" + path if path else None


# --- pass 1: rewrite relative .md links ------------------------------------

LINK_RE = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+?\.(?:md|markdown))((?:#[^)\s]*)?)\)")


def rewrite_links(out_root):
    """Rewrite [text](some/path.md) to the URL that path was published at."""
    changed = 0
    for dirpath, _dirs, files in os.walk(out_root):
        for name in files:
            if not name.lower().endswith(MD_EXTS):
                continue
            out_file = os.path.join(dirpath, name)
            # apps/<rest>/docs/<name>.md came from docs-tmp/<rest>/...
            rel_out = os.path.relpath(out_file, out_root).replace(os.sep, "/")
            parts = rel_out.split("/")
            if len(parts) < 3 or parts[-2] != "docs":
                continue
            app = parts[0]
            src_dir = "/".join(parts[1:-2])

            with open(out_file, encoding="utf-8") as handle:
                text = handle.read()

            def repl(match):
                label, target, frag = match.group(1), match.group(2), match.group(3)
                if "://" in target or target.startswith("/"):
                    return match.group(0)
                joined = posixpath.normpath(posixpath.join(src_dir, target))
                if joined.startswith(".."):
                    return match.group(0)
                url = published_url(app, joined)
                return "[%s](%s%s)" % (label, url, frag) if url else match.group(0)

            new_text = LINK_RE.sub(repl, text)
            if new_text != text:
                with open(out_file, "w", encoding="utf-8") as handle:
                    handle.write(new_text)
                changed += 1
    return changed


# --- pass 2: derive redirects from git history -----------------------------

def _git(repo, *args):
    return subprocess.run(
        ["git", "-C", repo, *args],
        capture_output=True, text=True, check=True, timeout=300,
    ).stdout


def git_renames(repo):
    """Return (old, new) markdown rename pairs, oldest first."""
    try:
        out = _git(repo, "log", "--reverse", "--diff-filter=R", "--find-renames",
                   "--name-status", "--format=%x00")
    except Exception as exc:  # noqa: BLE001 - a bad clone must not fail the build
        print("  ! could not read history for %s: %s" % (repo, exc), file=sys.stderr)
        return []
    pairs = []
    for line in out.splitlines():
        if not line.startswith("R"):
            continue
        cols = line.split("\t")
        if len(cols) != 3:
            continue
        _score, old, new = cols
        if old.lower().endswith(MD_EXTS) or new.lower().endswith(MD_EXTS):
            pairs.append((old, new))
    return pairs


def resolve_chains(pairs):
    """Collapse A->B->C into A->C, dropping anything that returns to itself."""
    final = {}
    for old, new in pairs:
        for key, value in list(final.items()):
            if value == old:
                final[key] = new
        final[old] = new
    return {k: v for k, v in final.items() if k != v}


def git_deletions(repo):
    """Markdown files deleted at some point and absent from the working tree."""
    try:
        out = _git(repo, "log", "--diff-filter=D", "--name-only", "--format=%x00")
    except Exception:  # noqa: BLE001
        return set()
    gone = set()
    for line in out.splitlines():
        if line and not line.startswith("\x00") and line.lower().endswith(MD_EXTS):
            if not os.path.exists(os.path.join(repo, line)):
                gone.add(line)
    return gone


def load_overrides(path):
    """Parse the tiny `- from: X` / `  to: Y` list without a YAML dependency."""
    mapping = {}
    if not path or not os.path.exists(path):
        return mapping
    source = None
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("- from:"):
                source = line.split(":", 1)[1].strip()
            elif line.startswith("to:") and source:
                mapping[source] = line.split(":", 1)[1].strip()
                source = None
    return mapping


STUB = """---
layout: redirect
canonical_url: {target}
sitemap: false
nav_exclude: true
---
"""


def write_stub(out_root, url, target):
    rel = url.lstrip("/")
    if not rel.startswith("apps/"):
        return False
    dest = os.path.join(out_root, os.path.relpath(rel, "apps").replace("/", os.sep))
    dest = os.path.splitext(dest)[0] + ".md"
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w", encoding="utf-8") as handle:
        handle.write(STUB.format(target=target))
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--docs-tmp", default="docs-tmp")
    parser.add_argument("--out", default="apps")
    parser.add_argument("--overrides", default="redirects.yml")
    parser.add_argument("--csv", default="cloudflare-redirects.csv")
    parser.add_argument("--host", default="apps.blueacornici.shop")
    args = parser.parse_args()

    print("Rewriting relative markdown links...")
    print("  rewrote links in %d file(s)" % rewrite_links(args.out))

    def exists(url):
        rel = url.lstrip("/")
        if not rel.startswith("apps/"):
            return False
        stem = os.path.join(args.out, os.path.relpath(rel, "apps").replace("/", os.sep))
        return os.path.exists(os.path.splitext(stem)[0] + ".md")

    print("Deriving redirects from git history...")
    mapping = {}
    if os.path.isdir(args.docs_tmp):
        for app in sorted(os.listdir(args.docs_tmp)):
            repo = os.path.join(args.docs_tmp, app)
            if not os.path.isdir(os.path.join(repo, ".git")):
                continue
            renames = resolve_chains(git_renames(repo))
            found = 0
            for old, new in renames.items():
                old_url, new_url = published_url(app, old), published_url(app, new)
                if not old_url or not new_url or old_url == new_url:
                    continue
                mapping[old_url] = new_url
                found += 1
            dropped = git_deletions(repo)
            print("  %-14s %d rename(s), %d deleted doc(s)" % (app, found, len(dropped)))
            for path in sorted(dropped):
                url = published_url(app, path)
                if url and not exists(url):
                    print("      deleted, no automatic target: %s" % url)

    overrides = load_overrides(args.overrides)
    if overrides:
        print("  %d manual override(s) from %s" % (len(overrides), args.overrides))
    mapping.update(overrides)

    # Only redirect a URL this build does not publish, toward one that it does.
    final = {}
    for old_url, new_url in sorted(mapping.items()):
        if exists(old_url):
            print("  skip (still published): %s" % old_url)
            continue
        if not exists(new_url):
            print("  skip (target missing):  %s -> %s" % (old_url, new_url))
            continue
        final[old_url] = new_url

    written = sum(1 for u, t in final.items() if write_stub(args.out, u, t))
    print("  wrote %d redirect stub(s)" % written)

    with open(args.csv, "w", encoding="utf-8") as handle:
        for old_url, new_url in sorted(final.items()):
            handle.write("%s%s,https://%s%s,301\n" % (args.host, old_url, args.host, new_url))
    print("  wrote %s (%d rule(s))" % (args.csv, len(final)))


if __name__ == "__main__":
    main()
