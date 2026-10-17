"""Sector 03 combat music: a seamless 64-bar loop at 128 BPM in A minor (2 minutes).

Drums are ElevenLabs one-shots (source_art/audio/music_samples, made with generate_audio-style prompts);
bass, arpeggio, pads and lead are synthesised here with numpy and processed/mastered with ffmpeg.
Run:  python3 source_art/audio/compose_music.py   ->  assets/audio/music.ogg
"""
import os, subprocess, tempfile
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SAMPLES = os.path.join(ROOT, 'source_art', 'audio', 'music_samples')
OUT = os.path.join(ROOT, 'assets', 'audio', 'music.ogg')
SR = 44100
BPM = 128
BEAT = 60 / BPM
BAR = 4 * BEAT
STEP = BEAT / 4  # sixteenth
BARS = 64
N = int(round(BARS * BAR * SR))
rng = np.random.default_rng(3)

# Arrangement (bar ranges): intro, drop A, break, drop B (lead), A2 -> loops back to intro
SECTIONS = [('intro', 0, 8), ('a', 8, 24), ('break', 24, 32), ('b', 32, 48), ('a2', 48, 64)]
# Am - F - C - G, two bars each
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
BASS_ROOT = [45, 41, 48, 43]
LEAD = [76, 74, 72, 74, 76, 79, 76, 72, 74, 72, 71, 72, 74, 76, 74, 71]  # one note per beat over 4 bars


def section(bar):
    for name, a, b in SECTIONS:
        if a <= bar < b:
            return name, bar - a, b - a
    return 'a2', 0, 16


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def at(t):
    return int(round(t * SR))


def load(name):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(SAMPLES, name + '.mp3'), '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).copy()
    nz = np.nonzero(np.abs(x) > .02)[0]
    x = x[nz[0]:] if len(nz) else x
    return x / (np.max(np.abs(x)) + 1e-9)


def add(buf, start, x, gain=1.0):
    s = at(start)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(x))
    buf[s:e] += x[:e - s] * gain


def env(n, a, d, sus=1.0, rel=None):
    t = np.arange(n) / SR
    out = np.minimum(1.0, t / max(a, 1e-4))
    if rel is not None:
        out *= np.clip((n / SR - t) / rel, 0, 1)
    return out * (sus + (1 - sus) * np.exp(-t / max(d, 1e-4)))


def saw(f, n, detune=0.0, voices=1):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voices):
        fv = f * (1 + detune * (v - (voices - 1) / 2))
        ph = (t * fv + rng.random()) % 1.0
        out += 2 * ph - 1
    return out / voices


def pulse(f, n, width=.5):
    t = np.arange(n) / SR
    return np.where((t * f) % 1.0 < width, 1.0, -1.0)


def ffx(x, filters):
    """Run a mono float buffer through an ffmpeg filter chain."""
    with tempfile.TemporaryDirectory() as d:
        src, dst = os.path.join(d, 'i.f32'), os.path.join(d, 'o.f32')
        x.astype(np.float32).tofile(src)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', src,
                        '-af', filters, '-f', 'f32le', '-ar', str(SR), '-ac', '1', dst], check=True)
        y = np.fromfile(dst, dtype=np.float32).astype(np.float64)
    out = np.zeros(len(x)); out[:min(len(x), len(y))] = y[:len(x)]
    return out


