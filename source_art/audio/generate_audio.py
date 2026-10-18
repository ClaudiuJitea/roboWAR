"""Generate Sector 03 sound effects and music with the ElevenLabs API.

Usage:  ELEVENLABS_API_KEY=... python3 source_art/audio/generate_audio.py [name ...]
Raw MP3 responses go to source_art/audio/raw/ and trimmed, loudness-normalised
OGG files to assets/audio/. The key is read from the environment only; never commit it.
"""
import json, os, subprocess, sys, urllib.request, urllib.error

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RAW = os.path.join(ROOT, 'source_art', 'audio', 'raw')
OUT = os.path.join(ROOT, 'assets', 'audio')
API = 'https://api.elevenlabs.io/v1'

# name: (prompt, requested seconds, trimmed max seconds, loudness target LUFS)
SFX = {
    # machine gun and rifle: real gunfire bursts, keeping the last shot (LAST_SHOT)
    'minigun': ('Heavy machine gun firing a long burst, powerful booming 7.62 rounds, rhythmic rapid fire with a rolling outdoor echo, realistic military recording', 1.6, .16, -14),
    'sword': ('Energy sword swing, quick plasma blade whoosh with a bright electric hum, sci-fi, dry', .7, .45, -15),
    # hand cannon: real handgun range takes beat "magnum" prompts, which come back as dull thumps; the last shot is kept (LAST_SHOT)
    'pistol': ('Police officer firing a handgun three times outdoors, loud realistic pistol shots with a sharp crack and quick echo, no ricochet', 3.0, .45, -13),
    'rail': ('Railgun discharge, powerful electric crack and magnetic zap with a short metallic ring, sci-fi weapon', 1.2, .9, -14),
    'bolt': ('Arcane energy bolt launched from a gauntlet, purple magic whoosh with a soft electric sparkle, sci-fi', .8, .5, -16),
    'rifle': ('Battle rifle 7.62 NATO gunshots, three slow shots outdoors, powerful sharp crack and thunderous body with a long natural tail, documentary sound recording', 3.0, .45, -14),
    # single-shot SMG prompts come back near silent; a full-auto burst sounds right, so its last shot is kept (LAST_SHOT)
    'smg': ('Submachine gun firing a quick full-auto burst of rapid 9mm shots, very fast rate of fire, loud punchy reports and mechanical rattle, realistic recording', 1.0, .15, -16),
    'shotgun': ('One single loud shotgun blast, huge punchy boom with a short sharp tail, gunshot only, no pump, no reload, no click, no shell sounds', 1.0, .5, -12),
    'rocket': ('Rocket launcher firing, whoosh of a missile launching with a hissing thruster, sci-fi', 1.0, .75, -15),
    'grenade': ('Grenade launcher firing, hollow thump pop of a launched grenade, short, sci-fi', .5, .35, -16),
    'plasma': ('Plasma gun shot, short bright energy zap with a purple electric fizz, sci-fi', .5, .25, -17),
    'explosion': ('Punchy explosion with debris, short powerful blast and metal fragments, video game', 1.6, 1.3, -13),
    'destroyed_1': ('Combat robot destroyed: sharp metallic crunch, electrical burst and small metal parts scattering on a hard floor, punchy, short, video game', 1.0, .65, -14),
    'destroyed_2': ('Small sci-fi drone smashed apart, heavy metal clang with a crackling spark pop and debris rattle, punchy and dry', 1.0, .65, -14),
    'destroyed_3': ('Robot enemy blown to pieces, crunchy servo break, short electric zap and scattered metal fragments, arcade game sound', 1.0, .65, -14),
    'blade_hit': ('Energy sword slicing through metal armor, hot sizzling cut with a bright metallic ring, short', .6, .4, -15),
    'sniper': ('One powerful long-range sniper rifle shot: sharp supersonic crack, deep heavy boom and a long rolling outdoor echo tail, realistic, single shot only, no reload', 2.0, 1.6, -12),
    'rack': ('Bolt-action sniper rifle cycling: bolt lifted and pulled back, empty brass casing ejected and tinkling on concrete, bolt pushed forward and locked, crisp mechanical, short', 1.2, .9, -16),
    'switch': ('Weapon swap, quick mechanical click and clack of a gun being readied, short', .5, .25, -18),
    'shatter': ('Small metal robot shattering into pieces, crunchy break and metal bits scattering on the floor, short', .8, .55, -18),
    'disintegrate': ('Robot disintegrating into energy, rising electric dissolve shimmer with a soft crackle, sci-fi', 1.0, .7, -18),
    'windup': ('Small robot charging an attack, quick rising electronic whine, servo motor, sci-fi', .8, .6, -18),
    'damage': ('Metal robot armour hit, hard clank impact with a small electric spark, game sound effect, dry', .5, .3, -16),
    'death': ('Small combat robot destroyed, short electrical burst, sparks and metal parts clattering on the floor', 1.2, .9, -16),
    'pickup': ('Health pickup collected, bright positive sci-fi chime, short and clean', .7, .55, -17),
    'wave': ('Industrial facility alarm, short two-tone klaxon warning for a new enemy wave, sci-fi', 1.8, 1.6, -17),
    'ui': ('Clean minimal UI click, soft digital tick for a menu button, very short', .5, .12, -20),
}
LAST_SHOT = {'smg', 'minigun', 'rifle', 'pistol'}  # burst takes: keep only the final shot and its natural tail
MUSIC_PROMPT = ('Driving electronic action loop for a top-down sci-fi arena shooter, industrial synth bass, '
                'tight drums, tense but upbeat, instrumental, no vocals, seamless loop')


