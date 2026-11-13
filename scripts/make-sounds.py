#!/usr/bin/env python3
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds")

def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE

def env(x, attack, decay):
    a = np.minimum(1, x / max(attack, 1e-6))
    return a * np.exp(-x / decay)

def save(name, samples, gain=0.9):
    samples = samples / (np.max(np.abs(samples)) or 1) * gain
    fade = int(RATE * 0.004)
    samples[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, f"tap_{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((samples * 32767).astype(np.int16).tobytes())

def click():
    x = t(0.05)
    noise = np.random.default_rng(1).standard_normal(len(x))
    hp = np.diff(noise, prepend=0)
    tone = np.sin(2 * np.pi * 3200 * x)
    return (hp * 0.6 + tone * 0.5) * env(x, 0.0004, 0.006)

def pop():
    x = t(0.09)
    f = 380 + 1100 * (1 - np.exp(-x / 0.012))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * env(x, 0.001, 0.022)

def wood():
    x = t(0.12)
    s = np.sin(2 * np.pi * 820 * x) * 1.0 + np.sin(2 * np.pi * 2350 * x) * 0.45 + np.sin(2 * np.pi * 4100 * x) * 0.15
    noise = np.random.default_rng(2).standard_normal(len(x)) * env(x, 0.0003, 0.002) * 0.4
    return s * env(x, 0.0006, 0.028) + noise

def boop():
    x = t(0.14)
    f = 260 - 70 * (x / x[-1])
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return (np.sin(phase) + 0.2 * np.sin(2 * phase)) * env(x, 0.003, 0.045)

def sweep(f):
    return 2 * np.pi * np.cumsum(f) / RATE

def noise(n, seed):
    return np.random.default_rng(seed).standard_normal(n)

def bandpass(sig, lo, hi):
    spec = np.fft.rfft(sig)
    freqs = np.fft.rfftfreq(len(sig), 1 / RATE)
    spec[(freqs < lo) | (freqs > hi)] = 0
    return np.fft.irfft(spec, len(sig))

def tock():
    x = t(0.09)
    s = np.sin(2 * np.pi * 520 * x) + 0.4 * np.sin(2 * np.pi * 1460 * x)
    return s * env(x, 0.0005, 0.018) + 0.3 * bandpass(noise(len(x), 3), 800, 4000) * env(x, 0.0002, 0.002)

def clack():
    x = t(0.08)
    low = np.sin(2 * np.pi * 150 * x) * env(x, 0.0005, 0.012)
    top = bandpass(noise(len(x), 5), 1200, 6000) * env(x, 0.0002, 0.004)
    return low * 0.8 + top

def typewriter():
    x = t(0.1)
    strike = bandpass(noise(len(x), 6), 2000, 9000) * env(x, 0.0001, 0.003)
    body = np.sin(2 * np.pi * 380 * x) * env(x, 0.001, 0.02)
    k = int(RATE * 0.018)
    late = np.zeros(len(x))
    late[k:] = bandpass(noise(len(x) - k, 7), 3000, 9000) * env(x[: len(x) - k], 0.0001, 0.002) * 0.5
    return strike + 0.6 * body + late

def snap():
    x = t(0.06)
    burst = bandpass(noise(len(x), 8), 1500, 7000) * env(x, 0.0002, 0.006)
    return burst + 0.4 * np.sin(2 * np.pi * 2100 * x) * env(x, 0.0002, 0.004)

def blip():
    x = t(0.07)
    return np.sign(np.sin(2 * np.pi * 988 * x)) * 0.5 * env(x, 0.0005, 0.03)

def coin():
    x = t(0.18)
    f = np.where(x < 0.05, 988, 1319)
    return np.sign(np.sin(sweep(f))) * 0.5 * env(x, 0.0005, 0.07)

def pew():
    x = t(0.12)
    f = 2400 * np.exp(-x / 0.03) + 300
    return np.sign(np.sin(sweep(f))) * 0.4 * env(x, 0.0005, 0.05)

def quack():
    x = t(0.14)
    ph = sweep(520 - 120 * x / x[-1])
    s = sum(np.sin(k * ph) / k for k in range(1, 9))
    return bandpass(s, 600, 2600) * env(x, 0.004, 0.06)

def chirp():
    x = t(0.09)
    f = 2600 + 1400 * np.sin(np.pi * x / x[-1])
    return np.sin(sweep(f)) * np.sin(np.pi * x / x[-1]) * np.exp(-x / 0.06)

def squeak():
    x = t(0.13)
    f = 1150 + 650 * np.sin(np.pi * x / x[-1]) + 30 * np.sin(2 * np.pi * 38 * x)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    shape = np.sin(np.pi * np.minimum(1, x / x[-1]))
    return (np.sin(phase) + 0.3 * np.sin(2 * phase)) * shape * np.exp(-x / 0.09)

def main():
    os.makedirs(OUT, exist_ok=True)
    sounds = [click, tock, clack, typewriter, snap, wood, pop, boop, blip, coin, pew, squeak, quack, chirp]
    for name, fn in [(fn.__name__, fn) for fn in sounds]:
        save(name, fn())
    print("wrote", sorted(os.listdir(OUT)))

if __name__ == "__main__":
    main()
