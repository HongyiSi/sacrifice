/* Long music is decoded by the browser's media pipeline, independently of
 * Godot's frame/mixing loop. Keep one unlocked element; never decode a whole
 * song into a Web Audio buffer. Original recordings are cached by content hash. */
(() => {
  const tracks = ['music-lobby.wav', 'music-battle.mp3'];
  const media = new Audio();
  media.loop = true;
  media.preload = 'auto';
  media.setAttribute('playsinline', '');
  const urls = new Map(), pending = new Map(), attempts = new Map();
  let desired = 0, current = -1, generation = 0, level = .5, unlocked = false;
  let context, gain, switching;
  const report = event => window.sacrificeDiagnostic?.('music_' + event, JSON.stringify(status()));
  function status() {
    return {track:current, desired, paused:media.paused, ready:media.readyState,
      time:Math.round(media.currentTime || 0), context:context?.state || 'locked'};
  }
  function volume(fade = .08) {
    if (!gain) return;
    const now = context.currentTime;
    gain.gain.cancelScheduledValues(now);
    gain.gain.setValueAtTime(gain.gain.value, now);
    gain.gain.linearRampToValueAtTime(switching || current < 0 ? 0 : level, now + fade);
  }
  function play() {
    if (!unlocked || document.hidden || desired < 0) return;
    context.resume().catch(() => report('resume_blocked'));
    media.play().catch(error => { if (error.name !== 'AbortError') report('play_blocked'); });
  }
  async function load(track) {
    if (urls.has(track)) return urls.get(track);
    if (pending.has(track)) return pending.get(track);
    const request = (async () => {
      const response = await fetch(new URL(tracks[track], document.baseURI));
      if (!response.ok) throw new Error('music HTTP ' + response.status);
      // The full compressed recording is local before playback; no network
      // buffer underrun or cross-origin media source is involved during a song.
      const blob = new Blob([await response.arrayBuffer()], {type:track === 0 ? 'audio/wav' : 'audio/mpeg'});
      const url = URL.createObjectURL(blob);
      urls.set(track, url);
      return url;
    })();
    pending.set(track, request);
    try { return await request; } finally { pending.delete(track); }
  }
  async function update() {
    const track = desired, ticket = generation;
    if (track < 0) { media.pause(); current = -1; volume(); return; }
    if (track === current) { play(); return; }
    try {
      const url = await load(track);
      if (ticket !== generation || !unlocked) return;
      // Reuse the same element after the user's gesture, including source changes.
      clearTimeout(switching);
      switching = setTimeout(() => {
        switching = null;
        if (ticket !== generation) return;
        media.src = url; current = track;
        volume(.45); play();
      }, current < 0 ? 0 : 200);
      volume(.18);
    } catch {
      report('download_failed');
      const count = (attempts.get(track) || 0) + 1; attempts.set(track, count);
      if (count < 3) setTimeout(() => { if (desired === track) update(); }, 5000);
    }
  }
  function unlock() {
    if (!context) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      context = new AudioContext();
      gain = context.createGain(); gain.gain.value = 0;
      context.createMediaElementSource(media).connect(gain).connect(context.destination);
      context.addEventListener('statechange', () => report('context'));
      // One silent PCM frame unlocks this reusable element during the actual
      // tap even if its first recording is still downloading.
      media.src = 'data:audio/wav;base64,UklGRiYAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQIAAAAAAA==';
    }
    unlocked = true;
    play();
    update();
  }
  for (const event of ['waiting', 'stalled', 'error', 'playing']) media.addEventListener(event, () => report(event));
  document.addEventListener('visibilitychange', () => { if (document.hidden) media.pause(); else if (unlocked) play(); });
  document.addEventListener('pointerup', () => {
    if (unlocked && desired >= 0 && (media.paused || context.state !== 'running')) { play(); update(); }
  });
  window.sacrificeMusic = {
    unlock, status,
    prepare() { load(desired).catch(() => {}); },
    setContext(value) {
      const next = value === 0 || value === 1 ? value : -1;
      if (next === desired) return;
      desired = next; generation++; clearTimeout(switching); switching = null;
      if (next < 0) { media.pause(); current = -1; volume(); }
      else if (unlocked) update();
    },
    setLevel(value) { level = Math.max(0, Math.min(1, value)); volume(); },
  };
})();