def post(path, payload, key):
    req = urllib.request.Request(API + path, data=json.dumps(payload).encode(),
                                 headers={'xi-api-key': key, 'Content-Type': 'application/json', 'Accept': 'audio/mpeg'})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def last_shot_start(src):
    """Seconds where the last shot of a burst begins: 8 ms before the envelope's last upward crossing of half its peak
    that follows a real gap (below 30% of the peak) and reaches 80% of the peak, so an echo hump is not a new shot."""
    import numpy as np
    sr = 44100
    x = np.frombuffer(subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', src, '-f', 'f32le', '-ac', '1', '-ar', str(sr), '-'],
                                     capture_output=True, check=True).stdout, np.float32)
    hop = int(.005 * sr)
    env = np.convolve(np.abs(x), np.ones(441) / 441, 'same')[::hop]
    half = env.max() * .5
    rises, gap = [], True
    for i in range(1, len(env)):
        if env[i] < env.max() * .3:
            gap = True
        if env[i - 1] < half <= env[i] and gap and env[i:i + 8].max() >= env.max() * .8:
            rises.append(i); gap = False
    return max(0.0, rises[-1] * hop / sr - .008) if rises else 0.0


def master(src, dst, max_s, lufs, loop=False, start=None):
    fade = min(.08, max_s * .3)
    if start is not None:  # sliced from inside a take: tiny fade-in instead of silence trimming
        filters = [f'atrim={start}:{start + max_s}', 'asetpts=N/SR/TB', 'afade=t=in:d=0.002', f'afade=t=out:st={max_s - fade}:d={fade}']
    else:
        filters = [] if loop else ['silenceremove=start_periods=1:start_threshold=-50dB', f'atrim=0:{max_s}', f'afade=t=out:st={max_s - fade}:d={fade}']
    filters.append(f'loudnorm=I={lufs}:TP=-1.5:LRA=11')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-af', ','.join(filters),
                    '-ar', '44100', '-ac', '1' if not loop else '2', '-c:a', 'libvorbis', '-q:a', '5', dst], check=True)


def main():
    key = os.environ.get('ELEVENLABS_API_KEY')
    if not key:
        sys.exit('Set ELEVENLABS_API_KEY')
    os.makedirs(RAW, exist_ok=True); os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or list(SFX) + ['music']
    for name in wanted:
        raw = os.path.join(RAW, name + '.mp3')
        try:
            if name == 'music':
                try:
                    data = post('/music', {'prompt': MUSIC_PROMPT, 'music_length_ms': 60000}, key)
                except urllib.error.HTTPError as e:
                    print('music endpoint unavailable (%s), using a looping sound generation instead' % e.code)
                    data = post('/sound-generation', {'text': MUSIC_PROMPT, 'duration_seconds': 22, 'prompt_influence': .5, 'loop': True}, key)
            else:
                prompt, seconds, _, _ = SFX[name]
                data = post('/sound-generation', {'text': prompt, 'duration_seconds': seconds, 'prompt_influence': .6}, key)
        except urllib.error.HTTPError as e:
            print('FAILED', name, e.code, e.read()[:300].decode(errors='replace'))
            continue
        open(raw, 'wb').write(data)
        if name == 'music':
            master(raw, os.path.join(OUT, 'music.ogg'), 0, -20, loop=True)
        else:
            _, _, max_s, lufs = SFX[name]
            master(raw, os.path.join(OUT, name + '.ogg'), max_s, lufs, start=last_shot_start(raw) if name in LAST_SHOT else None)
        print('OK', name, len(data), 'bytes')


if __name__ == '__main__':
    main()
