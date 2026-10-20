/* The HTML embeds a manifest of the exported bytes, independently of game version.
 * CacheStorage is explicit: the browser's ordinary HTTP cache drops our large PCK.
 * No service worker is installed, so the HTML always discovers the current build.
 */
(function (scope) {
  'use strict';
  scope.SacrificeResourceCache = {
    install(manifest) {
      const originalFetch = scope.fetch.bind(scope);
      const cacheName = 'sacrifice-resources-v1';
      const entries = new Map();
      const pending = new Set();
      const stats = { hits: 0, downloads: 0, writes: 0, failures: 0, cachedBytes: 0, files: {} };
      let storagePromise;
      for (const [name, asset] of Object.entries(manifest.assets)) {
        const url = new URL(name, document.baseURI);
        if (url.origin !== location.origin || !/^[a-f0-9]{64}$/.test(asset.sha256) || !Number.isSafeInteger(asset.bytes)) continue;
        const key = new URL(url);
        key.searchParams.set('sacrifice_asset', asset.sha256);
        entries.set(url.href, { ...asset, name, key: key.href });
      }
      const currentKeys = new Set([...entries.values()].map(asset => asset.key));
      function failed() { stats.failures++; }
      async function storage() {
        if (!storagePromise) {
          storagePromise = (async () => {
            try { return scope.isSecureContext && scope.caches && scope.crypto?.subtle ? await caches.open(cacheName) : null; }
            catch { failed(); return null; }
          })();
        }
        return storagePromise;
      }
      async function digest(bytes) {
        return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), b => b.toString(16).padStart(2, '0')).join('');
      }
      async function valid(bytes, asset) {
        return bytes.byteLength === asset.bytes && await digest(bytes) === asset.sha256;
      }
      function headersFor(asset, response) {
        // fetch() already decoded HTTP gzip. Reconstructed responses contain plain bytes.
        return new Headers({
          'Content-Type': response.headers.get('Content-Type') || (asset.name.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream'),
          'Content-Length': String(asset.bytes),
          'X-Sacrifice-SHA256': asset.sha256,
        });
      }
      async function discardObsolete(cache) {
        for (const key of await cache.keys()) {
          if (!currentKeys.has(key.url)) await cache.delete(key);
        }
      }
      function persist(cache, asset, bytes, headers) {
        if (!cache) return;
        const write = (async () => {
          try {
            try { await cache.put(asset.key, new Response(bytes, { headers })); }
            catch (error) {
              if (error.name !== 'QuotaExceededError') throw error;
              await discardObsolete(cache);
              await cache.put(asset.key, new Response(bytes, { headers }));
            }
            stats.writes++;
          } catch { failed(); } // Storage is optional; a valid download still starts the game.
        })();
        pending.add(write);
        write.finally(() => pending.delete(write));
      }
      async function load(request, asset) {
        const cache = await storage();
        if (cache) {
          try {
            const hit = await cache.match(asset.key);
            if (hit) {
              const bytes = await hit.arrayBuffer();
              if (await valid(bytes, asset)) {
                stats.hits++; stats.cachedBytes += bytes.byteLength;
                stats.files[asset.name] = 'cache';
                return new Response(bytes, { headers: headersFor(asset, hit) });
              }
              failed();
              await cache.delete(asset.key); // Corrupt or partial data is fetched again.
            }
          } catch { failed(); }
        }
        stats.downloads++; stats.files[asset.name] = 'network';
        const response = await originalFetch(new Request(asset.key, request));
        if (!response.ok || !response.body) return response;
        if (!scope.crypto?.subtle) return response;
        const headers = headersFor(asset, response);
        // Preserve live download progress and streaming WASM compilation. Validation
        // gates the stream's final EOF, so mismatched release bytes cannot be executed.
        const [playback, verification] = response.body.tee();
        const verified = new Response(verification).arrayBuffer().then(async bytes => {
          if (!await valid(bytes, asset)) throw new Error('游戏资源已更新或下载不完整，请刷新页面后重试。');
          persist(cache, asset, bytes, headers);
        });
        verified.catch(() => {}); // The reader below propagates the same failure.
        const reader = playback.getReader();
        return new Response(new ReadableStream({
          async pull(controller) {
            try {
              const chunk = await reader.read();
              if (!chunk.done) controller.enqueue(chunk.value);
              else { await verified; controller.close(); }
            } catch (error) { controller.error(error); }
          },
          cancel(reason) { return reader.cancel(reason); },
        }), { headers });
      }
      scope.fetch = function (input, init) {
        let request, asset;
        try {
          request = new Request(input, init);
          asset = entries.get(request.url);
        } catch { return originalFetch(input, init); }
        if (!asset || request.method !== 'GET' || request.headers.has('Range')) return originalFetch(input, init);
        return load(request, asset);
      };
      async function settled() {
        while (pending.size) await Promise.all([...pending]);
      }
      return {
        stats, manifest, cacheName, settled,
        async ready() {
          await settled();
          try {
            const cache = await storage();
            if (cache) await discardObsolete(cache);
          } catch { failed(); }
        },
      };
    },
  };
})(globalThis);
