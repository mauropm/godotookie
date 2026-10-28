#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

"""Build-time NLLB-200 translation of the 150-sentence phrase banks.

This tool is not used by the shipped game and is not a runtime dependency. It
requires ctranslate2, transformers, sentencepiece and the int8 CTranslate2 NLLB
model. See docs/LOCALIZATION_REVIEW.md for license and review notes.

Example:
    python3 tools/translate_nllb.py --model /tmp/opencode/nllb-model --locales de,ja,he
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK_DIR = ROOT / "data" / "fortunes" / "_banks"
NLLB_LANGS = {
    "de": "deu_Latn",
    "ja": "jpn_Jpan",
    "mr": "mar_Deva",
    "te": "tel_Telu",
    "tr": "tur_Latn",
    "ta": "tam_Taml",
    "vi": "vie_Latn",
    "ko": "kor_Hang",
    "it": "ita_Latn",
    "th": "tha_Thai",
    "fa": "pes_Arab",
    "sw": "swh_Latn",
    "ha": "hau_Latn",
    "yo": "yor_Latn",
    "nl": "nld_Latn",
    "pl": "pol_Latn",
    "fil": "tgl_Latn",
    "he": "heb_Hebr",
    "id": "ind_Latn",
}
PUNCTUATION_END = tuple(".!?。！？…؟।॥")
CJK = {"ja", "zh"}


def clean(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace(" ,", ",").replace(" .", ".")
    return text


def ensure_punctuation(text: str, code: str) -> str:
    if not text:
        return text
    if code == "ja":
        text = re.sub(r"(?<=[぀-ヿ一-鿿]) +(?=[぀-ヿ一-鿿])", "", text)
        text = text.replace(",", "、").replace(".", "。")
    if text.endswith(PUNCTUATION_END):
        return text
    if code in CJK:
        return text + "。"
    return text + "."


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="/tmp/opencode/nllb-model")
    parser.add_argument("--locales", required=True)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--beam-size", type=int, default=4)
    args = parser.parse_args()

    import ctranslate2
    import transformers

    source_bank = json.loads((BANK_DIR / "en.json").read_text(encoding="utf-8"))
    translator = ctranslate2.Translator(
        args.model, device="cpu", compute_type="int8", inter_threads=1, intra_threads=8
    )
    requested = [item.strip() for item in args.locales.split(",") if item.strip()]
    for code in requested:
        if code not in NLLB_LANGS:
            raise SystemExit(f"Unsupported NLLB locale: {code}")
        target = NLLB_LANGS[code]
        tokenizer = transformers.AutoTokenizer.from_pretrained(args.model, src_lang="eng_Latn")
        translated: list[str] = []
        for start in range(0, len(source_bank), args.batch_size):
            batch = source_bank[start:start + args.batch_size]
            token_batch = [
                tokenizer.convert_ids_to_tokens(tokenizer.encode(item["text"]))
                for item in batch
            ]
            results = translator.translate_batch(
                token_batch,
                target_prefix=[[target] for _ in batch],
                beam_size=args.beam_size,
                max_decoding_length=160,
                max_batch_size=args.batch_size,
            )
            for result in results:
                tokens = result.hypotheses[0][1:]
                text = tokenizer.decode(tokenizer.convert_tokens_to_ids(tokens), skip_special_tokens=True)
                translated.append(ensure_punctuation(clean(text), code))
            print(f"  {code}: {min(start + args.batch_size, len(source_bank))}/{len(source_bank)}", flush=True)
        if len(translated) != len(source_bank):
            raise RuntimeError(f"Translation count mismatch for {code}")
        bank = []
        for item, text in zip(source_bank, translated):
            if not text:
                raise RuntimeError(f"Empty translation for {code}: {item['text']}")
            bank.append({"id": item["id"], "category": item["category"], "text": text})
        output = BANK_DIR / f"{code}.json"
        output.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {output} ({len(bank)} sentences)")
        for sample in bank[:3]:
            print("   ", sample["text"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
