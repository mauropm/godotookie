#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

"""Validate the 30-language fortune library and interface catalogue.

Checks structure, UTF-8/Unicode integrity, counts, duplicates, near-duplicates,
required fields, malformed text, placeholders and message lengths. Writes JSON
and Markdown reports and exits nonzero when a locale fails.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATEGORIES = {
    "luck", "hope", "love", "growth", "prosperity", "wisdom",
    "courage", "happiness", "resilience", "adventure", "generosity", "peace",
}
REQUIRED_FIELDS = {"id", "locale", "text", "category"}
MIN_RECORDS = 2000
MIN_LENGTH = 8
MAX_LENGTH = 240
NEAR_DUPLICATE_HAMMING = 5
PLACEHOLDER_PATTERNS = [
    re.compile(r"\{[^}]*\}"),
    re.compile(r"%[sdif]"),
    re.compile(r"\b(?:TODO|TBD|FIXME|LOREM|IPSUM|XXX)\b", re.IGNORECASE),
    re.compile(r"\{\{|\}\}"),
]
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
NONCHARACTERS = {0xFFFE, 0xFFFF, 0xFDD0, 0xFDEF}
# Conservative English-only guardrails. Content in other languages is reviewed
# by speakers; scanning for a handful of English words would create false alarms.
ENGLISH_NEGATIVE_RE = re.compile(
    r"\b(curse|doom|disaster|death|die|dying|cancer|illness|disease|"
    r"guarantee[ds]?|guaranteed|lottery jackpot|risk-free|get rich|"
    r"bad luck|misfortune|unlucky|hopeless|failure|hate)\b",
    re.IGNORECASE,
)


def normalize_for_compare(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).casefold()
    text = re.sub(r"[^\w\s]", " ", text, flags=re.UNICODE)
    return re.sub(r"\s+", " ", text).strip()


def shingles(text: str, size: int = 5) -> list[str]:
    compact = re.sub(r"\s+", " ", normalize_for_compare(text))
    if len(compact) <= size:
        return [compact]
    return [compact[i:i + size] for i in range(len(compact) - size + 1)]


def hash64(value: str) -> int:
    # Stable FNV-1a; Python's hash() is salted per process.
    result = 0xCBF29CE484222325
    for byte in value.encode("utf-8"):
        result ^= byte
        result = (result * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return result


def simhash(text: str) -> int:
    vector = [0] * 64
    for shingle in set(shingles(text)):
        hashed = hash64(shingle)
        for bit in range(64):
            vector[bit] += 1 if (hashed >> bit) & 1 else -1
    result = 0
    for bit, weight in enumerate(vector):
        if weight >= 0:
            result |= 1 << bit
    return result


def hamming(a: int, b: int) -> int:
    return (a ^ b).bit_count()


def find_near_duplicates(records: list[dict]) -> tuple[int, list[dict]]:
    hashes = [simhash(record["text"]) for record in records]
    buckets: dict[tuple[int, int], list[int]] = defaultdict(list)
    pairs: list[tuple[int, int, int]] = []
    seen: set[tuple[int, int]] = set()
    for index, value in enumerate(hashes):
        for band in range(4):
            key = (band, (value >> (band * 16)) & 0xFFFF)
            bucket = buckets[key]
            for candidate in bucket:
                pair = (min(index, candidate), max(index, candidate))
                if pair in seen:
                    continue
                seen.add(pair)
                distance = hamming(value, hashes[candidate])
                if distance <= NEAR_DUPLICATE_HAMMING:
                    normalized_a = normalize_for_compare(records[index]["text"])
                    normalized_b = normalize_for_compare(records[candidate]["text"])
                    if normalized_a == normalized_b:
                        continue
                    pairs.append((distance, index, candidate))
            bucket.append(index)
    pairs.sort(key=lambda item: item[0])
    samples = []
    for distance, first, second in pairs[:200]:
        samples.append({
            "distance": distance,
            "first_id": records[first]["id"],
            "first_text": records[first]["text"],
            "second_id": records[second]["id"],
            "second_text": records[second]["text"],
        })
    return len(pairs), samples


def validate_record(record: object, code: str, index: int) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []
    if not isinstance(record, dict):
        return [f"record {index}: not an object"], warnings
    missing = REQUIRED_FIELDS - set(record)
    if missing:
        failures.append(f"record {index}: missing fields {sorted(missing)}")
        return failures, warnings
    if not isinstance(record["id"], str) or not record["id"].strip():
        failures.append(f"record {index}: invalid id")
    if not isinstance(record["locale"], str) or record["locale"] != code:
        failures.append(f"record {index}: locale mismatch ({record.get('locale')!r})")
    if record["category"] not in CATEGORIES:
        failures.append(f"record {index}: invalid category {record['category']!r}")
    text = record["text"]
    if not isinstance(text, str):
        failures.append(f"record {index}: text is not a string")
        return failures, warnings
    if not text.strip():
        failures.append(f"record {index}: empty text")
        return failures, warnings
    if text != text.strip():
        failures.append(f"record {index}: leading/trailing whitespace")
    if "\n" in text or "\r" in text:
        failures.append(f"record {index}: contains newline")
    if CONTROL_RE.search(text):
        failures.append(f"record {index}: contains control characters")
    if any(ord(ch) in NONCHARACTERS for ch in text):
        failures.append(f"record {index}: contains Unicode noncharacters")
    try:
        text.encode("utf-8", errors="strict")
    except UnicodeEncodeError as exc:
        failures.append(f"record {index}: invalid Unicode ({exc})")
    if unicodedata.normalize("NFC", text) != text:
        warnings.append(f"record {index}: text is not NFC-normalised")
    min_length = 6 if code in {"zh", "ja"} else MIN_LENGTH
    if len(text) < min_length:
        failures.append(f"record {index}: too short ({len(text)} chars)")
    if len(text) > MAX_LENGTH:
        failures.append(f"record {index}: too long ({len(text)} chars)")
    for pattern in PLACEHOLDER_PATTERNS:
        if pattern.search(text):
            failures.append(f"record {index}: placeholder-like content")
            break
    if code == "en" and ENGLISH_NEGATIVE_RE.search(text):
        failures.append(f"record {index}: negative/guarantee language: {text!r}")
    return failures, warnings


def load_json(path: Path) -> tuple[object | None, str | None]:
    try:
        raw = path.read_bytes()
        raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        return None, f"invalid UTF-8: {exc}"
    except OSError as exc:
        return None, str(exc)
    try:
        return json.loads(raw.decode("utf-8")), None
    except json.JSONDecodeError as exc:
        return None, f"invalid JSON at line {exc.lineno}: {exc.msg}"


def validate_ui(code: str, expected_keys: list[str], ui_dir: Path) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []
    path = ui_dir / f"{code}.json"
    data, error = load_json(path)
    if error:
        return [f"UI: {error}"], warnings
    if not isinstance(data, dict):
        return ["UI: catalogue is not an object"], warnings
    missing = [key for key in expected_keys if key not in data]
    extra = [key for key in data if key not in expected_keys]
    if missing:
        failures.append(f"UI: missing keys {missing[:12]}")
    if extra:
        warnings.append(f"UI: extra keys {extra[:12]}")
    for key in expected_keys:
        if key not in data:
            continue
        value = data[key]
        if not isinstance(value, str) or not value.strip():
            failures.append(f"UI: empty/non-string value for {key}")
        elif CONTROL_RE.search(value):
            failures.append(f"UI: control characters in {key}")
    return failures, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", default=str(ROOT / "data"))
    parser.add_argument("--reports-dir", default=str(ROOT / "reports"))
    parser.add_argument("--no-near-duplicates", action="store_true", help="skip the slower near-duplicate scan")
    args = parser.parse_args()
    data_dir = Path(args.data_dir)
    reports_dir = Path(args.reports_dir)
    reports_dir.mkdir(parents=True, exist_ok=True)

    meta_data, meta_error = load_json(data_dir / "locales.json")
    if meta_error or not isinstance(meta_data, dict):
        print(f"FATAL: cannot read locales.json: {meta_error}", file=sys.stderr)
        return 2
    locales = meta_data.get("locales", [])
    codes = [item["code"] for item in locales if isinstance(item, dict) and item.get("code")]
    fallback = meta_data.get("fallback_locale", "en")

    en_data, en_error = load_json(data_dir / "ui" / f"{fallback}.json")
    expected_ui_keys = list(en_data.keys()) if isinstance(en_data, dict) and not en_error else []

    report = {
        "generated_at": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "minimum_records": MIN_RECORDS,
        "locale_count": len(codes),
        "locales": {},
        "totals": {"records": 0, "unique": 0, "failures": 0, "warnings": 0, "near_duplicates": 0},
    }
    overall_ok = True
    for meta in locales:
        code = str(meta["code"])
        path = data_dir / "fortunes" / f"{code}.json"
        failures: list[str] = []
        warnings: list[str] = []
        stats = {
            "native_name": meta.get("native_name"),
            "english_name": meta.get("english_name"),
            "file": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
            "records": 0,
            "unique": 0,
            "valid": 0,
            "exact_duplicates": 0,
            "near_duplicates": 0,
            "near_duplicate_samples": [],
            "min_length": 0,
            "max_length": 0,
            "average_length": 0.0,
            "failures": [],
            "warnings": [],
        }
        if not path.exists():
            failures.append("missing fortune file")
        else:
            data, error = load_json(path)
            if error:
                failures.append(error)
            elif not isinstance(data, list):
                failures.append("top-level value is not a list")
            else:
                stats["records"] = len(data)
                valid_records: list[dict] = []
                ids: set[str] = set()
                for index, record in enumerate(data):
                    record_failures, record_warnings = validate_record(record, code, index)
                    failures.extend(record_failures)
                    warnings.extend(record_warnings)
                    if record_failures or not isinstance(record, dict):
                        continue
                    record_id = record["id"]
                    if record_id in ids:
                        failures.append(f"record {index}: duplicate id {record_id}")
                        continue
                    ids.add(record_id)
                    if not re.fullmatch(re.escape(code) + r"-\d{4,}", record_id):
                        warnings.append(f"record {index}: unexpected id format {record_id!r}")
                    valid_records.append(record)
                texts = [record["text"] for record in valid_records]
                normalized = [normalize_for_compare(text) for text in texts]
                counts = Counter(normalized)
                duplicates = sum(1 for value in counts.values() if value > 1)
                duplicate_records = sum(value - 1 for value in counts.values() if value > 1)
                stats["exact_duplicates"] = duplicate_records
                unique_indexes = []
                seen = set()
                for index, value in enumerate(normalized):
                    if value not in seen:
                        seen.add(value)
                        unique_indexes.append(index)
                unique_records = [valid_records[i] for i in unique_indexes]
                stats["unique"] = len(unique_records)
                stats["valid"] = len(valid_records)
                lengths = [len(text) for text in texts]
                if lengths:
                    stats["min_length"] = min(lengths)
                    stats["max_length"] = max(lengths)
                    stats["average_length"] = round(sum(lengths) / len(lengths), 2)
                if duplicate_records:
                    warnings.append(f"{duplicate_records} exact duplicate records (not counted as unique)")
                if len(unique_records) < MIN_RECORDS:
                    failures.append(f"only {len(unique_records)} unique valid fortunes; {MIN_RECORDS} required")
                if not args.no_near_duplicates and len(unique_records) > 1:
                    near_count, near_samples = find_near_duplicates(unique_records)
                    stats["near_duplicates"] = near_count
                    stats["near_duplicate_samples"] = near_samples
                    if near_count:
                        warnings.append(f"{near_count} near-duplicate pairs flagged for editorial review")
        ui_failures, ui_warnings = validate_ui(code, expected_ui_keys, data_dir / "ui")
        failures.extend(ui_failures)
        warnings.extend(ui_warnings)
        stats["failures"] = failures
        stats["warnings"] = warnings
        stats["ok"] = not failures
        report["locales"][code] = stats
        report["totals"]["records"] += stats["records"]
        report["totals"]["unique"] += stats["unique"]
        report["totals"]["failures"] += len(failures)
        report["totals"]["warnings"] += len(warnings)
        report["totals"]["near_duplicates"] += stats["near_duplicates"]
        if failures:
            overall_ok = False

    report["ok"] = overall_ok
    json_path = reports_dir / "fortune-validation.json"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Fortune Library Validation",
        "",
        f"- Generated: {report['generated_at']}",
        f"- Locales: {len(codes)}",
        f"- Unique valid fortunes: {report['totals']['unique']:,}",
        f"- Minimum per locale: {MIN_RECORDS:,}",
        f"- Near-duplicate pairs flagged: {report['totals']['near_duplicates']:,}",
        f"- Result: **{'PASS' if overall_ok else 'FAIL'}**",
        "",
        "| Locale | Language | Records | Unique | Near-dups | Min/Max chars | Result |",
        "|---|---|---:|---:|---:|---|---|",
    ]
    for code in codes:
        item = report["locales"][code]
        result = "PASS" if item["ok"] else "FAIL"
        lines.append(
            f"| `{code}` | {item['native_name']} | {item['records']:,} | {item['unique']:,} | "
            f"{item['near_duplicates']:,} | {item['min_length']}/{item['max_length']} | {result} |"
        )
    lines.extend(["", "## Failures", ""])
    any_failure = False
    for code in codes:
        item = report["locales"][code]
        if item["failures"]:
            any_failure = True
            lines.append(f"### {code} — {item['native_name']}")
            lines.extend(f"- {failure}" for failure in item["failures"][:40])
            lines.append("")
    if not any_failure:
        lines.append("None. All locale datasets and interface catalogues passed.")
    lines.extend(["", "## Near-duplicate samples", ""])
    samples_written = 0
    for code in codes:
        item = report["locales"][code]
        if not item["near_duplicate_samples"]:
            continue
        lines.append(f"### {code} — {item['native_name']} ({item['near_duplicates']} pairs)")
        for sample in item["near_duplicate_samples"][:4]:
            lines.append(
                f"- `{sample['first_id']}` {sample['first_text']}\n"
                f"  - `{sample['second_id']}` {sample['second_text']}"
            )
            samples_written += 1
        lines.append("")
    if samples_written == 0:
        lines.append("No near-duplicate samples flagged.")
    lines.extend([
        "",
        "Near-duplicate flags are advisory and require fluent-speaker editorial review;",
        "they do not by themselves fail validation.",
        "",
    ])
    md_path = reports_dir / "fortune-validation.md"
    md_path.write_text("\n".join(lines), encoding="utf-8")

    print(f"Unique valid fortunes: {report['totals']['unique']:,}")
    print(f"Failures: {report['totals']['failures']}  Warnings: {report['totals']['warnings']}")
    print(f"Near-duplicate pairs flagged: {report['totals']['near_duplicates']:,}")
    print(f"Reports: {json_path} and {md_path}")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
