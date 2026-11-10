#!/usr/bin/env python3
"""Regenerate every The Hill sound effect, loop, synth music stem and placeholder bark.
Standard library + ffmpeg only.

    python3 assets/audio/tools/make_cues.py                    # everything (parallel)
    python3 assets/audio/tools/make_cues.py dig_dirt_1 fall_2   # just these files
    python3 assets/audio/tools/make_cues.py --list              # stems and their kinds
    python3 assets/audio/tools/make_cues.py --preview handoff/sfx_preview.ogg

Primitives and the loudness pass are copied from spaceballs/assets/audio/tools/make_cues.py
(itself from openjar-launcher). Every sound is synthesised here, seeded per file
("openjar-the-hill:<stem>") so the output is byte-reproducible. WAV sources go to
.scratch/cue-wav/ and never into git. Each file is Ogg Vorbis q5, 44.1 kHz mono:
  - sfx / voice: -16 LUFS integrated (short cues measured looped 10x, so "as loud as the rest
    while it sounds"), per-file trim for frequent or bed-like cues.
  - loop (engines, snore bed): seamless, measured whole, trimmed under the SFX.
  - stem (music layers for music_down): exactly the length of music_down.ogg (1437660 samples),
    every oscillator on a whole number of cycles per loop so the seam is clean, D major,
    no beat (so nothing can flam against the 80 BPM theme). -26 LUFS (they sit under -20 music).
  - everything: true peak at or below -1 dBTP (checked after encoding).
Nothing above 9.5 kHz in the synths. Kid rule: nothing scary. No growls, no screams, no minor
stingers; the Dragon purrs and yawns, she never roars.
"""
import argparse
import math
import os
import random
import re
import shutil
import struct
import subprocess
import sys
import wave
from multiprocessing import Pool

SR = 44100
TAU = 2.0 * math.pi
PARTIAL_CEILING = 9500.0

AUDIO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(AUDIO_DIR))
SFX_TARGET = -16.0
STEM_TARGET = -26.0
TP_CEILING = -1.0
SHORT_CUE = 0.6
STEM_SAMPLES = 1437660   # music_down.ogg, 32.6 s
STEM_SEC = STEM_SAMPLES / SR

# ---------------------------------------------------------------- primitives

def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def silence(sec):
    return [0.0] * int(round(sec * SR))


def mix(dst, src, at=0.0, gain=1.0, wrap=False):
    """Add src into dst at `at` seconds. wrap=True folds overhang back to the start (loops)."""
    o = int(round(at * SR))
    n = len(dst)
    if wrap:
        for i, s in enumerate(src):
            dst[(o + i) % n] += s * gain
    else:
        for i in range(max(0, -o), min(len(src), n - o)):
            dst[o + i] += src[i] * gain
    return dst


def osc(dur, freq, partials=((1, 1.0, 1.0),), decay=None, attack=0.002, amp=None):
    """Additive oscillator. freq: Hz or f(t). partials: (ratio, gain, decay_scale); partial k
    decays as exp(-t * decay_scale / decay). amp: optional overall envelope f(t).
    Partials above PARTIAL_CEILING are skipped."""
    n = int(dur * SR)
    out = [0.0] * n
    ph = [0.0] * len(partials)
    fixed = not callable(freq)
    for i in range(n):
        t = i / SR
        f = freq if fixed else freq(t)
        s = 0.0
        for k, (r, g, ds) in enumerate(partials):
            fk = f * r
            ph[k] += TAU * fk / SR
            if fk < PARTIAL_CEILING:
                s += (g if decay is None else g * math.exp(-t * ds / decay)) * math.sin(ph[k])
        a = min(1.0, t / attack) if attack > 0 else 1.0
        if amp is not None:
            a *= amp(t)
        out[i] = s * a
    return fades(out, 0.0, 0.003)   # never stop a ringing partial dead


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def envelope(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def svf(x, fc, q=0.707, mode="low", circular=False):
    """TPT state-variable filter. fc: Hz or f(t). circular: run twice so the state at the
    start equals the state at the end (seamless loops)."""
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = [0.0] * len(x)
    moving = callable(fc)

    def coeffs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coeffs(fc) if not moving else (0, 0, 0)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            if moving:
                a1, a2, a3 = coeffs(fc(i / SR))
            v3 = v - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v2 if mode == "low" else (k * v1 if mode == "band" else v - k * v1 - v2)
    return out


def soft(x, fc, circular=False):
    """4-pole low-pass (two cascaded SVFs): keeps noise sources out of the top octave."""
    return svf(svf(x, fc, circular=circular), fc, circular=circular)


def dc_block(x, circular=False):
    r = 0.9972  # ~20 Hz
    x1 = y1 = 0.0
    out = [0.0] * len(x)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            y1 = v - x1 + r * y1
            x1 = v
            out[i] = y1
    return out


def fades(x, fade_in=0.001, fade_out=0.02):
    n = len(x)
    fi, fo = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    for i in range(min(fi, n)):
        x[i] *= i / fi
    for i in range(min(fo, n)):
        x[n - 1 - i] *= (i / fo) ** 2
    return x


def limit(x, threshold, lookahead=0.002, release=0.06):
    """Lookahead peak limiter: shaves transients so loudness can rise under the peak ceiling."""
    n = len(x)
    la = int(lookahead * SR)
    need = [min(1.0, threshold / abs(v)) if v else 1.0 for v in x]
    gain = [1.0] * n
    for i in range(n):   # n is small (SFX only), so a plain window minimum is fine
        gain[i] = min(need[max(0, i - la):i + la + 1])
    rel = math.exp(-1.0 / (release * SR))
    g = 1.0
    for i in range(n):
        g = gain[i] if gain[i] < g else gain[i] + (g - gain[i]) * rel
        gain[i] = g
    return [v * gain[i] for i, v in enumerate(x)]


def peak_normalise(x, peak=0.5):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


# ---------------------------------------------------------------- instruments

MARIMBA = ((1, 1.0, 1.0), (3.98, 0.30, 3.0), (9.85, 0.06, 6.0))
XYLO = ((1, 1.0, 1.0), (3.0, 0.28, 2.5), (6.1, 0.07, 5.0))
BELL = ((1, 1.0, 1.0), (2.76, 0.40, 1.8), (5.40, 0.12, 3.0), (8.93, 0.04, 4.0))
WOOD = ((1, 1.0, 1.0), (2.57, 0.35, 1.6), (4.80, 0.12, 2.6))


def mallet(rng, fc=3000.0, sec=0.005, gain=0.25):
    n = int(sec * SR)
    x = [rng.uniform(-1, 1) * (1 - i / n) ** 2 for i in range(n)]
    return [v * gain for v in svf(x, fc)]


def struck(f, decay, rng, partials=MARIMBA, vel=1.0, click=0.2):
    """Marimba / xylophone / bell note: decaying partials plus a mallet tick."""
    x = osc(min(decay * 7.0, 3.0), f, partials, decay=decay, attack=0.0015)
    mix(x, mallet(rng, fc=min(4000.0, f * 4.0)), 0.0, click)
    return [v * vel for v in x]


def formant(x):
    return (0.25 + math.exp(-((x - 650) / 260) ** 2) + 0.6 * math.exp(-((x - 1700) / 420) ** 2)
            + 0.25 * math.exp(-((x - 2800) / 500) ** 2))


def kazoo(f, sec, vib_rate=5.5, vib_depth=0.012, attack=0.015, release=0.06):
    """Buzzy, voice-like toy horn: band-limited saw shaped by fixed formants, with vibrato."""
    parts = []
    n = 1
    while n * f < PARTIAL_CEILING:
        parts.append((n, formant(n * f) / n, 0.0))
        n += 1
    total = sec

    def amp(t):
        return min(1.0, (total - t) / release) if t > total - release else 1.0

    def freq(t):
        return f * (1.0 + vib_depth * min(1.0, t / 0.12) * math.sin(TAU * vib_rate * t))

    return osc(sec, freq, tuple(parts), attack=attack, amp=amp)


def chirp(f0, f1, sec, partials=((1, 1.0, 0.0),), attack=0.004):
    """Pitch glide f0 -> f1 (exponential) with a rounded envelope."""
    return osc(sec, lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), partials, attack=attack,
               amp=lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 0.6)


def sparkle(rng, count, start, end, gain=0.12, notes=(96, 98, 100, 103, 105)):
    """A few quiet glockenspiel pings from a high C-major pentatonic."""
    out = silence(end + 0.3)
    for _ in range(count):
        mix(out, struck(midi(rng.choice(notes)), 0.05, rng, BELL, click=0.05),
            rng.uniform(start, end), gain * rng.uniform(0.6, 1.0))
    return out


def chord(notes, decay, rng, partials=MARIMBA, vel=1.0):
    out = silence(min(decay * 7.0, 3.0) + 0.01)
    for n in notes:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), 0.0, vel / len(notes) ** 0.5)
    return out


# ---------------------------------------------------------------- cues
# Each returns raw samples at any scale; build() cleans them up.

# ---------------------------------------------------------------- spaceballs primitives

# Cartoon formants (F1, F2, F3), a little brighter than an adult voice so it reads as a Jarling.
VOWELS = {"a": (820, 1250, 2650), "e": (520, 1900, 2650), "i": (330, 2350, 3050),
          "o": (520, 880, 2500), "u": (360, 760, 2400), "l": (320, 1100, 2600)}
METAL = ((1, 1.0, 1.0), (2.41, 0.6, 1.4), (3.93, 0.4, 2.0), (5.33, 0.25, 3.0), (6.9, 0.12, 4.0))


