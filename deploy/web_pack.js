/* A packed project remains in the browser's virtual file system. Load only
 * the texture family this GPU can use, rather than retaining both families. */
function selectSacrificePack(config, manifest) {
  let probe, gl;
  let desktop = false;
  try {
    probe = document.createElement('canvas');
    gl = probe.getContext('webgl2', {antialias:false});
    desktop = !!(gl && (gl.getExtension('WEBGL_compressed_texture_s3tc') ||
      gl.getExtension('WEBKIT_WEBGL_compressed_texture_s3tc') || gl.getExtension('MOZ_WEBGL_compressed_texture_s3tc')));
  } catch {}
  finally {
    // The capability probe owns no assets and must not retain a GPU context.
    if (gl) gl.getExtension('WEBGL_lose_context')?.loseContext();
    if (probe) { probe.width = 1; probe.height = 1; }
  }
  config.mainPack = desktop ? 'index.pck' : 'index-mobile.pck';
  const asset = manifest.assets[config.mainPack];
  window.sacrificePack = {name:config.mainPack, bytes:asset.bytes, format:desktop ? 's3tc' : 'etc2'};
}

async function waitForSacrificeVisibility() {
  if (!document.hidden) return;
  window.sacrificeDiagnostic?.('waiting_visible');
  await new Promise(resolve => {
    const resume = () => {
      if (document.hidden) return;
      document.removeEventListener('visibilitychange', resume);
      resolve();
    };
    document.addEventListener('visibilitychange', resume);
  });
}
