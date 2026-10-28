#!/usr/bin/env python3
"""Build alternate fortune libraries from translated 150-sentence phrase banks.

This is a resilience fallback for locales whose full-library machine-translation
pass is blocked by provider throttling. Each locale bank is a list of complete,
positive English sentences (one per source record). Two different sentences are
paired into each fortune, yielding 2,000+ unique two-sentence fortunes while
retaining category diversity. Banks remain subject to fluent-speaker review.

Usage:
    python3 tools/build_pair_fortunes.py --make-bank
    python3 tools/build_pair_fortunes.py --locales de,ja,he
"""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FORTUNE_DIR = ROOT / "data" / "fortunes"
BANK_DIR = FORTUNE_DIR / "_banks"
BANK_SIZE = 150
TARGET = 2100
MAX_LENGTH = 235
CATEGORIES = [
    "luck", "hope", "love", "growth", "prosperity", "wisdom",
    "courage", "happiness", "resilience", "adventure", "generosity", "peace",
]
NO_SPACE_SENTENCE_LANGS = {"zh", "ja"}
SEPARATORS = {
    "ar": " ",
    "fa": " ",
    "ur": " ",
    "he": " ",
    "hi": " ",
    "mr": " ",
    "bn": " ",
    "ta": " ",
    "te": " ",
    "th": " ",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def make_bank() -> None:
    curated = ROOT / "tools" / "curated_pair_bank.json"
    if not curated.exists():
        raise FileNotFoundError(f"missing curated source bank: {curated}")
    bank = load(curated)
    if len(bank) < BANK_SIZE:
        raise ValueError(f"curated bank has {len(bank)} sentences, needs {BANK_SIZE}")
    write(BANK_DIR / "en.json", bank[:BANK_SIZE])
    print(f"wrote English pair bank with {len(bank[:BANK_SIZE])} curated sentences")


def make_locale(code: str) -> None:
    bank_path = BANK_DIR / f"{code}.json"
    if not bank_path.exists():
        raise FileNotFoundError(f"missing translated sentence bank: {bank_path}")
    bank = load(bank_path)
    if len(bank) < 100:
        raise ValueError(f"{code} bank has only {len(bank)} usable sentences")
    separator = "" if code in NO_SPACE_SENTENCE_LANGS else " "
    rng = random.Random(90_123 + sum(ord(ch) for ch in code) * 31)
    pairs: list[tuple[int, int, str]] = []
    seen_pairs: set[tuple[int, int]] = set()
    seen_texts: set[str] = set()
    attempts = 0
    while len(pairs) < TARGET and attempts < TARGET * 160:
        attempts += 1
        a = rng.randrange(len(bank))
        b = rng.randrange(len(bank))
        if a == b:
            continue
        pair = (a, b) if a < b else (b, a)
        if pair in seen_pairs:
            continue
        text = bank[a]["text"].strip() + separator + bank[b]["text"].strip()
        if len(text) > MAX_LENGTH:
            continue
        key = text.casefold()
        if key in seen_texts:
            continue
        seen_pairs.add(pair)
        seen_texts.add(key)
        pairs.append((a, b, text))
    if len(pairs) < 2000:
        raise RuntimeError(f"{code}: only {len(pairs)} valid pairs")

    records = []
    for number, (a, _b, text) in enumerate(pairs, start=1):
        records.append({
            "id": f"{code}-{number:04d}",
            "locale": code,
            "text": text,
            "category": bank[a]["category"],
        })
    write(FORTUNE_DIR / f"{code}.json", records)
    print(f"wrote {code}: {len(records)} paired fortunes")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--make-bank", action="store_true")
    parser.add_argument("--locales", default="")
    args = parser.parse_args()
    if args.make_bank:
        make_bank()
    for code in [item.strip() for item in args.locales.split(",") if item.strip()]:
        make_locale(code)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