def saw(freq, sec):
    """PolyBLEP sawtooth (cheap, nearly alias-free); freq: Hz or f(t)."""
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    fixed = not callable(freq)
    for i in range(n):
        dt = (freq if fixed else freq(i / SR)) / SR
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        v = 2.0 * ph - 1.0
        if ph < dt:
            x = ph / dt
            v -= x + x - x * x - 1.0
        elif ph > 1.0 - dt:
            x = (ph - 1.0) / dt
            v -= x * x + x + x + 1.0
        out[i] = v
    return out


def ar(total, attack=0.01, release=0.05):
    """Attack / release envelope as f(t)."""
    def f(t):
        a = min(1.0, t / attack) if attack > 0 else 1.0
        return a * (max(0.0, (total - t) / release) if t > total - release else 1.0)
    return f


def voice(f0, sec, vowel="a", amp=None, rng=None, breath=0.04, scale=1.0, rough=0.0,
          gains=(1.0, 0.55, 0.22), qs=(4.0, 7.0, 9.0)):
    """Formant voice: a saw through three band-pass filters. vowel: key of VOWELS, a tuple, or
    f(t) -> (F1, F2, F3) for glides (\"mi-a-ow\"). rough: amplitude flutter for croaks."""
    src = saw(f0, sec)
    if rng is not None and breath:
        src = [v + breath * rng.uniform(-1, 1) for v in src]
    if rough:
        src = [v * (1.0 - rough + rough * abs(math.sin(math.pi * 38.0 * i / SR)))
               for i, v in enumerate(src)]
    out = [0.0] * len(src)
    for k in range(3):
        if callable(vowel):
            fc = (lambda t, k=k: vowel(t)[k] * scale)
        else:
            fc = (VOWELS[vowel] if isinstance(vowel, str) else vowel)[k] * scale
        mix(out, svf(src, fc, qs[k], "band"), 0.0, gains[k])
    env = amp or ar(sec)
    return fades([v * env(i / SR) for i, v in enumerate(out)], 0.002, 0.01)


def glide(a, b, t0, t1):
    """Vowel glide a -> b between t0 and t1 as f(t) -> formants."""
    va, vb = VOWELS[a], VOWELS[b]

    def f(t):
        u = min(1.0, max(0.0, (t - t0) / (t1 - t0)))
        return tuple(x + (y - x) * u for x, y in zip(va, vb))
    return f


def burst(rng, sec, fc, q=1.0, decay=0.01, mode="band"):
    """Filtered noise hit with an exponential tail: cracks, slaps, claps, ticks."""
    x = svf(noise(sec, rng), fc, q, mode)
    return fades([v * math.exp(-i / SR / decay) for i, v in enumerate(x)], 0.0005, 0.004)


def thump(f0, f1, sec, decay):
    """Sine with a falling pitch: the body of every kick and landing."""
    return osc(sec, lambda t: f1 + (f0 - f1) * math.exp(-t / (decay * 0.6)), decay=decay,
               attack=0.001)


def rumble(rng, sec, fc, decay, attack=0.003):
    x = soft(noise(sec, rng), fc)
    return fades([v * min(1.0, i / SR / attack) * math.exp(-i / SR / decay)
                  for i, v in enumerate(x)], 0.0, 0.05)


def whistle(f0, f1, sec, rng, curve=1.3, vib=0.018, breath=0.06):
    """Slide whistle: a near-sine rising f0 -> f1 with vibrato and a little breath."""
    def freq(t):
        u = min(1.0, t / sec) ** curve
        return f0 * (f1 / f0) ** u * (1.0 + vib * math.sin(TAU * 6.0 * t))
    x = osc(sec, freq, ((1, 1.0, 0.0), (2, 0.07, 0.0), (3, 0.02, 0.0)), attack=0.03,
            amp=lambda t: min(1.0, (sec - t) / 0.08) if t > sec - 0.08 else 1.0)
    air = svf(noise(sec, rng), (f0 + f1) * 0.6, 2.0, "band")
    return [v + breath * a for v, a in zip(x, air)]


def notes_seq(seq, rng, partials=MARIMBA, decay=0.12, vel=1.0):
    """[(midi_note, at_seconds), ...] of struck notes."""
    end = max(at for _, at in seq)
    out = silence(end + min(decay * 7.0, 3.0) + 0.02)
    for n, at in seq:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), at, vel)
    return out


def brass(f, sec, rng, wah=None, vib=0.0, scoop=0.0, bright=2200.0):
    """Toy trombone / fanfare horn: saw, brightness follows the envelope (wah: f(t) 0..1)."""
    def freq(t):
        s = 1.0 - scoop * math.exp(-t / 0.04)
        return f * s * (1.0 + vib * min(1.0, t / 0.4) * math.sin(TAU * 5.0 * t))
    src = saw(freq, sec)
    w = wah or (lambda t: 1.0)
    x = svf(src, lambda t: 250.0 + bright * w(t), 1.2)
    env = ar(sec, 0.02, 0.08)
    return [v * env(i / SR) for i, v in enumerate(x)]


def clap(rng):
    x = burst(rng, 0.06, rng.uniform(1100, 1700), 1.4, 0.008)
    mix(x, burst(rng, 0.06, rng.uniform(700, 900), 2.0, 0.012), 0.0, 0.4)
    return x


# ================================================================ the hill
# D major everywhere (the music is D major, 80 BPM). Pentatonic D E F# A B so nothing clashes.

D_HI = (86, 88, 90, 93, 95, 98)         # D6 .. D7 pentatonic, for sparkles
D_MID = (74, 76, 78, 81, 83, 86)        # D5 .. D6


def at_len(x, sec):
    n = int(sec * SR)
    return (x + [0.0] * (n - len(x)))[:n]


def grains(rng, sec, count, fc_lo, fc_hi, dec_lo, dec_hi, gain=1.0, spread=1.0):
    """Many tiny noise bursts: crumbles, rattles, crunches, debris."""
    out = silence(sec + 0.1)
    for _ in range(count):
        t = (rng.random() ** spread) * sec * 0.8
        mix(out, burst(rng, 0.05, rng.uniform(fc_lo, fc_hi), 1.2, rng.uniform(dec_lo, dec_hi)),
            t, gain * rng.uniform(0.4, 1.0))
    return out


def echo(x, delay, fb, n=4):
    out = x + silence(delay * n)
    for k in range(1, n + 1):
        mix(out, x, delay * k, fb ** k)
    return out


# ---------------------------------------------------------------- digging

def dig_dirt(rng, f0=120.0):
    """Crumble: a soft thump and a handful of low clods."""
    x = silence(0.4)
    mix(x, thump(f0, f0 * 0.5, 0.18, 0.05), 0.0, 0.9)
    mix(x, grains(rng, 0.28, 14, 300, 1100, 0.008, 0.025, spread=1.6), 0.0, 0.7)
    mix(x, rumble(rng, 0.25, 500, 0.06), 0.0, 0.4)
    return x


def dig_clay(rng, f0=210.0):
    """Squelch: a wet formant blop that opens up, then a little suck."""
    x = silence(0.45)
    v = voice(f0, 0.22, glide("u", "a", 0.0, 0.16), rng=rng, breath=0.2, amp=ar(0.22, 0.01, 0.1))
    mix(x, v, 0.0, 0.8)
    mix(x, chirp(f0 * 0.7, f0 * 1.6, 0.12, ((1, 1.0, 0.0), (2, 0.3, 0.0))), 0.18, 0.35)
    mix(x, thump(110, 60, 0.15, 0.05), 0.0, 0.6)
    return x


def dig_stone(rng, f0=190.0):
    """Crack: a sharp snap, a woody knock, then a few chips skittering."""
    x = silence(0.5)
    mix(x, burst(rng, 0.05, rng.uniform(2200, 2800), 1.5, 0.006), 0.0, 0.55)
    mix(x, struck(f0, 0.07, rng, WOOD, click=0.3), 0.0, 0.9)
    mix(x, thump(140, 70, 0.16, 0.05), 0.0, 0.7)
    mix(x, grains(rng, 0.35, 6, 2000, 4500, 0.003, 0.008), 0.06, 0.35)
    return x


def dig_ice(rng, f0=1300.0):
    """Crunch: packed snow under a boot, plus two glassy tinks."""
    x = silence(0.5)
    mix(x, grains(rng, 0.2, 26, f0, f0 * 2.6, 0.004, 0.012, spread=1.3), 0.0, 0.8)
    for k in range(2):
        mix(x, struck(midi(rng.choice(D_HI)), 0.06, rng, BELL, click=0.05), 0.05 + k * 0.09, 0.25)
    mix(x, thump(160, 90, 0.1, 0.03), 0.0, 0.4)
    return x


def dig_crystal(rng, root=86):
    """Chime: a little D-major glass arpeggio."""
    seq = [(root, 0.0), (root + 4, 0.06), (root + 7, 0.12)]
    x = notes_seq(seq, rng, BELL, decay=0.18, vel=0.6)
    mix(x, sparkle(rng, 4, 0.05, 0.3, 0.2, D_HI), 0.0, 1.0)
    mix(x, burst(rng, 0.03, 3000, 1.0, 0.005), 0.0, 0.3)
    return at_len(x, 1.0)


def dig_blocked(rng, f0=330.0):
    """Bounce off: a springy boing and a sparkle (never a buzzer)."""
    def freq(t):
        return f0 * (1.0 + 0.25 * math.exp(-t / 0.15) * math.sin(TAU * 22.0 * t))
    x = osc(0.45, freq, ((1, 1.0, 1.0), (2, 0.25, 1.5)), decay=0.16)
    mix(x, sparkle(rng, 3, 0.05, 0.25, 0.25, D_HI), 0.0, 1.0)
    return at_len(x, 0.7)


