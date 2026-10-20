/* Bounded first-party diagnostics. No hands, names, action payloads or tokens. */
(() => {
  const storageGet = key => { try { return JSON.parse(sessionStorage.getItem(key)); } catch { return null; } };
  const storageSet = (key, value) => { try { sessionStorage.setItem(key, JSON.stringify(value)); } catch {} };
  const previous = storageGet('sacrifice-checkpoint');
  const id = Math.random().toString(36).slice(2, 12) + Date.now().toString(36);
  const recent = [];
  let sequence = 0, allowance = 8, criticalAllowance = 2, lastState = '', lastChange = 0;
  const criticalEvents = new Set(['js_error','unhandled_rejection','webgl_context_lost','load_failure','pagehide','previous_page']);
  window.sacrificeSaveResume = value => storageSet('sacrifice-resume', {...value, at: Date.now()});
  window.sacrificeClearResume = () => { storageSet('sacrifice-resume', null); emit('leave'); };
  window.sacrificeResumeCandidate = () => {
    const value = storageGet('sacrifice-resume');
    const requested = new URLSearchParams(location.search).get('room')?.toUpperCase();
    return value && /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$/.test(value.room) && Date.now()-value.at < 21600000 && (!requested || requested === value.room) ? value : null;
  };
  function snapshot() {
    const s = window.sacrificeStatus || {}, c = document.getElementById('canvas');
    // All values below are produced by our own bridge; omit user-supplied names.
    return {room:s.room || '', team:s.team ?? -1, version:s.version || window.sacrificeAssetCache?.manifest?.version || '', phase:s.phase || 'loading', round:s.round || 0,
      revision:s.revision || 0, animation:s.animation || {}, reconnecting:!!s.reconnecting, peer_missing:!!s.peer_missing,
      visibility:document.visibilityState, online:navigator.onLine, canvas:c ? [c.width,c.height] : [],
      native:window.sacrificeNativeMetrics || {}, music:window.sacrificeMusic?.status() || {},
      wasm_bytes:window.sacrificeRuntimeMetrics?.().wasm_bytes || 0,
      pack_bytes:window.sacrificeRuntimeMetrics?.().pack_bytes || 0,
      pack_name:window.sacrificeRuntimeMetrics?.().pack_name || '',
      js_bytes:performance.memory?.usedJSHeapSize || null};
  }
  function emit(event, detail = '') {
    const row = {id, seq:++sequence, at:Date.now(), event, state:snapshot(), detail:String(detail).slice(0,700)};
    recent.push({at:row.at,event,phase:row.state.phase,round:row.state.round,animation:row.state.animation});
    if (recent.length > 8) recent.shift();
    storageSet('sacrifice-checkpoint', {id,at:row.at,event,state:row.state,recent});
    // Ordinary state/music bursts must not crowd out the crash evidence.
    if (allowance > 0) allowance--;
    else if (criticalEvents.has(event) && criticalAllowance > 0) criticalAllowance--;
    else return;
    const url = '/client-diagnostics?d=' + encodeURIComponent(JSON.stringify(row));
    // Beacon can finish after navigation and does not depend on the game socket.
    if (!navigator.sendBeacon?.(url, '')) fetch(url, {method:'POST',keepalive:true,cache:'no-store'}).catch(()=>{});
  }
  window.sacrificeDiagnostic = emit;
  window.sacrificeDiagnosticError = (...args) => {
    console.error(...args);
    emit('engine_error', args.map(String).join(' '));
  };
  window.addEventListener('error', e => emit('js_error', e.message || 'resource error'));
  window.addEventListener('unhandledrejection', e => emit('unhandled_rejection', String(e.reason)));
  document.addEventListener('visibilitychange', () => emit('visibility'));
  window.addEventListener('online', () => emit('network_online'));
  window.addEventListener('offline', () => emit('network_offline'));
  window.addEventListener('pagehide', () => emit('pagehide'));
  const NativeSocket = window.WebSocket;
  window.WebSocket = class extends NativeSocket {
    constructor(...args) {
      super(...args);
      this.addEventListener('open', () => emit('socket_open'));
      this.addEventListener('close', e => emit('socket_close', JSON.stringify({code:e.code,clean:e.wasClean,reason:e.reason})));
      this.addEventListener('error', () => emit('socket_error'));
    }
  };
  document.getElementById('canvas').addEventListener('webglcontextlost', () => emit('webgl_context_lost'));
  setInterval(() => {
    allowance = Math.min(8, allowance + 2);
    criticalAllowance = Math.min(2, criticalAllowance + 1);
    const s = snapshot(), key = [s.room,s.phase,s.round,s.animation.id,s.animation.stage,s.reconnecting,s.peer_missing].join('/');
    if (key !== lastState && Date.now()-lastChange >= 1000) {
      lastState=key;lastChange=Date.now();emit('state');
    }
  }, 2000);
  setInterval(() => emit('checkpoint'), 10000);
  emit('boot', navigator.userAgent);
  // A previous unfinished checkpoint is evidence of an interrupted page, not
  // proof of a crash: manual refresh, OS suspension and process termination overlap.
  if (previous) {
    // Keep this parseable within the 700-character envelope. A full nested
    // state used to be cut mid-JSON just when a crashed page mattered most.
    const s=previous.state || {}, n=s.native || {};
    emit('previous_page', JSON.stringify({schema:2,id:previous.id,at:previous.at,event:previous.event,
      room:s.room,version:s.version,phase:s.phase,round:s.round,revision:s.revision,
      animation:s.animation,visibility:s.visibility,wasm_bytes:s.wasm_bytes,
      pack_bytes:s.pack_bytes,pack_name:s.pack_name,texture_bytes:n.texture_bytes,
      nodes:n.nodes,objects:n.objects,queued_views:n.queued_views}));
  }
})();
