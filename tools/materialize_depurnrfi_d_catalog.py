#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

CANONICAL_SOURCE_TEXT_SHA256 = "c46dc9a945d37e3e53e2a6e3879045c6c7de38b25ea5f92894fded5cbaff857b"
EXPECTED_COUNTS = {
    "F1": 27, "F2": 69, "F3": 80, "F4": 124, "F5": 145,
    "F6": 144, "F7": 152, "F8": 85, "F9": 93,
    "D1": 19, "D2": 20, "F10": 54, "F11": 45,
}
SOURCE_TO_PHASE = {"F3A": "F3", "F4A": "F4", "F5A": "F5", "F6A": "F6", "F7A": "F7", "F8A": "F8", "F9A": "F9"}
HEADING_RE = re.compile(
    r"^(?:#{1,6}\s+)?"
    r"(F(?:1|2|3A|4A|5A|6A|7A|8A|9A|10|11)|D(?:1|2))"
    r"\.(\d+)\s+[—-]\s+(.+?)\s*$"
)


def normalized_text(path: Path) -> str:
    # text mode intentionally normalizes CRLF/LF exactly as the canonical
    # exported-text fingerprint used by the production catalog.
    return path.read_text(encoding="utf-8")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def parse_catalog(text: str) -> list[dict]:
    lines = text.splitlines()
    headings: list[tuple[int, re.Match[str]]] = []
    for index, line in enumerate(lines):
        match = HEADING_RE.match(line)
        if match:
            headings.append((index, match))

    rows: list[dict] = []
    for pos, (start_idx, match) in enumerate(headings):
        end_idx = headings[pos + 1][0] - 1 if pos + 1 < len(headings) else len(lines) - 1
        source_prefix, number, title = match.groups()
        phase = SOURCE_TO_PHASE.get(source_prefix, source_prefix)
        source_code = f"{source_prefix}.{number}"
        requirement_id = source_code
        section_lines = lines[start_idx : end_idx + 1]
        heading_text = f"{source_code} — {title.strip()}"
        if section_lines:
            section_lines[0] = heading_text
        requirement_text = "\n".join(section_lines).strip()
        rows.append(
            {
                "requirement_id": requirement_id,
                "phase_code": phase,
                "source_code": source_code,
                "title": title.strip(),
                "source_start_line": start_idx + 1,
                "source_end_line": end_idx + 1,
                "section_hash": sha256_text(requirement_text),
                "requirement_text": requirement_text,
                "source_text_sha256": CANONICAL_SOURCE_TEXT_SHA256,
            }
        )
    return rows


def validate(rows: list[dict], source_hash: str) -> None:
    if source_hash != CANONICAL_SOURCE_TEXT_SHA256:
        raise SystemExit(
            f"SOURCE_HASH_MISMATCH expected={CANONICAL_SOURCE_TEXT_SHA256} got={source_hash}"
        )
    counts = Counter(row["phase_code"] for row in rows)
    if len(rows) != 1057:
        raise SystemExit(f"CATALOG_COUNT_MISMATCH expected=1057 got={len(rows)}")
    if dict(counts) != EXPECTED_COUNTS:
        raise SystemExit(f"PHASE_COUNT_MISMATCH expected={EXPECTED_COUNTS} got={dict(counts)}")
    ids = [row["requirement_id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise SystemExit("DUPLICATE_REQUIREMENT_ID")
    if any(row["source_start_line"] <= 0 or row["source_end_line"] < row["source_start_line"] for row in rows):
        raise SystemExit("INVALID_SOURCE_LOCATOR")
    if any(row["title"].startswith("Canonical source subsection ") for row in rows):
        raise SystemExit("PLACEHOLDER_TITLE_FORBIDDEN")


def main() -> int:
    parser = argparse.ArgumentParser(description="Materialize @AnalistaDepuracionRNFI_D canonical requirement catalog")
    parser.add_argument("source", type=Path, help="Canonical Drive text export")
    parser.add_argument("-o", "--output", type=Path, help="Write JSON to this file instead of stdout")
    args = parser.parse_args()

    text = normalized_text(args.source)
    source_hash = sha256_text(text)
    rows = parse_catalog(text)
    validate(rows, source_hash)
    payload = {
        "source_text_sha256": source_hash,
        "requirement_count": len(rows),
        "phase_counts": EXPECTED_COUNTS,
        "requirements": rows,
    }
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