def swing(rng, lo=500.0, hi=1600.0):
    """A shovel swing that hits nothing: airy whoosh."""
    sec = 0.22
    x = svf(noise(sec, rng), lambda t: lo + (hi - lo) * math.sin(math.pi * t / sec), 2.0, "band")
    return envelope(x, lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 1.5)


def mole_dig(rng):
    x = grains(rng, 0.35, 18, 250, 900, 0.006, 0.02, spread=1.0)
    mix(x, thump(160, 90, 0.08, 0.03), 0.0, 0.4)
    mix(x, thump(170, 95, 0.08, 0.03), 0.16, 0.35)
    return x


# ---------------------------------------------------------------- vehicles

def loop_len(x, sec):
    """Fold the overhang into the start so the loop is seamless."""
    n = int(round(sec * SR))
    out = [0.0] * n
    for i, v in enumerate(x):
        out[i % n] += v
    return out


def engine(rng, f0, cyl, chug, growl_fc, extras=(), sec=1.0):
    """Looped engine at idle-to-cruise. f0, cyl, every extra frequency are whole Hz so a 1 s
    loop is seamless. cyl: firing pulses per second; chug: 0..1 how lumpy."""
    n = int(sec * SR)
    out = [0.0] * n
    parts = [(k, 1.0 / k ** 0.8, 0.0) for k in range(1, 18)]
    body = osc(sec, f0, tuple(parts), attack=0.0)
    body = svf(body, growl_fc, 0.9, circular=True)
    mix(out, body, 0.0, 1.0)
    exhaust = soft(noise(sec, rng), growl_fc * 0.8, circular=True)
    mix(out, exhaust, 0.0, 0.35)
    for f, g in extras:
        mix(out, osc(sec, f, ((1, 1.0, 0.0), (2, 0.2, 0.0)), attack=0.0), 0.0, g)
    puls = [1.0 - chug + chug * (0.5 + 0.5 * math.cos(TAU * cyl * i / SR)) ** 3 for i in range(n)]
    out = [v * p for v, p in zip(out, puls)]
    return dc_block(out, circular=True)


def engine_front_loader(rng):    # chuggy little diesel, the friendly one
    return engine(rng, 31, 12, 0.6, 700, ((186, 0.04),))


def engine_excavator(rng):       # deeper, with a hydraulic whine on top
    return engine(rng, 24, 8, 0.5, 520, ((440, 0.06), (661, 0.02)))


def engine_dump_truck(rng):      # big low rumble and a turbo whistle
    return engine(rng, 19, 6, 0.45, 420, ((1174, 0.012),))


def engine_crane(rng):           # steady hum with gear ticks
    x = engine(rng, 36, 18, 0.25, 900, ((288, 0.05),))
    for k in range(4):
        mix(x, burst(rng, 0.03, 3200, 3.0, 0.004), k * 0.25, 0.25, wrap=True)
    return x


def engine_drill_rig(rng):       # buzzy, with a whirring bit
    x = engine(rng, 47, 23, 0.35, 1200, ((188, 0.1), (376, 0.05)))
    trem = [0.8 + 0.2 * math.sin(TAU * 9 * i / SR) for i in range(len(x))]
    return [v * t for v, t in zip(x, trem)]


def beeps(f, count, on, gap, partials=((1, 1.0, 0.0), (2, 0.15, 0.0), (3, 0.08, 0.0))):
    x = silence(count * (on + gap) + 0.05)
    for k in range(count):
        mix(x, osc(on, f, partials, attack=0.005, amp=ar(on, 0.005, 0.03)), k * (on + gap), 1.0)
    return x


def horn_front_loader(rng):      # cheerful beep-beep
    x = silence(0.6)
    mix(x, kazoo(midi(74), 0.16), 0.0, 1.0)
    mix(x, kazoo(midi(78), 0.22), 0.2, 1.0)
    return x


def horn_excavator(rng):         # low friendly honk
    return brass(midi(50), 0.55, rng, wah=lambda t: min(1.0, t / 0.1), scoop=0.15, bright=1400)


def horn_dump_truck(rng):        # big air horn chord (D major)
    x = silence(0.8)
    for n in (50, 54, 57):
        mix(x, brass(midi(n), 0.7, rng, scoop=0.1, bright=2000), 0.0, 0.6)
    return x


def dump_truck_reverse(rng):     # soft reverse beeper, A5 so it is not piercing
    return beeps(midi(81), 3, 0.18, 0.16, ((1, 1.0, 0.0), (3, 0.05, 0.0)))


def horn_crane(rng):             # ding-ding bell
    return notes_seq([(81, 0.0), (81, 0.22)], rng, BELL, decay=0.2)


def horn_drill_rig(rng):         # toot-toot steam whistle
    x = silence(0.7)
    mix(x, whistle(midi(79), midi(81), 0.18, rng, vib=0.0, breath=0.15), 0.0, 1.0)
    mix(x, whistle(midi(79), midi(83), 0.3, rng, vib=0.01, breath=0.15), 0.25, 1.0)
    return x


def horn_generic(rng):
    return kazoo(midi(69), 0.3)


def honk_soft(rng):              # "can't afford that": a soft clown bwah, falling, friendly
    return brass(midi(57), 0.35, rng, wah=lambda t: max(0.0, 1.0 - t / 0.35), scoop=-0.05,
                 bright=1000)


def hydraulic(rng, f0, f1, sec, gain_noise=0.15):
    """Hydraulic whine: a filtered saw gliding f0 -> f1 plus hiss."""
    src = saw(lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), sec)
    x = svf(src, lambda t: 600 + 900 * t / sec, 2.0, "band")
    mix(x, svf(noise(sec, rng), 2500, 1.0, "band"), 0.0, gain_noise)
    return envelope(x, ar(sec, 0.04, 0.08))


def scoop(rng, f0=180.0):
    x = hydraulic(rng, f0, f0 * 1.5, 0.35)
    mix(x, grains(rng, 0.2, 10, 400, 1500, 0.006, 0.02), 0.25, 0.6)
    return x


def tip(rng, f0=200.0):
    """Bucket or truck bed tips: hydraulic down-whine and a rattle of blocks."""
    x = hydraulic(rng, f0 * 1.4, f0, 0.4)
    mix(x, grains(rng, 0.45, 22, 300, 1400, 0.01, 0.03, spread=0.8), 0.25, 0.9)
    mix(x, thump(100, 55, 0.2, 0.06), 0.45, 0.6)
    return x


def pile_dump(rng):
    x = grains(rng, 0.5, 28, 250, 1200, 0.01, 0.03, spread=0.9)
    mix(x, thump(110, 55, 0.2, 0.07), 0.1, 0.7)
    return x


def vehicle_dig(rng, f0, fc):
    x = hydraulic(rng, f0, f0 * 1.3, 0.25, 0.1)
    mix(x, grains(rng, 0.25, 14, fc * 0.5, fc, 0.006, 0.02), 0.08, 0.8)
    mix(x, thump(120, 60, 0.12, 0.04), 0.05, 0.6)
    return x


def drill_spin(rng):
    sec = 0.6
    src = saw(lambda t: 120 + 260 * min(1.0, t / 0.3), sec)
    x = svf(src, 1400, 1.5, "band")
    mix(x, grains(rng, sec, 20, 1000, 3000, 0.004, 0.01), 0.0, 0.4)
    return envelope(x, ar(sec, 0.03, 0.15))


def drill_stop(rng):
    sec = 0.5
    x = svf(saw(lambda t: 380 * (0.3 / 1.0) ** (t / sec), sec), 1200, 1.5, "band")
    return envelope(x, ar(sec, 0.005, 0.3))


def crane_hook(rng):
    x = silence(0.8)
    for k in range(5):        # chain rattle
        mix(x, struck(rng.uniform(900, 1300), 0.02, rng, METAL, click=0.4), k * 0.06, 0.4)
    mix(x, struck(midi(62), 0.12, rng, METAL), 0.35, 0.8)   # clank
    return x


def hop_in(rng):
    x = silence(0.4)
    mix(x, thump(150, 90, 0.1, 0.03), 0.0, 0.7)
    mix(x, burst(rng, 0.04, 1800, 2.0, 0.008), 0.08, 0.5)    # door click
    mix(x, struck(midi(81), 0.06, rng, MARIMBA), 0.12, 0.4)
    return x


def hop_out(rng):
    x = silence(0.4)
    mix(x, burst(rng, 0.04, 1500, 2.0, 0.008), 0.0, 0.5)
    mix(x, thump(170, 100, 0.1, 0.03), 0.1, 0.7)
    mix(x, struck(midi(74), 0.06, rng, MARIMBA), 0.12, 0.3)
    return x


def vehicle_rollout(rng):
    x = hydraulic(rng, 60, 110, 0.9, 0.05)
    mix(x, notes_seq([(74, 0.0), (78, 0.1), (81, 0.2), (86, 0.3)], rng, MARIMBA, 0.1), 0.6, 0.6)
    return x


def garage_door(rng):
    x = silence(1.1)
    for k in range(12):      # roller door clatter
        mix(x, struck(rng.uniform(500, 700), 0.015, rng, METAL, click=0.3), k * 0.07, 0.3)
    mix(x, thump(120, 70, 0.15, 0.05), 0.85, 0.8)
    return x


def garage_waits(rng):       # a hopeful little "it's ready" two-note
    return notes_seq([(81, 0.0), (86, 0.14)], rng, MARIMBA, 0.12)


def backpack_full(rng):      # a full-bag "boop boop", happy not alarming
    return notes_seq([(86, 0.0), (81, 0.1), (86, 0.2)], rng, XYLO, 0.07)


