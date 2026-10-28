#!/usr/bin/env python3
"""Generate original, dependency-free sound effects for the game."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(20261027)


def write_wav(name: str, samples: list[float], peak: float = 0.72) -> None:
    highest = max(1e-9, max(abs(sample) for sample in samples))
    gain = peak / highest
    with wave.open(str(OUT / name), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = bytearray()
        for sample in samples:
            value = int(max(-1.0, min(1.0, sample * gain)) * 32767)
            frames.extend(struct.pack("<h", value))
        handle.writeframes(frames)
    print(f"wrote {name} ({len(samples) / RATE:.2f}s)")


def lowpass_noise(duration: float, cutoff: float, seed: int = 1) -> list[float]:
    rng = random.Random(seed)
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    value = 0.0
    out = []
    for _ in range(int(RATE * duration)):
        value += alpha * (rng.uniform(-1, 1) - value)
        out.append(value)
    return out


def crack() -> None:
    duration = 0.46
    n = int(RATE * duration)
    rng = random.Random(41)
    noise = lowpass_noise(duration, 6200, 42)
    low = lowpass_noise(duration, 240, 43)
    samples = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 34.0)
        snap = noise[i] * env * 1.1
        body = low[i] * math.exp(-t * 16.0) * 0.8
        second = 0.0
        if t > 0.075:
            dt = t - 0.075
            second = noise[i] * math.exp(-dt * 28.0) * 0.42
        click = math.sin(2 * math.pi * 135 * t) * math.exp(-t * 35.0) * 0.28
        samples.append(snap + body + second + click)
    # tiny silence tail to avoid an abrupt cutoff
    samples.extend([0.0] * int(RATE * 0.03))
    write_wav("crack.wav", samples, 0.78)


def paper() -> None:
    duration = 0.62
    n = int(RATE * duration)
    noise = lowpass_noise(duration, 4700, 71)
    high = lowpass_noise(duration, 9000, 72)
    samples = []
    for i in range(n):
        t = i / RATE
        env = math.sin(math.pi * min(1.0, t / duration)) ** 1.4
        flutter = 0.62 + 0.38 * math.sin(2 * math.pi * 13 * t + 0.4)
        sample = (noise[i] * 0.6 + high[i] * 0.25) * env * flutter
        samples.append(sample)
    write_wav("paper.wav", samples, 0.44)


def chime() -> None:
    duration = 1.7
    n = int(RATE * duration)
    notes = [(659.25, 0.0, 1.0), (783.99, 0.12, 0.72), (987.77, 0.25, 0.58), (1318.5, 0.39, 0.34)]
    samples = [0.0] * n
    for frequency, offset, level in notes:
        start = int(offset * RATE)
        for i in range(start, n):
            t = (i - start) / RATE
            env = math.exp(-t * 2.8) * (1.0 - math.exp(-t * 80.0))
            tone = (
                math.sin(2 * math.pi * frequency * t)
                + 0.28 * math.sin(2 * math.pi * frequency * 2.01 * t)
                + 0.12 * math.sin(2 * math.pi * frequency * 3.98 * t)
            )
            samples[i] += tone * env * level * 0.22
    write_wav("chime.wav", samples, 0.52)


def click() -> None:
    duration = 0.085
    n = int(RATE * duration)
    samples = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 75.0)
        samples.append((math.sin(2 * math.pi * 880 * t) * 0.6 + math.sin(2 * math.pi * 1320 * t) * 0.2) * env)
    write_wav("click.wav", samples, 0.28)


if __name__ == "__main__":
    crack()
    paper()
    chime()
    click()
