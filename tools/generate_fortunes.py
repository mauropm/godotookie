#!/usr/bin/env python3
"""Build the offline fortune library and localised interface strings.

The English source is composed locally from a large, category-aware phrase
grammar.  Optional build-time translation seeds the other locales; the
resulting JSON is committed so the shipped game never uses the network.

Usage:
    python3 tools/generate_fortunes.py --all
    python3 tools/generate_fortunes.py --english
    python3 tools/generate_fortunes.py --translate --locales es,fr,ar
    python3 tools/generate_fortunes.py --ui --locales es,fr

The translation helper uses a public, keyless endpoint for drafting only.  All
non-English output must be reviewed by fluent speakers before release.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FORTUNE_DIR = ROOT / "data" / "fortunes"
UI_DIR = ROOT / "data" / "ui"
LOCALES_FILE = ROOT / "data" / "locales.json"
CATEGORIES = [
    "luck", "hope", "love", "growth", "prosperity", "wisdom",
    "courage", "happiness", "resilience", "adventure", "generosity", "peace",
]
PER_CATEGORY = 220
SEED = 731_2026

TEMPLATES = [
    "May {gift} find you {manner}.",
    "{gift} is closer than it appears.",
    "Your {quality} makes room for {gift}.",
    "{gift} arrives through {source}.",
    "You will discover {gift} {place}.",
    "Let {gift} meet you {manner}.",
    "Your {quality} heart welcomes {gift}.",
    "The {quality} you carry attracts {gift}.",
    "{ordinary} leads to {gift}.",
    "Something {adj} is growing from {source}.",
    "You are ready to welcome {gift}.",
    "A {adj} surprise waits {place}.",
    "Your {quality} turns {ordinary} into {gift}.",
    "{gift} draws nearer when you {action}.",
    "Notice {gift} {place}.",
    "The path ahead holds {gift}.",
    "{ordinary} will bring {gift}.",
    "You have permission to welcome {gift}.",
    "Keep {quality}; it is opening the way to {gift}.",
    "A {adj} new chapter begins with {gift}.",
    "{source} will lead you toward {gift}.",
    "Open your day to {gift}.",
    "With {quality}, {gift} becomes possible.",
    "Look for {gift} {place}.",
    "Your kindness returns as {gift}.",
    "A gentle {action_noun} invites {gift}.",
    "This season rewards your {quality} with {gift}.",
    "Where you see {ordinary}, {gift} is waiting.",
    "One {adj} choice can make room for {gift}.",
    "Good things gather around {gift}.",
    "You are moving toward {gift} with {quality}.",
    "Every {ordinary} carries a hint of {gift}.",
    "The small joy of {ordinary} points toward {gift}.",
    "Your {quality} spirit makes {gift} feel at home.",
    "{gift} is taking root {place}.",
    "Let {quality} guide you into {gift}.",
    "Today holds a gentle invitation to {gift}.",
    "Your {quality} is a bridge to {gift}.",
    "{gift} appears through the smallest {action_noun}.",
    "Good news follows {gift}.",
]

GIFTS = {
    "luck": [
        "a timely opportunity", "a lucky turn", "an open door", "an unexpected blessing",
        "a helpful coincidence", "a promising chance", "a bright opening", "a friendly twist of fate",
        "a well-timed meeting", "a fresh opportunity", "a small stroke of luck", "a fortunate beginning",
        "a path that opens", "a gentle nudge", "a pleasant surprise", "a promising invitation",
        "a moment of good timing", "a happy accident",
    ],
    "hope": [
        "a new beginning", "a brighter horizon", "a reason to hope", "a fresh start",
        "a hopeful future", "a clear morning", "a season of renewal", "a gentle new chapter",
        "a promise of change", "a light ahead", "a seed of possibility", "a day full of potential",
        "a hopeful surprise", "a clean page", "a path toward tomorrow", "a quiet renewal",
        "a new dream", "a second chance",
    ],
    "love": [
        "a warm connection", "a lasting friendship", "a kindred spirit", "an honest conversation",
        "a generous heart", "a gentle romance", "a trusted companion", "a joyful reunion",
        "a shared laugh", "a deeper understanding", "a circle of care", "a loving gesture",
        "a familiar warmth", "a new friend", "a tender moment", "a bond that grows",
        "a heartfelt message", "a place to belong",
    ],
    "growth": [
        "a new skill", "a deeper confidence", "a clearer purpose", "a fresh perspective",
        "a healthier habit", "a new understanding", "a stronger voice", "a patient practice",
        "a creative spark", "a meaningful lesson", "a wider view", "a brave question",
        "a personal breakthrough", "a chance to learn", "a useful insight", "a new rhythm",
        "a mature choice", "a step forward",
    ],
    "prosperity": [
        "steady abundance", "a fruitful effort", "a promising project", "a satisfying result",
        "a wise investment of time", "a growing opportunity", "a well-earned reward", "a productive season",
        "a resourceful idea", "a generous harvest", "a useful connection", "a successful collaboration",
        "a flourishing plan", "a thoughtful opportunity", "a moment of plenty", "a sound decision",
        "a new source of support", "a rewarding venture",
    ],
    "wisdom": [
        "a clear insight", "a wise decision", "a simple truth", "a peaceful answer",
        "a new perspective", "a gentle realization", "a timely question", "a thoughtful choice",
        "a deeper understanding", "a calm clarity", "a useful lesson", "a patient knowing",
        "a bright idea", "a quieter mind", "a trustworthy instinct", "a wise pause",
        "a meaningful insight", "a path made clear",
    ],
    "courage": [
        "a brave step", "quiet strength", "a bold beginning", "a confident voice",
        "a steady heart", "a courageous choice", "a new sense of resolve", "a fearless question",
        "a moment of bravery", "a strong first move", "a resilient spirit", "a daring dream",
        "a calm determination", "a proud achievement", "a chance to rise", "a welcome challenge",
        "a clear yes", "a heart ready to try",
    ],
    "happiness": [
        "everyday joy", "a bright moment", "a warm laugh", "a small delight",
        "a cheerful surprise", "a contented pause", "a happy memory", "a light heart",
        "a reason to smile", "a joyful gathering", "a pleasant discovery", "a sunny detour",
        "a playful idea", "a sweet surprise", "a peaceful pleasure", "a moment worth savoring",
        "a genuine smile", "a day touched by light",
    ],
    "resilience": [
        "renewed strength", "a second wind", "a fresh reserve of hope", "a quiet comeback",
        "a resilient heart", "a new way forward", "a gentle rebound", "a stronger foundation",
        "a calm after effort", "a brave return", "a helpful reset", "a patient rebuild",
        "a moment of renewal", "a deep breath", "a clearer next step", "a soft place to land",
        "a reason to keep going", "a steady spirit",
    ],
    "adventure": [
        "a surprising journey", "a fresh path", "a new horizon", "a curious detour",
        "a memorable encounter", "a bold exploration", "a creative adventure", "an unexpected invitation",
        "a bright unknown", "a chance to wander", "a story worth telling", "a new place to discover",
        "a playful challenge", "a road with a view", "a delightful surprise", "an open map",
        "a small expedition", "a moment of wonder",
    ],
    "generosity": [
        "a generous gesture", "a circle of care", "a shared blessing", "a kind return",
        "a warm welcome", "a helping hand", "a meaningful gift", "a moment of giving",
        "a stronger community", "a thoughtful contribution", "a ripple of kindness", "a neighborly hello",
        "a shared meal", "a generous offer", "a caring connection", "a small act with a big heart",
        "a gift of time", "a place at the table",
    ],
    "peace": [
        "a calm center", "a gentle pause", "a quiet mind", "a peaceful moment",
        "a softer pace", "a restful evening", "a clear breath", "a tranquil corner",
        "a steady stillness", "a kind silence", "a moment of balance", "a releasing sigh",
        "a warm calm", "a peaceful morning", "a gentle boundary", "a quiet joy",
        "a place of ease", "a calm heart",
    ],
}

QUALITIES = [
    "patience", "kindness", "curiosity", "courage", "honesty", "warmth", "calm",
    "resilience", "generosity", "openness", "good humor", "steady effort",
    "hopefulness", "gentleness",
]
SOURCES = [
    "a thoughtful conversation", "a generous gesture", "an honest friendship",
    "a patient effort", "a moment of rest", "a shared meal", "a warm hello",
    "a curious question", "a familiar song", "a walk in the open air",
    "a kind message", "a new routine", "a little courage", "a hopeful plan",
    "a cheerful memory", "a peaceful pause",
]
PLACES = [
    "in everyday moments", "in quiet corners", "among the people around you",
    "in your morning routine", "along a familiar path", "in a shared smile",
    "in the pause between tasks", "near the edge of something new", "in your own home",
    "in a favorite place", "on an ordinary afternoon", "in the middle of a busy day",
    "in a warm conversation", "beside a good friend", "in a small, unexpected detail",
    "at the start of a new habit",
]
ADJECTIVES = [
    "gentle", "bright", "steady", "warm", "hopeful", "joyful", "peaceful",
    "generous", "brave", "curious", "kind", "fresh", "golden", "quiet",
    "open", "thoughtful", "resilient", "radiant", "easy", "tender",
]
MANNERS = [
    "quietly", "gently", "in unexpected ways", "at just the right moment",
    "through everyday moments", "with a warm surprise", "in your own time",
    "from an unlikely direction", "like a soft sunrise", "with quiet delight",
    "sooner than you think", "in a way that feels right",
]
ORDINARY = [
    "a kind word", "a quiet morning", "a shared smile", "an honest conversation",
    "a small pause", "a familiar routine", "a moment of rest", "a thoughtful question",
    "a generous gesture", "a warm meal", "a walk outside", "a friendly hello",
    "a simple plan", "a patient effort", "a hopeful thought", "a good night's rest",
]
ACTIONS = [
    "pause", "listen", "share what you have", "take one small step", "speak kindly",
    "make time to rest", "ask a thoughtful question", "say yes to a new idea",
    "let yourself be helped", "welcome the unexpected", "choose patience",
    "follow your curiosity", "offer a warm word", "take a deep breath",
    "trust your own pace", "notice what is good", "reach out to a friend",
    "make room for joy", "begin again", "keep going",
]
ACTION_NOUNS = [
    "step", "pause", "question", "hello", "conversation", "moment of rest",
    "act of kindness", "new habit",
]

# Nigerian Pidgin is authored rather than machine-translated.
PCM_GIFTS = {
    "luck": [
        "good luck", "sweet opportunity", "open door", "surprise blessing",
        "helpful coincidence", "bright chance", "good timing", "friendly meeting",
        "fresh chance", "small luck", "happy beginning", "road wey open",
        "gentle push", "sweet surprise", "good invitation", "happy accident",
        "better timing", "lucky turn",
    ],
    "hope": [
        "new beginning", "brighter tomorrow", "reason to hope", "fresh start",
        "hopeful future", "clear morning", "new season", "new chapter",
        "promise of change", "light ahead", "seed of possibility", "day full of chance",
        "hopeful surprise", "clean page", "road to tomorrow", "quiet renewal",
        "new dream", "second chance",
    ],
    "love": [
        "warm connection", "true friendship", "kindred spirit", "honest talk",
        "generous heart", "gentle love", "trusted friend", "sweet reunion",
        "shared laugh", "deeper understanding", "circle of care", "loving gesture",
        "familiar warmth", "new friend", "tender moment", "bond wey grow",
        "heartfelt message", "place to belong",
    ],
    "growth": [
        "new skill", "deeper confidence", "clearer purpose", "fresh view",
        "better habit", "new understanding", "stronger voice", "patient practice",
        "creative spark", "meaningful lesson", "wider view", "brave question",
        "personal breakthrough", "chance to learn", "useful insight", "new rhythm",
        "mature choice", "step forward",
    ],
    "prosperity": [
        "steady blessing", "fruitful work", "promising project", "sweet result",
        "wise use of time", "growing opportunity", "well-earned reward", "productive season",
        "resourceful idea", "generous harvest", "useful connection", "successful collaboration",
        "flourishing plan", "thoughtful opportunity", "moment of plenty", "sound decision",
        "new support", "rewarding venture",
    ],
    "wisdom": [
        "clear insight", "wise decision", "simple truth", "peaceful answer",
        "new perspective", "gentle realization", "timely question", "thoughtful choice",
        "deeper understanding", "calm clarity", "useful lesson", "patient knowing",
        "bright idea", "quieter mind", "trustworthy instinct", "wise pause",
        "meaningful insight", "clear road",
    ],
    "courage": [
        "brave step", "quiet strength", "bold beginning", "confident voice",
        "steady heart", "courageous choice", "new resolve", "fearless question",
        "moment of bravery", "strong first move", "resilient spirit", "daring dream",
        "calm determination", "proud achievement", "chance to rise", "welcome challenge",
        "clear yes", "heart ready to try",
    ],
    "happiness": [
        "everyday joy", "bright moment", "warm laugh", "small delight",
        "cheerful surprise", "contented pause", "happy memory", "light heart",
        "reason to smile", "joyful gathering", "pleasant discovery", "sunny detour",
        "playful idea", "sweet surprise", "peaceful pleasure", "moment to savor",
        "genuine smile", "day touched by light",
    ],
    "resilience": [
        "renewed strength", "second wind", "fresh hope", "quiet comeback",
        "resilient heart", "new way forward", "gentle rebound", "stronger foundation",
        "calm after effort", "brave return", "helpful reset", "patient rebuild",
        "moment of renewal", "deep breath", "clear next step", "soft place to land",
        "reason to continue", "steady spirit",
    ],
    "adventure": [
        "surprising journey", "fresh path", "new horizon", "curious detour",
        "memorable meeting", "bold exploration", "creative adventure", "unexpected invitation",
        "bright unknown", "chance to wander", "story worth telling", "new place to discover",
        "playful challenge", "road with a view", "delightful surprise", "open map",
        "small expedition", "moment of wonder",
    ],
    "generosity": [
        "generous gesture", "circle of care", "shared blessing", "kind return",
        "warm welcome", "helping hand", "meaningful gift", "moment of giving",
        "stronger community", "thoughtful contribution", "ripple of kindness", "neighborly hello",
        "shared meal", "generous offer", "caring connection", "small act with big heart",
        "gift of time", "place at the table",
    ],
    "peace": [
        "calm center", "gentle pause", "quiet mind", "peaceful moment",
        "softer pace", "restful evening", "clear breath", "tranquil corner",
        "steady stillness", "kind silence", "moment of balance", "releasing sigh",
        "warm calm", "peaceful morning", "gentle boundary", "quiet joy",
        "place of ease", "calm heart",
    ],
}
PCM_TEMPLATES = [
    "Good luck go find you {manner}.",
    "{gift} dey close to you.",
    "Your {quality} dey open door for {gift}.",
    "{gift} dey come through {source}.",
    "You go find {gift} {place}.",
    "Make {gift} meet you {manner}.",
    "Your {quality} heart welcome {gift}.",
    "The {quality} wey you get go attract {gift}.",
    "{ordinary} go lead you to {gift}.",
    "Something sweet dey grow from {source}.",
    "You ready to welcome {gift}.",
    "Sweet surprise dey wait for you {place}.",
    "Your {quality} dey turn {ordinary} to {gift}.",
    "{gift} dey come near when you {action}.",
    "Notice {gift} {place}.",
    "The road ahead get {gift}.",
    "{ordinary} go bring {gift}.",
    "You get permission to welcome {gift}.",
    "Keep {quality}; e dey open way to {gift}.",
    "New chapter dey start with {gift}.",
    "{source} go carry you toward {gift}.",
    "Open your day for {gift}.",
    "With {quality}, {gift} dey possible.",
    "Look for {gift} {place}.",
    "Your kindness go come back as {gift}.",
    "One gentle {action_noun} invite {gift}.",
    "This season dey reward your {quality} with {gift}.",
    "Where you see {ordinary}, {gift} dey wait.",
    "One sweet choice go make room for {gift}.",
    "Good things dey gather around {gift}.",
    "You dey move toward {gift} with {quality}.",
    "Every {ordinary} carry small sign of {gift}.",
    "The small joy of {ordinary} dey point to {gift}.",
    "Your {quality} spirit dey make {gift} feel at home.",
    "{gift} dey take root {place}.",
    "Make {quality} guide you enter {gift}.",
    "Today get gentle invitation to {gift}.",
    "Your {quality} be bridge to {gift}.",
    "{gift} dey show through the smallest {action_noun}.",
    "Good news dey follow {gift}.",
]
PCM_QUALITIES = [
    "patience", "kindness", "curiosity", "courage", "honesty", "warm heart",
    "calm", "strength", "generosity", "open mind", "good laugh", "steady work",
    "hope", "gentleness",
]
PCM_SOURCES = [
    "one kind conversation", "one generous hand", "one honest friendship",
    "one patient effort", "one small rest", "one shared meal", "one warm hello",
    "one good question", "one familiar song", "one walk outside",
    "one kind message", "one new routine", "one small courage", "one hopeful plan",
    "one sweet memory", "one peaceful pause",
]
PCM_PLACES = [
    "for everyday moments", "for quiet corner", "around your people",
    "for your morning", "along road wey you know", "inside one shared smile",
    "for the pause between work", "near something new", "for your own house",
    "for one favorite place", "for ordinary afternoon", "inside one busy day",
    "inside one warm talk", "beside one good friend", "inside one small detail",
    "for the start of new habit",
]
PCM_ADJECTIVES = [
    "gentle", "bright", "steady", "warm", "hopeful", "joyful", "peaceful",
    "generous", "brave", "curious", "kind", "fresh", "golden", "quiet",
    "open", "thoughtful", "strong", "radiant", "easy", "tender",
]
PCM_MANNERS = [
    "small small", "softly", "in way you no expect", "at the right time",
    "through everyday things", "with warm surprise", "for your own time",
    "from place you no expect", "like soft morning light", "with quiet joy",
    "before you think", "in way wey feel right",
]
PCM_ORDINARY = [
    "one kind word", "one quiet morning", "one shared smile", "one honest talk",
    "one small pause", "one familiar routine", "one moment of rest", "one good question",
    "one generous hand", "one warm meal", "one walk outside", "one friendly hello",
    "one simple plan", "one patient effort", "one hopeful thought", "one good night rest",
]
PCM_ACTIONS = [
    "wait small", "listen well", "share wetin you get", "take one small step",
    "talk kind", "rest well", "ask good question", "accept help",
    "welcome surprise", "choose patience", "follow your curiosity", "give warm word",
    "breathe deep", "trust your pace", "notice good things", "reach out to friend",
    "make room for joy", "start again", "continue", "do your best",
]
PCM_ACTION_NOUNS = [
    "step", "pause", "question", "hello", "conversation", "small rest",
    "act of kindness", "new habit",
]


def clean_text(text: str) -> str:
    text = re.sub(r"[\u200b\uFEFF]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def render(template: str, category: str, rng: random.Random,
           gifts: dict[str, list[str]], qualities: list[str], sources: list[str],
           places: list[str], adjectives: list[str], manners: list[str],
           ordinary: list[str], actions: list[str], action_nouns: list[str]) -> str:
    values = {
        "gift": rng.choice(gifts[category]),
        "quality": rng.choice(qualities),
        "source": rng.choice(sources),
        "place": rng.choice(places),
        "adj": rng.choice(adjectives),
        "manner": rng.choice(manners),
        "ordinary": rng.choice(ordinary),
        "action": rng.choice(actions),
        "action_noun": rng.choice(action_nouns),
    }
    text = template.format(**values)
    text = clean_text(text)
    return text[:1].upper() + text[1:]


def build_locale(code: str, *, pidgin: bool = False) -> list[dict]:
    rng = random.Random(SEED + sum(ord(c) for c in code) * 97)
    if pidgin:
        gifts, templates, qualities, sources, places = PCM_GIFTS, PCM_TEMPLATES, PCM_QUALITIES, PCM_SOURCES, PCM_PLACES
        adjectives, manners, ordinary, actions, nouns = PCM_ADJECTIVES, PCM_MANNERS, PCM_ORDINARY, PCM_ACTIONS, PCM_ACTION_NOUNS
    else:
        gifts, templates, qualities, sources, places = GIFTS, TEMPLATES, QUALITIES, SOURCES, PLACES
        adjectives, manners, ordinary, actions, nouns = ADJECTIVES, MANNERS, ORDINARY, ACTIONS, ACTION_NOUNS
    seen: set[str] = set()
    records: list[dict] = []
    number = 1
    for category in CATEGORIES:
        count = 0
        attempts = 0
        while count < PER_CATEGORY and attempts < PER_CATEGORY * 200:
            attempts += 1
            text = render(rng.choice(templates), category, rng, gifts, qualities, sources,
                          places, adjectives, manners, ordinary, actions, nouns)
            key = text.casefold()
            if key in seen:
                continue
            seen.add(key)
            records.append({
                "id": f"{code}-{number:04d}",
                "locale": code,
                "text": text,
                "category": category,
            })
            number += 1
            count += 1
        if count < PER_CATEGORY:
            raise RuntimeError(f"Could only build {count}/{PER_CATEGORY} {category} fortunes for {code}")
    return records


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def load_locale_meta() -> list[dict]:
    return json.loads(LOCALES_FILE.read_text(encoding="utf-8"))["locales"]


def translate_texts(texts: list[str], target: str) -> list[str]:
    """Translate a list of newline-delimited strings, preserving order."""
    result: list[str] = []
    batch_size = 50
    for start in range(0, len(texts), batch_size):
        batch = texts[start:start + batch_size]
        translated = _translate_batch(batch, target)
        if translated is None:
            for item in batch:
                one = _translate_batch([item], target)
                if one is None or len(one) != 1:
                    raise RuntimeError(f"Translation failed for {target}: {item[:80]!r}")
                result.extend(one)
            translated = []
        result.extend(translated)
        if start % (batch_size * 8) == 0:
            print(f"  {target}: {min(start + batch_size, len(texts))}/{len(texts)}", flush=True)
        time.sleep(0.45)
    return result


def _translate_batch(texts: list[str], target: str) -> list[str] | None:
    query = "\n".join(texts)
    payload = urllib.parse.urlencode({
        "client": "gtx", "sl": "en", "tl": target, "dt": "t", "q": query,
    }).encode("utf-8")
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single",
        data=payload,
        headers={
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "User-Agent": "FortuneCookieContentBuilder/1.0 (offline game build)",
        },
        method="POST",
    )
    last_error = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                data = json.loads(response.read().decode("utf-8"))
            text = "".join(segment[0] for segment in data[0] if segment and segment[0])
            lines = text.split("\n")
            while lines and not lines[-1].strip():
                lines.pop()
            lines = [clean_text(line) for line in lines]
            if len(lines) == len(texts) and all(lines):
                return lines
            return None
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code == 429:
                time.sleep(12.0 * (attempt + 1))
            else:
                time.sleep(2.0 * (attempt + 1))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            time.sleep(2.0 * (attempt + 1))
    print(f"  translation error for {target}: {last_error}", file=sys.stderr)
    return None


def translate_locale(code: str, meta: dict, english: list[dict]) -> None:
    target = meta.get("google")
    if not target:
        raise RuntimeError(f"No translation target for {code}")
    out_path = FORTUNE_DIR / f"{code}.json"
    if out_path.exists():
        print(f"skip {code}: {out_path} exists")
        return
    print(f"translating {code} ({target})...", flush=True)
    english = english[:2200]
    texts = [record["text"] for record in english]
    translated = translate_texts(texts, target)
    seen: set[str] = set()
    records = []
    for source, text in zip(english, translated):
        text = clean_text(text)
        if not text:
            continue
        key = text.casefold()
        if key in seen:
            continue
        seen.add(key)
        record = dict(source)
        record["locale"] = code
        record["id"] = f"{code}-{source['id'].split('-')[-1]}"
        record["text"] = text
        records.append(record)
    if len(records) < 2000:
        raise RuntimeError(f"{code}: only {len(records)} unique translated fortunes")
    write_json(out_path, records)
    print(f"wrote {code}: {len(records)} records", flush=True)


def translate_ui(code: str, meta: dict) -> None:
    target = meta.get("google")
    if not target:
        return
    out_path = UI_DIR / f"{code}.json"
    if out_path.exists():
        print(f"skip UI {code}: exists")
        return
    english = json.loads((UI_DIR / "en.json").read_text(encoding="utf-8"))
    keys = list(english)
    values = [english[key] for key in keys]
    translated = translate_texts(values, target)
    data = {key: value for key, value in zip(keys, translated)}
    # Brand and short labels read more naturally when kept consistent.
    data.setdefault("app_title", english["app_title"])
    write_json(out_path, data)
    print(f"wrote UI {code}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--english", action="store_true")
    parser.add_argument("--pidgin", action="store_true")
    parser.add_argument("--translate", action="store_true")
    parser.add_argument("--ui", action="store_true")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--locales", default="")
    parser.add_argument("--workers", type=int, default=1)
    args = parser.parse_args()
    FORTUNE_DIR.mkdir(parents=True, exist_ok=True)
    UI_DIR.mkdir(parents=True, exist_ok=True)

    if args.all or args.english:
        english_path = FORTUNE_DIR / "en.json"
        if not english_path.exists() or args.english:
            records = build_locale("en")
            write_json(english_path, records)
            print(f"wrote en: {len(records)} records")

    if args.all or args.pidgin:
        pcm_path = FORTUNE_DIR / "pcm.json"
        if not pcm_path.exists() or args.pidgin:
            records = build_locale("pcm", pidgin=True)
            write_json(pcm_path, records)
            print(f"wrote pcm: {len(records)} records")

    meta = load_locale_meta()
    by_code = {item["code"]: item for item in meta}
    wanted = [code.strip() for code in args.locales.split(",") if code.strip()]
    if args.all:
        wanted = [item["code"] for item in meta if item["code"] not in {"en", "pcm"}]
    if args.translate and wanted:
        english = json.loads((FORTUNE_DIR / "en.json").read_text(encoding="utf-8"))
        tasks = [(code, by_code[code], english) for code in wanted]
        failures: list[str] = []
        if args.workers > 1:
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
                futures = {pool.submit(translate_locale, code, item, source): code for code, item, source in tasks}
                for future in concurrent.futures.as_completed(futures):
                    try:
                        future.result()
                    except Exception as exc:  # keep going so the UI catalogue can finish
                        code = futures[future]
                        failures.append(code)
                        print(f"fortune translation failed for {code}: {exc}", file=sys.stderr)
        else:
            for code, item, source in tasks:
                try:
                    translate_locale(code, item, source)
                except Exception as exc:
                    failures.append(code)
                    print(f"fortune translation failed for {code}: {exc}", file=sys.stderr)

    if args.ui and wanted:
        for code in wanted:
            try:
                translate_ui(code, by_code[code])
            except Exception as exc:
                print(f"UI translation failed for {code}: {exc}", file=sys.stderr)
    return 1 if 'failures' in locals() and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