# ---------------------------------------------------------------- treasure (bigger = rarer)

def treasure_tier(rng, tier):
    seqs = {
        0: [(86, 0.0), (93, 0.1)],
        1: [(81, 0.0), (86, 0.09), (90, 0.18)],
        2: [(74, 0.0), (78, 0.09), (81, 0.18), (86, 0.27)],
        3: [(74, 0.0), (78, 0.08), (81, 0.16), (86, 0.24), (90, 0.32), (93, 0.4)],
    }
    seq = seqs[tier]
    end = seq[-1][1]
    x = silence(1.0 + tier * 0.5)
    mix(x, notes_seq(seq, rng, BELL, decay=0.2 + 0.05 * tier, vel=0.7), 0.0, 1.0)
    mix(x, sparkle(rng, 3 + tier * 5, 0.05, end + 0.4 + tier * 0.2, 0.22, D_HI), 0.0, 1.0)
    if tier >= 2:
        mix(x, chord([62, 66, 69, 74], 0.4, rng, MARIMBA, 0.6), end + 0.08, 0.8)
    if tier == 3:
        for n in (62, 66, 69):
            mix(x, brass(midi(n), 0.7, rng, scoop=0.05, bright=1800), end + 0.08, 0.25)
    return x


def treasure_reveal(rng):     # rising shimmer while it pops out
    x = whistle(midi(74), midi(86), 0.45, rng, curve=1.0, vib=0.0, breath=0.1)
    mix(x, sparkle(rng, 6, 0.0, 0.45, 0.2, D_HI), 0.0, 1.0)
    return [v * 0.7 for v in x]


def treasure_pickup(rng):     # whoosh into the pile and a ding
    x = swing(rng, 800, 2400)
    mix(x, struck(midi(93), 0.25, rng, BELL), 0.18, 0.7)
    return at_len(x, 1.2)


def treasure_hint(rng):
    return [v * 0.6 for v in sparkle(rng, 4, 0.0, 0.35, 0.3, D_HI)]


def shelf_place(rng):
    x = silence(0.6)
    mix(x, struck(220, 0.04, rng, WOOD, click=0.3), 0.0, 0.8)
    mix(x, struck(midi(86), 0.15, rng, BELL), 0.06, 0.4)
    return x


def polish(rng):              # squeaky-clean rub rub, then a gleam
    x = silence(0.9)
    for k in range(3):
        mix(x, chirp(1400, 2000, 0.09), k * 0.13, 0.4)
    mix(x, struck(midi(98), 0.2, rng, BELL), 0.45, 0.5)
    return x


# ---------------------------------------------------------------- falls, bonks, water

def fall(rng, f0=95.0):
    x = silence(0.5)
    mix(x, thump(f0, f0 * 0.5, 0.3, 0.09), 0.0, 1.0)
    mix(x, rumble(rng, 0.3, 380, 0.07), 0.0, 0.5)
    mix(x, grains(rng, 0.3, 6, 400, 1200, 0.008, 0.02), 0.03, 0.3)
    return x


def bonk(rng, f0=520.0):
    """Cartoon bonk with stars: hollow wood knock, a spring and twinkles. Funny, never hurt."""
    x = silence(1.0)
    mix(x, struck(f0, 0.07, rng, WOOD, click=0.4), 0.0, 1.0)
    mix(x, osc(0.35, lambda t: f0 * 1.5 * (1 + 0.2 * math.sin(TAU * 18 * t)), decay=0.12), 0.03, 0.4)
    for k, n in enumerate((93, 98, 95, 98)):
        mix(x, struck(midi(n), 0.06, rng, BELL, click=0.05), 0.15 + k * 0.08, 0.3)
    return x


def float_up(rng):            # bubbly rising giggle
    x = silence(1.0)
    for k in range(7):
        f = 300 * 1.18 ** k
        mix(x, chirp(f, f * 1.6, 0.07), k * 0.09 + rng.uniform(0, 0.02), 0.5)
    return x


def flood(rng):
    """Gurgle (bubbles in rising water) then a giggle of bubbles."""
    sec = 1.6
    x = soft(noise(sec, rng), 700)
    x = envelope(x, lambda t: 0.4 * min(1.0, t / 0.2) * (1 - t / sec))
    for _ in range(26):
        f = rng.uniform(250, 700)
        mix(x, chirp(f, f * 1.8, rng.uniform(0.03, 0.06)), rng.uniform(0, 1.2), 0.35)
    for k in range(5):
        mix(x, chirp(500 + 80 * k, 900 + 120 * k, 0.06), 1.1 + k * 0.07, 0.5)
    return x


def splash(rng, fc=1200.0):
    x = burst(rng, 0.5, fc, 0.8, 0.12, "low")
    for _ in range(6):
        f = rng.uniform(400, 900)
        mix(x, chirp(f, f * 1.7, 0.05), rng.uniform(0.05, 0.3), 0.3)
    return x


def jump(rng, f0=330.0):
    return chirp(f0, f0 * 2.0, 0.14, ((1, 1.0, 0.0), (2, 0.2, 0.0)))


def shake_off(rng):           # brr-rr wet-dog shake
    x = silence(0.6)
    for k in range(8):
        mix(x, burst(rng, 0.04, 2200, 1.5, 0.01), k * 0.05, 0.6)
    return x


def rumble_cue(rng):          # distant friendly rumble (warning for cave-in)
    x = rumble(rng, 1.0, 160, 0.4, attack=0.15)
    mix(x, grains(rng, 0.8, 8, 300, 900, 0.01, 0.03), 0.1, 0.3)
    return x


def cave_in(rng):
    x = rumble(rng, 1.0, 300, 0.3)
    for k in range(5):
        mix(x, fall(rng, rng.uniform(80, 120)), k * 0.12, 0.5)
    return x


def pop(rng, f0=600.0):
    x = chirp(f0, f0 * 2.2, 0.06)
    mix(x, burst(rng, 0.03, 2000, 1.5, 0.004), 0.0, 0.4)
    return at_len(x, 0.25)


def prop_break(rng):
    x = silence(0.8)
    mix(x, burst(rng, 0.06, 1800, 1.0, 0.012), 0.0, 1.0)
    mix(x, struck(170, 0.06, rng, WOOD), 0.0, 0.6)
    mix(x, grains(rng, 0.6, 16, 400, 2500, 0.006, 0.02), 0.03, 0.6)
    return x


def wall_crumble(rng):
    x = rumble(rng, 0.8, 400, 0.2)
    mix(x, grains(rng, 0.8, 30, 300, 1500, 0.008, 0.03, spread=0.7), 0.0, 0.8)
    return x


# ---------------------------------------------------------------- elevator

def elevator(rng):
    """Cage clang, a rattle on the way, a ding at the top."""
    x = silence(1.6)
    mix(x, struck(midi(50), 0.15, rng, METAL, click=0.5), 0.0, 0.9)
    for k in range(10):
        mix(x, struck(rng.uniform(700, 1000), 0.015, rng, METAL, click=0.3), 0.25 + k * 0.08, 0.2)
    mix(x, hydraulic(rng, 80, 120, 0.9, 0.03), 0.2, 0.4)
    mix(x, struck(midi(86), 0.3, rng, BELL), 1.15, 0.7)
    return x


def cage_door(rng):
    x = silence(0.5)
    mix(x, burst(rng, 0.1, 1500, 3.0, 0.04), 0.0, 0.4)
    mix(x, struck(midi(55), 0.08, rng, METAL, click=0.5), 0.12, 0.9)
    return x


def elevator_clank(rng):
    return at_len(struck(midi(48), 0.12, rng, METAL, click=0.6), 0.6)


def elevator_ding(rng):
    return at_len(struck(midi(86), 0.3, rng, BELL), 1.2)


# ---------------------------------------------------------------- building

def build_place(rng):
    """Clunk, an unfold creak, a little fanfare."""
    x = silence(1.4)
    mix(x, thump(130, 70, 0.2, 0.06), 0.0, 1.0)
    mix(x, struck(180, 0.05, rng, WOOD, click=0.4), 0.0, 0.6)
    mix(x, chirp(260, 380, 0.25, ((1, 1.0, 0.0), (2, 0.5, 0.0), (3, 0.3, 0.0))), 0.15, 0.25)
    mix(x, notes_seq([(74, 0.0), (78, 0.1), (81, 0.2), (86, 0.32)], rng, MARIMBA, 0.15), 0.42, 0.8)
    return x


def build_unfold(rng):
    x = silence(0.8)
    for k in range(4):
        mix(x, chirp(240 + 30 * k, 320 + 30 * k, 0.1, ((1, 1.0, 0.0), (2, 0.5, 0.0))), k * 0.12, 0.3)
        mix(x, struck(200 + 20 * k, 0.03, rng, WOOD), k * 0.12 + 0.08, 0.4)
    return x


def build_pick(rng):
    return at_len(struck(midi(81), 0.08, rng, MARIMBA), 0.4)


def build_pickup(rng):        # build_move: a pop
    return pop(rng, 500)


def build_cancel(rng):
    return notes_seq([(81, 0.0), (74, 0.09)], rng, MARIMBA, 0.08)


def cheer_small(rng):
    """Two jaunty 'yay's (formant voices), no crowd roar."""
    x = silence(0.9)
    for k, f in enumerate((300, 360, 420)):
        mix(x, voice(f, 0.35, glide("e", "a", 0.0, 0.2), rng=rng, amp=ar(0.35, 0.02, 0.2)),
            k * 0.05, 0.4)
    return x


