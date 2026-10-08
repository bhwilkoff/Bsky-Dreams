// Runs in <head>, before first paint, so dark-mode users don't see a light flash
// while ~760 KB of scripts load. No saved choice = follow the OS setting.
(function () {
  let saved = null;
  try { saved = localStorage.getItem('bsky_theme'); } catch (e) { /* storage blocked */ }
  const dark = saved ? saved === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
  if (dark) document.documentElement.setAttribute('data-theme', 'dark');
})();
