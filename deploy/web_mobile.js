/* Keep Retina phones from allocating unnecessarily large render surfaces.
 * No asset changes: only the canvas resolution is capped on touch devices.
 */
function configureSacrificeMobile(config, canvas) {
  const touch = navigator.maxTouchPoints > 0;
  if (!touch) return;
  config.canvasResizePolicy = 0;
  const resize = () => {
    const width = window.innerWidth, height = window.innerHeight;
    const scale = Math.min(window.devicePixelRatio || 1, 2, Math.sqrt(1920 * 1080 / (width * height)));
    const w = Math.max(1, Math.round(width * scale)), h = Math.max(1, Math.round(height * scale));
    if (canvas.width !== w) canvas.width = w;
    if (canvas.height !== h) canvas.height = h;
  };
  resize();
  window.addEventListener('resize', resize);
}