def book(rng, up=True):
    x = burst(rng, 0.25, 1800, 0.7, 0.06)
    mix(x, struck(midi(78 if up else 74), 0.06, rng, MARIMBA), 0.05, 0.4)
    return at_len(x, 0.45)


def book_hint(rng):
    return notes_seq([(86, 0.0), (90, 0.08)], rng, XYLO, 0.06)


def bundle_pop(rng):
    x = pop(rng, 420)
    mix(x, sparkle(rng, 2, 0.02, 0.1, 0.25, D_HI), 0.0, 1.0)
    return x


def clipboard(rng):           # pencil scribble tick-tick and a clip snap
    x = silence(0.6)
    for k in range(5):
        mix(x, burst(rng, 0.04, 3000, 2.5, 0.006), k * 0.06, 0.5)
    mix(x, struck(900, 0.03, rng, METAL, click=0.4), 0.38, 0.6)
    return x


# ---------------------------------------------------------------- hillville clearing

def tree_fall(rng):
    """Creak, then a soft thump and a leafy swish."""
    x = silence(1.6)
    creak = saw(lambda t: 90 + 40 * t, 0.7)
    creak = svf(creak, 800, 4.0, "band")
    creak = [v * (0.5 + 0.5 * math.sin(TAU * 23 * i / SR)) for i, v in enumerate(creak)]
    mix(x, envelope(creak, ar(0.7, 0.1, 0.2)), 0.0, 0.6)
    mix(x, svf(noise(0.5, rng), 3000, 0.8, "band"), 0.55, 0.15)
    mix(x, thump(90, 45, 0.4, 0.12), 0.9, 1.0)
    mix(x, grains(rng, 0.4, 10, 300, 900, 0.01, 0.03), 0.92, 0.4)
    return x


def rock_crack(rng):
    x = silence(0.7)
    mix(x, burst(rng, 0.05, 2400, 1.3, 0.008), 0.0, 1.0)
    mix(x, burst(rng, 0.05, 1600, 1.3, 0.01), 0.05, 0.6)
    mix(x, thump(120, 60, 0.15, 0.05), 0.04, 0.6)
    mix(x, grains(rng, 0.4, 10, 1000, 3500, 0.004, 0.012), 0.08, 0.4)
    return x


def stump_pop(rng):
    x = pop(rng, 300)
    mix(x, grains(rng, 0.2, 8, 300, 900, 0.008, 0.02), 0.03, 0.5)
    return at_len(x, 0.4)


# ---------------------------------------------------------------- residents

def gnome_whistle(rng, a=93, b=98):
    """Tiny two-note pea whistle."""
    x = silence(0.5)
    mix(x, whistle(midi(a), midi(a), 0.1, rng, vib=0.03, breath=0.1), 0.0, 1.0)
    mix(x, whistle(midi(b), midi(b), 0.16, rng, vib=0.03, breath=0.1), 0.13, 1.0)
    return x


def whistle_muffled(rng):     # the walled-in crew, behind rock
    return soft(gnome_whistle(rng), 900)


def march_step(rng):
    return at_len(struck(320, 0.02, rng, WOOD, click=0.5), 0.15)


def crew_march(rng):
    """Marching feet, tiny and tidy, 160 steps a minute."""
    x = silence(1.6)
    for k in range(8):
        mix(x, struck(300 + 40 * (k % 2), 0.02, rng, WOOD, click=0.5), k * 0.1875, 0.7)
    return x


def crew_cheer(rng):          # a tiny gnome 'hooray'
    x = silence(0.7)
    for k, f in enumerate((520, 600, 680)):
        mix(x, voice(f, 0.3, glide("u", "e", 0.0, 0.2), rng=rng, amp=ar(0.3, 0.02, 0.15),
                     scale=1.25), k * 0.04, 0.4)
    return x


def mole_sound(rng, kind):
    """The Mole: small, polite, nasal."""
    if kind == "wave":
        return notes_seq([(81, 0.0), (86, 0.1)], rng, MARIMBA, 0.08)
    if kind == "steal":       # a sneaky tiptoe pluck and a zip
        x = notes_seq([(74, 0.0), (76, 0.12), (78, 0.24)], rng, XYLO, 0.04, 0.6)
        mix(x, chirp(500, 1500, 0.12), 0.38, 0.6)
        return x
    if kind == "sorry":
        return voice(300, 0.5, glide("o", "e", 0.0, 0.4), rng=rng, amp=ar(0.5, 0.03, 0.2),
                     scale=1.15)
    if kind == "hello":
        return voice(340, 0.35, glide("e", "o", 0.0, 0.3), rng=rng, amp=ar(0.35, 0.02, 0.15),
                     scale=1.15)
    if kind == "gift":
        x = notes_seq([(78, 0.0), (81, 0.1), (86, 0.2)], rng, MARIMBA, 0.1)
        mix(x, sparkle(rng, 3, 0.2, 0.4, 0.2, D_HI), 0.0, 1.0)
        return x
    if kind == "found":
        return notes_seq([(74, 0.0), (81, 0.1), (86, 0.2), (90, 0.3)], rng, XYLO, 0.08)
    if kind == "pop":
        x = pop(rng, 350)
        mix(x, grains(rng, 0.15, 6, 300, 900, 0.008, 0.02), 0.0, 0.5)
        return x
    raise ValueError(kind)


def shovel_back(rng):
    x = silence(0.7)
    mix(x, struck(900, 0.06, rng, METAL, click=0.4), 0.0, 0.6)
    mix(x, notes_seq([(81, 0.0), (86, 0.1)], rng, MARIMBA, 0.1), 0.12, 0.6)
    return x


def ice_drip(rng, n=93):
    x = chirp(midi(n) * 0.7, midi(n), 0.05)
    mix(x, struck(midi(n), 0.1, rng, BELL, click=0.0), 0.02, 0.3)
    return at_len(x, 0.6)


def ice_crack(rng):
    x = silence(1.0)
    for k in range(4):
        mix(x, burst(rng, 0.05, rng.uniform(1800, 2800), 1.5, 0.01), k * 0.09, 0.7)
    mix(x, grains(rng, 0.5, 20, 1500, 4000, 0.004, 0.01), 0.3, 0.5)
    mix(x, sparkle(rng, 4, 0.3, 0.7, 0.2, D_HI), 0.0, 1.0)
    return x


def caveman(rng, kind):
    if kind == "laugh":       # hearty "ho ho ho"
        x = silence(1.0)
        for k in range(3):
            mix(x, voice(150 - k * 5, 0.18, "o", rng=rng, amp=ar(0.18, 0.01, 0.1)), k * 0.22, 1.0)
        return x
    if kind == "hoot":        # delighted "oo-OO!"
        x = silence(0.7)
        mix(x, voice(180, 0.18, "u", rng=rng, amp=ar(0.18, 0.02, 0.08)), 0.0, 1.0)
        mix(x, voice(250, 0.3, "u", rng=rng, amp=ar(0.3, 0.02, 0.15)), 0.2, 1.0)
        return x
    if kind == "huh":         # baffled rising "huh?"
        return voice(lambda t: 150 + 120 * t / 0.4, 0.4, "a", rng=rng, amp=ar(0.4, 0.02, 0.15))
    raise ValueError(kind)


def dragon(rng, kind):
    """The Dragon is huggable: warm, low, purry, never a roar."""
    if kind == "snore":       # in... and a fluttery purr out
        sec = 2.4
        x = rumble(rng, sec, 220, 10.0, attack=0.6)
        x = envelope(x, lambda t: (math.sin(math.pi * t / 1.1) if t < 1.1 else
                                   0.6 * math.sin(math.pi * (t - 1.1) / 1.3)) ** 2)
        purr = [0.6 + 0.4 * math.sin(TAU * 24 * i / SR) for i in range(len(x))]
        x = [v * (1.0 if i < 1.1 * SR else p) for i, (v, p) in enumerate(zip(x, purr))]
        mix(x, thump(55, 40, 1.2, 0.6), 1.1, 0.4)
        return x
    if kind == "purr":
        sec = 1.4
        src = voice(70, sec, "o", rng=rng, breath=0.3, rough=0.6, amp=ar(sec, 0.2, 0.4))
        return src
    if kind == "yawn":        # a big, sleepy, rising-falling "aaah-mm"
        sec = 1.6
        return voice(lambda t: 110 + 60 * math.sin(math.pi * t / sec), sec,
                     glide("a", "u", 0.6, 1.4), rng=rng, breath=0.2, amp=ar(sec, 0.25, 0.4))
    if kind == "flap":
        x = silence(0.8)
        for k in range(3):
            mix(x, burst(rng, 0.2, 500, 0.6, 0.05, "low"), k * 0.22, 1.0)
        return x
    if kind == "boing":
        return dig_blocked(rng, 180)
    if kind == "hopeful":
        return voice(lambda t: 120 + 50 * t, 0.5, glide("u", "e", 0.1, 0.4), rng=rng,
                     amp=ar(0.5, 0.05, 0.2))
    if kind == "mumble":
        x = silence(1.0)
        for k in range(3):
            mix(x, voice(95 + 10 * k, 0.22, rng.choice("aou"), rng=rng, amp=ar(0.22, 0.03, 0.1)),
                k * 0.26, 1.0)
        return x
    if kind == "stretch":
        sec = 1.0
        return voice(lambda t: 90 + 50 * t, sec, glide("o", "a", 0.0, 0.8), rng=rng, breath=0.2,
                     amp=ar(sec, 0.15, 0.3))
    if kind == "whoosh":
        return swing(rng, 300, 900)
    if kind == "smoke_ring":  # a soft "puh" and a fizzy little ring
        x = burst(rng, 0.3, 500, 0.7, 0.08, "low")
        mix(x, chirp(400, 700, 0.3), 0.05, 0.25)
        return x
    raise ValueError(kind)


