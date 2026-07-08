#!/usr/bin/env python3
"""Discovery strategies for the continuous acquisition crawler.

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md
(§Targets, §Discovery). Implements the four strategies the spec requires:

  1. Sitemaps            -> ``parse_sitemap()``
  2. Link-following       -> ``extract_links()`` + ``looks_like_section()``
                             (BFS driver lives in crawl.py; robots.txt gating
                             lives in ``RobotsCache``)
  3. Direct-PDF probing   -> ``candidate_probe_urls()`` (caller HEADs each)
  4. Search-page / search-engine hook (Cloudflare-blocked HTML, e.g. CISCE)
                          -> ``set_search_hook()`` / ``search_discover()``

Stdlib-only (xml.etree, html.parser, urllib.robotparser) — no scraping deps,
matching the rest of this workspace's "stdlib-only by design" convention.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from typing import Callable, Iterable
from urllib.parse import urljoin, urlsplit
from urllib.robotparser import RobotFileParser

RESOURCE_EXTENSIONS = {"pdf", "doc", "docx", "epub", "zip"}

SECTION_KEYWORDS = [
    "publication", "download", "curriculum", "syllabus", "textbook",
    "teacher", "sample-paper", "sample_paper", "sampl", "marking-scheme",
    "marking_scheme", "circular", "manual", "archive", "sitemap",
    "resource", "e-book", "ebook", "question",
]

# --------------------------------------------------------- per-board adapters
# Targets + sections per CRAWLER_SPEC.md §Targets. board keys match boards.json
# (cbse/ap/telangana/icse) so classification stays consistent with the rest of
# the acquisition pipeline, though this crawler does not require boards.json to
# run (the spec's target list is small and stable enough to encode directly).

BOARD_DOMAINS: dict[str, dict] = {
    "cbse": {
        "code": "CBSE",
        "board_folder": "cbse",
        "domains": ["cbseacademic.nic.in", "cbse.gov.in", "ncert.nic.in"],
        "sitemaps": [
            "https://cbseacademic.nic.in/sitemap.xml",
            "https://cbse.gov.in/sitemap.xml",
            "https://ncert.nic.in/sitemap.xml",
        ],
        "seeds": [
            "https://cbseacademic.nic.in/curriculum.html",
            "https://ncert.nic.in/textbook.php",
        ],
        "blocked": False,
    },
    "ap": {
        "code": "APSCERT",
        "board_folder": "ap",
        "domains": ["bse.ap.gov.in", "cse.ap.gov.in", "apscert.gov.in"],
        "sitemaps": [
            "https://bse.ap.gov.in/sitemap.xml",
            "https://apscert.gov.in/sitemap.xml",
        ],
        "seeds": [
            "https://bse.ap.gov.in",
            "https://cse.ap.gov.in",
            "https://apscert.gov.in",
        ],
        "blocked": False,
    },
    "telangana": {
        "code": "TSSCERT",
        "board_folder": "telangana",
        "domains": ["scert.telangana.gov.in"],
        "sitemaps": ["https://scert.telangana.gov.in/sitemap.xml"],
        "seeds": ["https://scert.telangana.gov.in"],
        "blocked": False,
    },
    "icse": {
        "code": "CISCE",
        "board_folder": "icse",
        "domains": ["cisce.org"],
        "sitemaps": ["https://cisce.org/wp-sitemap.xml"],
        "seeds": ["https://cisce.org"],
        # Cloudflare managed-challenge on HTML incl. sitemaps/wp-json to
        # non-browser clients (documented in acquisition/cisce_manifest.json);
        # static /wp-content/uploads/ assets are NOT challenged.
        "blocked": True,
        "probe_prefixes": ["https://cisce.org/wp-content/uploads/"],
    },
}


def domain_of(url: str) -> str:
    return (urlsplit(url).hostname or "").lower()


def board_for_domain(host: str) -> str | None:
    host = (host or "").lower()
    for board, cfg in BOARD_DOMAINS.items():
        if any(host == d or host.endswith("." + d) for d in cfg["domains"]):
            return board
    return None


def is_resource_url(url: str) -> bool:
    path = urlsplit(url).path.lower()
    tail = path.rsplit("/", 1)[-1]
    ext = tail.rsplit(".", 1)[-1] if "." in tail else ""
    return ext in RESOURCE_EXTENSIONS


def looks_like_section(url: str) -> bool:
    low = url.lower()
    return any(k in low for k in SECTION_KEYWORDS)


# ------------------------------------------------------------- sitemap parse

_LOC_RE = re.compile(rb"<loc>\s*([^<\s][^<]*?)\s*</loc>", re.IGNORECASE)


def parse_sitemap(xml_bytes: bytes) -> dict:
    """Parse a ``sitemap.xml`` / ``wp-sitemap*.xml`` payload.

    Handles both a ``<urlset>`` (leaf sitemap, each ``<url><loc>`` a real
    resource/page) and a ``<sitemapindex>`` (each ``<sitemap><loc>`` another
    sitemap to fetch). Returns ``{"sitemaps": [...], "urls": [...]}``.

    Falls back to a tolerant ``<loc>`` regex scan when the XML doesn't parse
    (some government sitemaps are not well-formed) so discovery degrades
    gracefully instead of raising.
    """
    sitemaps: list[str] = []
    urls: list[str] = []
    try:
        root = ET.fromstring(xml_bytes)
        root_tag = root.tag.rsplit("}", 1)[-1].lower()
        for child in root:
            child_tag = child.tag.rsplit("}", 1)[-1].lower()
            if child_tag not in ("sitemap", "url"):
                continue
            loc = None
            for sub in child:
                if sub.tag.rsplit("}", 1)[-1].lower() == "loc" and sub.text:
                    loc = sub.text.strip()
                    break
            if not loc:
                continue
            if root_tag == "sitemapindex" or child_tag == "sitemap":
                sitemaps.append(loc)
            else:
                urls.append(loc)
    except ET.ParseError:
        for m in _LOC_RE.finditer(xml_bytes):
            loc = m.group(1).decode("utf-8", "replace").strip()
            (sitemaps if loc.lower().endswith(".xml") else urls).append(loc)
    return {"sitemaps": sitemaps, "urls": urls}


# ------------------------------------------------------------ link-following

class _LinkExtractor(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.hrefs: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "a":
            return
        for name, value in attrs:
            if name.lower() == "href" and value:
                self.hrefs.append(value)


def extract_links(html: bytes | str, base_url: str) -> list[str]:
    """Same-page ``<a href>`` extraction, resolved against ``base_url``."""
    if isinstance(html, bytes):
        html = html.decode("utf-8", "replace")
    parser = _LinkExtractor()
    try:
        parser.feed(html)
    except Exception:
        pass  # malformed HTML: keep whatever links were parsed before the error
    out = []
    for href in parser.hrefs:
        href = href.strip()
        if not href or href.startswith(("mailto:", "javascript:", "tel:", "#")):
            continue
        out.append(urljoin(base_url, href))
    return out


class RobotsCache:
    """Per-host ``robots.txt`` cache. ``fetch_text`` is injected so this
    module never opens a socket itself (fetch.py owns all networking)."""

    def __init__(self, fetch_text: Callable[[str], str | None]):
        self._fetch_text = fetch_text
        self._parsers: dict[str, RobotFileParser] = {}

    def allowed(self, url: str, user_agent: str) -> bool:
        parts = urlsplit(url)
        host_key = f"{parts.scheme}://{parts.netloc}"
        rp = self._parsers.get(host_key)
        if rp is None:
            rp = RobotFileParser()
            text = self._fetch_text(urljoin(host_key + "/", "robots.txt")) or ""
            rp.parse(text.splitlines())
            self._parsers[host_key] = rp
        try:
            return rp.can_fetch(user_agent, url)
        except Exception:
            return True  # fail open: an unparsable robots.txt never blocks discovery


# --------------------------------------------------------- direct-PDF probing

def candidate_probe_urls(prefix: str, years: Iterable[str], months: Iterable[int] = range(1, 13)) -> list[str]:
    """Generate candidate asset directory paths for a known upload pattern
    (e.g. CISCE ``/wp-content/uploads/YYYY/MM/``). The caller HEAD-probes each
    before ever issuing a GET (spec: "probe candidate URLs with HEAD before GET")."""
    return [f"{prefix.rstrip('/')}/{y}/{int(m):02d}/" for y in years for m in months]


# ------------------------------------------------------- search-page / hook

SearchHook = Callable[[str, str], list[str]]
_SEARCH_HOOK: SearchHook | None = None


def set_search_hook(hook: SearchHook | None) -> None:
    """Wire an external search provider — ``site:<domain> filetype:pdf <topic>``
    — for domains where directory crawling is Cloudflare-blocked (spec
    §Discovery.4, e.g. CISCE). Left unset by default: this build ships the
    seam, not a bundled search-engine client. An operator can call this with
    e.g. a SERP API wrapper or the harness's own web-search tool before
    invoking crawl.py for a blocked board."""
    global _SEARCH_HOOK
    _SEARCH_HOOK = hook


def get_search_hook() -> SearchHook | None:
    return _SEARCH_HOOK


def search_discover(domain: str, topic: str) -> list[str]:
    """Only ever returns URLs on the same official domain — a search hook can
    suggest candidates, but never enqueues an off-domain result."""
    if _SEARCH_HOOK is None:
        return []
    try:
        results = _SEARCH_HOOK(domain, topic) or []
    except Exception:
        return []
    return [u for u in results if domain_of(u) == domain or domain_of(u).endswith("." + domain)]
