"""Mix production card cues on the rendered frame clock, then optionally remux."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import wave
import numpy as np

RATE = 48000

def run(command):
    return subprocess.run(command, check=True, capture_output=True,
                          creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))

def mix_audio(project, timeline, output, ffmpeg, intro=4.0, outro=4.0):
    project, output, ffmpeg = Path(project), Path(output), Path(ffmpeg)
    info = json.loads(Path(timeline).read_text(encoding='utf8'))
    assert not info.get('preview'), 'Preview frames cannot be mixed as a complete video'
    assert info.get('audio_cues'), 'Re-run capture.gd to export production sound cues'
    fps = info['fps']
    seconds = intro + info['frames']/fps + outro
    length = round(seconds*RATE)
    cache, source_hashes = {}, {}

    def decode(resource):
        assert resource.startswith('res://')
        source = (project/resource[6:]).resolve()
        assert source.is_relative_to(project.resolve()) and source.is_file()
        if resource not in cache:
            raw = run([str(ffmpeg), '-v', 'error', '-i', str(source), '-f', 'f32le',
                       '-ac', '2', '-ar', str(RATE), 'pipe:1']).stdout
            cache[resource] = np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()
            source_hashes[resource] = hashlib.sha256(source.read_bytes()).hexdigest()
        return cache[resource]

    music_source = decode('res://assets/music/woodland_fantasy.mp3')
    music = np.tile(music_source, (int(np.ceil(length/len(music_source))), 1))[:length].copy()
    effects = np.zeros((length, 2), dtype=np.float32)
    duck = np.ones(length, dtype=np.float32)
    cues = []
    for cue in info['audio_cues']:
        start = round((intro+cue['frame']/fps)*RATE)
        sound = decode(cue['file']).copy()*float(cue.get('gain', 1.0))*0.9
        # Production cut_with_stage cues end at the stage boundary. Other tails
        # survive subsequent stages, but reset when the next preset match starts.
        end_frame = cue['stage_last']+1 if cue.get('cut_with_stage') else next(
            (s['first'] for s in info.get('audio_matches', [])
             if s['first'] > cue['frame'] and s['match'] != cue['match']), info['frames'])
        end = min(length, round((intro+end_frame/fps)*RATE), start+len(sound))
        assert end > start >= 0
        truncated = end-start < len(sound)
        sound = sound[:end-start]
        if truncated:
            fade = min(len(sound), round(.005*RATE))
            sound[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None]
        effects[start:end] += sound
        # A short, smooth music dip keeps quiet paper and metal details audible.
        before, after = max(0, start-round(.055*RATE)), min(length, end+round(.32*RATE))
        duck[before:start] = np.minimum(duck[before:start], np.linspace(1, .45, start-before))
        duck[start:end] = np.minimum(duck[start:end], .45)
        duck[end:after] = np.minimum(duck[end:after], np.linspace(.45, 1, after-end))
        cues.append({**cue, 'start_seconds': start/RATE, 'end_seconds': end/RATE,
                     'truncated_at_boundary': truncated, 'rms': float(np.sqrt(np.mean(sound**2)))})
    fade = np.ones(length, dtype=np.float32)
    fade[:round(1.5*RATE)] = np.linspace(0, 1, round(1.5*RATE))
    fade[-3*RATE:] = np.linspace(1, 0, 3*RATE)
    music *= (.24*duck*fade)[:, None]
    mixed = music+effects
    peak = float(np.max(np.abs(mixed)))
    master = min(1.0, .95/max(peak, 1e-9))
    mixed *= master
    output.parent.mkdir(parents=True, exist_ok=True)
    def write_wav(path, samples):
        assert float(np.max(np.abs(samples))) < 1.0
        with wave.open(str(path), 'wb') as writer:
            writer.setnchannels(2); writer.setsampwidth(2); writer.setframerate(RATE)
            writer.writeframes(np.rint(samples*32767).astype('<i2').tobytes())
    write_wav(output, mixed)
    # Separate stems make audible presence and synchronized contacts verifiable.
    write_wav(output.with_name('demo-sfx.wav'), effects*master)
    write_wav(output.with_name('demo-music.wav'), music*master)
    manifest = {'duration_seconds': seconds, 'sample_rate': RATE, 'channels': 2,
                'music_gain': .24, 'music_duck_gain': .45, 'sfx_gain': .9,
                'master_gain': master, 'peak': float(np.max(np.abs(mixed))),
                'clipped_samples': int(np.count_nonzero(np.abs(mixed)>=1)),
                'source_sha256': source_hashes, 'cues': cues,
                'wav_sha256': hashlib.sha256(output.read_bytes()).hexdigest()}
    output.with_suffix('.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    return manifest

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for flag in ['project', 'timeline', 'output', 'ffmpeg']:
        parser.add_argument('--'+flag, type=Path, required=True)
    parser.add_argument('--video', type=Path, help='Existing video; preserve its picture stream exactly')
    parser.add_argument('--output-video', type=Path)
    args = parser.parse_args()
    manifest = mix_audio(args.project, args.timeline, args.output, args.ffmpeg)
    if args.video:
        assert args.output_video and args.video.resolve() != args.output_video.resolve()
        run([str(args.ffmpeg), '-y', '-v', 'error', '-i', str(args.video), '-i', str(args.output),
             '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
             '-t', str(manifest['duration_seconds']), '-movflags', '+faststart', str(args.output_video)])
    print(json.dumps({k: v for k, v in manifest.items() if k not in ['source_sha256', 'cues']}, indent=2))