def resident(rng, kind):
    """Picture-bubble moments of every arc (resident_* cues, the restore, the payoff)."""
    if kind == "hope":
        return notes_seq([(74, 0.0), (78, 0.12), (81, 0.24)], rng, MARIMBA, 0.12)
    if kind == "hm":
        return voice(200, 0.4, "u", rng=rng, amp=ar(0.4, 0.05, 0.2), gains=(1.0, 0.3, 0.1))
    if kind == "happy":
        return notes_seq([(81, 0.0), (86, 0.1), (90, 0.2)], rng, XYLO, 0.1)
    if kind == "cheer":
        x = cheer_small(rng)
        mix(x, sparkle(rng, 5, 0.1, 0.6, 0.2, D_HI), 0.0, 1.0)
        return x
    if kind == "arrive":      # ding-dong of the shaft: someone new is waiting
        x = silence(1.4)
        mix(x, notes_seq([(86, 0.0), (81, 0.3)], rng, BELL, 0.25), 0.0, 0.8)
        mix(x, notes_seq([(74, 0.6), (78, 0.72), (81, 0.84)], rng, MARIMBA, 0.1), 0.0, 0.6)
        return x
    if kind == "ruin_rumble":
        x = rumble(rng, 0.8, 250, 0.3)
        mix(x, grains(rng, 0.7, 10, 300, 1000, 0.01, 0.03), 0.0, 0.5)
        return x
    if kind == "light_on":    # click, hum, a warm chord
        x = silence(1.3)
        mix(x, burst(rng, 0.03, 2500, 2.0, 0.004), 0.0, 0.6)
        mix(x, chord([62, 66, 69, 74], 0.35, rng, MARIMBA, 0.7), 0.08, 1.0)
        mix(x, sparkle(rng, 3, 0.2, 0.6, 0.2, D_HI), 0.0, 1.0)
        return x
    raise ValueError(kind)


def plank(rng, f0=200.0):
    """One plank of the restore: a hammer knock and a tiny note (rises across variants)."""
    x = silence(0.4)
    mix(x, struck(f0, 0.04, rng, WOOD, click=0.5), 0.0, 1.0)
    mix(x, struck(f0 * 1.5, 0.03, rng, WOOD, click=0.3), 0.07, 0.5)
    return x


def payoff(rng, who):
    """Each arc's payoff: the same rising D-major fanfare, coloured per resident."""
    seq = [(62, 0.0), (66, 0.12), (69, 0.24), (74, 0.4)]
    x = silence(2.2)
    mix(x, notes_seq(seq, rng, MARIMBA, 0.2), 0.0, 0.8)
    mix(x, chord([62, 66, 69, 74, 78], 0.5, rng, MARIMBA, 0.7), 0.55, 0.9)
    if who == "mole":         # a cheeky mole squeak on top
        mix(x, mole_sound(rng, "hello"), 0.6, 0.5)
    elif who == "caveman":
        mix(x, caveman(rng, "hoot"), 0.6, 0.5)
    elif who == "gnomes":
        mix(x, gnome_whistle(rng), 0.6, 0.6)
        mix(x, crew_march(rng), 0.9, 0.3)
    elif who == "dragon":
        mix(x, dragon(rng, "purr"), 0.6, 0.4)
        for n in (62, 69):
            mix(x, brass(midi(n), 0.9, rng, scoop=0.05, bright=1500), 0.55, 0.25)
    mix(x, sparkle(rng, 8, 0.5, 1.6, 0.2, D_HI), 0.0, 1.0)
    return x


# ---------------------------------------------------------------- input and flow

def ui_move(rng, n=81):
    return at_len(struck(midi(n), 0.05, rng, MARIMBA), 0.3)


def ui_confirm(rng):
    return notes_seq([(81, 0.0), (86, 0.07)], rng, MARIMBA, 0.09)


def player_join(rng):
    return notes_seq([(74, 0.0), (78, 0.08), (81, 0.16), (86, 0.24)], rng, XYLO, 0.1)


def round_start(rng):
    x = notes_seq([(74, 0.0), (81, 0.15), (86, 0.3)], rng, MARIMBA, 0.15)
    mix(x, chord([62, 66, 69], 0.4, rng), 0.45, 0.6)
    return x


def round_end(rng):
    return notes_seq([(86, 0.0), (81, 0.15), (78, 0.3), (74, 0.45)], rng, MARIMBA, 0.15)


def pause_cue(rng):
    return notes_seq([(81, 0.0), (74, 0.08)], rng, XYLO, 0.06)


def split_cue(rng):
    return swing(rng, 400, 1400)


def action(rng):
    return at_len(struck(midi(78), 0.05, rng, WOOD), 0.25)


# ---------------------------------------------------------------- barks (synth placeholders)
# Real lines come from each character's voice pack (Chatterbox). These are gibberish formant
# syllables in the right register so the hooks are audible until then.

BARKERS = {
    "jeff": (250.0, 1.08, "aeio"),
    "chuck": (165.0, 0.95, "aou"),
    "mole": (300.0, 1.15, "oe"),
    "gnome_foreman": (420.0, 1.3, "ieu"),
    "dragon": (85.0, 0.85, "aou"),
}


def babble(rng, who, syllables, rise=0.0):
    f0, scale, vowels = BARKERS[who]
    x = silence(syllables * 0.2 + 0.4)
    t = 0.0
    for k in range(syllables):
        d = rng.uniform(0.11, 0.2)
        f = f0 * rng.uniform(0.92, 1.12) * (1.0 + rise * k / max(1, syllables - 1))
        v = voice(f, d, rng.choice(vowels), rng=rng, scale=scale, amp=ar(d, 0.015, 0.06))
        mix(x, v, t, 1.0)
        t += d + rng.uniform(0.02, 0.06)
    return x


def bark_oh_dear(rng):        # "oh dear": "oh" falls, "dear" falls further
    f0, scale, _ = BARKERS["mole"]
    x = silence(1.0)
    k = rng.uniform(0.95, 1.08)
    mix(x, voice(lambda t: f0 * k * (1.0 - 0.1 * t / 0.25), 0.25, "o", rng=rng, scale=scale,
                 amp=ar(0.25, 0.02, 0.08)), 0.0, 1.0)
    mix(x, voice(lambda t: f0 * k * (1.05 - 0.25 * t / 0.4), 0.4, glide("i", "e", 0.0, 0.3),
                 rng=rng, scale=scale, amp=ar(0.4, 0.02, 0.2)), 0.3, 1.0)
    return x


def bark_dragon_rumble(rng):
    x = dragon(rng, "purr")
    mix(x, babble(rng, "dragon", 2), 0.2, 0.6)
    return x


def bark_foreman_whistle(rng):
    x = gnome_whistle(rng)
    mix(x, babble(rng, "gnome_foreman", 3), 0.45, 0.8)
    return x


# ---------------------------------------------------------------- music stems for music_down
# One per depth zone below Topsoil (Audio.gd fades in layers 1..zone). D major, no beat.

def qf(f):
    """Snap a frequency to a whole number of cycles per stem loop (seamless seam)."""
    return round(f * STEM_SEC) / STEM_SEC


def stem_swell(k):
    """Slow amplitude swell with k whole cycles per loop."""
    return lambda t: 0.65 + 0.35 * math.sin(TAU * k * t / STEM_SEC)


def stem_drone(rng):         # Clay: a warm low D/A drone, like a bowed cello far away
    out = [0.0] * STEM_SAMPLES
    for f, g in ((midi(38), 1.0), (midi(45), 0.6), (midi(50), 0.35)):
        s = saw(qf(f), STEM_SEC)[:STEM_SAMPLES]
        mix(out, s, 0.0, g)
    out = svf(out, 420.0, 0.8, circular=True)
    sw = stem_swell(4)
    return dc_block([v * sw(i / SR) for i, v in enumerate(out)], circular=True)


def stem_shimmer(rng):       # Stone: a soft high pad, A4 D5 F#5 with a slow chorus
    out = [0.0] * STEM_SAMPLES
    for n, g in ((69, 0.6), (74, 0.5), (78, 0.4)):
        for det in (-1, 1):
            f = qf(midi(n) * (1.0 + det * 0.0025))
            mix(out, osc(STEM_SEC, f, ((1, 1.0, 0.0), (2, 0.12, 0.0)), attack=0.0)[:STEM_SAMPLES],
                0.0, g)
    sw = stem_swell(2)
    return [v * sw(i / SR) for i, v in enumerate(out)]


def stem_bells(rng):         # Ice: sparse echoing bell drops, D pentatonic, wrapped round the seam
    out = [0.0] * STEM_SAMPLES
    t = 0.5
    while t < STEM_SEC:
        n = rng.choice(D_MID)
        b = struck(midi(n), 0.35, rng, BELL, vel=rng.uniform(0.5, 0.9), click=0.05)
        mix(out, echo(b, 0.75, 0.4, 3), t, 1.0, wrap=True)
        t += rng.choice((1.5, 2.25, 3.0))
    return out


def stem_glass(rng):         # Crystal: high glassy harmonics and a breath of air
    out = [0.0] * STEM_SAMPLES
    t = 1.0
    while t < STEM_SEC:
        n = rng.choice(D_HI)
        mix(out, struck(midi(n), 0.6, rng, BELL, vel=rng.uniform(0.3, 0.6), click=0.0), t, 1.0,
            wrap=True)
        t += rng.uniform(0.8, 1.9)
    air = soft(noise(STEM_SEC, rng), 3000, circular=True)[:STEM_SAMPLES]
    air = svf(air, 1500, 0.7, "high", circular=True)
    sw = stem_swell(3)
    mix(out, [v * sw(i / SR) for i, v in enumerate(air)], 0.0, 0.08)
    return out