def main():
    kick, snare, clap, hat, ohat, riser, impact = (load(n) for n in ('kick', 'snare', 'clap', 'hat', 'ohat', 'riser', 'impact'))
    drums, bass, arp, pad, lead, fx = (np.zeros(N) for _ in range(6))
    duck = np.ones(N)  # sidechain envelope from the kick
    for bar in range(BARS):
        name, i, length = section(bar)
        t0 = bar * BAR
        chord = CHORDS[(bar // 2) % 4]
        root = BASS_ROOT[(bar // 2) % 4]
        full = name in ('a', 'b', 'a2')
        # ---- drums
        for beat in range(4):
            tb = t0 + beat * BEAT
            if full or (name == 'intro' and i >= 4):
                add(drums, tb, kick, .95)
                d = env(at(.32), .002, .09, 0.0)
                duck[at(tb):at(tb) + len(d)] = np.minimum(duck[at(tb):at(tb) + len(d)], 1 - .75 * (1 - np.clip(np.arange(len(d)) / at(.24), 0, 1)))
            if full and beat in (1, 3):
                add(drums, tb, snare, .55); add(drums, tb, clap, .35)
            for s in range(4):
                if name != 'break' or i >= 4:
                    add(drums, tb + s * STEP, hat, (.26 if s % 2 else .16) * (1.0 if full else .7))
            if full and beat % 2 == 1:
                add(drums, tb + 2 * STEP, ohat, .18)
        if full and bar % 8 == 7:  # fill: snare roll in the last beat
            for s in range(4):
                add(drums, t0 + 3 * BEAT + s * STEP, snare, .25 + .1 * s)
        # ---- bass: offbeat-pumping eighths, octave jumps in the drops
        if name != 'break':
            for e in range(8):
                note = root + (12 if (full and e % 4 == 3) else 0)
                n = at(STEP * 1.8)
                x = saw(hz(note), n, .006, 2) * env(n, .003, .12, .55, .02)
                add(bass, t0 + e * 2 * STEP, x, .5 if full else .3)
        # ---- arp: sixteenth chord tones, two octaves
        if name in ('a', 'break', 'b', 'a2') or (name == 'intro' and i >= 2):
            order = [0, 1, 2, 1, 0, 2, 1, 2]
            for s in range(16):
                note = chord[order[s % 8]] + (12 if s // 8 else 0) + 12
                n = at(STEP * .9)
                x = pulse(hz(note), n, .3) * env(n, .002, .07, .0, .01)
                add(arp, t0 + s * STEP, x, .16 if name != 'intro' else .1)
        # ---- pad: sustained chord every two bars
        if bar % 2 == 0:
            n = at(2 * BAR)
            x = sum(saw(hz(m), n, .01, 3) for m in chord + [chord[0] - 12]) / 4
            add(pad, t0, x * env(n, .6, 1.0, 1.0, .5), .32 if name in ('intro', 'break') else .2)
        # ---- lead melody in drop B
        if name == 'b':
            for beat in range(4):
                m = LEAD[(i % 4) * 4 + beat]
                n = at(BEAT * .95)
                x = (saw(hz(m), n, .004, 2) * .6 + np.sin(2 * np.pi * hz(m) * np.arange(n) / SR) * .4) * env(n, .01, .25, .6, .05)
                add(lead, t0 + beat * BEAT, x, .22)
        # ---- transitions
        if name == 'break' and i == length - 2:
            add(fx, t0 + 2 * BAR - len(riser) / SR, riser, .45)
        if name in ('a', 'b') and i == 0:
            add(fx, t0, impact, .5)
    # ---- process stems
    bass = ffx(bass, 'lowpass=f=900,lowpass=f=900,highpass=f=35') * duck
    arp = ffx(arp, 'lowpass=f=3800,aecho=0.8:0.6:352:0.35')  # dotted-eighth-ish delay at 128 BPM
    pad = ffx(pad, 'lowpass=f=1800,highpass=f=120,aecho=0.8:0.7:60|97|133:0.4|0.3|0.25') * (.55 + .45 * duck)
    lead = ffx(lead, 'lowpass=f=4200,aecho=0.8:0.5:469:0.3')
    drums = ffx(drums, 'highpass=f=25')
    mix = drums * .9 + bass + arp + pad + lead + fx
    # stereo-ish width: delayed copy of pads/arp on the right
    left = mix
    right = mix.copy()
    width = np.roll(pad + arp, at(.012))
    right += (width - (pad + arp)) * .35
    stereo = np.stack([left, right], axis=1)
    stereo /= np.max(np.abs(stereo)) + 1e-9
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, 'mix.f32')
        stereo.astype(np.float32).tofile(src)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', src,
                        '-af', 'acompressor=threshold=-14dB:ratio=3:attack=10:release=120,loudnorm=I=-16:TP=-1.5:LRA=9',
                        '-ar', str(SR), '-c:a', 'libvorbis', '-q:a', '6', OUT], check=True)
    print('MUSIC_OK', OUT, round(N / SR, 1), 's')


if __name__ == '__main__':
    main()