# ---------------------------------------------------------------- files
# stem: (make, kind, trim dB). kind: sfx | voice | loop | stem.
# A stem ending in _<n> is variant n of its cue (Audio.gd rotates through them).

def v(fn, *a):
    return lambda rng: fn(rng, *a)


FILES = {}


def add(stem, make, kind="sfx", trim=0.0):
    FILES[stem] = (make, kind, trim)


for i, f in enumerate((120, 105, 135), 1):
    add("dig_dirt_%d" % i, v(dig_dirt, f), trim=-2.0)
for i, f in enumerate((210, 185, 235), 1):
    add("dig_clay_%d" % i, v(dig_clay, f), trim=-2.0)
for i, f in enumerate((190, 170, 215), 1):
    add("dig_stone_%d" % i, v(dig_stone, f), trim=-2.0)
for i, f in enumerate((1300, 1150, 1450), 1):
    add("dig_ice_%d" % i, v(dig_ice, f), trim=-2.0)
for i, r in enumerate((86, 81, 88), 1):
    add("dig_crystal_%d" % i, v(dig_crystal, r), trim=-2.0)
for i, f in enumerate((330, 290), 1):
    add("dig_blocked_%d" % i, v(dig_blocked, f))
add("swing_1", v(swing, 500, 1600), trim=-4.0)
add("swing_2", v(swing, 450, 1400), trim=-4.0)
add("mole_dig_1", mole_dig, trim=-4.0)
add("mole_dig_2", mole_dig, trim=-4.0)
add("dig_free", v(dig_dirt, 140))

for veh in ("front_loader", "excavator", "dump_truck", "crane", "drill_rig"):
    add(veh + "_engine", globals()["engine_" + veh], "loop", -8.0)
    add(veh + "_horn", globals()["horn_" + veh])
add("dump_truck_reverse", dump_truck_reverse, trim=-3.0)
add("front_loader_dig", v(vehicle_dig, 170, 1200), trim=-2.0)
add("excavator_dig", v(vehicle_dig, 130, 1000), trim=-2.0)
add("dump_truck_dig", v(vehicle_dig, 110, 900), trim=-2.0)
add("crane_dig", v(vehicle_dig, 150, 1100), trim=-2.0)
add("drill_rig_dig", v(vehicle_dig, 200, 2000), trim=-2.0)
add("drill_rig_spin", drill_spin, trim=-3.0)
add("drill_stop", drill_stop)
add("crane_hook", crane_hook)
add("dump_truck_tip", v(tip, 180))
add("bucket_tip", v(tip, 220))
add("scoop_1", v(scoop, 180))
add("scoop_2", v(scoop, 200))
add("pile_dump_1", pile_dump)
add("pile_dump_2", pile_dump)
add("horn", horn_generic)
add("honk", honk_soft, trim=-2.0)
add("hop_in", hop_in)
add("hop_out", hop_out)
add("vehicle_rollout", vehicle_rollout)
add("garage_door", garage_door)
add("garage_waits", garage_waits)
add("backpack_full", backpack_full, trim=-2.0)

add("treasure_small", v(treasure_tier, 0))
add("treasure", v(treasure_tier, 1))
add("treasure_big", v(treasure_tier, 2), trim=1.0)
add("treasure_huge", v(treasure_tier, 3), trim=2.0)
add("treasure_reveal", treasure_reveal)
add("treasure_pickup", treasure_pickup)
add("treasure_hint", treasure_hint, trim=-4.0)
add("shelf_place", shelf_place)
add("polish", polish, trim=-2.0)

for i, f in enumerate((95, 85, 108), 1):
    add("fall_%d" % i, v(fall, f), trim=-1.0)
add("bonk_1", v(bonk, 520))
add("bonk_2", v(bonk, 460))
add("float_up", float_up)
add("flood", flood)
add("splash_1", v(splash, 1200))
add("splash_2", v(splash, 1000))
add("jump_1", v(jump, 330), trim=-4.0)
add("jump_2", v(jump, 370), trim=-4.0)
add("shake_off", shake_off)
add("rumble", rumble_cue, trim=-2.0)
add("cave_in", cave_in)
add("pop", pop)
add("prop_break", prop_break)
add("wall_crumble", wall_crumble)

add("elevator", elevator)
add("cage_door", cage_door)
add("elevator_clank", elevator_clank)
add("elevator_ding", elevator_ding)

add("build_place", build_place, trim=1.0)
add("build_unfold", build_unfold)
add("build_pick", build_pick, trim=-3.0)
add("build_pickup", build_pickup)
add("build_cancel", build_cancel, trim=-3.0)
add("cheer", cheer_small)
add("book_open", v(book, True), trim=-3.0)
add("book_close", v(book, False), trim=-3.0)
add("book_hint", book_hint, trim=-3.0)
add("bundle_pop", bundle_pop)
add("clipboard", clipboard, trim=-5.0)

add("tree_fall", tree_fall)
add("rock_crack_1", rock_crack)
add("rock_crack_2", rock_crack)
add("stump_pop", stump_pop)

add("whistle_1", v(gnome_whistle, 93, 98))
add("whistle_2", v(gnome_whistle, 95, 98))
add("whistle_3", v(gnome_whistle, 90, 95))
add("whistle_muffled", whistle_muffled)
add("march_step", march_step, trim=-6.0)
add("crew_march", crew_march, trim=-2.0)
add("crew_cheer", crew_cheer)
for k in ("wave", "steal", "sorry", "hello", "gift", "found", "pop"):
    add("mole_" + k, v(mole_sound, k))
add("shovel_back", shovel_back)
add("ice_drip_1", v(ice_drip, 93), trim=-6.0)
add("ice_drip_2", v(ice_drip, 90), trim=-6.0)
add("ice_crack", ice_crack)
for k in ("laugh", "hoot", "huh"):
    add("caveman_" + k, v(caveman, k))
add("dragon_snore_1", v(dragon, "snore"), trim=-2.0)
add("dragon_snore_2", v(dragon, "snore"), trim=-2.0)
for k in ("purr", "yawn", "flap", "boing", "hopeful", "mumble", "stretch", "whoosh"):
    add("dragon_" + k, v(dragon, k))
add("smoke_ring", v(dragon, "smoke_ring"))
for k in ("hope", "hm", "happy", "cheer", "arrive"):
    add("resident_" + k, v(resident, k))
add("ruin_rumble", v(resident, "ruin_rumble"))
add("light_on", v(resident, "light_on"))
for i, f in enumerate((200, 225, 250, 280), 1):
    add("plank_%d" % i, v(plank, f), trim=-2.0)
for who in ("mole", "caveman", "gnomes", "dragon"):
    add("payoff_" + who, v(payoff, who), trim=1.0)

# ui_move, ui_confirm, player_join: the Showtime menu kit (UiSound) synthesises its own.
add("round_start", round_start)
add("round_end", round_end)
add("pause", pause_cue, trim=-2.0)
add("solo_on", v(lambda rng: notes_seq([(74, 0.0), (86, 0.1)], rng, XYLO, 0.08)), trim=-2.0)
add("solo_off", v(lambda rng: notes_seq([(86, 0.0), (74, 0.1)], rng, XYLO, 0.08)), trim=-2.0)
add("split", split_cue, trim=-4.0)
add("action", action, trim=-3.0)

# Placeholder barks: voice/<character>_<cue>_<n>.ogg (Audio.bark falls back to these).
for i in range(1, 5):
    add("jeff_rock_name_%d" % i, v(lambda rng: babble(rng, "jeff", 3, 0.25)), "voice")
    add("chuck_narrate_%d" % i, v(lambda rng: babble(rng, "chuck", 4, -0.1)), "voice")
for i in range(1, 4):
    add("mole_oh_dear_%d" % i, bark_oh_dear, "voice")
    add("gnome_foreman_mutter_%d" % i, v(lambda rng: babble(rng, "gnome_foreman", 4)), "voice", -2.0)
add("gnome_foreman_whistle", bark_foreman_whistle, "voice")
add("dragon_rumble_1", bark_dragon_rumble, "voice", -2.0)
add("dragon_rumble_2", bark_dragon_rumble, "voice", -2.0)
add("dragon_yawn_1", v(dragon, "yawn"), "voice", -2.0)

add("music_down_layer_1", stem_drone, "stem", 0.0)
add("music_down_layer_2", stem_shimmer, "stem", -2.0)
add("music_down_layer_3", stem_bells, "stem", 0.0)
add("music_down_layer_4", stem_glass, "stem", -1.0)

# The order of handoff/sfx_preview.ogg: the main cues in play order.
PREVIEW = ["dig_dirt_1", "dig_clay_1", "dig_stone_1", "dig_ice_1", "dig_crystal_1", "fall_1",
           "bonk_1", "treasure_small", "treasure_huge", "elevator", "hop_in", "front_loader_horn",
           "dump_truck_reverse", "drill_rig_horn", "tree_fall",
           "build_place", "whistle_1", "mole_oh_dear_1", "light_on", "payoff_mole",
           "dragon_snore_1"]
# ---------------------------------------------------------------- ffmpeg

def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<i", int(round(max(-1.0, min(1.0, v)) * 8388607)))[:3]
                               for v in x))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def measure(path, tile=1):
    """(integrated LUFS, true peak dBTP) via ebur128. tile > 1 loops the input first."""
    cmd = ["ffmpeg", "-hide_banner", "-nostats"]
    if tile > 1:
        cmd += ["-stream_loop", str(tile - 1)]
    cmd += ["-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"]
    err = run(cmd).stderr
    summary = err[err.rfind("Summary:"):]
    num = r"(-?inf|-?\d+(?:\.\d+)?)"
    lufs = float(re.search(r"I:\s+" + num + r" LUFS", summary).group(1))
    peak = float(re.search(r"True peak:\s+Peak:\s+" + num, summary).group(1))
    return lufs, peak


def rms_db(path, highpass=None):
    af = "astats=metadata=0"
    if highpass:
        af = "highpass=f=%d,highpass=f=%d,highpass=f=%d," % ((highpass,) * 3) + af
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", af, "-f", "null", "-"]).stderr
    return float(re.findall(r"RMS level dB:\s+(-?inf|-?\d+(?:\.\d+)?)", err)[-1])


def dc_offset(path):
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "astats=metadata=0",
               "-f", "null", "-"]).stderr
    return float(re.findall(r"DC offset:\s+(-?\d+(?:\.\d+)?)", err)[-1])


def duration(path):
    out = run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-count_packets",
               "-show_entries", "stream=duration_ts,sample_rate,duration", "-of",
               "default=nw=1", path]).stdout
    return float(re.search(r"duration=([\d.]+)", out).group(1))


def decoded_samples(path):
    raw = run_bytes(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-"])
    return struct.unpack("<%df" % (len(raw) // 4), raw)


def run_bytes(cmd):
    return subprocess.run(cmd, capture_output=True, check=True).stdout


def encode(wav, ogg, gain_db):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", wav, "-af", "volume=%.2fdB" % gain_db,
         "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg])


def loop_seam(ogg, samples_in):
    """Decoded length must equal the rendered length; the jump across the seam should look
    like an ordinary sample-to-sample step."""
    y = decoded_samples(ogg)
    steps = [abs(y[i + 1] - y[i]) for i in range(len(y) - 1)]
    typical = sorted(steps)[int(len(steps) * 0.99)]
    return {"decoded": len(y), "rendered": samples_in, "first": y[0], "last": y[-1],
            "seam_step": abs(y[0] - y[-1]), "p99_step": typical, "max_step": max(steps)}


def spectrogram(ogg, out_png):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", ogg, "-filter_complex",
         "[0:a]asplit[a][b];[a]showspectrumpic=s=640x240:legend=0:stop=16000[s];"
         "[b]showwavespic=s=640x120:colors=white[w];[s][w]vstack", "-frames:v", "1", out_png])




LOOP_RATE = 22050   # loops and stems ship as PCM WAV: Vorbis loses ~128 samples at the seam


def out_path(stem, kind):
    sub = {"sfx": "sfx", "loop": "sfx", "voice": "voice", "stem": "music"}[kind]
    return os.path.join(AUDIO_DIR, sub, stem + (".wav" if kind in ("loop", "stem") else ".ogg"))


def write_wav16(path, x, rate):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(round(max(-1.0, min(1.0, v)) * 32767)))
                               for v in x))


def build_loop(stem, tmp, x, kind, trim):
    """Seamless loop: circular low-pass under the new Nyquist, decimate 2:1, loudness by gain."""
    x = soft(x, 9500.0, circular=True)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    target = (STEM_TARGET if kind == "stem" else SFX_TARGET) + trim
    lufs, peak = measure(wav)
    gain = min(target - lufs, TP_CEILING - 0.5 - peak)
    k = 10.0 ** (gain / 20.0)
    y = [v * k for v in x[::2]]
    out = out_path(stem, kind)
    write_wav16(out, y, LOOP_RATE)
    lufs, peak = measure(out)
    steps = sorted(abs(y[i + 1] - y[i]) for i in range(len(y) - 1))
    return {"stem": stem, "ogg": out, "kind": kind, "seconds": len(y) / LOOP_RATE, "lufs": lufs,
            "active_lufs": None, "true_peak": peak, "target": target,
            "hf_db": rms_db(out, 10000) - rms_db(out), "dc": dc_offset(out),
            "seam": {"decoded": len(y), "rendered": len(x) // 2, "seam_step": abs(y[0] - y[-1]),
                     "p99_step": steps[int(len(steps) * 0.99)]}}


def build(stem, tmp):
    make, kind, trim = FILES[stem]
    rng = random.Random("openjar-the-hill:" + stem)
    x = make(rng)
    if kind == "stem":
        x = (x + [0.0] * STEM_SAMPLES)[:STEM_SAMPLES]
    if kind in ("loop", "stem"):
        return build_loop(stem, tmp, x, kind, trim)
    if kind in ("sfx", "voice"):
        x = fades(dc_block(soft(x, 9500.0)), 0.001, 0.005)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    secs = len(x) / SR
    tile = 10 if kind in ("sfx", "voice") and secs < SHORT_CUE else 1
    target = (STEM_TARGET if kind == "stem" else SFX_TARGET) + trim
    lufs, peak = measure(wav, tile)
    short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    for _ in range(2):
        if kind not in ("sfx", "voice") or short_by <= 0.5:
            break
        # Peak-bound, not loudness-bound: limit the transients (at most 10 dB) and re-measure.
        x = peak_normalise(limit(x, 0.5 * 10.0 ** (-min(short_by, 10.0) / 20.0)), 0.5)
        write_wav(wav, x)
        lufs, peak = measure(wav, tile)
        short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    gain = min(target - lufs, TP_CEILING - 0.3 - peak)
    ogg = out_path(stem, kind)
    for _ in range(4):   # Vorbis can push peaks up a little; back off until under the ceiling
        encode(wav, ogg, gain)
        lufs, peak = measure(ogg, tile)
        if peak <= TP_CEILING:
            break
        gain -= peak - TP_CEILING + 0.1
    file_lufs = measure(ogg)[0] if tile > 1 else lufs
    r = {"stem": stem, "ogg": ogg, "kind": kind, "seconds": duration(ogg), "lufs": file_lufs,
         "active_lufs": lufs if tile > 1 else None, "true_peak": peak, "target": target,
         "hf_db": rms_db(ogg, 10000) - rms_db(ogg), "dc": dc_offset(ogg)}
    return r


def _job(args):
    stem, tmp = args
    return build(stem, tmp)


def preview(path, tmp):
    """Stitch PREVIEW with 0.35 s gaps (plus 2 s of the Front Loader engine after hop_in)."""
    parts = []
    gap = os.path.join(tmp, "gap.wav")
    write_wav(gap, silence(0.35))
    for stem in PREVIEW:
        parts.append(out_path(stem, FILES[stem][1]))
        if stem == "hop_in":
            eng = os.path.join(tmp, "engine_preview.wav")
            run(["ffmpeg", "-y", "-v", "error", "-stream_loop", "2", "-i",
                 out_path("front_loader_engine", "loop"), "-t", "2", "-ar", str(SR), "-ac", "1",
                 "-af", "afade=t=in:d=0.2,afade=t=out:st=1.7:d=0.3", eng])
            parts += [gap, eng]
        parts.append(gap)
    cmd = ["ffmpeg", "-y", "-hide_banner", "-v", "error"]
    for p in parts:
        cmd += ["-i", p]
    flt = "".join("[%d:a]aresample=%d,aformat=channel_layouts=mono[a%d];" % (i, SR, i)
                  for i in range(len(parts)))
    flt += "".join("[a%d]" % i for i in range(len(parts))) + "concat=n=%d:v=0:a=1[out]" % len(parts)
    run(cmd + ["-filter_complex", flt, "-map", "[out]", "-c:a", "libvorbis", "-q:a", "5", path])
    return duration(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("only", nargs="*", help="file stems to build (default: all)")
    ap.add_argument("--keep-wav", default=os.path.join(REPO, ".scratch", "cue-wav"),
                    help="WAV sources go here (default .scratch/cue-wav)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--preview", help="write the stitched preview .ogg here (after building)")
    ap.add_argument("--no-build", action="store_true", help="with --preview: just stitch")
    args = ap.parse_args()
    if args.list:
        for s, (_, kind, trim) in FILES.items():
            print("%-28s %-5s %+.1f" % (s, kind, trim))
        return
    stems = args.only or list(FILES)
    unknown = [s for s in stems if s not in FILES]
    if unknown:
        sys.exit("unknown stem(s): %s" % ", ".join(unknown))
    tmp = args.keep_wav
    os.makedirs(tmp, exist_ok=True)
    for sub in ("sfx", "voice", "music"):
        os.makedirs(os.path.join(AUDIO_DIR, sub), exist_ok=True)
    if not args.no_build:
        print("%-24s %-5s %7s %7s %7s %6s %7s %8s" % ("file", "kind", "sec", "LUFS", "active", "TP",
                                                    ">10k", "DC"))
        # Longest first so the stems do not finish last on one core.
        order = sorted(stems, key=lambda s: FILES[s][1] != "stem")
        with Pool(args.jobs) as pool:
            for r in pool.imap_unordered(_job, [(s, tmp) for s in order]):
                act = "%7.1f" % r["active_lufs"] if r["active_lufs"] is not None else "%7s" % "-"
                print("%-24s %-5s %7.3f %7.1f %s %6.1f %7.1f %8.5f" % (
                    r["stem"], r["kind"], r["seconds"], r["lufs"], act, r["true_peak"], r["hf_db"],
                    r["dc"]), flush=True)
                if "seam" in r:
                    s = r["seam"]
                    print("  loop: decoded %d / rendered %d, seam step %.4f (p99 %.4f)" % (
                        s["decoded"], s["rendered"], s["seam_step"], s["p99_step"]), flush=True)
    if args.preview:
        print("preview: %s (%.1f s)" % (args.preview, preview(args.preview, tmp)))


if __name__ == "__main__":
    main()
