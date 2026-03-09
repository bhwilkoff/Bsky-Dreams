/**
 * app.js — UI orchestration for Bsky Dreams
 *
 * Handles view transitions, event wiring, and DOM rendering.
 * All API calls go through api.js. All auth operations go through auth.js.
 */

(function () {
  'use strict';

  /* ================================================================
     DOM REFERENCES
  ================================================================ */
  const $ = (id) => document.getElementById(id);

  const authScreen     = $('auth-screen');
  const appScreen      = $('app-screen');
  const authForm       = $('auth-form');
  const authError      = $('auth-error');
  const authSubmit     = $('auth-submit');

  const navFeedBtn      = $('nav-feed-btn');
  const navSearchBtn    = $('nav-search-btn');
  const navComposeBtn   = $('nav-compose-btn');
  const navNotifBtn     = $('nav-notif-btn');
  const navTvBtn        = $('nav-tv-btn');
  const navProfileBtn   = $('nav-profile-btn');
  const navAnalyticsBtn = $('nav-analytics-btn');
  const navTimelineBtn  = $('nav-timeline-btn');
  const navAvatar      = $('nav-avatar');
  const navHandle      = $('nav-handle');

  const viewFeed          = $('view-feed');
  const viewSearch        = $('view-search');
  const viewCompose       = $('view-compose');
  const viewThread        = $('view-thread');
  const viewProfile       = $('view-profile');
  const viewNotifications = $('view-notifications');
  const viewTv            = $('view-tv');
  const viewAnalytics     = $('view-analytics');
  const viewTimeline      = $('view-timeline');

  const feedResults    = $('feed-results');
  const ptrIndicator   = $('ptr-indicator');
  const feedSentinel    = $('feed-load-sentinel');    // M60: infinite scroll sentinel
  const searchSentinel  = $('search-load-sentinel');  // infinite scroll sentinel
  const profileSentinel = $('profile-load-sentinel'); // infinite scroll sentinel
  const notifSentinel   = $('notif-load-sentinel');   // infinite scroll sentinel
  const feedTabFollowing = $('feed-tab-following');
  const feedTabDiscover  = $('feed-tab-discover');

  const profileHeaderEl    = $('profile-header');
  const profileFeedEl      = $('profile-feed');
  const profileBackBtn     = $('profile-back-btn');

  const searchForm     = $('search-form');
  const searchInput    = $('search-input');
  const searchResults  = $('search-results');
  const filterChips    = document.querySelectorAll('.filter-chip');

  const composeForm          = $('compose-form');
  const composeText          = $('compose-text');
  const composeCount         = $('compose-char-count');
  const composeError         = $('compose-error');
  const composeSuccess       = $('compose-success');
  const composeAvatar        = $('compose-avatar');
  const composeImgBtn        = $('compose-img-btn');
  const composeImgInput      = $('compose-img-input');
  const composeImagesPreview = $('compose-images-preview');

  const notifList        = $('notif-list');
  const notifBadge       = $('notif-badge');
  const notifRefreshBtn  = $('notif-refresh-btn');

  const channelsSidebar   = $('channels-sidebar');
  const channelsList      = $('channels-list');
  const sidebarCloseBtn   = $('sidebar-close-btn');
  const sidebarOverlay    = $('sidebar-overlay');
  const navChannelsBtn    = $('nav-channels-btn');

  const threadContent    = $('thread-content');
  const threadBackBtn    = $('thread-back-btn');
  const threadReplyArea  = $('thread-reply-area');
  const replyForm        = $('reply-form');
  const replyText        = $('reply-text');
  const replyCount       = $('reply-char-count');
  const replyAvatar      = $('reply-avatar');
  const replyError       = $('reply-error');
  const replyToHandle    = $('reply-to-handle');

  const profileMenu      = $('profile-menu');
  const menuDisplayName  = $('menu-display-name');
  const menuHandle       = $('menu-handle');
  const menuSignOut      = $('menu-sign-out');

  const loadingOverlay   = $('loading-overlay');

  const reportModal        = $('report-modal');
  const reportModalClose   = $('report-modal-close');
  const reportModalCancel  = $('report-modal-cancel');
  const reportModalSubmit  = $('report-modal-submit');
  const reportModalSubtitle = $('report-modal-subtitle');
  const reportModalError   = $('report-modal-error');
  const reportNote         = $('report-note');

  const scrollToTopBtn   = $('scroll-to-top-btn');  // M34 scroll-to-top

  const quoteModal        = $('quote-modal');          // M30 quote post
  const quoteModalClose   = $('quote-modal-close');
  const quoteModalCancel  = $('quote-modal-cancel');
  const quoteModalSubmit  = $('quote-modal-submit');
  const quoteModalText    = $('quote-modal-text');
  const quoteModalCount   = $('quote-modal-count');
  const quoteModalError   = $('quote-modal-error');
  const quoteModalPreview = $('quote-modal-preview');
  const quoteSuccessBanner = $('quote-success-banner'); // M51
  const quotePostLink      = $('quote-post-link');      // M51
  const quoteSuccessClose  = $('quote-success-close'); // M51

  const imageLightbox    = $('image-lightbox');
  const lightboxImg      = $('lightbox-img');
  const lightboxCaption  = $('lightbox-caption');
  const lightboxCounter  = $('lightbox-counter');
  const lightboxDots     = $('lightbox-dots');
  const lightboxPrevBtn  = $('lightbox-prev');
  const lightboxNextBtn  = $('lightbox-next');
  const lightboxCloseBtn = $('lightbox-close');

  const adultToggle      = $('hide-adult-toggle');
  const advToggleBtn     = $('advanced-toggle-btn');
  const advPanel         = $('advanced-panel');
  const advAuthorEl      = $('adv-author');
  const advMentionsEl    = $('adv-mentions');
  const advLangEl        = $('adv-lang');
  const advDomainEl      = $('adv-domain');
  const advSinceEl       = $('adv-since');
  const advUntilEl       = $('adv-until');

  /* ================================================================
     STATE
  ================================================================ */
  let currentView        = 'search';
  let activeFilter       = 'posts';
  let currentThread      = null;  // { rootUri, rootCid, authorHandle }
  let ownProfile         = null;
  let hideAdultContent   = true;
  let lastSearchResults  = [];   // cached for toggle re-renders
  let lastSearchType     = null; // 'posts' | 'actors'
  const DISCOVER_FEED_URI = 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot';
  // iOS Shortcut share-to-compose — update this URL after publishing the shortcut to iCloud
  const IPHONE_SHORTCUT_URL = 'https://www.icloud.com/shortcuts/334a8826fb2b447da09fd342006d9d83';
  let feedMode           = 'discover';  // 'following' | 'discover'
  let feedCursor         = null; // pagination cursor for home feed
  let feedLoaded         = false; // true after first load
  let profileActor       = null; // handle/DID currently shown in profile view
  let profileCursor      = null; // pagination cursor for profile feed
  let notifCursor        = null; // pagination cursor for notifications
  let notifLoaded        = false;
  let composeImages      = [];   // array of { file, previewUrl, altInput } for pending uploads
  let searchCursor       = null; // M48: pagination cursor for search results
  let lastSearchQuery    = '';   // M48: last query so "load more" knows what to append
  let lastSearchSort     = 'top'; // M48: last sort so "load more" preserves it
  let lastSearchOpts     = {};   // M48: last advanced opts for "load more"
  let searchMediaFilters = new Set(); // M49: active media-type filter keys

  // Avatar fallback — SVG with Memphis design + Bsky Dreams cloud logo
  const AVATAR_FALLBACK = `data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" fill="#0047FF"/><circle cx="4" cy="4" r="2.5" fill="#FF5C35"/><circle cx="36" cy="4" r="2.5" fill="#B8E04A"/><circle cx="4" cy="36" r="2.5" fill="#B8E04A"/><circle cx="36" cy="36" r="2.5" fill="#FF5C35"/><line x1="0" y1="14" x2="14" y2="0" stroke="#0A0A0A" stroke-width="1" opacity="0.25"/><line x1="26" y1="40" x2="40" y2="26" stroke="#0A0A0A" stroke-width="1" opacity="0.25"/><svg x="4" y="11" width="32" height="22" viewBox="0 0 80 54"><path d="M66 44H14C8.5 44 4 39.5 4 34C4 28.8 7.9 24.5 13 24.1C12.7 23.1 12.5 22.1 12.5 21C12.5 15.2 17.2 10.5 23 10.5C23.8 10.5 24.6 10.6 25.3 10.8C27.2 7.3 31 5 35.5 5C41 5 45.6 8.8 47 14C48.6 13 50.4 12.5 52.5 12.5C58.3 12.5 63 17.2 63 23C63 23.3 63 23.6 62.9 23.9C68.7 24.7 73 29.8 73 36C73 40.4 69.7 44 66 44Z" fill="white" stroke="#0A0A0A" stroke-width="3" stroke-linejoin="round"/></svg></svg>')}`;
  // Expose for use in innerHTML onerror attributes
  window._bskyAvatarFallback = AVATAR_FALLBACK;

  // Helper to wire fallback onto a programmatically created <img>
  function setAvatarSrc(imgEl, src) {
    imgEl.src = src || AVATAR_FALLBACK;
    imgEl.onerror = function () { this.onerror = null; this.src = AVATAR_FALLBACK; };
  }

  // M42 — Video upload state
  const VIDEO_DAILY_KEY   = 'bsky_video_daily';
  const DAILY_VIDEO_LIMIT = 25;
  let composeVideo = null; // { file, objectUrl, duration, aspectRatio } | null
  let quoteVideo   = null; // same shape

  // M40 — Seen-posts deduplication (unified across all interfaces)
  const FEED_SEEN_KEY = 'bsky_feed_seen';
  const FEED_SEEN_MAX = 10000;           // increased cap for cross-interface coverage
  let feedSeenMap     = loadFeedSeen();  // Map<uri, { seenAt, likeCount, repostCount }>
  let feedSeenBypass  = false;           // session flag: "show anyway" escape hatch

  // M20 — Cross-device prefs sync
  const PREFS_COLLECTION     = 'app.bsky-dreams.prefs';
  const PREFS_RKEY           = 'self';
  let prefsSyncTimer         = null;

  // M20+ — Cross-device seen-posts sync (7-day rolling window)
  const SEEN_SYNC_COLLECTION = 'app.bsky-dreams.seen';
  const SEEN_SYNC_RKEY       = 'recent';
  const SEEN_SYNC_WINDOW_MS  = 7 * 24 * 60 * 60 * 1000; // 7 days in ms
  let seenSyncTimer          = null;

  // M30 — Quote post state
  let quoteModalPostRef  = null;  // { uri, cid, post } being quoted

  /* ================================================================
     CHANNELS (M11) — Saved Searches / Channel Sidebar
  ================================================================ */
  const CHANNELS_KEY = 'bsky_channels';

  function channelsLoad() {
    try { return JSON.parse(localStorage.getItem(CHANNELS_KEY) || '[]'); }
    catch { return []; }
  }

  function channelsSave(list) {
    localStorage.setItem(CHANNELS_KEY, JSON.stringify(list));
  }

  function channelsAdd(name, query) {
    const list = channelsLoad();
    // Avoid duplicates (same query, case-insensitive)
    if (list.some((c) => c.query.toLowerCase() === query.toLowerCase())) return null;
    const id = String(Date.now());
    list.push({
      id,
      name: name || query,
      query,
      lastSeenAt: new Date().toISOString(),
      unreadCount: 0,
    });
    channelsSave(list);
    schedulePrefsSync(); // M20
    return id;
  }

  function channelsRemove(id) {
    channelsSave(channelsLoad().filter((c) => c.id !== id));
    schedulePrefsSync(); // M20
  }

  function channelsRename(id, newName) {
    const list = channelsLoad();
    const ch = list.find((c) => c.id === id);
    if (ch) { ch.name = newName; channelsSave(list); schedulePrefsSync(); } // M20
  }

  function channelsMarkSeen(id) {
    const list = channelsLoad();
    const ch = list.find((c) => c.id === id);
    if (ch) {
      ch.lastSeenAt  = new Date().toISOString();
      ch.unreadCount = 0;
      channelsSave(list);
    }
  }

  function channelsSetUnread(id, count) {
    const list = channelsLoad();
    const ch = list.find((c) => c.id === id);
    if (ch && ch.unreadCount !== count) {
      ch.unreadCount = count;
      channelsSave(list);
      renderChannelsSidebar();
    }
  }

  /** Render the full channel list into the sidebar. */
  function renderChannelsSidebar() {
    if (!channelsList) return;
    const list = channelsLoad();
    channelsList.innerHTML = '';

    if (!list.length) {
      const empty = document.createElement('p');
      empty.className   = 'channels-empty';
      empty.textContent = 'No channels yet. Search for something and save it as a channel!';
      channelsList.appendChild(empty);
      return;
    }

    list.forEach((ch) => {
      const item = document.createElement('div');
      item.className = 'channel-item';

      // Main button: name + unread badge
      const btn = document.createElement('button');
      btn.type      = 'button';
      btn.className = 'channel-btn';
      btn.setAttribute('aria-label', `Open channel: ${ch.name}${ch.unreadCount ? ` (${ch.unreadCount} new)` : ''}`);

      const glyphEl = document.createElement('span');
      glyphEl.className = 'channel-glyph';
      glyphEl.setAttribute('aria-hidden', 'true');
      if (ch.type === 'timeline') {
        glyphEl.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12"><line x1="2" y1="12" x2="22" y2="12"/><line x1="6" y1="8" x2="6" y2="16"/><line x1="12" y1="6" x2="12" y2="18"/><line x1="18" y1="8" x2="18" y2="16"/></svg>`;
      } else {
        glyphEl.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>`;
      }

      const nameEl = document.createElement('span');
      nameEl.className   = 'channel-name';
      nameEl.textContent = ch.name;
      btn.insertBefore(glyphEl, btn.firstChild);
      btn.appendChild(nameEl);

      if (ch.unreadCount > 0) {
        const badge = document.createElement('span');
        badge.className   = 'channel-badge';
        badge.textContent = ch.unreadCount > 99 ? '99+' : String(ch.unreadCount);
        btn.appendChild(badge);
      }

      btn.addEventListener('click', () => openChannel(ch));
      item.appendChild(btn);

      // ⋮ options button
      const menuBtn = document.createElement('button');
      menuBtn.type      = 'button';
      menuBtn.className = 'channel-menu-btn';
      menuBtn.setAttribute('aria-label', `Options for ${ch.name}`);
      menuBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor" width="14" height="14" aria-hidden="true"><circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="19" r="1.5"/></svg>`;
      menuBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        showChannelMenu(ch, item);
      });
      item.appendChild(menuBtn);

      channelsList.appendChild(item);
    });
  }

  /** Show the inline options dropdown for a channel item. */
  function showChannelMenu(ch, itemEl) {
    // Remove any existing dropdown
    document.querySelector('.channel-dropdown')?.remove();

    const menu = document.createElement('div');
    menu.className = 'channel-dropdown';
    menu.setAttribute('role', 'menu');

    const renameBtn = document.createElement('button');
    renameBtn.type      = 'button';
    renameBtn.className = 'channel-dropdown-item';
    renameBtn.setAttribute('role', 'menuitem');
    renameBtn.textContent = 'Rename';
    renameBtn.addEventListener('click', () => {
      menu.remove();
      const newName = prompt(`Rename "${ch.name}":`, ch.name);
      if (newName?.trim()) {
        channelsRename(ch.id, newName.trim());
        renderChannelsSidebar();
      }
    });

    const deleteBtn = document.createElement('button');
    deleteBtn.type      = 'button';
    deleteBtn.className = 'channel-dropdown-item channel-dropdown-delete';
    deleteBtn.setAttribute('role', 'menuitem');
    deleteBtn.textContent = 'Delete channel';
    deleteBtn.addEventListener('click', () => {
      menu.remove();
      channelsRemove(ch.id);
      renderChannelsSidebar();
    });

    menu.appendChild(renameBtn);
    menu.appendChild(deleteBtn);
    itemEl.appendChild(menu);

    // Dismiss on outside click
    setTimeout(() => {
      document.addEventListener('click', () => menu.remove(), { once: true });
    }, 0);
  }

  /** Open a saved channel: run its search and mark it as seen. */
  function openChannel(ch) {
    // Close mobile drawer
    closeSidebar();

    if (ch.type === 'timeline') {
      showView('timeline');
      $('timeline-search-input').value = ch.query;
      tlQuery = ch.query;
      tlDoSearch();
    } else {
      // Populate search input and set filter to "latest"
      searchInput.value = ch.query;
      filterChips.forEach((c) => c.classList.remove('active'));
      activeFilter = 'latest';
      const latestChip = document.querySelector('.filter-chip[data-filter="latest"]');
      if (latestChip) latestChip.classList.add('active');

      // Switch to search view and run the search
      showView('search');
      searchForm.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    }

    // Mark channel as seen (clear badge)
    channelsMarkSeen(ch.id);
    renderChannelsSidebar();
  }

  /**
   * Background check for unread posts in all channels.
   * Runs once per session after login, spacing API calls 700ms apart.
   * Updates unread counts and re-renders the sidebar.
   */
  async function checkChannelUnreads() {
    const list = channelsLoad();
    if (!list.length) return;

    for (const ch of list) {
      try {
        const data  = await API.searchPosts(ch.query, 'latest', 5);
        const posts = data.posts || [];
        if (!posts.length) continue;

        const lastSeen = ch.lastSeenAt;
        const unread   = lastSeen
          ? posts.filter((p) => (p.record?.createdAt || p.indexedAt || '') > lastSeen).length
          : 0;

        channelsSetUnread(ch.id, unread);
      } catch { /* silent — network failures don't break the app */ }

      // Throttle: 700ms between checks to avoid rate-limit
      await new Promise((r) => setTimeout(r, 700));
    }
  }

  /** Inject a "Save as channel" button above search results (after search). */
  function showSaveChannelBtn(query) {
    // Remove any stale save button
    document.querySelector('.save-channel-area')?.remove();

    const area = document.createElement('div');
    area.className = 'save-channel-area';

    const existing = channelsLoad().some(
      (c) => c.query.toLowerCase() === query.toLowerCase()
    );

    const btn = document.createElement('button');
    btn.type      = 'button';
    btn.className = 'btn btn-ghost save-channel-btn';

    if (existing) {
      btn.innerHTML  = `<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" width="14" height="14" aria-hidden="true"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg> Saved`;
      btn.disabled = true;
    } else {
      btn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14" aria-hidden="true"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg> Save as channel`;
      btn.addEventListener('click', () => {
        const defaultName = query.length > 40 ? query.slice(0, 40) + '…' : query;
        const name = prompt('Channel name:', defaultName);
        if (name === null) return; // cancelled
        channelsAdd(name.trim() || defaultName, query);
        renderChannelsSidebar();
        // Update button to saved state
        btn.innerHTML  = `<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" width="14" height="14" aria-hidden="true"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg> Saved!`;
        btn.disabled = true;
      });
    }

    area.appendChild(btn);
    // Insert above search-results div
    searchResults.parentNode.insertBefore(area, searchResults);
  }

  /* ---- M43: Sidebar toggle (mobile-only drawer; desktop sidebar always open) ---- */
  function openSidebar() {
    if (window.innerWidth >= 768) return; // desktop: always open, no toggle needed
    channelsSidebar.classList.add('open');
    sidebarOverlay.hidden = false;
    navChannelsBtn.setAttribute('aria-expanded', 'true');
  }

  function closeSidebar() {
    if (window.innerWidth >= 768) return; // desktop: never close
    channelsSidebar.classList.remove('open');
    sidebarOverlay.hidden = true;
    navChannelsBtn.setAttribute('aria-expanded', 'false');
  }

  navChannelsBtn.addEventListener('click', () => {
    channelsSidebar.classList.contains('open') ? closeSidebar() : openSidebar();
  });
  sidebarCloseBtn.addEventListener('click', closeSidebar);
  sidebarOverlay.addEventListener('click',  closeSidebar);

  /* ---- M43: Sidebar own-profile section ---- */
  const sidebarOwnProfile  = $('sidebar-own-profile');
  const sidebarOwnAvatar   = $('sidebar-own-avatar');
  const sidebarOwnName     = $('sidebar-own-name');
  const sidebarOwnHandle   = $('sidebar-own-handle');
  const sidebarSignOutBtn  = $('sidebar-sign-out-btn');
  const sidebarSettingsBtn = $('sidebar-settings-btn');

  function updateSidebarProfile(profile) {
    if (!profile) { sidebarOwnProfile.hidden = true; return; }
    sidebarOwnAvatar.src    = profile.avatar || '';
    sidebarOwnAvatar.alt    = profile.displayName || profile.handle || '';
    sidebarOwnName.textContent   = profile.displayName || profile.handle || '';
    sidebarOwnHandle.textContent = `@${profile.handle || ''}`;
    sidebarOwnProfile.hidden = false;
  }

  sidebarOwnProfile.addEventListener('click', () => {
    if (ownProfile) {
      closeSidebar();
      openProfile(ownProfile.handle);
    }
  });

  sidebarSignOutBtn.addEventListener('click', () => {
    AUTH.clearSession();
    AUTH.clearCredentials();
    appScreen.hidden  = true;
    authScreen.hidden = false;
    scrollToTopBtn.hidden = true;
    sidebarOwnProfile.hidden = true;
    ownProfile = null;
    feedLoaded = false;
    notifLoaded = false;
    notifBadge.hidden = true;
    closeSidebar();
  });

  /* ================================================================
     SETTINGS MODAL (M52)
  ================================================================ */
  const settingsModal      = $('settings-modal');
  const settingsHandleDisp = $('settings-handle-display');
  const settingsDidDisp    = $('settings-did-display');
  const settingsSavedLogin = $('settings-saved-login-display');
  const settingsForgetBtn  = $('settings-forget-login');
  const settingsDefaultTab = $('settings-default-tab');
  const settingsSeenCount  = $('settings-seen-count');
  const settingsTvCount    = $('settings-tv-count');
  const settingsClearSeen  = $('settings-clear-seen');
  const settingsClearTv    = $('settings-clear-tv');

  /* --- Accent color --- */
  function applyAccentColor(accent, accentDark, accentLight) {
    const root = document.documentElement;
    root.style.setProperty('--color-accent',       accent);
    root.style.setProperty('--color-accent-dark',  accentDark);
    root.style.setProperty('--color-accent-light', accentLight);
  }

  function syncAccentSwatches() {
    const saved = localStorage.getItem('bsky_accent') || '#0047FF';
    document.querySelectorAll('.accent-swatch').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.accent === saved);
    });
  }

  // Apply on load (only if user has overridden the CSS default)
  const savedAccent = localStorage.getItem('bsky_accent');
  if (savedAccent) {
    const savedDark  = localStorage.getItem('bsky_accent_dark')  || savedAccent;
    const savedLight = localStorage.getItem('bsky_accent_light') || '#E6EDFF';
    applyAccentColor(savedAccent, savedDark, savedLight);
  }

  document.getElementById('accent-swatch-row').addEventListener('click', (e) => {
    const btn = e.target.closest('.accent-swatch');
    if (!btn) return;
    const accent      = btn.dataset.accent;
    const accentDark  = btn.dataset.accentDark;
    const accentLight = btn.dataset.accentLight;
    localStorage.setItem('bsky_accent',       accent);
    localStorage.setItem('bsky_accent_dark',  accentDark);
    localStorage.setItem('bsky_accent_light', accentLight);
    applyAccentColor(accent, accentDark, accentLight);
    syncAccentSwatches();
  });

  function openSettings() {
    const session = AUTH.getSession();
    settingsHandleDisp.textContent = session?.handle ? `@${session.handle}` : '—';
    settingsDidDisp.textContent    = session?.did    || '—';

    const creds = AUTH.getSavedCredentials();
    if (creds) {
      settingsSavedLogin.textContent = `@${creds.identifier}`;
      settingsForgetBtn.disabled     = false;
    } else {
      settingsSavedLogin.textContent = 'None saved';
      settingsForgetBtn.disabled     = true;
    }

    const storedTab = localStorage.getItem('bsky_default_tab') || 'discover';
    settingsDefaultTab.value = storedTab;

    settingsSeenCount.textContent = `${feedSeenMap.size.toLocaleString()} posts`;

    try {
      const tvRaw  = localStorage.getItem('bsky_tv_seen');
      const tvCnt  = tvRaw ? JSON.parse(tvRaw).length : 0;
      settingsTvCount.textContent = `${tvCnt.toLocaleString()} videos`;
    } catch {
      settingsTvCount.textContent = '0 videos';
    }

    syncAccentSwatches();

    // iPhone shortcut link — show install button if URL is configured
    const shortcutRow  = $('settings-iphone-shortcut-row');
    const shortcutLink = $('settings-iphone-shortcut-link');
    if (shortcutRow && shortcutLink) {
      if (IPHONE_SHORTCUT_URL) {
        shortcutLink.href   = IPHONE_SHORTCUT_URL;
        shortcutRow.hidden  = false;
      } else {
        shortcutRow.hidden  = true;
      }
    }
    settingsModal.hidden = false;
    closeSidebar();
  }

  function closeSettings() {
    settingsModal.hidden = true;
  }

  sidebarSettingsBtn.addEventListener('click', openSettings);

  $('settings-modal-close').addEventListener('click', closeSettings);
  settingsModal.addEventListener('click', (e) => {
    if (e.target === settingsModal) closeSettings();
  });

  settingsForgetBtn.addEventListener('click', () => {
    AUTH.clearCredentials();
    settingsSavedLogin.textContent = 'None saved';
    settingsForgetBtn.disabled     = true;
  });

  settingsDefaultTab.addEventListener('change', () => {
    const tab = settingsDefaultTab.value;
    localStorage.setItem('bsky_default_tab', tab);
    setFeedMode(tab);
  });

  settingsClearSeen.addEventListener('click', () => {
    feedSeenMap.clear();
    saveFeedSeen();
    feedSeenBypass = false;
    settingsSeenCount.textContent = '0 posts';
  });

  settingsClearTv.addEventListener('click', () => {
    $('tv-clear-history-btn').click();
    settingsTvCount.textContent = '0 videos';
  });

  /* ================================================================
     LOADING HELPERS
  ================================================================ */
  function showLoading() {
    loadingOverlay.hidden = false;
  }

  function hideLoading() {
    loadingOverlay.hidden = true;
  }

  function showError(el, msg) {
    el.textContent = msg;
    el.hidden = false;
  }

  function hideError(el) {
    el.textContent = '';
    el.hidden = true;
  }

  /* ================================================================
     REPORT MODAL
  ================================================================ */
  let reportSubject = null; // { subject, subtitle } set by openReportModal

  function openReportModal({ subject, subtitle }) {
    reportSubject = subject;
    reportModalSubtitle.textContent = subtitle || '';
    reportNote.value = '';
    hideError(reportModalError);
    // Default to "Other" radio
    const defaultRadio = reportModal.querySelector('input[value="com.atproto.moderation.defs#reasonOther"]');
    if (defaultRadio) defaultRadio.checked = true;
    reportModal.hidden = false;
    reportModalSubmit.disabled = false;
    // Focus first radio for accessibility
    const firstRadio = reportModal.querySelector('input[type="radio"]');
    if (firstRadio) firstRadio.focus();
  }

  function closeReportModal() {
    reportModal.hidden = true;
    reportSubject = null;
  }

  reportModalClose.addEventListener('click', closeReportModal);
  reportModalCancel.addEventListener('click', closeReportModal);
  reportModal.addEventListener('click', (e) => {
    if (e.target === reportModal) closeReportModal();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !reportModal.hidden) closeReportModal();
  });

  /* ================================================================
     BANNER HELPER
  ================================================================ */
  function showBanner(text, isError = false) {
    const banner = document.createElement('div');
    banner.className = 'report-success-banner' + (isError ? ' banner-error' : '');
    banner.textContent = text;
    document.body.appendChild(banner);
    setTimeout(() => banner.remove(), 3000);
  }

  /* ================================================================
     POST ACTIONS MENU (Mute/Block/Report)
  ================================================================ */
  function showPostActionsMenu(btn, post, author) {
    // Remove any existing post-action dropdowns
    document.querySelectorAll('.post-action-dropdown').forEach(m => m.remove());

    const menu = document.createElement('div');
    menu.className = 'post-action-dropdown channel-dropdown';
    menu.setAttribute('role', 'menu');

    // Report post (only shown when a real post URI is provided)
    if (post.uri) {
      const reportPostItem = document.createElement('button');
      reportPostItem.type = 'button';
      reportPostItem.className = 'channel-dropdown-item';
      reportPostItem.setAttribute('role', 'menuitem');
      reportPostItem.textContent = 'Report post';
      reportPostItem.addEventListener('click', (e) => {
        e.stopPropagation();
        menu.remove();
        openReportModal({
          subject: { $type: 'com.atproto.repo.strongRef', uri: post.uri, cid: post.cid },
          subtitle: `Post by @${author.handle || ''}`,
        });
      });
      menu.appendChild(reportPostItem);
    }

    // Report account
    if (author.did) {
      const reportAccItem = document.createElement('button');
      reportAccItem.type = 'button';
      reportAccItem.className = 'channel-dropdown-item';
      reportAccItem.setAttribute('role', 'menuitem');
      reportAccItem.textContent = `Report @${author.handle || 'account'}`;
      reportAccItem.addEventListener('click', (e) => {
        e.stopPropagation();
        menu.remove();
        openReportModal({
          subject: { $type: 'com.atproto.admin.defs#repoRef', did: author.did },
          subtitle: `Account @${author.handle || ''}`,
        });
      });
      menu.appendChild(reportAccItem);

      // Separator
      const sep = document.createElement('div');
      sep.className = 'channel-dropdown-sep';
      menu.appendChild(sep);

      // Mute/Unmute
      const isMuted = !!author.viewer?.muted;
      const muteItem = document.createElement('button');
      muteItem.type = 'button';
      muteItem.className = 'channel-dropdown-item';
      muteItem.setAttribute('role', 'menuitem');
      muteItem.textContent = isMuted ? `Unmute @${author.handle || ''}` : `Mute @${author.handle || ''}`;
      muteItem.addEventListener('click', async (e) => {
        e.stopPropagation();
        menu.remove();
        try {
          if (isMuted) {
            await API.unmuteActor(author.did);
            showBanner('Unmuted @' + (author.handle || ''));
          } else {
            await API.muteActor(author.did);
            showBanner('Muted @' + (author.handle || '') + '. You won\'t see their posts in your feed.');
          }
        } catch (err) {
          showBanner('Error: ' + err.message, true);
        }
      });
      menu.appendChild(muteItem);

      // Block/Unblock
      const isBlocked = !!author.viewer?.blocking;
      const blockItem = document.createElement('button');
      blockItem.type = 'button';
      blockItem.className = 'channel-dropdown-item channel-dropdown-delete';
      blockItem.setAttribute('role', 'menuitem');
      blockItem.textContent = isBlocked ? `Unblock @${author.handle || ''}` : `Block @${author.handle || ''}`;
      blockItem.addEventListener('click', async (e) => {
        e.stopPropagation();
        menu.remove();
        try {
          if (isBlocked) {
            await API.unblockActor(author.viewer.blocking);
            showBanner('Unblocked @' + (author.handle || ''));
          } else {
            await API.blockActor(author.did);
            showBanner('Blocked @' + (author.handle || '') + '. They can\'t interact with you.');
          }
        } catch (err) {
          showBanner('Error: ' + err.message, true);
        }
      });
      menu.appendChild(blockItem);
    }

    // Position the dropdown relative to the button
    btn.parentElement.style.position = 'relative';
    btn.parentElement.appendChild(menu);
    menu.style.right = '0';
    menu.style.top = '100%';

    // Dismiss on outside click
    setTimeout(() => {
      document.addEventListener('click', () => menu.remove(), { once: true });
    }, 0);
  }

  reportModalSubmit.addEventListener('click', async () => {
    if (!reportSubject) return;
    const reasonType = (reportModal.querySelector('input[name="report-reason"]:checked') || {}).value
      || 'com.atproto.moderation.defs#reasonOther';
    const reason = reportNote.value.trim();
    reportModalSubmit.disabled = true;
    hideError(reportModalError);
    try {
      await API.createReport(reportSubject, reasonType, reason);
      closeReportModal();
      // Brief confirmation banner reusing the feed-empty pattern
      const banner = document.createElement('div');
      banner.className = 'report-success-banner';
      banner.textContent = 'Report submitted. Thank you.';
      document.body.appendChild(banner);
      setTimeout(() => banner.remove(), 3000);
    } catch (err) {
      showError(reportModalError, `Could not submit report: ${err.message}`);
      reportModalSubmit.disabled = false;
    }
  });

  /* ================================================================
     M40 — SEEN-POSTS DEDUPLICATION (home feed)
  ================================================================ */
  function loadFeedSeen() {
    try {
      const raw = localStorage.getItem(FEED_SEEN_KEY);
      return raw ? new Map(JSON.parse(raw)) : new Map();
    } catch { return new Map(); }
  }

  function saveFeedSeen() {
    try {
      localStorage.setItem(FEED_SEEN_KEY, JSON.stringify([...feedSeenMap.entries()]));
    } catch {}
    scheduleSeenSync(); // keep cloud in sync (30 s debounce)
  }

  /**
   * Mark a post as seen in the unified cross-interface registry.
   * Called immediately at render time in every interface (feed, gallery, TV).
   * No-op if the URI is already registered.
   */
  function markFeedPostSeen(uri) {
    if (!uri || feedSeenMap.has(uri)) return;
    if (feedSeenMap.size >= FEED_SEEN_MAX) {
      feedSeenMap.delete(feedSeenMap.keys().next().value); // evict oldest (FIFO)
    }
    feedSeenMap.set(uri, { seenAt: Date.now() });
  }

  function isFeedPostSeen(uri) {
    if (feedSeenBypass) return false;
    return feedSeenMap.has(uri);
  }

  function showFeedSeenHint(count) {
    document.querySelector('.feed-seen-hint')?.remove();
    const hint = document.createElement('div');
    hint.className = 'feed-seen-hint';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'btn btn-ghost feed-seen-hint-btn';
    btn.textContent = `${count} post${count === 1 ? '' : 's'} already seen across all interfaces — show anyway`;
    btn.addEventListener('click', () => {
      feedSeenBypass = true;
      hint.remove();
      loadFeed(false);
    });
    hint.appendChild(btn);
    feedResults.insertAdjacentElement('afterend', hint);
  }

  /* ================================================================
     M20 — CROSS-DEVICE PREFS SYNC (AT Protocol repo)
  ================================================================ */
  async function loadPrefsFromCloud() {
    const session = AUTH.getSession();
    if (!session?.did) return;
    try {
      const result = await API.getRecord(session.did, PREFS_COLLECTION, PREFS_RKEY);
      const prefs = result?.value || {};
      if (prefs.savedChannels && Array.isArray(prefs.savedChannels)) {
        channelsSave(prefs.savedChannels);
        renderChannelsSidebar();
      }
      if (prefs.uiPrefs) {
        if (typeof prefs.uiPrefs.hideAdult === 'boolean') {
          hideAdultContent = prefs.uiPrefs.hideAdult;
          if (adultToggle) adultToggle.checked = hideAdultContent;
        }
      }
      if (prefs.feedFilters) {
        if (Array.isArray(prefs.feedFilters.categories)) {
          activeFilterCats = new Set(prefs.feedFilters.categories);
        }
        if (Array.isArray(prefs.feedFilters.custom)) {
          customFilterKws = prefs.feedFilters.custom;
        }
        // Sync checkbox and text UI to restored cloud values
        ['politics', 'sports', 'news', 'entertainment'].forEach((cat) => {
          const el = $(`filter-${cat}`);
          if (el) el.checked = activeFilterCats.has(cat);
        });
        const customEl = $('feed-filter-custom');
        if (customEl) customEl.value = customFilterKws.join(', ');
        // Update "Remember" checkbox so subsequent filter changes persist locally too
        const rememberEl = $('feed-filter-remember');
        if (rememberEl && (activeFilterCats.size > 0 || customFilterKws.length > 0)) {
          rememberEl.checked = true;
        }
      }
    } catch {
      // Record doesn't exist yet or network error — silently fall back to localStorage
    }
  }

  async function savePrefsToCloud() {
    const session = AUTH.getSession();
    if (!session?.did) return;
    try {
      const record = {
        $type:        PREFS_COLLECTION,
        savedChannels: channelsLoad(),
        uiPrefs:      { hideAdult: hideAdultContent },
        feedFilters:  { categories: [...activeFilterCats], custom: customFilterKws },
      };
      await API.putRecord(session.did, PREFS_COLLECTION, PREFS_RKEY, record);
    } catch (err) {
      console.warn('Cloud prefs save failed:', err.message);
    }
  }

  function schedulePrefsSync() {
    clearTimeout(prefsSyncTimer);
    prefsSyncTimer = setTimeout(savePrefsToCloud, 2000);
  }

  /**
   * Pull the 7-day seen-URI list from the AT Protocol repo and merge it into
   * the local feedSeenMap. Called once on login, after loadPrefsFromCloud.
   */
  async function loadSeenFromCloud() {
    const session = AUTH.getSession();
    if (!session?.did) return;
    try {
      const result = await API.getRecord(session.did, SEEN_SYNC_COLLECTION, SEEN_SYNC_RKEY);
      const uris   = result?.value?.uris;
      if (!Array.isArray(uris) || uris.length === 0) return;
      // Use the record's syncedAt as the seenAt timestamp for all imported URIs.
      // Engagement counts are omitted from cloud storage (URI-only), so default to 0.
      const fallbackTs = result.value.syncedAt || Date.now();
      let added = 0;
      for (const uri of uris) {
        if (!uri || feedSeenMap.has(uri)) continue;
        if (feedSeenMap.size >= FEED_SEEN_MAX) {
          feedSeenMap.delete(feedSeenMap.keys().next().value); // FIFO eviction
        }
        feedSeenMap.set(uri, { seenAt: fallbackTs });
        added++;
      }
      if (added > 0) saveFeedSeen(); // persist merged map to localStorage
    } catch {
      // Record doesn't exist yet — first sync, nothing to merge.
    }
  }

  /**
   * Write URIs seen within the last 7 days to the AT Protocol repo.
   * URI-only (no engagement data) to keep payload small (~75–225 KB typical).
   */
  async function saveSeenToCloud() {
    const session = AUTH.getSession();
    if (!session?.did) return;
    const cutoff = Date.now() - SEEN_SYNC_WINDOW_MS;
    const uris   = [];
    for (const [uri, entry] of feedSeenMap) {
      if (entry.seenAt >= cutoff) uris.push(uri);
    }
    if (uris.length === 0) return;
    try {
      await API.putRecord(session.did, SEEN_SYNC_COLLECTION, SEEN_SYNC_RKEY, {
        $type:    SEEN_SYNC_COLLECTION,
        uris,
        syncedAt: Date.now(),
      });
    } catch (err) {
      console.warn('Cloud seen-posts sync failed:', err.message);
    }
  }

  /** Debounce cloud seen-posts writes (30 s) to avoid hammering the PDS. */
  function scheduleSeenSync() {
    clearTimeout(seenSyncTimer);
    seenSyncTimer = setTimeout(saveSeenToCloud, 30000);
  }

  /* ================================================================
     M32 — iOS SAFARI PWA SESSION PERSISTENCE
  ================================================================ */
  function getJwtExp(token) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      return typeof payload.exp === 'number' ? payload.exp * 1000 : null;
    } catch { return null; }
  }

  /**
   * Attempt to restore an expired session using (in order):
   * 1. The stored refresh token.
   * 2. Saved app-password credentials (silent re-login).
   * 3. Show the auth screen with the handle pre-filled as a last resort.
   *
   * Network errors (TypeError / "Failed to fetch") during the refresh attempt
   * are treated as transient — the existing session is preserved so the next
   * foreground event can retry.  Only a clear server-side auth rejection triggers
   * sign-out.
   */
  async function tryRestoreSession(session) {
    // 1. Try refresh token
    try {
      await AUTH.refreshSession(session.refreshJwt);
      return; // success — new tokens saved by refreshSession
    } catch (err) {
      // TypeError means a network failure (e.g. device just woke up, still offline).
      // Don't log the user out — keep the existing session and retry on next foreground.
      if (err instanceof TypeError) return;
    }

    // 2. Try silent re-login with saved app-password credentials
    const creds = AUTH.getSavedCredentials();
    if (creds) {
      try {
        await AUTH.login(creds.identifier, creds.password);
        return; // success
      } catch { /* credentials may have been revoked — fall through */ }
    }

    // 3. Both failed — show auth screen with handle pre-filled to minimise friction
    AUTH.clearSession();
    appScreen.hidden  = true;
    authScreen.hidden = false;
    scrollToTopBtn.hidden = true;
    const savedHandle = session?.handle || creds?.identifier || '';
    if (savedHandle) authForm.handle.value = savedHandle;
    showError(authError, 'Your session expired. Please sign in again.');
  }

  async function handleVisibilityChange() {
    if (document.hidden || !AUTH.isLoggedIn()) return;
    const session = AUTH.getSession();
    if (!session?.accessJwt || !session?.refreshJwt) return;

    const exp = getJwtExp(session.accessJwt);
    if (!exp) return;

    const msUntilExpiry = exp - Date.now();

    if (msUntilExpiry < 0) {
      await tryRestoreSession(session);
    } else if (msUntilExpiry < 15 * 60 * 1000) {
      // Within 15 minutes of expiry — proactively refresh
      try { await AUTH.refreshSession(session.refreshJwt); } catch { /* non-fatal */ }
    }
  }

  document.addEventListener('visibilitychange', handleVisibilityChange);

  // Flush the in-memory seen-posts map to localStorage whenever the page is hidden
  // (tab switch, app backgrounded, or mobile home-screen press). This ensures a
  // hard refresh or cold launch always starts with a fully up-to-date seen list.
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') {
      saveFeedSeen();       // flush to localStorage immediately
      saveSeenToCloud();    // best-effort immediate cloud flush; don't wait for 30 s debounce
    }
  });

  /* ================================================================
     ADULT CONTENT FILTER
  ================================================================ */
  const ADULT_LABELS = new Set([
    'porn', 'sexual', 'nudity', 'graphic-media', 'gore',
    'suggestive', 'adult-only', 'corpse',
  ]);

  function hasAdultContent(post) {
    if (!hideAdultContent) return false;
    const postLabels   = post.labels         || [];
    const authorLabels = post.author?.labels || [];
    return [...postLabels, ...authorLabels].some((l) => ADULT_LABELS.has(l.val));
  }

  /* ================================================================
     IMAGE LIGHTBOX — carousel-capable
  ================================================================ */
  let lightboxImages   = [];   // [{ src, alt }, ...]
  let lightboxIndex    = 0;
  let lightboxTouchX   = null; // for horizontal swipe detection
  let lightboxTouchY   = null; // M54: for vertical swipe-to-dismiss detection
  let lightboxTouches  = 0;    // max simultaneous touch points in current gesture (>1 = pinch)
  let lightboxPost     = null; // post object when opened from gallery; null otherwise

  function openLightbox(images, startIndex = 0, post = null) {
    // Accept either an array of {src,alt} objects or a single {src,alt}
    lightboxImages = Array.isArray(images) ? images : [images];
    lightboxIndex  = Math.max(0, Math.min(startIndex, lightboxImages.length - 1));
    lightboxPost   = post || null;

    // Show/hide the "View conversation" button based on whether a post was provided
    const viewConvoBtn = document.getElementById('lightbox-view-convo');
    if (viewConvoBtn) viewConvoBtn.hidden = !lightboxPost;

    // Re-enable pinch-zoom inside the lightbox
    const vp = document.querySelector('meta[name="viewport"]');
    if (vp) vp.content = 'width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=5.0, user-scalable=yes';

    renderLightboxSlide();
    imageLightbox.hidden         = false;
    document.body.style.overflow = 'hidden';
    lightboxCloseBtn.focus();
  }

  function renderLightboxSlide() {
    const { src, alt } = lightboxImages[lightboxIndex];
    const total = lightboxImages.length;

    lightboxImg.src             = src;
    lightboxImg.alt             = alt || '';
    lightboxCaption.textContent = alt || '';
    lightboxCaption.hidden      = !alt;

    // Counter: "2 / 4"
    lightboxCounter.textContent = total > 1 ? `${lightboxIndex + 1} / ${total}` : '';
    lightboxCounter.hidden      = total <= 1;

    // Arrow buttons
    lightboxPrevBtn.hidden = total <= 1;
    lightboxNextBtn.hidden = total <= 1;

    // Dot indicators
    lightboxDots.innerHTML = '';
    if (total > 1) {
      lightboxImages.forEach((_, i) => {
        const dot = document.createElement('span');
        dot.className = 'lightbox-dot' + (i === lightboxIndex ? ' active' : '');
        dot.addEventListener('click', (e) => { e.stopPropagation(); goLightbox(i); });
        lightboxDots.appendChild(dot);
      });
    }
  }

  function goLightbox(index) {
    lightboxIndex = (index + lightboxImages.length) % lightboxImages.length;
    renderLightboxSlide();
  }

  function closeLightbox() {
    imageLightbox.hidden         = true;
    lightboxImg.src              = '';
    lightboxImages               = [];
    lightboxPost                 = null;
    document.body.style.overflow = '';
    const viewConvoBtn = document.getElementById('lightbox-view-convo');
    if (viewConvoBtn) viewConvoBtn.hidden = true;

    // Restore no-zoom viewport for the rest of the app
    const vp = document.querySelector('meta[name="viewport"]');
    if (vp) vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  }

  lightboxCloseBtn.addEventListener('click', closeLightbox);
  lightboxPrevBtn.addEventListener('click', (e) => { e.stopPropagation(); goLightbox(lightboxIndex - 1); });
  lightboxNextBtn.addEventListener('click', (e) => { e.stopPropagation(); goLightbox(lightboxIndex + 1); });

  // "View conversation" button — only visible when opened from gallery
  document.getElementById('lightbox-view-convo')?.addEventListener('click', (e) => {
    e.stopPropagation();
    const post = lightboxPost; // capture before closeLightbox() nulls it
    if (!post) return;
    closeLightbox();
    openThread(post.uri, post.cid || '', post.author?.handle || '');
  });

  imageLightbox.addEventListener('click', (e) => {
    if (e.target === imageLightbox) closeLightbox();
  });

  document.addEventListener('keydown', (e) => {
    if (imageLightbox.hidden) return;
    if (e.key === 'Escape')      closeLightbox();
    if (e.key === 'ArrowLeft')   goLightbox(lightboxIndex - 1);
    if (e.key === 'ArrowRight')  goLightbox(lightboxIndex + 1);
  });

  // Touch swipe support (M54: vertical swipe closes; horizontal swipe navigates)
  // Pinch-to-zoom (multi-touch) is detected and excluded so zoom doesn't trigger dismiss
  imageLightbox.addEventListener('touchstart', (e) => {
    lightboxTouches = Math.max(lightboxTouches, e.touches.length);
    if (e.touches.length === 1) {
      lightboxTouchX = e.touches[0].clientX;
      lightboxTouchY = e.touches[0].clientY;
    } else {
      // Second finger added — cancel any pending swipe tracking
      lightboxTouchX = null;
      lightboxTouchY = null;
    }
  }, { passive: true });

  imageLightbox.addEventListener('touchmove', (e) => {
    if (e.touches.length > 1) {
      // Additional finger during move — definitely a pinch, cancel swipe
      lightboxTouches = Math.max(lightboxTouches, e.touches.length);
      lightboxTouchX = null;
      lightboxTouchY = null;
    }
  }, { passive: true });

  imageLightbox.addEventListener('touchend', (e) => {
    if (e.touches.length > 0) return; // more fingers still on screen
    const wasPinch = lightboxTouches > 1;
    lightboxTouches = 0; // reset for next gesture

    if (wasPinch || lightboxTouchX === null || lightboxTouchY === null) {
      lightboxTouchX = null;
      lightboxTouchY = null;
      return; // pinch gesture — don't dismiss or navigate
    }
    const dx = e.changedTouches[0].clientX - lightboxTouchX;
    const dy = e.changedTouches[0].clientY - lightboxTouchY;
    lightboxTouchX = null;
    lightboxTouchY = null;
    // Vertical swipe (any direction, ≥ 80px) → dismiss lightbox
    if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) >= 80) {
      closeLightbox();
      return;
    }
    // Horizontal swipe → navigate images
    if (Math.abs(dx) < 40) return;
    if (dx < 0) goLightbox(lightboxIndex + 1);  // swipe left → next
    else         goLightbox(lightboxIndex - 1);  // swipe right → prev
  }, { passive: true });

  /* ================================================================
     M39 — FEED CONTENT FILTERS
  ================================================================ */
  const FEED_FILTERS_KEY = 'bsky_feed_filters';

  // Filter state
  let feedFilterWords  = {};          // loaded from filter-words.json
  let activeFilterCats = new Set();   // 'politics' | 'sports' | 'news' | 'entertainment'
  let customFilterKws  = [];          // user-supplied keywords
  let feedFilterCount  = 0;           // posts hidden this session

  // Load filter-words.json once
  fetch('js/filter-words.json')
    .then((r) => r.json())
    .then((data) => { feedFilterWords = data; })
    .catch(() => {}); // non-fatal

  // Load remembered filters from localStorage
  function loadFeedFilters() {
    try {
      const stored = JSON.parse(localStorage.getItem(FEED_FILTERS_KEY) || 'null');
      if (!stored) return;
      activeFilterCats = new Set(stored.categories || []);
      customFilterKws  = stored.custom || [];
      // Sync checkboxes
      ['politics', 'sports', 'news', 'entertainment'].forEach((cat) => {
        const el = $(`filter-${cat}`);
        if (el) el.checked = activeFilterCats.has(cat);
      });
      const customEl = $('feed-filter-custom');
      if (customEl) customEl.value = customFilterKws.join(', ');
    } catch {}
  }

  function saveFeedFilters() {
    const rememberEl = $('feed-filter-remember');
    if (!rememberEl?.checked) return;
    localStorage.setItem(FEED_FILTERS_KEY, JSON.stringify({
      categories: [...activeFilterCats],
      custom:     customFilterKws,
    }));
  }

  /**
   * Apply filters to all rendered feed posts. Call after filter state changes.
   */
  function applyFeedFilters() {
    const cards = feedResults?.querySelectorAll('.post-card') || [];
    let hidden = 0;
    cards.forEach((card) => {
      const postText = (card.querySelector('.post-text')?.textContent || '').toLowerCase();
      const matchesCat = [...activeFilterCats].some((cat) => {
        const words = feedFilterWords[cat] || [];
        return words.some((w) => postText.includes(w.toLowerCase()));
      });
      const matchesCustom = customFilterKws.some((kw) => kw && postText.includes(kw.toLowerCase()));
      const shouldHide = matchesCat || matchesCustom;
      card.style.display = shouldHide ? 'none' : '';
      if (shouldHide) hidden++;
    });
    feedFilterCount = hidden;
    updateFeedFilterCount();
  }

  function updateFeedFilterCount() {
    const countEl = $('feed-filter-count');
    if (!countEl) return;
    if (feedFilterCount > 0) {
      countEl.textContent = `${feedFilterCount} post${feedFilterCount !== 1 ? 's' : ''} filtered`;
      countEl.hidden = false;
    } else {
      countEl.hidden = true;
    }
  }

  // Wire up filter panel toggle
  const feedFilterToggle = $('feed-filter-toggle');
  const feedFilterPanel  = $('feed-filter-panel');

  if (feedFilterToggle && feedFilterPanel) {
    feedFilterToggle.addEventListener('click', () => {
      const willOpen = feedFilterPanel.hidden;
      feedFilterPanel.hidden = !willOpen;
      feedFilterToggle.setAttribute('aria-expanded', willOpen ? 'true' : 'false');
      feedFilterToggle.textContent = willOpen ? 'Filters ▴' : 'Filters ▾';
    });
  }

  // Wire up category checkboxes
  ['politics', 'sports', 'news', 'entertainment'].forEach((cat) => {
    const el = $(`filter-${cat}`);
    if (!el) return;
    el.addEventListener('change', () => {
      if (el.checked) activeFilterCats.add(cat);
      else activeFilterCats.delete(cat);
      applyFeedFilters();
      saveFeedFilters();
      schedulePrefsSync(); // M20: push filter change to cloud
    });
  });

  // Wire up custom keywords input (debounced)
  const feedFilterCustomEl = $('feed-filter-custom');
  if (feedFilterCustomEl) {
    let customTimer = null;
    feedFilterCustomEl.addEventListener('input', () => {
      clearTimeout(customTimer);
      customTimer = setTimeout(() => {
        customFilterKws = feedFilterCustomEl.value
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .filter(Boolean);
        applyFeedFilters();
        saveFeedFilters();
        schedulePrefsSync(); // M20: push filter change to cloud
      }, 400);
    });
  }

  // Wire up "Remember my filters" checkbox
  const feedFilterRemember = $('feed-filter-remember');
  if (feedFilterRemember) {
    feedFilterRemember.addEventListener('change', () => {
      if (!feedFilterRemember.checked) {
        localStorage.removeItem(FEED_FILTERS_KEY);
      } else {
        saveFeedFilters();
      }
    });
  }

  /* ================================================================
     M37 — IMAGE GALLERY VIEW
  ================================================================ */
  const navGalleryBtn  = $('nav-gallery-btn');
  const viewGallery    = $('view-gallery');
  const galleryFeed    = $('gallery-feed');
  const gallerySentinel = $('gallery-load-sentinel');
  const galleryLoading = $('gallery-loading');
  const galleryEmpty   = $('gallery-empty');
  const galleryEndMsg  = $('gallery-end'); // M59: end-of-feed indicator

  let galleryCursorTimeline = null;
  let galleryCursorDiscover = null;
  let galleryLoading_flag   = false;
  let galleryAllDone        = false;
  let gallerySeenCids       = new Set(); // dedup by blob CID (within session)
  let galleryScrollObserver = null;

  /**
   * Returns true when a post has at least one image embed
   * (images or recordWithMedia with image media).
   */
  function postHasImages(post) {
    const embed = post.embed || {};
    const type  = embed.$type || '';
    if (type === 'app.bsky.embed.images#view') return true;
    if (type === 'app.bsky.embed.recordWithMedia#view') {
      const media = embed.media || {};
      return (media.$type || '') === 'app.bsky.embed.images#view';
    }
    return false;
  }

  /**
   * Extract image view objects from a post embed.
   * @returns {Array} array of { thumb, fullsize, alt } objects
   */
  function extractImages(post) {
    const embed = post.embed || {};
    const type  = embed.$type || '';
    if (type === 'app.bsky.embed.images#view') {
      return embed.images || [];
    }
    if (type === 'app.bsky.embed.recordWithMedia#view') {
      const media = embed.media || {};
      if ((media.$type || '') === 'app.bsky.embed.images#view') {
        return media.images || [];
      }
    }
    return [];
  }

  /**
   * Build a single gallery card for a post with images.
   */
  function buildGalleryCard(post) {
    const author = post.author || {};
    const images = extractImages(post);
    if (!images.length) return null;

    // Check for duplicate blob CIDs
    const cids = images.map((img) => {
      const src = img.fullsize || img.thumb || '';
      // CID appears in AT Protocol CDN URLs as a path segment
      const match = src.match(/\/([A-Za-z0-9]{46,})\//);
      return match ? match[1] : src;
    });
    const allSeen = cids.every((c) => gallerySeenCids.has(c));
    if (allSeen) return null;
    cids.forEach((c) => gallerySeenCids.add(c));

    const card = document.createElement('div');
    card.className = 'gallery-card';
    card.dataset.uri = post.uri;

    // Image grid — reuse buildImageGrid for consistent sizing
    const lightboxPayload = images.map((img) => ({
      src: img.fullsize || img.thumb || '',
      alt: img.alt || '',
    }));
    const grid = buildImageGrid(images);
    // Make each image open lightbox at the right index
    grid.querySelectorAll('img').forEach((img, idx) => {
      img.style.cursor = 'pointer';
      img.addEventListener('click', (e) => {
        e.stopPropagation();
        openLightbox(lightboxPayload, idx, post);
      });
    });
    card.appendChild(grid);

    // Author strip
    const strip = document.createElement('div');
    strip.className = 'gallery-author-strip';

    const avatar = document.createElement('img');
    setAvatarSrc(avatar, author.avatar);
    avatar.alt       = '';
    avatar.className = 'gallery-author-avatar';
    avatar.loading   = 'lazy';
    strip.appendChild(avatar);

    const meta = document.createElement('div');
    meta.className = 'gallery-author-meta';
    const nameBtn = document.createElement('button');
    nameBtn.className   = 'gallery-author-name';
    nameBtn.textContent = author.displayName || author.handle || '';
    nameBtn.addEventListener('click', (e) => { e.stopPropagation(); openProfile(author.handle); });
    const handle = document.createElement('span');
    handle.className   = 'gallery-author-handle';
    handle.textContent = `@${author.handle || ''}`;
    meta.appendChild(nameBtn);
    meta.appendChild(handle);
    strip.appendChild(meta);

    // Like / Repost / Reply counts
    const counts = document.createElement('div');
    counts.className = 'gallery-counts post-actions'; // post-actions enables repost action sheet positioning

    const likeCount   = post.likeCount   || 0;
    const repostCount = post.repostCount || 0;
    const replyCount  = post.replyCount  || 0;

    // Reply button — inline reply directly on the gallery card
    const replyBtn = document.createElement('button');
    replyBtn.className   = 'gallery-action-btn';
    replyBtn.title       = 'Reply';
    replyBtn.setAttribute('aria-label', 'Reply');
    replyBtn.innerHTML   = `<svg viewBox="0 0 24 24" width="15" height="15" stroke="currentColor" fill="none" stroke-width="2" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg> <span class="action-count">${replyCount}</span>`;
    replyBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      expandInlineReply(card, post);
    });

    // Repost button — uses showRepostActionSheet (same as main feed)
    const repostBtn = document.createElement('button');
    repostBtn.className = 'gallery-action-btn repost-action-btn' + (post.viewer?.repost ? ' reposted' : '');
    repostBtn.title     = 'Repost or Quote Post';
    repostBtn.setAttribute('aria-label', 'Repost or Quote Post');
    repostBtn.dataset.uri       = post.uri;
    repostBtn.dataset.cid       = post.cid;
    repostBtn.dataset.repostUri = post.viewer?.repost || '';
    repostBtn.innerHTML = `<svg viewBox="0 0 24 24" width="15" height="15" stroke="${post.viewer?.repost ? 'var(--color-repost)' : 'currentColor'}" fill="none" stroke-width="2" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg> <span class="action-count">${repostCount}</span>`;
    repostBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      showRepostActionSheet(repostBtn, post);
    });

    // Like button — optimistic update with rollback
    const likeBtn = document.createElement('button');
    likeBtn.className = 'gallery-action-btn';
    likeBtn.title     = post.viewer?.like ? 'Unlike' : 'Like';
    likeBtn.setAttribute('aria-label', post.viewer?.like ? 'Unlike' : 'Like');
    likeBtn.innerHTML = `<svg viewBox="0 0 24 24" width="15" height="15" stroke="currentColor" fill="${post.viewer?.like ? 'currentColor' : 'none'}" stroke-width="2" aria-hidden="true"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg> <span class="action-count">${likeCount}</span>`;
    likeBtn.dataset.uri    = post.uri;
    likeBtn.dataset.cid    = post.cid;
    likeBtn.dataset.likeUri = post.viewer?.like || '';
    likeBtn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const btn = e.currentTarget;
      if (btn.disabled) return;
      btn.disabled = true;
      const liked      = !!btn.dataset.likeUri;
      const prevLikeUri = btn.dataset.likeUri;
      const countSpan  = btn.querySelector('.action-count');
      const prevCount  = parseInt(countSpan.textContent, 10);
      // Optimistic
      if (liked) {
        btn.dataset.likeUri = '';
        btn.querySelector('svg').setAttribute('fill', 'none');
        countSpan.textContent = Math.max(0, prevCount - 1);
      } else {
        btn.querySelector('svg').setAttribute('fill', 'currentColor');
        countSpan.textContent = prevCount + 1;
      }
      try {
        if (liked) {
          await API.unlikePost(prevLikeUri);
        } else {
          const result = await API.likePost(btn.dataset.uri, btn.dataset.cid);
          btn.dataset.likeUri = result?.uri || '';
        }
      } catch {
        // Rollback
        btn.dataset.likeUri = prevLikeUri;
        btn.querySelector('svg').setAttribute('fill', liked ? 'currentColor' : 'none');
        countSpan.textContent = prevCount;
      } finally {
        btn.disabled = false;
      }
    });

    counts.appendChild(replyBtn);
    counts.appendChild(repostBtn);
    counts.appendChild(likeBtn);
    strip.appendChild(counts);
    card.appendChild(strip);

    // Clicking the card (not on an image or button) opens the thread
    card.addEventListener('click', () => openThread(post.uri, post.cid || '', author.handle || ''));

    // Mark seen immediately at render time — unified cross-interface registry
    markFeedPostSeen(post.uri);

    return card;
  }

  /**
   * Fetch one batch of images from both timeline and discover feeds,
   * filter and render them.
   */
  async function loadGalleryBatch() {
    if (galleryLoading_flag || galleryAllDone) return;
    galleryLoading_flag = true;
    galleryLoading.hidden = false;

    try {
      const [timelineRes, discoverRes] = await Promise.allSettled([
        galleryCursorTimeline !== 'done' ? API.getTimeline(30, galleryCursorTimeline || undefined) : Promise.resolve(null),
        galleryCursorDiscover !== 'done' ? API.getFeed(DISCOVER_FEED_URI, 30, galleryCursorDiscover || undefined) : Promise.resolve(null),
      ]);

      const timelineData = timelineRes.status === 'fulfilled' ? timelineRes.value : null;
      const discoverData = discoverRes.status === 'fulfilled'  ? discoverRes.value  : null;

      // Update cursors
      if (timelineData) {
        galleryCursorTimeline = timelineData.cursor || 'done';
      } else {
        galleryCursorTimeline = 'done';
      }
      if (discoverData) {
        galleryCursorDiscover = discoverData.cursor || 'done';
      } else {
        galleryCursorDiscover = 'done';
      }

      if (galleryCursorTimeline === 'done' && galleryCursorDiscover === 'done') {
        galleryAllDone = true;
      }

      // Merge, dedup by URI, extract image posts
      const allItems = [
        ...(timelineData?.feed || []),
        ...(discoverData?.feed || []),
      ];

      let rendered = 0;
      for (const item of allItems) {
        const post = item.post;
        if (!post?.uri) continue;
        // Use the unified feedSeenMap for cross-interface + cross-session dedup.
        // buildGalleryCard calls markFeedPostSeen, so within-batch duplicates are
        // automatically caught by feedSeenMap after the first occurrence is rendered.
        if (isFeedPostSeen(post.uri)) continue;
        if (!postHasImages(post)) continue;
        const card = buildGalleryCard(post);
        if (!card) continue;
        galleryFeed.appendChild(card);
        rendered++;
      }

      // Persist seen-state synchronously after each gallery batch.
      if (rendered > 0) saveFeedSeen();

      // If we rendered nothing but there's more to load, try another batch
      if (rendered === 0 && !galleryAllDone) {
        galleryLoading_flag = false;
        galleryLoading.hidden = true;
        await loadGalleryBatch();
        return;
      }

      galleryEmpty.hidden = galleryFeed.children.length > 0;
      // M59: show end-of-feed message when all posts have been loaded
      if (galleryAllDone) {
        if (galleryEndMsg) galleryEndMsg.hidden = false;
        if (galleryScrollObserver) galleryScrollObserver.disconnect();
      }
    } catch (err) {
      // silently log — gallery is non-critical
      console.warn('Gallery load error:', err);
    } finally {
      galleryLoading_flag = false;
      galleryLoading.hidden = true;
    }
  }

  /** Reset gallery state and load fresh. */
  function loadGallery() {
    galleryCursorTimeline = null;
    galleryCursorDiscover = null;
    galleryLoading_flag   = false;
    galleryAllDone        = false;
    gallerySeenCids       = new Set(); // reset blob-CID dedup for this session
    galleryFeed.innerHTML = '';
    galleryEmpty.hidden   = true;
    galleryLoading.hidden = true;
    if (galleryEndMsg) galleryEndMsg.hidden = true;
    setupGalleryScrollObserver();
    loadGalleryBatch();
  }

  /** Set up IntersectionObserver on the sentinel to trigger infinite scroll. */
  function setupGalleryScrollObserver() {
    if (galleryScrollObserver) galleryScrollObserver.disconnect();
    galleryScrollObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && !galleryLoading_flag) {
          loadGalleryBatch();
        }
      },
      { root: viewGallery, rootMargin: '0px 0px 400px 0px', threshold: 0 }
    );
    if (gallerySentinel) galleryScrollObserver.observe(gallerySentinel);
  }

  if (navGalleryBtn) {
    navGalleryBtn.addEventListener('click', () => {
      showView('gallery');
      loadGallery();
    });
  }

  /* ================================================================
     INIT — check stored session on page load
  ================================================================ */
  async function init() {
    const urlParams = new URLSearchParams(window.location.search);
    // Seed history preserving any existing URL params
    if (!window.location.search) {
      history.replaceState({ view: 'feed' }, '', '?view=feed');
    }

    if (AUTH.isLoggedIn()) {
      // On cold launch the access token may already be expired.  Proactively
      // restore it before enterApp fires any API calls with a stale token.
      const session = AUTH.getSession();
      const exp = session?.accessJwt ? getJwtExp(session.accessJwt) : null;
      if (exp !== null && exp - Date.now() < 0) {
        await tryRestoreSession(session);
        if (!AUTH.isLoggedIn()) return; // auth screen is now shown — stop here
      }
      await enterApp(urlParams);
    }
    // Auth screen visible by default
  }

  /* ================================================================
     AUTH
  ================================================================ */
  authForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideError(authError);
    const handle   = authForm.handle.value.trim();
    const password = authForm.password.value.trim();
    if (!handle || !password) return;

    authSubmit.disabled = true;
    authSubmit.textContent = 'Signing in…';

    try {
      await AUTH.login(handle, password);
      AUTH.saveCredentials(handle, password); // enables silent re-login if refresh token expires
      await enterApp(new URLSearchParams(window.location.search));
    } catch (err) {
      showError(authError, err.message || 'Sign in failed. Check your handle and app password.');
    } finally {
      authSubmit.disabled = false;
      authSubmit.textContent = 'Sign in';
    }
  });

  async function enterApp(urlParams) {
    authScreen.hidden = true;
    appScreen.hidden  = false;
    showLoading();
    try {
      ownProfile = await API.getOwnProfile();
      renderNav(ownProfile);
      renderComposeAvatars(ownProfile);
    } catch {
      // Non-fatal — app still usable without profile data
    } finally {
      hideLoading();
    }

    // Render channels sidebar and kick off background tasks
    renderChannelsSidebar();
    checkChannelUnreads();    // async background unread check
    loadPrefsFromCloud();     // M20: merge cloud prefs (channels, filters, uiPrefs) with localStorage
    loadSeenFromCloud();      // M20+: merge cloud seen-posts (7-day window) with localStorage
    loadFeedFilters();        // M39: restore persisted filter settings (localStorage fallback)

    // M52: apply saved default feed tab preference
    const savedTab = localStorage.getItem('bsky_default_tab');
    if (savedTab === 'following' || savedTab === 'discover') setFeedMode(savedTab);

    // M43: populate sidebar own-profile section
    updateSidebarProfile(ownProfile);

    // Route to the view specified by the URL (deep-link / bookmark support)
    const p = urlParams instanceof URLSearchParams ? urlParams : new URLSearchParams();
    const urlView = p.get('view');
    const urlQ    = p.get('q');

    if (urlView === 'post' && p.get('uri')) {
      await openThread(p.get('uri'), '', p.get('handle') || '', { fromHistory: true });
    } else if (urlView === 'profile' && p.get('actor')) {
      await openProfile(p.get('actor'), { fromHistory: true });
    } else if (urlView === 'notifications') {
      showView('notifications', true);
      loadNotifications();
    } else if (urlView === 'feed') {
      showView('feed', true);
      loadFeed();
    } else if (urlView === 'gallery') {
      showView('gallery', true);
      loadGallery();
    } else if (urlView === 'analytics') {
      showView('analytics', true);
    } else if (urlView === 'compose') {
      showView('compose', true);
      const shareText = p.get('shareText');
      if (shareText) {
        composeText.value = shareText;
        updateCharCount(composeText, composeCount);
        // Trigger link-preview immediately (no debounce) for share-to-compose
        const urlMatch = shareText.match(/https?:\/\/[^\s]+/);
        if (urlMatch) fetchLinkPreview(urlMatch[0]);
        else composeText.dispatchEvent(new Event('input', { bubbles: true }));
      }
      // Strip share params from URL so Back doesn't re-trigger compose pre-fill
      history.replaceState({ view: 'compose' }, '', '?view=compose');
    } else if (urlView === 'timeline') {
      showView('timeline', true);
    } else if (urlQ) {
      // Restore a saved search from URL
      searchInput.value = urlQ;
      const filter = p.get('filter') || 'posts';
      activeFilter = filter;
      filterChips.forEach((c) => c.classList.remove('active'));
      const chip = document.querySelector(`.filter-chip[data-filter="${filter}"]`);
      if (chip) chip.classList.add('active');
      showView('search', true);
      searchForm.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    } else {
      showView('feed', true);
      loadFeed();
    }
  }

  function renderNav(profile) {
    if (!profile) return;
    navAvatar.src = profile.avatar || '';
    navAvatar.alt = profile.displayName || profile.handle || '';
    navHandle.textContent = `@${profile.handle}`;
    menuDisplayName.textContent = profile.displayName || profile.handle;
    menuHandle.textContent = `@${profile.handle}`;
  }

  function renderComposeAvatars(profile) {
    if (!profile) return;
    [composeAvatar, replyAvatar].forEach((el) => {
      el.src = profile.avatar || '';
      el.alt = profile.displayName || profile.handle || '';
    });
  }

  /* ================================================================
     NAVIGATION
  ================================================================ */
  function showView(name, fromHistory = false) {
    currentView = name;

    const views = {
      feed:          viewFeed,
      search:        viewSearch,
      compose:       viewCompose,
      thread:        viewThread,
      profile:       viewProfile,
      notifications: viewNotifications,
      tv:            viewTv,
      gallery:       viewGallery,
      analytics:     viewAnalytics,
      timeline:      viewTimeline,
    };
    const navBtns = {
      feed:          navFeedBtn,
      search:        navSearchBtn,
      compose:       navComposeBtn,
      notifications: navNotifBtn,
      tv:            navTvBtn,
      gallery:       navGalleryBtn,
      analytics:     navAnalyticsBtn,
      timeline:      navTimelineBtn,
    };

    Object.entries(views).forEach(([n, el]) => {
      el.hidden  = n !== name;
      el.classList.toggle('active', n === name);
    });

    Object.entries(navBtns).forEach(([n, btn]) => {
      btn.classList.toggle('active', n === name);
      btn.setAttribute('aria-current', n === name ? 'page' : 'false');
    });

    // M43: close mobile sidebar drawer on any navigation
    closeSidebar();

    // Remove any stale "Save as channel" button when leaving search view
    if (name !== 'search') {
      document.querySelector('.save-channel-area')?.remove();
    }

    // Reset compose state when switching to compose view
    if (name === 'compose') {
      composeForm.reset();
      composeCount.textContent = '300';
      hideError(composeError);
      composeSuccess.hidden = true;
      clearComposeImages();
      clearComposeVideo();
      // M41: clear link preview and toggle panels
      composeLinkEmbed = null;
      clearTimeout(linkPreviewTimer);
      const lpWrap = $('compose-link-preview-wrap');
      if (lpWrap) lpWrap.innerHTML = '';
      const gifP  = $('compose-gif-panel');
      const setP  = $('compose-settings-panel');
      const rgEl  = $('compose-reply-gate');
      const qgEl  = $('compose-quote-gate');
      if (gifP)  gifP.hidden  = true;
      if (setP)  setP.hidden  = true;
      if (rgEl)  rgEl.value   = 'everyone';
      if (qgEl)  qgEl.value   = 'everyone';
    }

    if (!fromHistory) {
      const state = { view: name };
      let url = '?';
      if (name === 'search') {
        state.query  = searchInput.value;
        state.filter = activeFilter;
        if (searchInput.value) {
          url = `?q=${encodeURIComponent(searchInput.value)}&filter=${encodeURIComponent(activeFilter)}`;
        }
      } else if (name === 'feed') {
        url = '?view=feed';
      } else if (name === 'notifications') {
        url = '?view=notifications';
      } else if (name === 'compose') {
        url = '?view=compose';
      } else if (name === 'tv') {
        url = '?view=tv';
      } else if (name === 'gallery') {
        url = '?view=gallery';
      } else if (name === 'analytics') {
        url = '?view=analytics';
      } else if (name === 'timeline') {
        url = '?view=timeline';
      }
      history.pushState(state, '', url);
    }

    // Pause TV playback when leaving the TV view
    if (name !== 'tv') {
      window.tvStop?.();
    }

    // M44: disconnect feed seen observer when leaving the feed view
    if (name !== 'feed' && feedSeenObserver) {
      feedSeenObserver.disconnect();
      feedSeenObserver = null;
    }

    // disconnect feed infinite-scroll observer when leaving feed view
    if (name !== 'feed' && feedScrollObserver) {
      feedScrollObserver.disconnect();
    }

    // M37: disconnect gallery scroll observer when leaving gallery view
    if (name !== 'gallery' && galleryScrollObserver) {
      galleryScrollObserver.disconnect();
      galleryScrollObserver = null;
    }

    // disconnect profile scroll observer when leaving profile view
    if (name !== 'profile' && profileScrollObserver) {
      profileScrollObserver.disconnect();
    }

    // disconnect notifications scroll observer when leaving notifications view
    if (name !== 'notifications' && notifScrollObserver) {
      notifScrollObserver.disconnect();
    }

    // disconnect search scroll observer when leaving search view
    if (name !== 'search' && searchScrollObserver) {
      searchScrollObserver.disconnect();
    }

    // Hide scroll-to-top button on view switch (M34)
    scrollToTopBtn.hidden = true;
  }

  // Logo / title click always returns to feed and refreshes
  $('nav-home-btn').addEventListener('click', () => {
    showView('feed', true);
    loadFeed();
  });

  navFeedBtn.addEventListener('click', () => {
    showView('feed');
    if (!feedLoaded) {
      loadFeed();
    } else {
      // Feed already loaded — restore the scroll observer that showView disconnected.
      const hasMore = feedCursor || (feedMode === 'discover' && feedDiscoverLooped);
      if (hasMore) setupFeedScrollObserver();
    }
  });
  navSearchBtn.addEventListener('click', () => showView('search'));
  navComposeBtn.addEventListener('click', () => showView('compose'));
  navNotifBtn.addEventListener('click', () => {
    showView('notifications');
    clearNotifBadge();
    if (!notifLoaded) loadNotifications();
  });
  navTvBtn.addEventListener('click', () => showView('tv'));
  navAnalyticsBtn.addEventListener('click', () => {
    showView('analytics');
    loadAnalytics();
  });
  navTimelineBtn.addEventListener('click', () => showView('timeline'));

  // Use browser history for the Back button so Forward/Back both work
  threadBackBtn.addEventListener('click',  () => history.back());
  profileBackBtn.addEventListener('click', () => history.back());

  // Restore state on browser Back/Forward
  window.addEventListener('popstate', async (e) => {
    if (!AUTH.isLoggedIn()) return;
    const state  = e.state;
    const params = new URLSearchParams(window.location.search);

    // Prefer richer history.state; fall back to URL params for direct shares
    if (state?.view === 'thread' && state.uri) {
      await openThread(state.uri, state.cid, state.handle, { fromHistory: true });
    } else if (params.get('view') === 'post' && params.get('uri')) {
      await openThread(params.get('uri'), '', params.get('handle') || '', { fromHistory: true });
    } else if (state?.view === 'profile' && state.actor) {
      await openProfile(state.actor, { fromHistory: true });
    } else if (params.get('view') === 'profile' && params.get('actor')) {
      await openProfile(params.get('actor'), { fromHistory: true });
    } else {
      const view = state?.view || params.get('view') || 'search';
      showView(view, true);
      const q = state?.query || params.get('q');
      if (view === 'search' && q) searchInput.value = q;
      if (view === 'feed' && !feedLoaded) {
        loadFeed();
      } else if (view === 'feed' && feedLoaded) {
        // Feed already has content — the scroll observer was disconnected on the way
        // out (showView tears it down) so reconnect it without reloading the feed.
        const hasMore = feedCursor || (feedMode === 'discover' && feedDiscoverLooped);
        if (hasMore) setupFeedScrollObserver();
      }
      if (view === 'gallery') {
        if (galleryFeed.children.length === 0) {
          loadGallery();
        } else if (!galleryAllDone) {
          // Gallery has content — scroll observer was disconnected on the way out; reconnect it.
          setupGalleryScrollObserver();
        }
      }
      if (view === 'notifications' && !notifLoaded) loadNotifications();
    }
  });

  /* ================================================================
     PROFILE DROPDOWN
  ================================================================ */
  navProfileBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    profileMenu.hidden = !profileMenu.hidden;
  });

  document.addEventListener('click', () => {
    profileMenu.hidden = true;
  });

  $('menu-settings').addEventListener('click', () => {
    profileMenu.hidden = true;
    openSettings();
  });

  menuSignOut.addEventListener('click', () => {
    AUTH.clearSession();
    AUTH.clearCredentials();
    appScreen.hidden  = true;
    authScreen.hidden = false;
    scrollToTopBtn.hidden = true;
    profileMenu.hidden = true;
    ownProfile = null;
    feedLoaded = false;
    notifLoaded = false;
    notifBadge.hidden = true;
    clearComposeImages();
    searchResults.innerHTML = '<div class="feed-empty"><p>Search for posts, people, or topics on BlueSky.</p></div>';
    threadContent.innerHTML = '';
    updateSidebarProfile(null); // M43: clear sidebar profile
    // Clear save-channel button if any
    document.querySelector('.save-channel-area')?.remove();
  });

  /* ================================================================
     SEARCH
  ================================================================ */
  filterChips.forEach((chip) => {
    chip.addEventListener('click', () => {
      filterChips.forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');
      activeFilter = chip.dataset.filter;
    });
  });

  // Adult content toggle — re-render cached results immediately
  adultToggle.addEventListener('change', () => {
    hideAdultContent = adultToggle.checked;
    if (lastSearchType === 'posts' && lastSearchResults.length) {
      renderPostFeed(lastSearchResults, searchResults);
    }
    schedulePrefsSync(); // M20
  });

  // Advanced panel toggle
  advToggleBtn.addEventListener('click', () => {
    const open = advPanel.hidden;
    advPanel.hidden = !open;
    advToggleBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  });

  // M49: media filter chip toggle
  document.querySelectorAll('.adv-media-chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      const key = chip.dataset.media;
      if (searchMediaFilters.has(key)) {
        searchMediaFilters.delete(key);
        chip.classList.remove('active');
      } else {
        searchMediaFilters.add(key);
        chip.classList.add('active');
      }
    });
  });

  // Trigger a post search programmatically (used by hashtag clicks)
  function triggerSearch(query) {
    searchInput.value = query;
    // Switch to Posts filter for hashtag/keyword searches
    filterChips.forEach((c) => c.classList.remove('active'));
    const postsChip = document.querySelector('.filter-chip[data-filter="posts"]');
    if (postsChip) postsChip.classList.add('active');
    activeFilter = 'posts';
    showView('search');
    searchForm.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
  }

  /* ---- M49: Apply client-side media type filter to post array ---- */
  function applyMediaFilter(posts) {
    if (!searchMediaFilters.size) return posts;
    return posts.filter((post) => {
      const embed = post.embed;
      if (!embed) return false;
      const t = embed.$type || '';
      if (searchMediaFilters.has('image')  && (t.includes('images') || (embed.media?.$type || '').includes('images'))) return true;
      if (searchMediaFilters.has('video')  && (t.includes('video')  || (embed.media?.$type || '').includes('video')))  return true;
      if (searchMediaFilters.has('link')   && (t.includes('external') || (post.record?.facets || []).some(
        (f) => f.features?.[0]?.$type === 'app.bsky.richtext.facet#link'))) return true;
      return false;
    });
  }

  /* ---- M48 (updated): Infinite scroll for search results ---- */
  let searchScrollObserver = null;
  let searchScrollLoading  = false;

  function setupSearchScrollObserver(type) {
    if (searchScrollObserver) searchScrollObserver.disconnect();
    searchScrollObserver = new IntersectionObserver(
      async (entries) => {
        if (!entries[0]?.isIntersecting || !searchCursor || searchScrollLoading) return;
        searchScrollLoading = true;
        try {
          if (type === 'actors') {
            const data   = await API.searchActors(lastSearchQuery, 25, searchCursor);
            const actors = data.actors || [];
            searchCursor  = data.cursor || null;
            lastSearchResults = [...(lastSearchResults || []), ...actors];
            renderActorResultsAppend(actors);
          } else {
            const data = await API.searchPosts(lastSearchQuery, lastSearchSort, 25, searchCursor, lastSearchOpts);
            let posts  = data.posts || [];
            searchCursor = data.cursor || null;
            posts = applyMediaFilter(posts);
            lastSearchResults = [...(lastSearchResults || []), ...posts];
            renderPostFeed(posts, searchResults, true);
          }
          if (searchCursor) {
            setupSearchScrollObserver(type);
          } else if (searchScrollObserver) {
            searchScrollObserver.disconnect();
          }
        } catch (err) {
          console.error('Search infinite scroll error:', err.message);
        } finally {
          searchScrollLoading = false;
        }
      },
      { root: viewSearch, rootMargin: '0px 0px 400px 0px', threshold: 0 }
    );
    if (searchSentinel) searchScrollObserver.observe(searchSentinel);
  }

  searchForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const q = searchInput.value.trim();
    if (!q) return;

    showLoading();
    searchResults.innerHTML = '<div class="feed-loading">Searching…</div>';

    try {
      // Detect bsky.app URLs and redirect to the appropriate view instead of searching
      if (q.includes('bsky.app/profile/')) {
        const postPattern    = /bsky\.app\/profile\/[^/\s]+\/post\/[^?&#\s]+/;
        const profilePattern = /bsky\.app\/profile\/([^/\s?&#]+)(?:[/?#]|$)/;
        if (postPattern.test(q)) {
          // Paste of a bsky.app post URL → resolve AT URI and open thread
          const atUri = await API.resolvePostUrl(q);
          const hMatch = q.match(/bsky\.app\/profile\/([^/\s]+)\//);
          await openThread(atUri, '', hMatch?.[1] || '');
          return;
        }
        const pm = q.match(profilePattern);
        if (pm) {
          // Paste of a bsky.app profile URL → open profile view
          await openProfile(pm[1]);
          return;
        }
      }

      // Reset cursor, observer, and media filters on new search
      searchCursor = null;
      if (searchScrollObserver) { searchScrollObserver.disconnect(); searchScrollObserver = null; }
      lastSearchQuery = q;
      document.querySelector('.search-load-more')?.remove();

      if (activeFilter === 'users') {
        const data = await API.searchActors(q);
        lastSearchResults = data.actors || [];
        lastSearchType    = 'actors';
        searchCursor      = data.cursor || null;
        renderActorResults(lastSearchResults);
        if (searchCursor) setupSearchScrollObserver('actors');
      } else {
        const sort = activeFilter === 'latest' ? 'latest' : 'top';
        lastSearchSort = sort;

        // Collect advanced filter values
        const since = advSinceEl.value ? new Date(advSinceEl.value).toISOString() : undefined;
        const until = advUntilEl.value ? new Date(advUntilEl.value).toISOString() : undefined;
        const opts  = {
          author:   advAuthorEl.value.trim()   || undefined,
          mentions: advMentionsEl.value.trim() || undefined,
          lang:     advLangEl.value.trim()     || undefined,
          domain:   advDomainEl.value.trim()   || undefined,
          since,
          until,
        };
        lastSearchOpts = opts;

        const data = await API.searchPosts(q, sort, 25, undefined, opts);
        let posts = data.posts || [];
        searchCursor = data.cursor || null;
        // M49: apply client-side media filter
        posts = applyMediaFilter(posts);
        lastSearchResults = posts;
        lastSearchType    = 'posts';
        renderPostFeed(posts, searchResults);
        if (searchCursor) setupSearchScrollObserver('posts');
      }

      // Show "Save as channel" button above results
      showSaveChannelBtn(q);

      // Update URL so this search is bookmarkable / shareable
      const searchUrl = `?q=${encodeURIComponent(q)}&filter=${encodeURIComponent(activeFilter)}`;
      history.replaceState({ view: 'search', query: q, filter: activeFilter }, '', searchUrl);
    } catch (err) {
      searchResults.innerHTML = `<div class="feed-empty"><p>Search failed: ${escHtml(err.message)}</p></div>`;
    } finally {
      hideLoading();
    }
  });

  function renderActorResults(actors) {
    if (!actors.length) {
      searchResults.innerHTML = '<div class="feed-empty"><p>No users found.</p></div>';
      return;
    }
    searchResults.innerHTML = '';
    actors.forEach((actor) => {
      const card = document.createElement('article');
      card.className = 'post-card';

      const followUri   = actor.viewer?.following || '';
      const isFollowing = !!followUri;
      const isSelf      = ownProfile && actor.did === ownProfile.did;

      // --- Header row: avatar | meta | follow button ---
      const header = document.createElement('div');
      header.className = 'actor-card-header';

      const avatar = document.createElement('img');
      setAvatarSrc(avatar, actor.avatar);
      avatar.alt       = '';
      avatar.className = 'post-avatar';
      avatar.loading   = 'lazy';
      header.appendChild(avatar);

      const meta = document.createElement('div');
      meta.className = 'post-meta';
      const nameEl = document.createElement('div');
      nameEl.className   = 'post-display-name';
      nameEl.textContent = actor.displayName || actor.handle;
      const handleEl = document.createElement('div');
      handleEl.className   = 'post-handle';
      handleEl.textContent = `@${actor.handle}`;
      meta.appendChild(nameEl);
      meta.appendChild(handleEl);
      header.appendChild(meta);

      if (!isSelf) {
        const followBtn = document.createElement('button');
        followBtn.className    = isFollowing ? 'follow-btn following' : 'follow-btn';
        followBtn.textContent  = isFollowing ? 'Following' : 'Follow';
        followBtn.dataset.did       = actor.did;
        followBtn.dataset.followUri = followUri;
        followBtn.setAttribute('aria-label', isFollowing
          ? `Unfollow @${actor.handle}` : `Follow @${actor.handle}`);

        followBtn.addEventListener('click', async (e) => {
          e.stopPropagation();
          const btn        = e.currentTarget;
          const curUri     = btn.dataset.followUri;
          const nowFollow  = btn.classList.contains('following');
          btn.disabled = true;
          try {
            if (nowFollow && curUri) {
              await API.unfollowActor(curUri);
              btn.classList.remove('following');
              btn.textContent       = 'Follow';
              btn.dataset.followUri = '';
              btn.setAttribute('aria-label', `Follow @${actor.handle}`);
            } else {
              const result = await API.followActor(actor.did);
              btn.classList.add('following');
              btn.textContent       = 'Following';
              btn.dataset.followUri = result.uri || '';
              btn.setAttribute('aria-label', `Unfollow @${actor.handle}`);
            }
          } catch (err) {
            console.error('Follow error:', err.message);
          } finally {
            btn.disabled = false;
          }
        });
        header.appendChild(followBtn);
      }

      card.appendChild(header);

      if (actor.description) {
        const bio = document.createElement('p');
        bio.className   = 'post-text';
        bio.textContent = actor.description;
        card.appendChild(bio);
      }

      searchResults.appendChild(card);
    });
  }

  /* ---- M48: Append actor result cards without wiping the container ---- */
  function renderActorResultsAppend(actors) {
    actors.forEach((actor) => {
      const card = document.createElement('article');
      card.className = 'post-card post-card-clickable';
      card.style.cursor = 'default';

      const followUri   = actor.viewer?.following || '';
      const isFollowing = !!followUri;
      const isSelf      = ownProfile && actor.did === ownProfile.did;

      const header = document.createElement('div');
      header.className = 'actor-card-header';

      const av = document.createElement('img');
      setAvatarSrc(av, actor.avatar); av.alt = ''; av.className = 'post-avatar'; av.loading = 'lazy';
      header.appendChild(av);

      const meta = document.createElement('div');
      meta.className = 'post-meta';
      const nameEl = document.createElement('div');
      nameEl.className = 'post-display-name'; nameEl.textContent = actor.displayName || actor.handle;
      const handleEl = document.createElement('div');
      handleEl.className = 'post-handle'; handleEl.textContent = `@${actor.handle}`;
      meta.appendChild(nameEl); meta.appendChild(handleEl);
      header.appendChild(meta);

      if (!isSelf) {
        const followBtn = document.createElement('button');
        followBtn.className = isFollowing ? 'follow-btn following' : 'follow-btn';
        followBtn.textContent = isFollowing ? 'Following' : 'Follow';
        followBtn.dataset.did = actor.did; followBtn.dataset.followUri = followUri;
        followBtn.addEventListener('click', async (e) => {
          e.stopPropagation();
          const btn = e.currentTarget; const curUri = btn.dataset.followUri; const nowFollow = btn.classList.contains('following');
          btn.disabled = true;
          try {
            if (nowFollow && curUri) { await API.unfollowActor(curUri); btn.classList.remove('following'); btn.textContent = 'Follow'; btn.dataset.followUri = ''; }
            else { const r = await API.followActor(actor.did); btn.classList.add('following'); btn.textContent = 'Following'; btn.dataset.followUri = r.uri || ''; }
          } catch (err) { console.error('Follow error:', err.message); }
          finally { btn.disabled = false; }
        });
        header.appendChild(followBtn);
      }
      card.appendChild(header);
      if (actor.description) { const bio = document.createElement('p'); bio.className = 'post-text'; bio.textContent = actor.description; card.appendChild(bio); }
      card.addEventListener('click', () => openProfile(actor.handle));
      searchResults.appendChild(card);
    });
  }

  /* ================================================================
     HOME / FOLLOWING FEED
  ================================================================ */

  function setFeedMode(mode) {
    feedMode = mode;
    const isFollowing = mode === 'following';
    feedTabFollowing.classList.toggle('feed-tab-active', isFollowing);
    feedTabDiscover.classList.toggle('feed-tab-active', !isFollowing);
    feedTabFollowing.setAttribute('aria-selected', isFollowing ? 'true' : 'false');
    feedTabDiscover.setAttribute('aria-selected', isFollowing ? 'false' : 'true');
  }

  async function loadFeed(append = false) {
    // Guard: prevent concurrent append calls. The IntersectionObserver fires immediately
    // when observe() is called on an already-visible sentinel (e.g. after an all-filtered
    // batch adds nothing to the DOM), which would exhaust the Discovery cursor silently.
    if (append && feedLoading) return;

    if (!append) {
      feedCursor         = null;
      feedLoaded         = false;
      feedSeenBypass     = false;    // M40: reset bypass on fresh feed load
      feedDiscoverLooped = false;    // reset loop-back flag on fresh load / tab switch
      feedResults.innerHTML = '<div class="feed-loading">Loading your feed…</div>';
      document.querySelector('.feed-seen-hint')?.remove();
    }

    feedLoading = true;
    showLoading();
    try {
      // When feedCursor is null during an append (e.g. Discovery loop-back), pass undefined
      // so the API fetches the first page again (api.js get() skips null/undefined params).
      const apiCursor = (append && feedCursor) ? feedCursor : undefined;
      const data = feedMode === 'discover'
        ? await API.getFeed(DISCOVER_FEED_URI, 50, apiCursor)
        : await API.getTimeline(50, apiCursor);
      const items  = data.feed || [];
      feedCursor   = data.cursor || null;
      feedLoaded   = true;

      if (!append) feedResults.innerHTML = '';

      // M40: filter out already-seen posts (unless bypass is active)
      let seenCount = 0;
      const displayItems = items.filter((item) => {
        const post = item.post;
        if (!post) return true;
        if (isFeedPostSeen(post.uri)) {
          seenCount++;
          return false;
        }
        return true;
      });

      if (!displayItems.length && !append) {
        const msg = feedMode === 'discover'
          ? 'Nothing to discover right now. Try again in a moment.'
          : 'No posts yet. Follow some people to see their posts here.';
        feedResults.innerHTML = `<div class="feed-empty"><p>${msg}</p></div>`;
      } else {
        renderFeedItems(displayItems, feedResults, append);
      }

      // M44: visual read indicator only — dedup marking happens at render time
      attachFeedSeenObserver(feedResults);

      // M60: update discovery loop state — observer setup is deferred to finally so that
      // feedLoading is guaranteed to be false when the observer first fires. Without this,
      // browsers that deliver the initial IntersectionObserver callback synchronously would
      // hit the feedLoading guard and never re-fire (no intersection change → stuck scroll).
      if (feedCursor && feedDiscoverLooped) {
        feedDiscoverLooped = false; // got a fresh cursor — back to normal pagination
      } else if (!feedCursor && append && feedMode === 'discover' && !feedDiscoverLooped && items.length > 0) {
        feedDiscoverLooped = true;  // cursor exhausted — queue one loop-back to fresh page 1
        feedCursor = null;          // ensure apiCursor resolves to undefined on next call
      }
    } catch (err) {
      if (!append) {
        feedResults.innerHTML = `<div class="feed-empty"><p>Could not load feed: ${escHtml(err.message)}</p></div>`;
      }
    } finally {
      feedLoading = false;
      hideLoading();
      // Set up or tear down the scroll observer AFTER feedLoading is cleared.
      // Doing it here also ensures the observer is restarted after API errors
      // (previously a failed append would leave the observer dead, requiring a PTR).
      const hasMore = feedCursor || (feedMode === 'discover' && feedDiscoverLooped);
      if (hasMore) {
        setupFeedScrollObserver();
      } else if (feedScrollObserver) {
        feedScrollObserver.disconnect();
      }
    }
  }

  /* ---- M44: Scroll-based visual read indicator (IntersectionObserver) ---- */
  // Posts are now marked seen immediately at render time (see renderFeedItems).
  // This observer is responsible only for adding the visual .post-seen dimming
  // style when a card scrolls above the viewport — dedup tracking is decoupled.
  let feedSeenObserver = null;

  function attachFeedSeenObserver(container) {
    if (feedSeenObserver) { feedSeenObserver.disconnect(); feedSeenObserver = null; }

    feedSeenObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting && entry.boundingClientRect.top < 0) {
          const card = entry.target;
          card.classList.add('post-seen');
          feedSeenObserver.unobserve(card);
        }
      });
    }, { root: null, rootMargin: '0px', threshold: 0 });

    container.querySelectorAll('.post-card[data-uri]').forEach((card) => {
      if (!card.classList.contains('post-seen')) feedSeenObserver.observe(card);
    });
  }

  /* ---- Pull-to-refresh on the home feed ---- */
  (() => {
    const PTR_THRESHOLD = 48;  // M65: reduced from 96px — original was too stiff on mobile
    const PTR_HOLD_MS   = 400; // M34: must hold at threshold for 400ms before triggering
    const PTR_HEIGHT    = 52;  // must match CSS height of .ptr-indicator
    let ptrStartY   = 0;
    let ptrDragging = false;
    let ptrActive   = false;   // true while refresh is in progress
    let ptrHoldTimer = null;   // M34: hold timer
    let ptrReadyToRelease = false; // M34: true after hold completes

    viewFeed.addEventListener('touchstart', (e) => {
      if (viewFeed.scrollTop === 0 && !ptrActive) {
        ptrStartY   = e.touches[0].clientY;
        ptrDragging = true;
        ptrReadyToRelease = false;
      }
    }, { passive: true });

    viewFeed.addEventListener('touchmove', (e) => {
      if (!ptrDragging) return;
      const dy = Math.max(0, e.touches[0].clientY - ptrStartY);
      if (dy <= 0) return;

      // Reveal the indicator by shrinking its negative top margin
      const pull = Math.min(dy * 0.5, PTR_HEIGHT); // dampen pull
      ptrIndicator.style.marginTop = `${pull - PTR_HEIGHT}px`;

      if (dy >= PTR_THRESHOLD) {
        // M34: start hold timer if not already counting
        if (!ptrHoldTimer && !ptrReadyToRelease) {
          ptrHoldTimer = setTimeout(() => {
            ptrReadyToRelease = true;
            ptrIndicator.dataset.state = 'release';
          }, PTR_HOLD_MS);
        }
      } else {
        // Below threshold — cancel hold timer
        clearTimeout(ptrHoldTimer);
        ptrHoldTimer = null;
        ptrReadyToRelease = false;
        ptrIndicator.dataset.state = 'pull';
      }
    }, { passive: true });

    viewFeed.addEventListener('touchend', async () => {
      if (!ptrDragging) return;
      ptrDragging = false;
      clearTimeout(ptrHoldTimer);
      ptrHoldTimer = null;

      if (ptrReadyToRelease) {
        ptrReadyToRelease = false;
        ptrActive = true;
        ptrIndicator.style.marginTop = '0px';
        ptrIndicator.dataset.state   = 'loading';
        await loadFeed(false);
        ptrActive = false;
      }

      // Snap back
      ptrIndicator.style.marginTop = '';
      delete ptrIndicator.dataset.state;
    });
  })();

  feedTabFollowing.addEventListener('click', () => {
    setFeedMode('following'); loadFeed(); // no guard: clicking active tab refreshes feed
  });
  feedTabDiscover.addEventListener('click', () => {
    setFeedMode('discover'); loadFeed(); // no guard: clicking active tab refreshes feed
  });

  /* ---- M47: Pull-to-refresh on Search + Profile views ---- */
  (() => {
    const PTR_THRESHOLD = 48; // M65: reduced from 96px
    const PTR_HOLD_MS   = 400;
    const PTR_HEIGHT    = 52;

    function makePTR(scrollEl, triggerFn) {
      let ptrStartY = 0, ptrDragging = false, ptrActive = false, ptrHoldTimer = null, ptrReadyToRelease = false;

      scrollEl.addEventListener('touchstart', (e) => {
        if (scrollEl.scrollTop === 0 && !ptrActive) {
          ptrStartY = e.touches[0].clientY; ptrDragging = true; ptrReadyToRelease = false;
        }
      }, { passive: true });

      scrollEl.addEventListener('touchmove', (e) => {
        if (!ptrDragging) return;
        const dy = Math.max(0, e.touches[0].clientY - ptrStartY);
        if (dy <= 0) return;
        const pull = Math.min(dy * 0.5, PTR_HEIGHT);
        ptrIndicator.style.marginTop = `${pull - PTR_HEIGHT}px`;
        if (dy >= PTR_THRESHOLD) {
          if (!ptrHoldTimer && !ptrReadyToRelease) {
            ptrHoldTimer = setTimeout(() => { ptrReadyToRelease = true; ptrIndicator.dataset.state = 'release'; }, PTR_HOLD_MS);
          }
        } else {
          clearTimeout(ptrHoldTimer); ptrHoldTimer = null; ptrReadyToRelease = false;
          ptrIndicator.dataset.state = 'pull';
        }
      }, { passive: true });

      scrollEl.addEventListener('touchend', async () => {
        if (!ptrDragging) return;
        ptrDragging = false; clearTimeout(ptrHoldTimer); ptrHoldTimer = null;
        if (ptrReadyToRelease) {
          ptrReadyToRelease = false; ptrActive = true;
          ptrIndicator.style.marginTop = '0px'; ptrIndicator.dataset.state = 'loading';
          await triggerFn();
          ptrActive = false;
        }
        ptrIndicator.style.marginTop = ''; delete ptrIndicator.dataset.state;
      });
    }

    // Search view PTR: re-run the last search from scratch
    makePTR(viewSearch, () => {
      const q = searchInput.value.trim();
      if (q) {
        searchCursor = null;
        searchForm.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
      }
    });

    // Profile view PTR: full profile feed refresh
    makePTR(viewProfile, () => {
      if (profileActor) loadProfileFeed(profileActor, false);
    });

    // M57: Gallery view PTR — reload gallery from scratch
    makePTR(viewGallery, () => loadGallery());
  })();

  /* ---- M34: Scroll-to-top button ---- */
  (() => {
    const SCROLL_SHOW_THRESHOLD = 300;
    const ALL_VIEWS = [viewFeed, viewSearch, viewCompose, viewThread, viewProfile, viewNotifications, viewTv, viewGallery, viewAnalytics, viewTimeline]; // M57: added viewGallery; M22/M13: added analytics, timeline

    ALL_VIEWS.forEach((view) => {
      view.addEventListener('scroll', () => {
        if (!view.hidden) {
          scrollToTopBtn.hidden = view.scrollTop < SCROLL_SHOW_THRESHOLD;
        }
      }, { passive: true });
    });

    scrollToTopBtn.addEventListener('click', () => {
      const active = ALL_VIEWS.find((v) => !v.hidden);
      if (active) active.scrollTo({ top: 0, behavior: 'smooth' });
    });
  })();

  /* M60: Infinite scroll for Following/Discover feed */
  let feedScrollObserver   = null;
  let feedLoading          = false; // guard: only one append in flight at a time
  let feedDiscoverLooped   = false; // true after Discovery cursor exhausted once (allows one fresh-start loop)

  function setupFeedScrollObserver() {
    if (feedScrollObserver) feedScrollObserver.disconnect();
    feedScrollObserver = new IntersectionObserver(
      (entries) => {
        // Fire when sentinel is visible AND there are more pages.
        // Also fire when Discovery has looped back (feedDiscoverLooped + null cursor = fresh fetch).
        const hasMore = feedCursor || (feedMode === 'discover' && feedDiscoverLooped);
        if (entries[0]?.isIntersecting && hasMore) loadFeed(true);
      },
      { root: viewFeed, rootMargin: '0px 0px 400px 0px', threshold: 0 }
    );
    if (feedSentinel) feedScrollObserver.observe(feedSentinel);
  }
  notifRefreshBtn.addEventListener('click', () => loadNotifications(false));

  /**
   * Render an array of timeline feed items (post + optional reason/reply context).
   * @param {Array}       items    - feed items from getTimeline
   * @param {HTMLElement} container
   * @param {boolean}     append   - if true, append instead of replacing
   */
  function renderFeedItems(items, container, append = false) {
    if (!append) container.innerHTML = '';

    items.forEach((item) => {
      const post = item.post;
      if (!post || hasAdultContent(post)) return;

      const wrapper = document.createElement('div');
      wrapper.className = 'feed-item';

      // Repost attribution
      if (item.reason?.$type === 'app.bsky.feed.defs#reasonRepost') {
        const by = item.reason.by || {};
        const bar = document.createElement('div');
        bar.className = 'feed-repost-bar';
        bar.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>`;
        // "Reposted by" prefix (plain text)
        bar.appendChild(document.createTextNode('Reposted by\u00a0'));
        // Reposter avatar + name as a clickable button
        const authorBtn = document.createElement('button');
        authorBtn.className = 'repost-author-link';
        authorBtn.setAttribute('aria-label', `View profile of ${by.displayName || by.handle || 'reposter'}`);
        {
          const avatar = document.createElement('img');
          setAvatarSrc(avatar, by.avatar);
          avatar.alt       = '';
          avatar.className = 'feed-repost-avatar';
          authorBtn.appendChild(avatar);
        }
        const nameSpan = document.createElement('span');
        nameSpan.textContent = by.displayName || by.handle || 'someone';
        authorBtn.appendChild(nameSpan);
        authorBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          if (by.handle) openProfile(by.handle);
        });
        bar.appendChild(authorBtn);
        wrapper.appendChild(bar);
      }

      // Reply context — compact parent preview card
      const rootUri = item.reply?.root?.uri || null;
      const rootCid = item.reply?.root?.cid || null;
      if (item.reply?.parent?.author) {
        const preview = buildParentPreview(item.reply.parent, rootUri, rootCid);
        wrapper.appendChild(preview);
      }

      // Root-first navigation: when this post is a reply, clicking opens from the root
      const card = buildPostCard(post, {
        clickable: true,
        openUri: rootUri || post.uri,
        openCid: rootCid || post.cid,
      });

      // M35: override reply button in feed to use inline reply (not navigate to thread)
      const feedRootRef = { uri: rootUri || post.uri, cid: rootCid || post.cid };
      const replyBtnFeed = card.querySelector('.reply-action-btn');
      replyBtnFeed.addEventListener('click', (e) => {
        e.stopPropagation();
        expandInlineReply(card, post, feedRootRef, () => {
          // On success: show "Replied ✓" briefly without navigating
          const countEl = replyBtnFeed.querySelector('.action-count');
          replyBtnFeed.classList.add('replied');
          const prev = replyBtnFeed.getAttribute('aria-label');
          replyBtnFeed.setAttribute('aria-label', 'Replied!');
          if (countEl) countEl.textContent = formatCount(parseFmtCount(countEl.textContent) + 1);
          setTimeout(() => {
            replyBtnFeed.classList.remove('replied');
            replyBtnFeed.setAttribute('aria-label', prev);
          }, 3000);
        });
      }, { capture: true });

      wrapper.appendChild(card);
      container.appendChild(wrapper);

      // Mark seen immediately at render time (unified cross-interface registry).
      // The scroll-based M44 observer is now only responsible for the visual
      // .post-seen dimming style; the dedup tracking happens here.
      markFeedPostSeen(post.uri);
    });

    // M39: re-apply content filters after every feed render
    if (container === feedResults) applyFeedFilters();

    // Persist seen-state synchronously so a hard refresh never loses the batch.
    saveFeedSeen();
  }

  /* ================================================================
     PROFILE VIEW
  ================================================================ */
  /**
   * Open the profile view for a given handle or DID.
   * Fetches the profile, renders the header, then loads their posts.
   * @param {string} actor       - handle or DID
   * @param {object} opts
   * @param {boolean} opts.fromHistory - if true, don't push a new history entry
   */
  async function openProfile(actor, opts = {}) {
    profileActor = actor;
    profileCursor = null;
    profileHeaderEl.innerHTML = '<div class="feed-loading">Loading profile…</div>';
    profileFeedEl.innerHTML   = '';
    showView('profile', true);

    if (!opts.fromHistory) {
      history.pushState({ view: 'profile', actor }, '', `?view=profile&actor=${encodeURIComponent(actor)}`);
    }

    showLoading();
    try {
      const profile = await API.getActorProfile(actor);
      renderProfileHeader(profile);
      await loadProfileFeed(actor, false);
    } catch (err) {
      profileHeaderEl.innerHTML = `<div class="feed-empty"><p>Could not load profile: ${escHtml(err.message)}</p></div>`;
    } finally {
      hideLoading();
    }
  }

  /** Build and insert the profile header card from a profile object. */
  function renderProfileHeader(profile) {
    const isSelf      = ownProfile && profile.did === ownProfile.did;
    const followUri   = profile.viewer?.following || '';
    const isFollowing = !!followUri;

    const el = document.createElement('div');

    // Top row: avatar + identity
    const top = document.createElement('div');
    top.className = 'profile-top';

    const avatar = document.createElement('img');
    setAvatarSrc(avatar, profile.avatar);
    avatar.alt       = '';
    avatar.className = 'profile-avatar-lg';
    top.appendChild(avatar);

    const identity = document.createElement('div');
    identity.className = 'profile-identity';
    identity.innerHTML = `
      <div class="profile-display-name">${escHtml(profile.displayName || profile.handle)}</div>
      <div class="profile-handle">@${escHtml(profile.handle)}</div>
    `;
    top.appendChild(identity);
    el.appendChild(top);

    // Bio
    if (profile.description) {
      const bio = document.createElement('p');
      bio.className   = 'profile-bio';
      bio.textContent = profile.description;
      el.appendChild(bio);
    }

    // Stats
    const stats = document.createElement('div');
    stats.className = 'profile-stats';
    [
      { count: profile.postsCount     ?? 0, label: 'Posts' },
      { count: profile.followsCount   ?? 0, label: 'Following' },
      { count: profile.followersCount ?? 0, label: 'Followers' },
    ].forEach(({ count, label }) => {
      const stat = document.createElement('div');
      stat.className = 'profile-stat';
      stat.innerHTML = `
        <span class="profile-stat-count">${formatCount(count)}</span>
        <span class="profile-stat-label">${label}</span>
      `;
      stats.appendChild(stat);
    });
    el.appendChild(stats);

    // Follow / Unfollow button
    if (!isSelf) {
      const followBtn = document.createElement('button');
      followBtn.className    = isFollowing ? 'follow-btn following' : 'follow-btn';
      followBtn.textContent  = isFollowing ? 'Following' : 'Follow';
      followBtn.dataset.did       = profile.did;
      followBtn.dataset.followUri = followUri;
      followBtn.setAttribute('aria-label', isFollowing
        ? `Unfollow @${profile.handle}` : `Follow @${profile.handle}`);

      followBtn.addEventListener('click', async (e) => {
        const btn       = e.currentTarget;
        const curUri    = btn.dataset.followUri;
        const nowFollow = btn.classList.contains('following');
        btn.disabled = true;
        try {
          if (nowFollow && curUri) {
            await API.unfollowActor(curUri);
            btn.classList.remove('following');
            btn.textContent       = 'Follow';
            btn.dataset.followUri = '';
            btn.setAttribute('aria-label', `Follow @${profile.handle}`);
          } else {
            const result = await API.followActor(profile.did);
            btn.classList.add('following');
            btn.textContent       = 'Following';
            btn.dataset.followUri = result.uri || '';
            btn.setAttribute('aria-label', `Unfollow @${profile.handle}`);
          }
        } catch (err) {
          console.error('Follow error:', err.message);
        } finally {
          btn.disabled = false;
        }
      });
      el.appendChild(followBtn);

      // Report account button
      const reportActorBtn = document.createElement('button');
      reportActorBtn.type      = 'button';
      reportActorBtn.className = 'btn btn-ghost report-actor-btn';
      reportActorBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" aria-hidden="true"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>`;
      reportActorBtn.setAttribute('aria-label', `More options for @${profile.handle}`);
      reportActorBtn.addEventListener('click', () => {
        showPostActionsMenu(reportActorBtn, { uri: '', cid: '' }, profile);
      });
      el.appendChild(reportActorBtn);

      // View Timeline button
      const viewTimelineBtn = document.createElement('button');
      viewTimelineBtn.type = 'button';
      viewTimelineBtn.className = 'report-actor-btn';
      viewTimelineBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14" aria-hidden="true"><line x1="2" y1="12" x2="22" y2="12"/><line x1="6" y1="8" x2="6" y2="16"/><line x1="12" y1="6" x2="12" y2="18"/><line x1="18" y1="8" x2="18" y2="16"/></svg>`;
      viewTimelineBtn.setAttribute('aria-label', `View ${profile.handle} timeline`);
      viewTimelineBtn.addEventListener('click', () => {
        showView('timeline');
        $('timeline-search-input').value = '@' + profile.handle;
        tlQuery = '@' + profile.handle;
        tlDoSearch();
      });
      el.appendChild(viewTimelineBtn);
    }

    profileHeaderEl.innerHTML = '';
    profileHeaderEl.appendChild(el);
  }

  let profileScrollObserver = null;
  let profileScrollLoading  = false;

  function setupProfileScrollObserver() {
    if (profileScrollObserver) profileScrollObserver.disconnect();
    profileScrollObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && profileCursor && !profileScrollLoading) {
          profileScrollLoading = true;
          loadProfileFeed(profileActor, true).finally(() => { profileScrollLoading = false; });
        }
      },
      { root: viewProfile, rootMargin: '0px 0px 400px 0px', threshold: 0 }
    );
    if (profileSentinel) profileScrollObserver.observe(profileSentinel);
  }

  /** Load (or append) posts for the current profile view. */
  async function loadProfileFeed(actor, append = false) {
    if (!append) {
      profileCursor = null;
      profileFeedEl.innerHTML = '<div class="feed-loading">Loading posts…</div>';
      if (profileScrollObserver) profileScrollObserver.disconnect();
    }
    try {
      const data  = await API.getAuthorFeed(actor, 25, append ? profileCursor : undefined);
      const items = data.feed || [];
      profileCursor = data.cursor || null;

      if (!append) profileFeedEl.innerHTML = '';
      if (!items.length && !append) {
        profileFeedEl.innerHTML = '<div class="feed-empty"><p>No posts yet.</p></div>';
      } else {
        renderFeedItems(items, profileFeedEl, append);
      }
      if (profileCursor) {
        setupProfileScrollObserver();
      } else if (profileScrollObserver) {
        profileScrollObserver.disconnect();
      }
    } catch (err) {
      if (!append) {
        profileFeedEl.innerHTML = `<div class="feed-empty"><p>Could not load posts: ${escHtml(err.message)}</p></div>`;
      }
    }
  }

  /* ================================================================
     NOTIFICATIONS VIEW
  ================================================================ */
  let notifScrollObserver = null;
  let notifScrollLoading  = false;

  function setupNotifScrollObserver() {
    if (notifScrollObserver) notifScrollObserver.disconnect();
    notifScrollObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && notifCursor && !notifScrollLoading) {
          notifScrollLoading = true;
          loadNotifications(true).finally(() => { notifScrollLoading = false; });
        }
      },
      { root: viewNotifications, rootMargin: '0px 0px 400px 0px', threshold: 0 }
    );
    if (notifSentinel) notifScrollObserver.observe(notifSentinel);
  }

  async function loadNotifications(append = false) {
    if (!append) {
      notifCursor  = null;
      notifLoaded  = false;
      notifList.innerHTML = '<div class="feed-loading">Loading notifications…</div>';
      if (notifScrollObserver) notifScrollObserver.disconnect();
    }

    showLoading();
    try {
      const data   = await API.listNotifications(50, append ? notifCursor : undefined);
      const notifs = data.notifications || [];
      notifCursor  = data.cursor || null;
      notifLoaded  = true;

      if (!append) notifList.innerHTML = '';

      if (!notifs.length && !append) {
        notifList.innerHTML = '<div class="feed-empty"><p>No notifications yet.</p></div>';
      } else {
        renderNotifications(notifs, notifList, append);
      }

      // Update unread badge — count unread on first load
      if (!append) {
        const unread = notifs.filter((n) => !n.isRead).length;
        if (unread > 0) {
          notifBadge.textContent = unread > 99 ? '99+' : String(unread);
          notifBadge.hidden = false;
        } else {
          notifBadge.hidden = true;
        }
        // Mark as seen
        API.updateSeen().catch(() => {});
      }

      if (notifCursor) {
        setupNotifScrollObserver();
      } else if (notifScrollObserver) {
        notifScrollObserver.disconnect();
      }
    } catch (err) {
      if (!append) {
        notifList.innerHTML = `<div class="feed-empty"><p>Could not load notifications: ${escHtml(err.message)}</p></div>`;
      }
    } finally {
      hideLoading();
    }
  }

  /** Clear the notification badge (called after viewing notifications). */
  function clearNotifBadge() {
    notifBadge.hidden = true;
  }

  /**
   * Render notification items into a container.
   */
  function renderNotifications(notifs, container, append = false) {
    if (!append) container.innerHTML = '';

    const ICONS = {
      like:    `<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>`,
      repost:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>`,
      follow:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`,
      reply:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`,
      mention: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-3.92 7.94"/></svg>`,
      quote:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`,
    };
    const ACTION_TEXT = {
      like:    'liked your post',
      repost:  'reposted your post',
      follow:  'followed you',
      reply:   'replied to your post',
      mention: 'mentioned you',
      quote:   'quoted your post',
    };

    notifs.forEach((notif) => {
      const reason = notif.reason || 'mention';
      const author = notif.author || {};
      const item = document.createElement('div');
      item.className = `notif-item${notif.isRead ? '' : ' notif-unread'}`;

      // Icon
      const icon = document.createElement('div');
      icon.className = `notif-icon notif-icon-${reason}`;
      icon.innerHTML = ICONS[reason] || ICONS.mention;
      item.appendChild(icon);

      // Avatar
      const avatar = document.createElement('img');
      setAvatarSrc(avatar, author.avatar);
      avatar.alt       = '';
      avatar.className = 'notif-avatar';
      avatar.loading   = 'lazy';
      item.appendChild(avatar);

      // Body
      const body = document.createElement('div');
      body.className = 'notif-body';

      const meta = document.createElement('div');
      meta.className = 'notif-meta';

      const authorEl = document.createElement('span');
      authorEl.className   = 'notif-author';
      authorEl.textContent = author.displayName || author.handle || 'Someone';
      meta.appendChild(authorEl);

      const action = document.createElement('span');
      action.className   = 'notif-action';
      action.textContent = ACTION_TEXT[reason] || reason;
      meta.appendChild(action);

      const time = document.createElement('span');
      time.className   = 'notif-time';
      time.textContent = formatTimestamp(notif.indexedAt);
      meta.appendChild(time);

      body.appendChild(meta);

      // Post preview text (for reply/mention/quote/like/repost)
      const postText = notif.record?.text;
      if (postText && reason !== 'follow') {
        const preview = document.createElement('div');
        preview.className   = 'notif-preview';
        preview.textContent = postText;
        body.appendChild(preview);
      }

      item.appendChild(body);

      // Click to open profile for follows; for likes/reposts open the subject post;
      // for replies/mentions/quotes open the notification post itself (M63)
      item.addEventListener('click', () => {
        if (reason === 'follow') {
          openProfile(author.handle);
        } else if ((reason === 'like' || reason === 'repost') && notif.reasonSubject) {
          // reasonSubject is the AT URI of the post that was liked/reposted
          openThread(notif.reasonSubject, '', '');
        } else if (notif.uri) {
          openThread(notif.uri, notif.cid, author.handle);
        }
      });

      container.appendChild(item);
    });
  }

  /* ================================================================
     POST FEED RENDERER
  ================================================================ */
  /**
   * Render an array of post objects into a container element.
   * Each card is clickable to open the thread view.
   */
  function renderPostFeed(posts, container, append = false) {
    if (!append) container.innerHTML = '';
    const filtered = posts.filter((p) => !hasAdultContent(p));
    if (!filtered.length && !append) {
      container.innerHTML = '<div class="feed-empty"><p>No results found.</p></div>';
      return;
    }
    filtered.forEach((post) => {
      const card = buildPostCard(post, { clickable: true });
      container.appendChild(card);
    });
  }

  /* ================================================================
     BSKY DREAMS TV — continuous video feed
  ================================================================ */
  (() => {
    /* ---- DOM refs ---- */
    const tvSetup        = $('tv-setup');
    const tvPlayer       = $('tv-player');
    const tvTopicInput   = $('tv-topic-input');
    const tvSlides       = [$('tv-slide-a'), $('tv-slide-b')];
    const tvVideos       = [$('tv-video'),   $('tv-video-b')];
    const tvAuthorAvatar = $('tv-author-avatar');
    const tvAuthorName   = $('tv-author-name');
    const tvAuthorHandle = $('tv-author-handle');
    const tvPostText     = $('tv-post-text');
    const tvLikeBtn      = $('tv-like-btn');
    const tvLikeCount    = $('tv-like-count');
    const tvRepostBtn    = $('tv-repost-btn');
    const tvRepostCount  = $('tv-repost-count');
    const tvOpenBtn      = $('tv-open-btn');
    const tvMuteBtn      = $('tv-mute-btn');
    const tvPauseBtn     = $('tv-pause-btn');  // M36 pause
    const tvStopBtn      = $('tv-stop-btn');
    const tvOverlayMeta  = $('tv-overlay-meta');
    const tvTopicBadge   = $('tv-topic-badge');
    const tvQueueCount   = $('tv-queue-count');

    /* ---- State ---- */
    let tvQueue    = [];
    let tvIndex    = 0;
    let tvCursor   = null;
    let tvTopic    = '';
    const tvHlsArr   = [null, null];
    let tvSlot       = 0;       // which slide slot is currently visible (0 = a, 1 = b)
    let tvSliding    = false;   // true while a slide transition is in progress
    let tvRunning    = false;
    let tvPaused     = false;    // M36 pause
    let tvCurrent    = null;
    let tvAllowAdult = false;
    let tvHideTimer  = null;
    const tvSeen     = loadSeen();  // URIs of videos already shown — loaded from localStorage

    /* ---- Slot helpers ---- */
    function activeVideo() { return tvVideos[tvSlot]; }
    function nextSlot()    { return 1 - tvSlot; }
    function destroyHls(s) { if (tvHlsArr[s]) { tvHlsArr[s].destroy(); tvHlsArr[s] = null; } }

    /* ---- Build HLS playlist URL from author DID + blob CID ---- */
    function buildPlaylistUrl(did, cid) {
      return `https://video.bsky.app/watch/${encodeURIComponent(did)}/${encodeURIComponent(cid)}/playlist.m3u8`;
    }

    /* ---- Resolve the best available video embed from a post ---- *
     * Handles all four cases seen in the wild:
     *   1. post.embed.$type === 'app.bsky.embed.video#view'   → hydrated view, has .playlist
     *   2. post.embed.$type === 'app.bsky.embed.video'        → record embed, has .cid or .video.ref
     *   3. Same two patterns wrapped in recordWithMedia
     *   4. post.record.embed.$type === 'app.bsky.embed.video' → raw record only (search results)
     */
    function getVideoEmbed(post) {
      const did = post.author?.did || '';

      function resolve(e) {
        if (!e) return null;
        const t = e.$type || '';
        if (t === 'app.bsky.embed.video#view' || t === 'app.bsky.embed.video') {
          // Case A: already has a ready-made playlist URL
          if (e.playlist) return e;
          // Case B: has a CID but no playlist — construct the URL
          const cid = e.cid || e.video?.ref?.$link;
          if (cid && did) return { ...e, playlist: buildPlaylistUrl(did, cid) };
        }
        if (t === 'app.bsky.embed.recordWithMedia#view' || t === 'app.bsky.embed.recordWithMedia') {
          return resolve(e.media);
        }
        return null;
      }

      return resolve(post.embed) || resolve(post.record?.embed);
    }

    function hasVideo(post) { return !!getVideoEmbed(post); }

    /* ---- Deduplicate posts already in the queue ---- */
    function dedup(posts) {
      const seen = new Set(tvQueue.map((p) => p.uri));
      return posts.filter((p) => p.uri && !seen.has(p.uri));
    }

    /* ---- Persistent "seen videos" store ---- */
    const TV_SEEN_KEY = 'bsky_tv_seen';
    const TV_SEEN_MAX = 1000;   // FIFO cap — oldest URI evicted when full

    function loadSeen() {
      try {
        const raw = localStorage.getItem(TV_SEEN_KEY);
        return raw ? new Set(JSON.parse(raw)) : new Set();
      } catch { return new Set(); }
    }

    function saveSeen() {
      try { localStorage.setItem(TV_SEEN_KEY, JSON.stringify([...tvSeen])); } catch {}
    }

    function markSeen(post) {
      const uri = post?.uri || post; // accept post object or bare URI
      if (!uri || tvSeen.has(uri)) return;
      tvSeen.add(uri);
      if (tvSeen.size > TV_SEEN_MAX) tvSeen.delete(tvSeen.values().next().value);
      saveSeen();
      // Also mark in the unified cross-interface registry and persist immediately.
      markFeedPostSeen(uri);
      saveFeedSeen();
    }

    /* ---- Show overlay meta and start auto-hide timer (3 s) ---- */
    function showTvMeta() {
      tvOverlayMeta.classList.remove('tv-meta-hidden');
      clearTimeout(tvHideTimer);
      tvHideTimer = setTimeout(() => {
        tvOverlayMeta.classList.add('tv-meta-hidden');
      }, 3000);
    }

    /* ---- Adult content filter ---- */
    const TV_ADULT_LABELS = new Set(['porn', 'sexual', 'nudity', 'graphic-media', 'gore', 'nsfw', 'adult']);
    function isAdultPost(post) {
      const labels = post.labels || [];
      return labels.some((l) => TV_ADULT_LABELS.has(l.val));
    }

    /* ---- Fetch more video posts ---- */
    async function fetchMore() {
      try {
        let posts = [];

        if (!tvTopic) {
          // No topic: pull from Timeline AND Discover in parallel for more video variety (M36).
          // Both feeds are seeded from the user's account, so content is personalized.
          const [rTimeline, rDiscover] = await Promise.allSettled([
            API.getTimeline(100, tvCursor || undefined),
            API.getFeed(DISCOVER_FEED_URI, 50),
          ]);
          if (rTimeline.status === 'fulfilled') {
            tvCursor = rTimeline.value.cursor || null;
            posts = posts.concat((rTimeline.value.feed || []).map((item) => item.post));
          }
          if (rDiscover.status === 'fulfilled') {
            posts = posts.concat((rDiscover.value.feed || []).map((item) => item.post));
          }
          // Dedup by URI before adding to queue
          const uriSet = new Set();
          posts = posts.filter((p) => p.uri && !uriSet.has(p.uri) && uriSet.add(p.uri));
        } else {
          // Topic mode: run hashtag search (#topic) AND free-text search (topic) in
          // parallel. People who post videos typically tag them explicitly, so the
          // hashtag search surfaces more video content; the text search catches posts
          // that mention the topic without a hashtag. Combining both maximises hits.
          const bare = tvTopic.replace(/^#/, ''); // strip leading # if user typed one
          const [rHash, rText] = await Promise.allSettled([
            API.searchPosts(`#${bare}`, 'latest', 50),                        // hashtag: always fresh
            API.searchPosts(bare,        'latest', 50, tvCursor || undefined), // text: paginated
          ]);
          tvCursor = rText.status === 'fulfilled' ? (rText.value.cursor || null) : tvCursor;
          const hashPosts = rHash.status === 'fulfilled' ? (rHash.value.posts || []) : [];
          const textPosts = rText.status === 'fulfilled' ? (rText.value.posts || []) : [];
          // Hashtag results first — higher topical precision for video content
          const seen = new Set();
          for (const p of [...hashPosts, ...textPosts]) {
            if (p.uri && !seen.has(p.uri)) { seen.add(p.uri); posts.push(p); }
          }
        }

        const found = dedup(posts).filter((p) =>
          hasVideo(p) &&
          (tvAllowAdult || !isAdultPost(p)) &&
          !tvSeen.has(p.uri) &&
          !feedSeenMap.has(p.uri)  // skip posts already seen in feed or gallery
        );
        tvQueue = tvQueue.concat(found);
        updateQueueCount();
      } catch (err) {
        console.warn('TV fetch error:', err.message);
      }
    }

    function updateQueueCount() {
      const remaining = tvQueue.length - tvIndex;
      tvQueueCount.textContent = remaining > 0
        ? `${remaining} video${remaining !== 1 ? 's' : ''} queued` : '';
    }

    /* ---- Load a video into a specific slot ---- */
    function loadVideoInSlot(s, src, thumb) {
      destroyHls(s);
      const vid = tvVideos[s];
      vid.pause();
      vid.removeAttribute('src');
      vid.load();
      vid.muted = activeVideo().muted;  // inherit current mute state
      if (thumb) vid.poster = thumb;

      // M36: Skip GIF URLs (they autoplay as images, not true videos)
      if (/\.gif(\?|$)/i.test(src)) { if (s === tvSlot) advanceToNext(); return; }

      if (typeof Hls !== 'undefined' && Hls.isSupported()) {
        const hls = new Hls({ lowLatencyMode: false, enableWorker: false });
        hls.loadSource(src);
        hls.attachMedia(vid);
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
        vid.play().catch(() => {
          // Autoplay blocked (e.g. browser policy); retry muted so video still plays
          vid.muted = true;
          if (s === tvSlot) syncMuteBtn(); // M58: only update icon for the currently active slot
          vid.play().catch(() => {});
        });
      });
        hls.on(Hls.Events.ERROR, (ev, data) => {
          if (data.fatal) { destroyHls(s); if (s === tvSlot) advanceToNext(); }
        });
        tvHlsArr[s] = hls;
      } else if (vid.canPlayType('application/vnd.apple.mpegurl')) {
        vid.src = src;
        vid.play().catch(() => { vid.muted = true; if (s === tvSlot) syncMuteBtn(); vid.play().catch(() => {}); }) // M58;
      }

      // M36: Short-clip filter — skip videos shorter than 5 seconds
      const onDuration = () => {
        vid.removeEventListener('durationchange', onDuration);
        if (isFinite(vid.duration) && vid.duration < 5) {
          if (s === tvSlot) advanceToNext();
        }
      };
      vid.addEventListener('durationchange', onDuration);
    }

    /* ---- Slide transition: animates current slot out, next slot in ---- */
    function slideTransition(direction, onComplete) {
      const DURATION = 320;
      const ns       = nextSlot();
      const curSlide = tvSlides[tvSlot];
      const nxtSlide = tvSlides[ns];

      // Snap next slide to off-screen with no transition
      nxtSlide.style.transition = 'none';
      nxtSlide.style.transform  = direction === 'up' ? 'translateY(100%)' : 'translateY(-100%)';

      // Force reflow so browser registers the starting position before we animate
      void nxtSlide.offsetHeight;

      // Animate both slides simultaneously
      const t = `transform ${DURATION}ms cubic-bezier(0.25, 0.46, 0.45, 0.94)`;
      curSlide.style.transition = t;
      nxtSlide.style.transition = t;
      curSlide.style.transform  = direction === 'up' ? 'translateY(-100%)' : 'translateY(100%)';
      nxtSlide.style.transform  = 'translateY(0)';

      setTimeout(() => {
        tvSlot = ns;
        tvVideos[1 - ns].pause();  // pause the now-offscreen slot
        tvSliding = false;
        onComplete();
      }, DURATION);
    }

    /* ---- Sync mute-button icon with current video.muted state ---- */
    function syncMuteBtn() {
      const muted = activeVideo().muted;
      tvMuteBtn.setAttribute('aria-label', muted ? 'Unmute' : 'Mute');
      tvMuteBtn.querySelectorAll('.tv-muted-x').forEach((l) => {
        l.style.display = muted ? '' : 'none';
      });
      tvMuteBtn.querySelectorAll('.tv-sound-waves').forEach((l) => {
        l.style.display = muted ? 'none' : '';
      });
    }

    /* ---- Sync pause-button icon with paused state (M36) ---- */
    function syncPauseBtn() {
      tvPauseBtn.setAttribute('aria-label', tvPaused ? 'Play' : 'Pause');
      // Show play triangle or pause bars depending on state
      tvPauseBtn.innerHTML = tvPaused
        ? `<svg viewBox="0 0 24 24" fill="currentColor" stroke="none" width="20" height="20" aria-hidden="true"><polygon points="5 3 19 12 5 21 5 3"/></svg>`
        : `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20" aria-hidden="true"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>`;
    }

    /* ---- Show a post in the overlay ---- */
    function showOverlay(post) {
      tvCurrent = post;
      const author = post.author || {};
      setAvatarSrc(tvAuthorAvatar, author.avatar);
      tvAuthorAvatar.alt             = author.displayName || author.handle || '';
      tvAuthorName.textContent       = author.displayName || author.handle || '';
      tvAuthorHandle.textContent     = `@${author.handle || ''}`;
      tvPostText.textContent         = post.record?.text || '';
      tvLikeBtn.classList.toggle('tv-action-liked', !!post.viewer?.like);
      tvLikeBtn.dataset.uri          = post.uri;
      tvLikeBtn.dataset.cid          = post.cid;
      tvLikeBtn.dataset.likeUri      = post.viewer?.like || '';
      tvLikeCount.textContent        = formatCount(post.likeCount   || 0);
      tvRepostBtn.classList.toggle('tv-action-reposted', !!post.viewer?.repost);
      tvRepostBtn.dataset.uri        = post.uri;
      tvRepostBtn.dataset.cid        = post.cid;
      tvRepostBtn.dataset.repostUri  = post.viewer?.repost || '';
      tvRepostCount.textContent      = formatCount(post.repostCount || 0);
      showTvMeta();
    }

    /* ---- Play video at idx with optional slide direction ('up'|'down'|'none') ---- */
    async function playAt(idx, direction) {
      if (idx < 0) { tvSliding = false; return; }
      if (idx >= tvQueue.length) {
        const before = tvQueue.length;
        await fetchMore();
        if (tvQueue.length === before) {
          tvQueueCount.textContent = tvTopic
            ? `No more videos found for "${tvTopic}".`
            : 'No more videos in your feed right now.';
          tvSliding = false;
          return;
        }
      }
      tvIndex = idx;
      const post  = tvQueue[idx];
      const embed = getVideoEmbed(post);
      if (!embed?.playlist) { tvSliding = false; advanceToNext(); return; }

      markSeen(post); // marks in both tvSeen and unified feedSeenMap
      showOverlay(post);

      if (!direction || direction === 'none') {
        // First load — no animation, load directly into the active slot
        loadVideoInSlot(tvSlot, embed.playlist, embed.thumbnail);
        updateQueueCount();
        if (tvQueue.length - tvIndex < 5) fetchMore();
      } else {
        // Load into the incoming slot, then animate it into view
        loadVideoInSlot(nextSlot(), embed.playlist, embed.thumbnail);
        slideTransition(direction, () => {
          syncMuteBtn(); // sync button with the new active slot's actual mute state
          updateQueueCount();
          if (tvQueue.length - tvIndex < 5) fetchMore();
        });
      }
    }

    function advanceToNext() {
      if (!tvRunning || tvSliding || tvPaused) return;
      tvSliding = true;
      playAt(tvIndex + 1, 'up');
    }

    function goBack() {
      if (!tvRunning || tvSliding || tvIndex === 0) return;
      tvSliding = true;
      playAt(tvIndex - 1, 'down');
    }

    /* ---- Start TV (shared by main button, topic form, and chips) ---- */
    function startTV(topic) {
      tvTopic      = (topic || '').trim();
      tvQueue      = [];
      tvIndex      = 0;
      tvCursor     = null;
      tvSlot       = 0;
      tvSliding    = false;
      tvPaused     = false;
      tvAllowAdult = !$('tv-adult-toggle').checked; // checkbox = "Hide adult" so invert
      tvTopicBadge.textContent = tvTopic || 'All videos';

      // Reset slides: A at 0 (visible), B below screen (ready for next)
      tvSlides[0].style.transition = 'none';
      tvSlides[0].style.transform  = 'translateY(0)';
      tvSlides[1].style.transition = 'none';
      tvSlides[1].style.transform  = 'translateY(100%)';

      tvSetup.hidden  = true;
      tvPlayer.hidden = false;
      tvRunning       = true;

      // Start unmuted — the click that called startTV() IS the user gesture
      tvVideos.forEach((v) => { v.muted = false; });
      syncMuteBtn();
      syncPauseBtn();

      fetchMore().then(() => playAt(0, 'none'));
    }

    /* ---- Public stop function (called from showView) ---- */
    window.tvStop = function () {
      if (!tvRunning) return;
      tvRunning = false;
      tvSliding = false;
      tvPaused  = false;
      clearTimeout(tvHideTimer);
      destroyHls(0);
      destroyHls(1);
      tvVideos.forEach((v) => { v.pause(); v.removeAttribute('src'); v.load(); });
      tvPlayer.hidden = true;
      tvSetup.hidden  = false;
      updateSeenBtn();
      tvQueue   = [];
      tvIndex   = 0;
      tvCursor  = null;
      tvCurrent = null;
    };

    /* ---- "Start Bsky Dreams TV" (no topic) ---- */
    $('tv-start-main-btn').addEventListener('click', () => startTV(''));

    /* ---- Topic form (optional custom topic) ---- */
    $('tv-form').addEventListener('submit', (e) => {
      e.preventDefault();
      startTV(tvTopicInput.value);
    });

    /* ---- Topic chips ---- */
    document.querySelectorAll('.tv-chip').forEach((chip) => {
      chip.addEventListener('click', () => startTV(chip.dataset.topic));
    });

    /* ---- "Clear watch history" button — shown only when history is non-empty ---- */
    function updateSeenBtn() {
      const btn = $('tv-clear-history-btn');
      if (tvSeen.size > 0) {
        btn.textContent = `Clear watch history (${tvSeen.size.toLocaleString()} seen)`;
        btn.hidden = false;
      } else {
        btn.hidden = true;
      }
    }
    updateSeenBtn();  // set initial state on load

    $('tv-clear-history-btn').addEventListener('click', () => {
      // Remove TV-watched URIs from the unified feed seen map so those
      // videos can resurface in the home feed and gallery after clearing history.
      tvSeen.forEach((uri) => feedSeenMap.delete(uri));
      saveFeedSeen();
      tvSeen.clear();
      saveSeen();
      updateSeenBtn();
    });

    // Auto-advance when either slot's video ends
    tvVideos.forEach((v) => v.addEventListener('ended', advanceToNext));

    /* ---- Mute toggle ---- */
    tvMuteBtn.addEventListener('click', () => {
      const muted = !activeVideo().muted;
      tvVideos.forEach((v) => { v.muted = muted; });
      syncMuteBtn();
    });

    /* ---- Pause / Resume toggle (M36) ---- */
    tvPauseBtn.addEventListener('click', () => {
      tvPaused = !tvPaused;
      if (tvPaused) {
        activeVideo().pause();
      } else {
        activeVideo().play().catch(() => {});
      }
      syncPauseBtn();
    });

    /* ---- Stop ---- */
    tvStopBtn.addEventListener('click', () => window.tvStop());

    /* ---- Swipe up → next video (mobile) ---- */
    let tvTouchStartY = 0;
    const tvWrap = $('tv-video-wrap');
    tvWrap.addEventListener('touchstart', (e) => {
      tvTouchStartY = e.touches[0].clientY;
      showTvMeta();
    }, { passive: true });
    tvWrap.addEventListener('touchend', (e) => {
      const dy = e.changedTouches[0].clientY - tvTouchStartY;
      if (dy < -60)      advanceToNext();   // swipe up   → next video
      else if (dy > 60)  goBack();          // swipe down → previous video
    });

    /* ---- Scroll → navigate videos (desktop) ---- */
    tvWrap.addEventListener('wheel', (e) => {
      e.preventDefault();
      if      (e.deltaY > 30)  advanceToNext();   // scroll down → next
      else if (e.deltaY < -30) goBack();           // scroll up   → previous
    }, { passive: false });

    /* ---- M53: Prevent long-press context menu / text-selection during 2× speed hold ---- */
    tvWrap.addEventListener('contextmenu', (e) => e.preventDefault());

    /* ---- 2× speed hold (M36): hold pointer on the video area for fast-forward ---- */
    tvWrap.addEventListener('pointerdown', (e) => {
      if (e.target.closest('button') || e.target.closest('[role="button"]')) return;
      if (!tvPaused) activeVideo().playbackRate = 2;
    });
    const restoreSpeed = () => { activeVideo().playbackRate = 1; };
    tvWrap.addEventListener('pointerup',     restoreSpeed);
    tvWrap.addEventListener('pointercancel', restoreSpeed);

    /* ---- Tap or mouse move → reveal meta overlay ---- */
    tvWrap.addEventListener('click', (e) => {
      if (!e.target.closest('button') && !e.target.closest('[role="button"]')) showTvMeta();
    });
    tvWrap.addEventListener('mousemove', showTvMeta);

    /* ---- Author click → profile ---- */
    $('tv-author').addEventListener('click', (e) => {
      e.stopPropagation();
      if (tvCurrent?.author?.handle) openProfile(tvCurrent.author.handle);
    });
    $('tv-author').addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        if (tvCurrent?.author?.handle) openProfile(tvCurrent.author.handle);
      }
    });

    /* ---- Like (in-view) ---- */
    tvLikeBtn.addEventListener('click', async () => {
      if (!tvCurrent) return;
      const isLiked = tvLikeBtn.classList.contains('tv-action-liked');
      tvLikeBtn.disabled = true;
      try {
        if (isLiked && tvLikeBtn.dataset.likeUri) {
          await API.unlikePost(tvLikeBtn.dataset.likeUri);
          tvLikeBtn.classList.remove('tv-action-liked');
          tvLikeBtn.dataset.likeUri = '';
          tvLikeCount.textContent = formatCount(Math.max(0, (tvCurrent.likeCount || 1) - 1));
        } else {
          const r = await API.likePost(tvLikeBtn.dataset.uri, tvLikeBtn.dataset.cid);
          tvLikeBtn.classList.add('tv-action-liked');
          tvLikeBtn.dataset.likeUri = r.uri || '';
          tvLikeCount.textContent = formatCount((tvCurrent.likeCount || 0) + 1);
        }
      } catch (err) { console.error('TV like error:', err.message); }
      tvLikeBtn.disabled = false;
    });

    /* ---- Repost (in-view) ---- */
    tvRepostBtn.addEventListener('click', async () => {
      if (!tvCurrent) return;
      const isReposted = tvRepostBtn.classList.contains('tv-action-reposted');
      tvRepostBtn.disabled = true;
      try {
        if (isReposted && tvRepostBtn.dataset.repostUri) {
          await API.unrepost(tvRepostBtn.dataset.repostUri);
          tvRepostBtn.classList.remove('tv-action-reposted');
          tvRepostBtn.dataset.repostUri = '';
          tvRepostCount.textContent = formatCount(Math.max(0, (tvCurrent.repostCount || 1) - 1));
        } else {
          const r = await API.repost(tvRepostBtn.dataset.uri, tvRepostBtn.dataset.cid);
          tvRepostBtn.classList.add('tv-action-reposted');
          tvRepostBtn.dataset.repostUri = r.uri || '';
          tvRepostCount.textContent = formatCount((tvCurrent.repostCount || 0) + 1);
        }
      } catch (err) { console.error('TV repost error:', err.message); }
      tvRepostBtn.disabled = false;
    });

    /* ---- Open post ---- */
    tvOpenBtn.addEventListener('click', () => {
      if (!tvCurrent) return;
      openThread(tvCurrent.uri, tvCurrent.cid, tvCurrent.author?.handle || '');
    });
  })();

  /* ================================================================
     M30 — REPOST ACTION SHEET + QUOTE POST MODAL
  ================================================================ */
  function showRepostActionSheet(btn, post) {
    // Dismiss any existing sheet
    document.querySelector('.repost-action-sheet')?.remove();

    const isReposted = btn.classList.contains('reposted');
    const repostUri  = btn.dataset.repostUri;
    const countEl    = btn.querySelector('.action-count');

    const sheet = document.createElement('div');
    sheet.className = 'repost-action-sheet';
    sheet.setAttribute('role', 'menu');

    const repostOpt = document.createElement('button');
    repostOpt.type      = 'button';
    repostOpt.className = 'repost-sheet-item';
    repostOpt.setAttribute('role', 'menuitem');
    repostOpt.innerHTML = isReposted
      ? `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg> Undo repost`
      : `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg> Repost`;

    const quoteOpt = document.createElement('button');
    quoteOpt.type      = 'button';
    quoteOpt.className = 'repost-sheet-item';
    quoteOpt.setAttribute('role', 'menuitem');
    quoteOpt.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg> Quote Post`;

    repostOpt.addEventListener('click', async (e) => {
      e.stopPropagation(); // prevent click bubbling to card's openThread handler
      sheet.remove();
      btn.disabled = true;
      try {
        if (isReposted && repostUri) {
          await API.unrepost(repostUri);
          btn.classList.remove('reposted');
          btn.dataset.repostUri = '';
          countEl.textContent = formatCount(Math.max(0, parseFmtCount(countEl.textContent) - 1));
        } else {
          const result = await API.repost(post.uri, post.cid);
          btn.classList.add('reposted');
          btn.dataset.repostUri = result.uri || '';
          countEl.textContent = formatCount(parseFmtCount(countEl.textContent) + 1);
        }
      } catch (err) { console.error('Repost error:', err.message); }
      btn.disabled = false;
    });

    quoteOpt.addEventListener('click', (e) => {
      e.stopPropagation(); // prevent click bubbling to card's openThread handler
      sheet.remove();
      openQuoteModal(post);
    });

    sheet.appendChild(repostOpt);
    sheet.appendChild(quoteOpt);

    // Position relative to the button's parent actions row
    const actionsRow = btn.closest('.post-actions');
    if (actionsRow) {
      actionsRow.style.position = 'relative';
      actionsRow.appendChild(sheet);
    } else {
      document.body.appendChild(sheet);
    }

    // Dismiss on outside click
    setTimeout(() => document.addEventListener('click', () => sheet.remove(), { once: true }), 0);
  }

  function openQuoteModal(post) {
    quoteModalPostRef = post;
    quoteModalText.value   = '';
    quoteModalCount.textContent = '300';
    quoteModalError.hidden = true;
    quoteModalSubmit.disabled = false;
    quoteModalSubmit.textContent = 'Quote Post';
    // Clear any leftover compose state from a previous quote
    clearQuoteImages();
    clearQuoteVideo();
    clearQuoteLinkPreview();
    clearTimeout(quoteLinkTimer);
    quoteGifPanel.hidden = true;
    quoteSettingsPanel.hidden = true;
    if (quoteReplyGate) quoteReplyGate.value = 'everyone';
    if (quoteQuoteGate) quoteQuoteGate.value = 'everyone';

    // Render quoted post preview
    quoteModalPreview.innerHTML = '';
    const preview = buildQuotedPost({
      uri:    post.uri,
      cid:    post.cid,
      author: post.author,
      value:  post.record,
    });
    // Prevent click navigation inside the modal preview
    preview.style.pointerEvents = 'none';
    quoteModalPreview.appendChild(preview);

    quoteModal.hidden = false;
    quoteModalText.focus();
  }

  /* ---- Quote modal extended compose state ---- */
  const quoteImgBtn        = $('quote-img-btn');
  const quoteImgInput      = $('quote-img-input');
  const quoteImgPreview    = $('quote-images-preview');
  const quoteGifBtn        = $('quote-gif-btn');
  const quoteGifPanel      = $('quote-gif-panel');
  const quoteGifInput      = $('quote-gif-input');
  const quoteGifGrid       = $('quote-gif-grid');
  const quoteGifSearchBtn  = $('quote-gif-search-btn');
  const quoteSettingsBtn   = $('quote-settings-btn');
  const quoteSettingsPanel = $('quote-settings-panel');
  const quoteReplyGate     = $('quote-reply-gate');
  const quoteQuoteGate     = $('quote-quote-gate');
  const quoteLinkWrap      = $('quote-link-preview-wrap');

  let quoteImages    = [];
  let quoteLinkEmbed = null;
  let quoteLinkTimer = null;

  function clearQuoteImages() {
    quoteImages.forEach(({ previewUrl }) => URL.revokeObjectURL(previewUrl));
    quoteImages = [];
    quoteImgPreview.innerHTML = '';
    quoteImgPreview.hidden = true;
    quoteImgBtn.disabled = false;
  }

  function refreshQuotePreview() {
    quoteImgPreview.innerHTML = '';
    quoteImgPreview.hidden = quoteImages.length === 0;
    quoteImgBtn.disabled = quoteImages.length >= 4;
    quoteImages.forEach((entry, idx) => {
      const item = document.createElement('div');
      item.className = 'compose-image-item';
      const thumb = document.createElement('img');
      thumb.src = entry.previewUrl; thumb.alt = ''; thumb.className = 'compose-image-thumb';
      item.appendChild(thumb);
      const removeBtn = document.createElement('button');
      removeBtn.type = 'button'; removeBtn.className = 'compose-image-remove';
      removeBtn.setAttribute('aria-label', 'Remove image'); removeBtn.textContent = '×';
      removeBtn.addEventListener('click', () => {
        URL.revokeObjectURL(entry.previewUrl);
        quoteImages.splice(idx, 1);
        refreshQuotePreview();
      });
      item.appendChild(removeBtn);
      const altInput = document.createElement('textarea');
      altInput.className = 'compose-alt-input'; altInput.placeholder = 'Alt text…';
      altInput.rows = 2; altInput.maxLength = 1000; altInput.value = entry.alt || '';
      altInput.addEventListener('input', () => { entry.alt = altInput.value; });
      item.appendChild(altInput);
      quoteImgPreview.appendChild(item);
    });
  }

  function clearQuoteLinkPreview() {
    quoteLinkEmbed = null;
    quoteLinkWrap.innerHTML = '';
  }

  function renderQuoteLinkPreviewCard(hostname) {
    const { title, description, _thumbUrl } = quoteLinkEmbed;
    quoteLinkWrap.innerHTML = `
      <div class="compose-link-preview">
        ${_thumbUrl ? `<img class="compose-link-preview-thumb" src="${escHtml(_thumbUrl)}" alt="" loading="lazy">` : ''}
        <div class="compose-link-preview-body">
          <input class="compose-link-preview-input compose-link-preview-title"
                 value="${escHtml(title)}" placeholder="Title" maxlength="300" aria-label="Link title">
          <input class="compose-link-preview-input compose-link-preview-desc"
                 value="${escHtml(description)}" placeholder="Description (optional)" maxlength="500" aria-label="Link description">
          <span class="compose-link-preview-host">${escHtml(hostname)}</span>
        </div>
        <button type="button" class="compose-link-preview-dismiss" aria-label="Remove link preview">✕</button>
      </div>
    `;
    quoteLinkWrap.querySelector('.compose-link-preview-title').addEventListener('input', (e) => { quoteLinkEmbed.title = e.target.value; });
    quoteLinkWrap.querySelector('.compose-link-preview-desc').addEventListener('input', (e) => { quoteLinkEmbed.description = e.target.value; });
    quoteLinkWrap.querySelector('.compose-link-preview-dismiss').addEventListener('click', clearQuoteLinkPreview);
  }

  async function fetchQuoteLinkPreview(url) {
    if (quoteLinkEmbed) return;
    try {
      const res  = await fetch(`https://api.allorigins.win/get?url=${encodeURIComponent(url)}`);
      const data = await res.json();
      const html = data.contents || '';
      const doc  = new DOMParser().parseFromString(html, 'text/html');
      const getOg = (name) => doc.querySelector(`meta[property="${name}"], meta[name="${name}"]`)?.getAttribute('content') || '';
      const title    = (getOg('og:title') || getOg('title') || doc.title || url).trim();
      const desc     = (getOg('og:description') || getOg('description') || '').trim();
      const thumb    = getOg('og:image') || getOg('twitter:image') || '';
      const hostname = (() => { try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return url; } })();
      quoteLinkEmbed = { uri: url, title, description: desc, _thumbUrl: thumb };
      renderQuoteLinkPreviewCard(hostname);
    } catch { /* silently ignore */ }
  }

  function quoteSelectGif(gifUrl, thumbUrl, alt) {
    clearQuoteImages();
    clearQuoteVideo();
    quoteLinkEmbed = { uri: gifUrl, title: alt, description: '', _thumbUrl: thumbUrl || null };
    quoteLinkWrap.innerHTML = `
      <div class="compose-link-preview compose-gif-preview">
        <img class="compose-gif-preview-img" src="${escHtml(gifUrl)}" alt="${escHtml(alt)}">
        <button type="button" class="compose-link-preview-dismiss" aria-label="Remove GIF">✕</button>
      </div>
    `;
    quoteLinkWrap.querySelector('.compose-link-preview-dismiss').addEventListener('click', clearQuoteLinkPreview);
    quoteGifPanel.hidden = true;
  }

  // GIF panel toggle
  quoteGifBtn.addEventListener('click', () => {
    const willOpen = quoteGifPanel.hidden;
    quoteGifPanel.hidden = !willOpen;
    quoteSettingsPanel.hidden = true;
    if (willOpen) quoteGifInput.focus();
  });

  // Settings panel toggle
  quoteSettingsBtn.addEventListener('click', () => {
    quoteSettingsPanel.hidden = !quoteSettingsPanel.hidden;
    quoteGifPanel.hidden = true;
  });

  // GIF search for quote modal
  quoteGifSearchBtn.addEventListener('click', () => {
    const q = quoteGifInput.value.trim();
    if (q) searchKlipyGifs(q, quoteGifGrid, quoteSelectGif);
  });
  quoteGifInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); quoteGifSearchBtn.click(); }
  });

  // Image attachment for quote modal
  quoteImgBtn.addEventListener('click', () => {
    if (quoteImages.length >= 4) return;
    quoteImgInput.click();
  });
  quoteImgInput.addEventListener('change', async () => {
    const files = Array.from(quoteImgInput.files || []);
    const available = 4 - quoteImages.length;
    quoteImgInput.value = '';
    quoteImgBtn.disabled = true;
    quoteImgPreview.hidden = false;
    for (const file of files.slice(0, available)) {
      if (!file.type.startsWith('image/')) continue;
      try {
        const resized    = await resizeImageFile(file);
        const previewUrl = URL.createObjectURL(resized);
        quoteImages.push({ file: resized, previewUrl, alt: '' });
        refreshQuotePreview();
      } catch (err) {
        showError(quoteModalError, `Could not process image "${file.name}": ${err.message}`);
      }
    }
    refreshQuotePreview();
  });

  function closeQuoteModal() {
    quoteModal.hidden = true;
    quoteModalPostRef = null;
    clearQuoteImages();
    clearQuoteVideo();
    clearQuoteLinkPreview();
    clearTimeout(quoteLinkTimer);
    quoteGifPanel.hidden = true;
    quoteSettingsPanel.hidden = true;
    if (quoteReplyGate) quoteReplyGate.value = 'everyone';
    if (quoteQuoteGate) quoteQuoteGate.value = 'everyone';
  }

  quoteModalClose.addEventListener('click', closeQuoteModal);
  quoteModalCancel.addEventListener('click', closeQuoteModal);
  quoteModal.addEventListener('click', (e) => { if (e.target === quoteModal) closeQuoteModal(); });

  // M61: attach @mention autocomplete to quote modal textarea
  attachMentionAutocomplete(quoteModalText);

  // Char count + link preview detection for quote textarea
  quoteModalText.addEventListener('input', () => {
    const remaining = 300 - quoteModalText.value.length;
    quoteModalCount.textContent = remaining;
    quoteModalCount.className = 'char-count' +
      (remaining <= 0 ? ' over' : remaining <= 20 ? ' warn' : '');
    clearTimeout(quoteLinkTimer);
    if (quoteLinkEmbed) return;
    const matches = quoteModalText.value.match(/https?:\/\/[^\s]+/g);
    if (!matches) return;
    quoteLinkTimer = setTimeout(() => fetchQuoteLinkPreview(matches[0]), 300);
  });
  quoteModalText.addEventListener('paste', () => {
    if (quoteLinkEmbed) return;
    clearTimeout(quoteLinkTimer);
    quoteLinkTimer = setTimeout(() => {
      const matches = quoteModalText.value.match(/https?:\/\/[^\s]+/g);
      if (matches) fetchQuoteLinkPreview(matches[0]);
    }, 0);
  });

  quoteModalSubmit.addEventListener('click', async () => {
    if (!quoteModalPostRef) return;
    const text = quoteModalText.value.trim();
    if (!text && quoteImages.length === 0 && !quoteVideo) { quoteModalText.focus(); return; }

    quoteModalSubmit.disabled    = true;
    quoteModalSubmit.textContent = 'Posting…';
    quoteModalError.hidden = true;

    try {
      // Upload images if attached
      let uploadedImages = [];
      if (quoteImages.length > 0) {
        quoteModalSubmit.textContent = `Uploading ${quoteImages.length} image${quoteImages.length > 1 ? 's' : ''}…`;
        uploadedImages = await Promise.all(
          quoteImages.map(async ({ file, alt }) => {
            const blob = await API.uploadBlob(file);
            return { blob, alt: alt || '' };
          })
        );
      }

      // M42: upload video if attached (mutually exclusive with images)
      let videoEmbed = null;
      if (quoteVideo && uploadedImages.length === 0) {
        quoteModalSubmit.textContent = 'Uploading video…';
        const altText = $('quote-video-alt')?.value?.trim() || '';
        const videoBlobRef = await API.uploadBlob(quoteVideo.file, quoteVideo.file.type || 'video/mp4');
        videoEmbed = {
          $type: 'app.bsky.embed.video',
          video: videoBlobRef,
          ...(altText ? { alt: altText } : {}),
          ...(quoteVideo.aspectRatio ? { aspectRatio: quoteVideo.aspectRatio } : {}),
        };
        incrementVideoDailyCount();
      }

      // External embed only when no images or video are attached
      const linkEmbed = uploadedImages.length === 0 && !videoEmbed ? quoteLinkEmbed : null;

      // Upload thumbnail for GIF / link previews
      if (linkEmbed?._thumbUrl) {
        try {
          quoteModalSubmit.textContent = 'Uploading preview…';
          const thumbRes  = await fetch(linkEmbed._thumbUrl);
          const thumbBlob = await thumbRes.blob();
          const thumbFile = new File([thumbBlob], 'thumb.jpg', { type: thumbBlob.type || 'image/jpeg' });
          linkEmbed.thumb = await API.uploadBlob(thumbFile);
        } catch { /* non-fatal */ }
      }

      quoteModalSubmit.textContent = 'Posting…';
      const embedRef = { uri: quoteModalPostRef.uri, cid: quoteModalPostRef.cid };
      const result = await API.createPost(text, null, uploadedImages, embedRef, linkEmbed, videoEmbed, buildFacets(text));

      // Apply gate records if non-default
      const replyGateVal = quoteReplyGate?.value || 'everyone';
      const quoteGateVal = quoteQuoteGate?.value || 'everyone';
      if (result.uri && (replyGateVal !== 'everyone' || quoteGateVal === 'nobody')) {
        const session  = AUTH.getSession();
        const postRkey = result.uri.split('/').pop();
        if (replyGateVal !== 'everyone') {
          const allow = replyGateVal === 'mentioned'
            ? [{ $type: 'app.bsky.feed.threadgate#mentionRule' }]
            : [{ $type: 'app.bsky.feed.threadgate#followingRule' }];
          await API.putRecord(session.did, 'app.bsky.feed.threadgate', postRkey, {
            $type: 'app.bsky.feed.threadgate', post: result.uri, allow, createdAt: new Date().toISOString(),
          });
        }
        if (quoteGateVal === 'nobody') {
          await API.putRecord(session.did, 'app.bsky.feed.postgate', postRkey, {
            $type: 'app.bsky.feed.postgate', post: result.uri,
            detachedEmbeddingUris: [], embeddingRules: [{ $type: 'app.bsky.feed.postgate#disableRule' }],
            createdAt: new Date().toISOString(),
          });
        }
      }

      closeQuoteModal();
      // M51: show in-app success banner with link to new post
      if (result?.uri && ownProfile) {
        quoteSuccessBanner.hidden = false;
        let qTimer = setTimeout(() => { quoteSuccessBanner.hidden = true; }, 4000);
        quotePostLink.onclick = (e) => {
          e.preventDefault();
          clearTimeout(qTimer);
          quoteSuccessBanner.hidden = true;
          openThread(result.uri, result.cid || '', ownProfile.handle);
        };
      } else {
        quoteSuccessBanner.hidden = false;
        setTimeout(() => { quoteSuccessBanner.hidden = true; }, 3000);
      }
    } catch (err) {
      showError(quoteModalError, err.message || 'Failed to post quote.');
      quoteModalSubmit.disabled    = false;
      quoteModalSubmit.textContent = 'Quote Post';
    }
  });

  // M51: dismiss quote success banner
  if (quoteSuccessClose) {
    quoteSuccessClose.addEventListener('click', () => { quoteSuccessBanner.hidden = true; });
  }

  /**
   * Build a single post card DOM element.
   * @param {object}  post            - post view object from BlueSky API
   * @param {object}  opts
   * @param {boolean} opts.clickable  - if true, clicking opens thread view
   * @param {boolean} opts.isRoot     - if true, adds thread-root class
   * @param {function} opts.onReply   - callback when reply button clicked
   */
  function buildPostCard(post, opts = {}) {
    const author = post.author || {};
    const record = post.record || {};
    const embed  = post.embed  || {};

    const card = document.createElement('article');
    card.className = 'post-card' +
      (opts.clickable ? ' post-card-clickable' : '') +
      (opts.isRoot    ? ' thread-root' : '');
    card.dataset.uri = post.uri;
    card.dataset.cid = post.cid;

    // Header
    const ts   = record.createdAt ? formatTimestamp(record.createdAt) : '';
    const rkey = (post.uri || '').split('/').pop();
    const bskyUrl = author.handle && rkey
      ? `https://bsky.app/profile/${encodeURIComponent(author.handle)}/post/${encodeURIComponent(rkey)}`
      : '';
    card.innerHTML = `
      <div class="post-header">
        <img src="${escHtml(author.avatar || window._bskyAvatarFallback)}" alt="" class="post-avatar author-link" loading="lazy" title="View @${escHtml(author.handle || '')}" onerror="this.onerror=null;this.src=window._bskyAvatarFallback">
        <div class="post-meta author-link" title="View @${escHtml(author.handle || '')}">
          <div class="post-display-name">${escHtml(author.displayName || author.handle || '')}</div>
          <div class="post-handle">@${escHtml(author.handle || '')}</div>
        </div>
        ${bskyUrl
          ? `<a class="post-timestamp" href="${escHtml(bskyUrl)}" target="_blank" rel="noopener" title="View on Bluesky"><time datetime="${escHtml(record.createdAt || '')}">${ts}</time></a>`
          : `<time class="post-timestamp" datetime="${escHtml(record.createdAt || '')}">${ts}</time>`}
      </div>
      <p class="post-text">${renderPostText(record.text || '', record.facets)}</p>
    `;

    // Clicking the avatar or author name opens the profile view
    if (author.handle) {
      card.querySelectorAll('.author-link').forEach((el) => {
        el.addEventListener('click', (e) => {
          e.stopPropagation();
          openProfile(author.handle);
        });
      });
    }

    // Clicking a @mention span opens that user's profile (M33)
    card.querySelectorAll('[data-mention-did]').forEach((mention) => {
      mention.addEventListener('click', (e) => {
        e.stopPropagation();
        const did = mention.dataset.mentionDid;
        if (did) openProfile(did);
      });
      mention.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          e.stopPropagation();
          const did = mention.dataset.mentionDid;
          if (did) openProfile(did);
        }
      });
    });

    // Embedded media — images, video, external links, and quoted posts
    const embedType = embed.$type;
    if (embedType === 'app.bsky.embed.images#view' && embed.images?.length) {
      card.appendChild(buildImageGrid(embed.images));
    } else if (embedType === 'app.bsky.embed.video#view') {
      card.appendChild(buildVideoEmbed(embed));
    } else if (embedType === 'app.bsky.embed.external#view' && embed.external) {
      // M29: route Tenor/Giphy/GIF URLs to animated <img> instead of link card
      if (isGifExternalEmbed(embed.external)) {
        card.appendChild(buildGifEmbed(embed.external));
      } else {
        const extEl = buildExternalEmbed(embed.external);
        if (extEl) card.appendChild(extEl);
      }
    } else if (embedType === 'app.bsky.embed.record#view') {
      // Pure quote-post (no attached media)
      card.appendChild(buildQuotedPost(embed.record));
    } else if (embedType === 'app.bsky.embed.recordWithMedia#view') {
      // Quoted post with attached media — render media first, then the quoted post
      const media = embed.media || {};
      if (media.$type === 'app.bsky.embed.images#view' && media.images?.length) {
        card.appendChild(buildImageGrid(media.images));
      } else if (media.$type === 'app.bsky.embed.video#view') {
        card.appendChild(buildVideoEmbed(media));
      } else if (media.$type === 'app.bsky.embed.external#view' && media.external) {
        if (isGifExternalEmbed(media.external)) {
          card.appendChild(buildGifEmbed(media.external));
        } else {
          const extEl = buildExternalEmbed(media.external);
          if (extEl) card.appendChild(extEl);
        }
      }
      // embed.record is app.bsky.embed.record#view; its .record is the viewRecord
      if (embed.record?.record) {
        card.appendChild(buildQuotedPost(embed.record.record));
      }
    }

    // Actions row
    const likeCount   = post.likeCount   || 0;
    const repostCount = post.repostCount || 0;
    const replyCount  = post.replyCount  || 0;

    const actions = document.createElement('div');
    actions.className = 'post-actions';
    actions.innerHTML = `
      <button class="action-btn reply-action-btn" aria-label="Reply (${replyCount})">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
        <span class="action-count">${formatCount(replyCount)}</span>
      </button>
      <button class="action-btn repost-action-btn${post.viewer?.repost ? ' reposted' : ''}" aria-label="Repost (${repostCount})" data-uri="${escHtml(post.uri)}" data-cid="${escHtml(post.cid)}" data-repost-uri="${escHtml(post.viewer?.repost || '')}">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
        <span class="action-count">${formatCount(repostCount)}</span>
      </button>
      <button class="action-btn like-action-btn${post.viewer?.like ? ' liked' : ''}" aria-label="Like (${likeCount})" data-uri="${escHtml(post.uri)}" data-cid="${escHtml(post.cid)}" data-like-uri="${escHtml(post.viewer?.like || '')}">
        <svg viewBox="0 0 24 24" fill="${post.viewer?.like ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
        <span class="action-count">${formatCount(likeCount)}</span>
      </button>
    `;
    // Share / copy-link button
    const shareBtn = document.createElement('button');
    shareBtn.type      = 'button';
    shareBtn.className = 'action-btn share-action-btn';
    shareBtn.setAttribute('aria-label', 'Copy link to post');
    shareBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18" aria-hidden="true"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`;
    shareBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      const pageUrl = new URL(window.location.href);
      pageUrl.search = `?view=post&uri=${encodeURIComponent(post.uri)}`;
      navigator.clipboard.writeText(pageUrl.toString()).then(() => {
        shareBtn.setAttribute('aria-label', 'Copied!');
        shareBtn.style.color = 'var(--color-success-text)';
        setTimeout(() => {
          shareBtn.setAttribute('aria-label', 'Copy link to post');
          shareBtn.style.color = '';
        }, 1500);
      }).catch(() => {/* clipboard unavailable — silent */});
    });
    actions.appendChild(shareBtn);

    // Actions menu button (⋯ overflow → report/mute/block)
    const reportBtn = document.createElement('button');
    reportBtn.type      = 'button';
    reportBtn.className = 'action-btn report-action-btn';
    reportBtn.setAttribute('aria-label', 'Post actions');
    reportBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18" aria-hidden="true"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>`;
    reportBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      showPostActionsMenu(reportBtn, post, author);
    });
    actions.appendChild(reportBtn);

    card.appendChild(actions);

    // Wire up click to open thread
    // opts.openUri/openCid allow feed items that are replies to navigate to the root
    const targetUri = opts.openUri || post.uri;
    const targetCid = opts.openCid || post.cid;

    if (opts.clickable) {
      card.addEventListener('click', (e) => {
        // Hashtag links → trigger search instead of following href="#"
        const hashEl = e.target.closest('[data-hashtag]');
        if (hashEl) {
          e.preventDefault();
          e.stopPropagation();
          triggerSearch(`#${hashEl.dataset.hashtag}`);
          return;
        }
        // Regular links, action buttons, and quoted post cards → let them handle their own events
        if (e.target.closest('a') || e.target.closest('button') || e.target.closest('.quoted-post-card')) return;
        openThread(targetUri, targetCid, author.handle);
      });
    }

    // Reply button → open thread (inline reply available once inside)
    actions.querySelector('.reply-action-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      openThread(targetUri, targetCid, author.handle);
    });

    // Like button — optimistic UI update with rollback on error
    actions.querySelector('.like-action-btn').addEventListener('click', async (e) => {
      e.stopPropagation();
      const btn      = e.currentTarget;
      const uri      = btn.dataset.uri;
      const cid      = btn.dataset.cid;
      const likeUri  = btn.dataset.likeUri;
      const countEl  = btn.querySelector('.action-count');
      const svgEl    = btn.querySelector('svg');
      const isLiked  = btn.classList.contains('liked');
      // Snapshot for rollback
      const prevLikeUri = likeUri;
      const prevCount   = countEl.textContent;

      // Optimistic update
      btn.disabled = true;
      if (isLiked) {
        btn.classList.remove('liked');
        btn.dataset.likeUri = '';
        countEl.textContent = formatCount(Math.max(0, parseFmtCount(prevCount) - 1));
        svgEl.setAttribute('fill', 'none');
      } else {
        btn.classList.add('liked');
        countEl.textContent = formatCount(parseFmtCount(prevCount) + 1);
        svgEl.setAttribute('fill', 'currentColor');
      }

      try {
        if (isLiked && likeUri) {
          await API.unlikePost(likeUri);
        } else if (!isLiked) {
          const result = await API.likePost(uri, cid);
          btn.dataset.likeUri = result.uri || '';
        }
      } catch (err) {
        // Roll back optimistic update
        if (isLiked) {
          btn.classList.add('liked');
          svgEl.setAttribute('fill', 'currentColor');
        } else {
          btn.classList.remove('liked');
          svgEl.setAttribute('fill', 'none');
        }
        btn.dataset.likeUri = prevLikeUri;
        countEl.textContent = prevCount;
        console.error('Like error:', err.message);
      } finally {
        btn.disabled = false;
      }
    });

    // Repost button (M30): show action sheet with Repost / Quote Post options
    actions.querySelector('.repost-action-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      const btn = e.currentTarget;
      showRepostActionSheet(btn, post);
    });

    return card;
  }

  /* ================================================================
     IMAGE GRID
  ================================================================ */
  function buildImageGrid(images) {
    const capped = images.slice(0, 4);
    const grid   = document.createElement('div');
    grid.className = `post-images count-${capped.length}`;

    // Build a shared lightbox payload for carousel navigation
    const lightboxPayload = capped.map((img) => ({
      src: img.fullsize || img.thumb || '',
      alt: img.alt || '',
    }));

    capped.forEach((img, idx) => {
      const wrap = document.createElement('div');
      wrap.className = 'post-image-wrap';
      wrap.setAttribute('role', 'button');
      wrap.setAttribute('tabindex', '0');
      wrap.setAttribute('aria-label', img.alt ? `View image: ${img.alt}` : 'View full-size image');

      const el = document.createElement('img');
      el.src     = img.thumb || img.fullsize || '';
      el.alt     = img.alt   || '';
      el.loading = 'lazy';
      wrap.appendChild(el);

      // Alt text displayed below the image
      if (img.alt) {
        const altEl = document.createElement('span');
        altEl.className   = 'post-image-alt';
        altEl.textContent = img.alt;
        wrap.appendChild(altEl);
      }

      // Click/keyboard → open lightbox carousel starting at this image
      wrap.addEventListener('click', (e) => {
        e.stopPropagation();
        openLightbox(lightboxPayload, idx);
      });
      wrap.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          e.stopPropagation();
          openLightbox(lightboxPayload, idx);
        }
      });

      grid.appendChild(wrap);
    });

    return grid;
  }

  /* ================================================================
     VIDEO EMBED
  ================================================================ */
  function buildVideoEmbed(videoEmbed) {
    const wrap = document.createElement('div');
    wrap.className = 'post-video-wrap';
    // Prevent native video control clicks from bubbling to the post card click handler
    wrap.addEventListener('click', (e) => e.stopPropagation());

    const src   = videoEmbed.playlist;
    const thumb = videoEmbed.thumbnail;
    if (!src) return wrap;

    // Show thumbnail + play button; activate real player on click
    const poster = document.createElement('div');
    poster.className = 'post-video-poster';
    poster.setAttribute('role', 'button');
    poster.setAttribute('tabindex', '0');
    poster.setAttribute('aria-label', 'Play video');

    if (thumb) {
      const thumbImg = document.createElement('img');
      thumbImg.src     = thumb;
      thumbImg.alt     = videoEmbed.alt || 'Video thumbnail';
      thumbImg.className = 'post-video-thumb';
      thumbImg.loading = 'lazy';
      poster.appendChild(thumbImg);
    }

    const playBtn = document.createElement('div');
    playBtn.className = 'post-video-play-btn';
    playBtn.setAttribute('aria-hidden', 'true');
    playBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor" width="32" height="32" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>';
    poster.appendChild(playBtn);

    const showFallback = (reason) => {
      const fallback = document.createElement('p');
      fallback.className = 'post-video-fallback';
      const link = document.createElement('a');
      link.href        = src;
      link.target      = '_blank';
      link.rel         = 'noopener noreferrer';
      link.textContent = reason ? `Watch video ↗ (${reason})` : 'Watch video ↗';
      fallback.appendChild(link);
      wrap.appendChild(fallback);
    };

    const activateVideo = () => {
      poster.remove();
      const video = document.createElement('video');
      video.className   = 'post-video';
      video.controls    = true;
      video.playsInline = true;
      video.muted       = true;  // required for autoplay in Chrome/Firefox
      video.autoplay    = true;
      if (thumb) video.poster = thumb;

      if (typeof Hls !== 'undefined' && Hls.isSupported()) {
        const hls = new Hls({ lowLatencyMode: false, enableWorker: false });
        // Append video to DOM before loading — some browsers require it
        wrap.appendChild(video);
        hls.loadSource(src);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, () => video.play().catch(() => {}));
        hls.on(Hls.Events.ERROR, (event, data) => {
          console.warn('HLS error:', data.type, data.details, data.fatal, src);
          if (data.fatal) {
            hls.destroy();
            video.remove();
            // Map HLS error types to readable labels so users can report them
            const typeLabels = {
              networkError: 'network error — possible CORS block',
              mediaError:   'media error — codec unsupported',
              keySystemError: 'DRM error',
              muxError:     'stream format error',
            };
            showFallback(typeLabels[data.type] || data.details || data.type);
          }
        });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        // Safari: native HLS
        video.src = src;
        wrap.appendChild(video);
        video.play().catch(() => {});
      } else {
        showFallback();
      }
    };

    poster.addEventListener('click', (e) => { e.stopPropagation(); activateVideo(); });
    poster.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        e.stopPropagation();
        activateVideo();
      }
    });

    wrap.appendChild(poster);

    if (videoEmbed.alt) {
      const altEl = document.createElement('span');
      altEl.className   = 'post-image-alt';
      altEl.textContent = videoEmbed.alt;
      wrap.appendChild(altEl);
    }

    return wrap;
  }

  /* ================================================================
     GIF EMBED (M29)
  ================================================================ */
  /** Return true if an external embed is an animated GIF from Tenor, Giphy, or Klipy. */
  function isGifExternalEmbed(external) {
    if (!external?.uri) return false;
    try {
      const url  = new URL(external.uri);
      const host = url.hostname;
      if (
        host === 'tenor.com'   || host.endsWith('.tenor.com') ||
        host === 'giphy.com'   || host.endsWith('.giphy.com') ||
        host === 'klipy.com'   || host.endsWith('.klipy.com')
      ) return true;
      // Direct .gif URL from any host
      if (url.pathname.toLowerCase().endsWith('.gif')) return true;
    } catch { /* invalid URL */ }
    return false;
  }

  /** Build an <img> element that plays the GIF directly. */
  function buildGifEmbed(external) {
    const wrap = document.createElement('div');
    wrap.className = 'post-gif-wrap';
    let src = external.uri;
    // Tenor/Klipy media URLs sometimes end in .mp4 — swap to .gif for animated display
    if ((src.includes('tenor.com') || src.includes('klipy.com')) && src.endsWith('.mp4')) {
      src = src.replace(/\.mp4$/, '.gif');
    }
    const img = document.createElement('img');
    img.src       = src;
    img.alt       = external.title || 'GIF';
    img.className = 'post-gif';
    img.loading   = 'lazy';
    wrap.appendChild(img);
    // Add KLIPY watermark for Klipy-sourced GIFs
    try {
      const host = new URL(external.uri).hostname;
      if (host === 'klipy.com' || host.endsWith('.klipy.com')) {
        const wm = document.createElement('img');
        wm.src       = 'assets/klipy-watermark.svg';
        wm.alt       = '';
        wm.className = 'post-gif-watermark';
        wm.setAttribute('aria-hidden', 'true');
        wrap.appendChild(wm);
      }
    } catch { /* invalid URL — skip watermark */ }
    return wrap;
  }

  /* ================================================================
     EXTERNAL LINK EMBED
  ================================================================ */
  function buildExternalEmbed(external) {
    if (!external?.uri) return null;

    const card = document.createElement('a');
    card.className = 'post-external-card';
    card.href      = external.uri;
    card.target    = '_blank';
    card.rel       = 'noopener noreferrer';

    if (external.thumb) {
      const img = document.createElement('img');
      img.src       = external.thumb;
      img.alt       = '';
      img.className = 'post-external-thumb';
      img.loading   = 'lazy';
      card.appendChild(img);
    }

    const info = document.createElement('div');
    info.className = 'post-external-info';

    if (external.title) {
      const title = document.createElement('div');
      title.className   = 'post-external-title';
      title.textContent = external.title;
      info.appendChild(title);
    }

    if (external.description) {
      const desc = document.createElement('div');
      desc.className   = 'post-external-desc';
      desc.textContent = external.description;
      info.appendChild(desc);
    }

    let hostname = '';
    try { hostname = new URL(external.uri).hostname; } catch { /* invalid URL */ }
    if (hostname) {
      const host = document.createElement('div');
      host.className   = 'post-external-hostname';
      host.textContent = hostname;
      info.appendChild(host);
    }

    card.appendChild(info);
    return card;
  }

  /* ================================================================
     PARENT POST PREVIEW (feed reply context)
  ================================================================ */
  /**
   * Build a compact preview of the parent post for a reply in the feed.
   * Clicking opens the thread from the root post.
   * @param {object} parentPost - PostView of the immediate parent
   * @param {string|null} rootUri - AT URI of the thread root (for navigation)
   * @param {string|null} rootCid
   */
  function buildParentPreview(parentPost, rootUri, rootCid) {
    const wrap = document.createElement('div');
    wrap.className = 'feed-parent-preview';

    // "Replying to" label
    const label = document.createElement('div');
    label.className = 'feed-reply-label';
    label.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`;
    const labelText = document.createElement('span');
    labelText.textContent = 'Replying to';
    label.appendChild(labelText);
    wrap.appendChild(label);

    // Parent post compact card
    const card = document.createElement('div');
    card.className = 'feed-parent-card';

    const pAuthor = parentPost.author || {};
    const pText   = parentPost.record?.text || '';

    const header = document.createElement('div');
    header.className = 'feed-parent-header';

    if (pAuthor.avatar) {
      const av = document.createElement('img');
      av.src       = pAuthor.avatar;
      av.alt       = '';
      av.className = 'feed-parent-avatar';
      header.appendChild(av);
    }

    const authorName = document.createElement('span');
    authorName.className   = 'feed-parent-author';
    authorName.textContent = pAuthor.displayName || pAuthor.handle || '';
    header.appendChild(authorName);

    const authorHandle = document.createElement('span');
    authorHandle.className   = 'feed-parent-handle';
    authorHandle.textContent = `@${pAuthor.handle || ''}`;
    header.appendChild(authorHandle);

    card.appendChild(header);

    if (pText) {
      const textEl = document.createElement('p');
      textEl.className   = 'feed-parent-text';
      textEl.textContent = pText;
      card.appendChild(textEl);
    }

    // Click opens thread from root (or parent if no root)
    const navUri = rootUri || parentPost.uri;
    const navCid = rootCid || parentPost.cid;
    card.addEventListener('click', (e) => {
      e.stopPropagation();
      openThread(navUri, navCid, pAuthor.handle);
    });

    wrap.appendChild(card);
    return wrap;
  }

  /* ================================================================
     QUOTED POST CARD
  ================================================================ */
  /**
   * Build a compact embedded card for a quoted post.
   * @param {object} record - app.bsky.embed.record#viewRecord
   */
  function buildQuotedPost(record) {
    const wrap = document.createElement('div');
    wrap.className = 'quoted-post-card';
    wrap.setAttribute('role', 'button');
    wrap.setAttribute('tabindex', '0');

    if (!record || !record.uri) {
      wrap.textContent = '[Quoted post unavailable]';
      wrap.classList.add('quoted-post-unavailable');
      return wrap;
    }

    const author = record.author || {};
    const value  = record.value  || {};

    // Author row: avatar + display name + handle
    const header = document.createElement('div');
    header.className = 'quoted-post-header';

    const avatar = document.createElement('img');
    setAvatarSrc(avatar, author.avatar);
    avatar.alt       = '';
    avatar.className = 'quoted-post-avatar';
    avatar.loading   = 'lazy';
    header.appendChild(avatar);

    const name = document.createElement('span');
    name.className   = 'quoted-post-author';
    name.textContent = author.displayName || author.handle || '';
    header.appendChild(name);

    const handle = document.createElement('span');
    handle.className   = 'quoted-post-handle';
    handle.textContent = `@${author.handle || ''}`;
    header.appendChild(handle);

    wrap.appendChild(header);

    if (value.text) {
      const text = document.createElement('p');
      text.className = 'quoted-post-text';
      text.textContent = value.text;
      wrap.appendChild(text);
    }

    // Click/keyboard → open THAT post's thread (not the outer post)
    const openQuoted = (e) => {
      e.stopPropagation();
      openThread(record.uri, record.cid, author.handle);
    };
    wrap.addEventListener('click', openQuoted);
    wrap.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        openQuoted(e);
      }
    });

    return wrap;
  }

  /* ================================================================
     THREAD VIEW
  ================================================================ */
  async function openThread(uri, cid, handle, opts = {}) {
    showLoading();
    try {
      const data = await API.getPostThread(uri);
      renderThread(data.thread, handle);
      currentThread = {
        rootUri:      uri,
        rootCid:      cid,
        authorHandle: handle,
      };
      // M46: show "← Back to parent thread" breadcrumb when opened via "Continue this thread →"
      const existingCrumb = threadContent.querySelector('.thread-continue-crumb');
      if (existingCrumb) existingCrumb.remove();
      if (opts.fromContinue) {
        const crumb = document.createElement('button');
        crumb.className   = 'btn btn-ghost thread-continue-crumb';
        crumb.textContent = '← Back to parent thread';
        crumb.addEventListener('click', () => history.back());
        threadContent.prepend(crumb);
      }
      // Switch to thread view without adding a second history entry;
      // push the thread state ourselves so Back/Forward knows the URI.
      showView('thread', true);
      if (!opts.fromHistory) {
        const threadUrl = `?view=post&uri=${encodeURIComponent(uri)}&handle=${encodeURIComponent(handle || '')}`;
        history.pushState({ view: 'thread', uri, cid, handle, fromContinue: !!opts.fromContinue }, '', threadUrl);
      }
    } catch (err) {
      threadContent.innerHTML = `<div class="feed-empty"><p>Could not load thread: ${escHtml(err.message)}</p></div>`;
      showView('thread', true);
      if (!opts.fromHistory) {
        const threadUrl = `?view=post&uri=${encodeURIComponent(uri)}&handle=${encodeURIComponent(handle || '')}`;
        history.pushState({ view: 'thread', uri, cid, handle }, '', threadUrl);
      }
    } finally {
      hideLoading();
    }
  }

  /**
   * Recursively render a thread node returned by getPostThread.
   * @param {object}      node        - thread node ({ post, replies, ... })
   * @param {string}      authorHandle
   * @param {HTMLElement} container   - target container
   * @param {boolean}     isRoot
   * @param {number}      depth       - current nesting level (0 = root)
   */
  function renderThread(node, authorHandle, container, isRoot = true, depth = 0) {
    if (!container) {
      container = threadContent;
      container.innerHTML = '';
    }

    if (!node || !node.post) return;

    const card = buildPostCard(node.post, { isRoot });

    // Make reply button open the inline reply compose box under this card
    const replyBtn = card.querySelector('.reply-action-btn');
    replyBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      expandInlineReply(card, node.post);
    }, { capture: true }); // override the existing listener

    container.appendChild(card);

    // Render replies recursively
    if (node.replies && node.replies.length) {
      const replies = node.replies.filter(
        (r) => r.$type !== 'app.bsky.feed.defs#blockedPost' && r.post
      );
      if (!replies.length) return;

      // M46: reduced depth cutoff from 8→5 to prevent horizontal overflow on narrow screens
      if (depth >= 4) {
        const best = replies[0];
        const continueBtn = document.createElement('button');
        continueBtn.className   = 'collapse-toggle continue-thread-btn';
        continueBtn.textContent = 'Continue this thread →';
        continueBtn.addEventListener('click', () => {
          openThread(best.post.uri, best.post.cid, best.post.author.handle, { fromContinue: true });
        });
        container.appendChild(continueBtn);
        return;
      }

      const group = document.createElement('div');
      group.className = 'reply-group';
      group.dataset.depth = depth + 1;

      // Small circle collapse button positioned on the connector line
      const collapseBtn = document.createElement('button');
      collapseBtn.type      = 'button';
      collapseBtn.className = 'reply-collapse-btn';
      collapseBtn.textContent = '−';
      collapseBtn.setAttribute('aria-label', 'Collapse replies');
      collapseBtn.setAttribute('aria-expanded', 'true');

      // Body wrapper — all reply content lives here for easy hide/show
      const body = document.createElement('div');
      body.className = 'reply-group-body';

      // Expand button shown when the group is collapsed
      const expandBtn = document.createElement('button');
      expandBtn.type      = 'button';
      expandBtn.className = 'reply-expand-btn';
      expandBtn.hidden    = true;

      collapseBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const total = body.querySelectorAll('.post-card').length;
        body.hidden         = true;
        collapseBtn.hidden  = true;
        expandBtn.textContent = `↓ ${total} repl${total === 1 ? 'y' : 'ies'}`;
        expandBtn.hidden    = false;
      });

      expandBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        body.hidden        = false;
        collapseBtn.hidden = false;
        expandBtn.hidden   = true;
      });

      group.appendChild(collapseBtn);
      group.appendChild(body);
      group.appendChild(expandBtn);

      // Show up to 5 replies; collapse the rest behind a toggle
      const MAX_VISIBLE = 5;
      replies.slice(0, MAX_VISIBLE).forEach((reply) => {
        renderThread(reply, authorHandle, body, false, depth + 1);
      });

      if (replies.length > MAX_VISIBLE) {
        const remaining = replies.length - MAX_VISIBLE;
        const toggle = document.createElement('button');
        toggle.className   = 'collapse-toggle show-more-replies';
        toggle.textContent = `Show ${remaining} more repl${remaining === 1 ? 'y' : 'ies'}`;
        const revealReplies = () => {
          replies.slice(MAX_VISIBLE).forEach((reply) => {
            renderThread(reply, authorHandle, body, false, depth + 1);
          });
          toggle.remove();
        };
        toggle.addEventListener('click', revealReplies);
        // M50: auto-reveal when the toggle button nears the viewport (200px pre-trigger)
        const showMoreObserver = new IntersectionObserver((entries, obs) => {
          if (entries[0].isIntersecting) { obs.disconnect(); revealReplies(); }
        }, { rootMargin: '0px 0px 200px 0px', threshold: 0 });
        showMoreObserver.observe(toggle);
        body.appendChild(toggle);
      }

      container.appendChild(group);
    }
  }

  /* ================================================================
     REPLY
  ================================================================ */
  function setupReplyArea(parentUri, parentCid, parentHandle) {
    currentThread = currentThread || {};
    currentThread.replyToUri    = parentUri;
    currentThread.replyToCid    = parentCid;
    currentThread.replyToHandle = parentHandle;

    replyToHandle.textContent = `@${parentHandle}`;
    threadReplyArea.hidden    = false;
    replyForm.reset();
    replyCount.textContent = '300';
    hideError(replyError);
  }

  replyText.addEventListener('input', () => {
    updateCharCount(replyText, replyCount);
  });

  replyForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideError(replyError);
    const text = replyText.value.trim();
    if (!text || !currentThread) return;

    const replyRef = {
      root:   { uri: currentThread.rootUri,    cid: currentThread.rootCid },
      parent: { uri: currentThread.replyToUri, cid: currentThread.replyToCid },
    };

    const btn = replyForm.querySelector('button[type="submit"]');
    btn.disabled = true;
    btn.textContent = 'Posting…';

    try {
      await API.createPost(text, replyRef, [], null, null, null, buildFacets(text));
      replyForm.reset();
      replyCount.textContent = '300';
      // Reload thread to show the new reply
      showLoading();
      const data = await API.getPostThread(currentThread.rootUri);
      renderThread(data.thread, currentThread.replyToHandle);
    } catch (err) {
      showError(replyError, err.message || 'Failed to post reply.');
    } finally {
      btn.disabled = false;
      btn.textContent = 'Reply';
      hideLoading();
    }
  });

  /* ================================================================
     M61 — @MENTION AUTOCOMPLETE
  ================================================================ */
  /**
   * Attach @mention autocomplete to any compose textarea.
   *
   * While typing, if the cursor is immediately after "@word", a dropdown of
   * matching Bluesky users is shown.  Selecting one inserts their handle.
   * Escape, blur, or clicking away dismisses the dropdown.
   *
   * @param {HTMLTextAreaElement} textarea - the textarea to augment
   */
  function attachMentionAutocomplete(textarea) {
    let dropdown = null;
    let debounceTimer = null;
    let activeIdx = -1;
    let lastQuery = '';

    function closeDropdown() {
      dropdown?.remove();
      dropdown = null;
      activeIdx = -1;
      lastQuery = '';
    }

    function getActiveMentionQuery() {
      const val  = textarea.value;
      const pos  = textarea.selectionStart;
      // Walk backwards from cursor to find the start of a @word
      let i = pos - 1;
      while (i >= 0 && val[i] !== '@' && val[i] !== ' ' && val[i] !== '\n') i--;
      if (i < 0 || val[i] !== '@') return null;
      // Make sure @ is not inside an existing handle (preceded by a letter)
      if (i > 0 && /\w/.test(val[i - 1])) return null;
      const query = val.slice(i + 1, pos);
      if (!query.length) return null;
      return { query, atStart: i, wordEnd: pos };
    }

    function showDropdown(items, atStart, wordEnd) {
      closeDropdown();
      if (!items.length) return;

      dropdown = document.createElement('div');
      dropdown.className = 'mention-dropdown';

      items.forEach((actor, idx) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'mention-item';
        btn.innerHTML = `
          <img class="mention-avatar" src="${escHtml(actor.avatar || '')}" alt="" loading="lazy">
          <span class="mention-name">${escHtml(actor.displayName || actor.handle || '')}</span>
          <span class="mention-handle">@${escHtml(actor.handle || '')}</span>
        `;
        btn.addEventListener('mousedown', (e) => {
          e.preventDefault(); // don't blur textarea
          insertHandle(actor.handle, atStart, wordEnd);
        });
        dropdown.appendChild(btn);
      });

      // Position below textarea
      const rect = textarea.getBoundingClientRect();
      dropdown.style.top  = `${rect.bottom + window.scrollY + 4}px`;
      dropdown.style.left = `${rect.left  + window.scrollX}px`;
      document.body.appendChild(dropdown);
      setActive(0);
    }

    function setActive(idx) {
      if (!dropdown) return;
      const items = dropdown.querySelectorAll('.mention-item');
      items.forEach((el, i) => el.classList.toggle('mention-item-active', i === idx));
      activeIdx = idx;
    }

    function insertHandle(handle, atStart, wordEnd) {
      const val  = textarea.value;
      const insert = handle + ' ';
      textarea.value = val.slice(0, atStart + 1) + insert + val.slice(wordEnd);
      textarea.selectionStart = textarea.selectionEnd = atStart + 1 + insert.length;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      closeDropdown();
      textarea.focus();
    }

    textarea.addEventListener('input', () => {
      clearTimeout(debounceTimer);
      const match = getActiveMentionQuery();
      if (!match) { closeDropdown(); return; }
      if (match.query === lastQuery) return;
      lastQuery = match.query;
      debounceTimer = setTimeout(async () => {
        try {
          const result = await API.searchActors(match.query, 5);
          const actors = result?.actors || [];
          const fresh = getActiveMentionQuery();
          if (!fresh || fresh.query !== match.query) return; // cursor moved
          showDropdown(actors, fresh.atStart, fresh.wordEnd);
        } catch { /* non-fatal */ }
      }, 300);
    });

    textarea.addEventListener('keydown', (e) => {
      if (!dropdown) return;
      const items = dropdown.querySelectorAll('.mention-item');
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setActive(Math.min(activeIdx + 1, items.length - 1));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setActive(Math.max(activeIdx - 1, 0));
      } else if (e.key === 'Enter' || e.key === 'Tab') {
        if (activeIdx >= 0) {
          e.preventDefault();
          items[activeIdx]?.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
        }
      } else if (e.key === 'Escape') {
        closeDropdown();
      }
    });

    textarea.addEventListener('blur', () => {
      // Small delay so mousedown on dropdown item fires first
      setTimeout(closeDropdown, 150);
    });
  }

  /* ================================================================
     INLINE REPLY COMPOSE (M9)
  ================================================================ */
  /**
   * Expand an inline reply compose box directly after `postCard`.
   * Calling again on the same card toggles it closed.
   *
   * @param {HTMLElement} postCard  - the post card element to reply to
   * @param {object}      post      - the AT Protocol PostView being replied to
   */
  function expandInlineReply(postCard, post, feedRootRef = null, onSuccess = null) {
    // Close any existing inline reply box
    const existing = document.querySelector('.inline-reply-box');
    if (existing) {
      const samePost = existing.dataset.replyTo === post.uri;
      existing.remove();
      if (samePost) return; // toggle closed if same card clicked again
    }

    // Determine root: explicit feedRootRef (feed context) or currentThread (thread context)
    const effectiveRoot = feedRootRef || {
      uri: currentThread?.rootUri || post.uri,
      cid: currentThread?.rootCid || post.cid,
    };

    const author = post.author || {};
    const record = post.record || {};
    const text   = record.text || '';

    // ---- Per-instance compose state ----
    let replyImages      = [];   // [{ file, previewUrl, altText }]
    let replyGifEmbed    = null; // { uri, title, description, _thumbUrl }
    let replyLinkEmbed   = null; // { uri, title, description, _thumbUrl } — link preview card
    let replyLinkTimer   = null;
    let replyVideo       = null; // { file, objectUrl, duration, altText }

    const box = document.createElement('div');
    box.className     = 'inline-reply-box';
    box.dataset.replyTo = post.uri;

    // ---- Mini quote of the parent post ----
    const quoteEl = document.createElement('div');
    quoteEl.className = 'inline-reply-quote';
    const quoteAv = document.createElement('img');
    quoteAv.src = author.avatar || '';
    quoteAv.alt = '';
    quoteAv.className = 'inline-reply-quote-avatar';
    quoteEl.appendChild(quoteAv);
    const quoteContent = document.createElement('div');
    quoteContent.className = 'inline-reply-quote-content';
    const quoteAuthor = document.createElement('span');
    quoteAuthor.className   = 'inline-reply-quote-author';
    quoteAuthor.textContent = `@${author.handle || ''}`;
    const quoteSnippet = text.length > 120 ? text.slice(0, 120) + '…' : text;
    quoteContent.appendChild(quoteAuthor);
    quoteContent.appendChild(document.createTextNode(' · ' + quoteSnippet));
    quoteEl.appendChild(quoteContent);
    box.appendChild(quoteEl);

    // ---- Compose row ----
    const composeEl = document.createElement('div');
    composeEl.className = 'inline-reply-compose';
    const myAv = document.createElement('img');
    myAv.src = ownProfile?.avatar || '';
    myAv.alt = '';
    myAv.className = 'inline-reply-user-avatar';
    composeEl.appendChild(myAv);

    const body = document.createElement('div');
    body.className = 'inline-reply-body';

    // Textarea
    const textarea = document.createElement('textarea');
    textarea.className   = 'compose-textarea inline-reply-textarea';
    textarea.placeholder = `Reply to @${author.handle || ''}…`;
    textarea.maxLength   = 300;
    textarea.rows        = 3;
    textarea.setAttribute('aria-label', 'Reply text');
    textarea.setAttribute('autocorrect', 'on');
    textarea.setAttribute('autocapitalize', 'sentences');
    textarea.setAttribute('spellcheck', 'true');
    attachMentionAutocomplete(textarea);
    body.appendChild(textarea);

    // Image preview area
    const imgPreviewEl = document.createElement('div');
    imgPreviewEl.className = 'compose-images-preview';
    imgPreviewEl.hidden = true;
    body.appendChild(imgPreviewEl);

    // Video preview area
    const videoPreviewEl = document.createElement('div');
    videoPreviewEl.className = 'compose-video-preview';
    videoPreviewEl.hidden = true;
    videoPreviewEl.innerHTML = `
      <div class="compose-video-preview-inner">
        <video class="compose-video-player" muted playsinline preload="metadata"></video>
        <button type="button" class="compose-video-remove-btn" aria-label="Remove video">✕</button>
      </div>
      <div class="compose-video-meta">
        <span class="compose-video-name"></span>
        <span class="compose-video-dur"></span>
      </div>
      <input type="text" class="compose-alt-input" placeholder="Video alt text (optional)">`;
    body.appendChild(videoPreviewEl);
    const videoPlayer  = videoPreviewEl.querySelector('.compose-video-player');
    const videoRemove  = videoPreviewEl.querySelector('.compose-video-remove-btn');
    const videoNameEl  = videoPreviewEl.querySelector('.compose-video-name');
    const videoDurEl   = videoPreviewEl.querySelector('.compose-video-dur');
    const videoAltEl   = videoPreviewEl.querySelector('.compose-alt-input');

    // GIF preview area
    const gifPreviewEl = document.createElement('div');
    gifPreviewEl.className = 'inline-reply-gif-preview';
    gifPreviewEl.hidden = true;
    body.appendChild(gifPreviewEl);

    // Link preview card area
    const linkPreviewEl = document.createElement('div');
    linkPreviewEl.className = 'compose-link-preview-wrap';
    body.appendChild(linkPreviewEl);

    // GIF picker panel
    const gifPanel = document.createElement('div');
    gifPanel.className = 'compose-gif-panel';
    gifPanel.hidden    = true;
    gifPanel.innerHTML = `
      <div class="compose-gif-search-row">
        <input type="search" class="compose-gif-input" placeholder="Search KLIPY…" autocomplete="off" spellcheck="false">
        <button type="button" class="btn btn-ghost">Search</button>
        <a href="https://klipy.com" target="_blank" rel="noopener noreferrer" class="klipy-attribution" aria-label="Powered by KLIPY">
          <img src="assets/klipy-powered-by.svg" alt="Powered by KLIPY" class="klipy-attribution-logo">
        </a>
      </div>
      <div class="compose-gif-grid"><p class="compose-gif-empty">Type above to search for GIFs</p></div>`;
    // gifPanel is NOT appended to body here — it gets appended directly to box
    // after composeEl so it spans the full reply box width (including avatar column)
    const gifInput     = gifPanel.querySelector('.compose-gif-input');
    const gifSearchBtn = gifPanel.querySelector('.btn');
    const gifGrid      = gifPanel.querySelector('.compose-gif-grid');

    // ---- Toolbar row (image / video / GIF buttons) ----
    const toolbarEl = document.createElement('div');
    toolbarEl.className = 'inline-reply-toolbar-row';

    // Hidden file inputs
    const imgFileInput = document.createElement('input');
    imgFileInput.type     = 'file';
    imgFileInput.accept   = 'image/jpeg,image/png,image/webp,image/gif';
    imgFileInput.multiple = true;
    imgFileInput.hidden   = true;
    imgFileInput.setAttribute('aria-hidden', 'true');

    const videoFileInput = document.createElement('input');
    videoFileInput.type   = 'file';
    videoFileInput.accept = 'video/mp4,video/webm,video/quicktime';
    videoFileInput.hidden = true;
    videoFileInput.setAttribute('aria-hidden', 'true');

    const imgBtn = document.createElement('button');
    imgBtn.type      = 'button';
    imgBtn.className = 'compose-attach-btn';
    imgBtn.title     = 'Attach images (up to 4)';
    imgBtn.setAttribute('aria-label', 'Attach images');
    imgBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>`;

    const videoBtn = document.createElement('button');
    videoBtn.type      = 'button';
    videoBtn.className = 'compose-attach-btn';
    videoBtn.title     = 'Attach video (MP4/WebM, max 3 min, 50 MB)';
    videoBtn.setAttribute('aria-label', 'Attach video');
    videoBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18" aria-hidden="true"><rect x="2" y="7" width="15" height="10" rx="2" ry="2"/><polygon points="22 7 16 12 22 17 22 7"/></svg>`;

    const gifBtn = document.createElement('button');
    gifBtn.type      = 'button';
    gifBtn.className = 'compose-attach-btn';
    gifBtn.title     = 'Search GIFs';
    gifBtn.setAttribute('aria-label', 'Add GIF');
    gifBtn.innerHTML = `<span style="font-size:0.8rem;font-weight:700;letter-spacing:-0.5px">GIF</span>`;

    toolbarEl.appendChild(imgFileInput);
    toolbarEl.appendChild(videoFileInput);
    toolbarEl.appendChild(imgBtn);
    toolbarEl.appendChild(videoBtn);
    toolbarEl.appendChild(gifBtn);
    body.appendChild(toolbarEl);

    // ---- Footer row (char count + cancel + reply) ----
    const footer = document.createElement('div');
    footer.className = 'inline-reply-footer';

    const countSpan = document.createElement('span');
    countSpan.className   = 'char-count';
    countSpan.textContent = '300';

    const errorEl = document.createElement('div');
    errorEl.className = 'inline-reply-error';
    errorEl.hidden    = true;
    errorEl.setAttribute('role', 'alert');

    const cancelBtn = document.createElement('button');
    cancelBtn.type        = 'button';
    cancelBtn.className   = 'btn btn-ghost';
    cancelBtn.textContent = 'Cancel';

    const submitBtn = document.createElement('button');
    submitBtn.type        = 'button';
    submitBtn.className   = 'btn btn-primary';
    submitBtn.textContent = 'Reply';

    footer.appendChild(errorEl);
    footer.appendChild(countSpan);
    footer.appendChild(cancelBtn);
    footer.appendChild(submitBtn);
    body.appendChild(footer);

    composeEl.appendChild(body);
    box.appendChild(composeEl);
    box.appendChild(gifPanel); // full-width — spans under avatar column

    // Insert inline after the post card
    postCard.insertAdjacentElement('afterend', box);
    box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    textarea.focus();

    // ---- Helpers ----

    function refreshImgPreview() {
      imgPreviewEl.innerHTML = '';
      imgPreviewEl.hidden    = replyImages.length === 0;
      imgBtn.disabled        = replyImages.length >= 4;
      replyImages.forEach((entry, idx) => {
        const item = document.createElement('div');
        item.className = 'compose-image-item';
        const thumb = document.createElement('img');
        thumb.src = entry.previewUrl; thumb.alt = ''; thumb.className = 'compose-image-thumb';
        item.appendChild(thumb);
        const removeBtn = document.createElement('button');
        removeBtn.type = 'button'; removeBtn.className = 'compose-image-remove';
        removeBtn.setAttribute('aria-label', 'Remove image'); removeBtn.textContent = '×';
        removeBtn.addEventListener('click', () => {
          URL.revokeObjectURL(entry.previewUrl);
          replyImages.splice(idx, 1);
          refreshImgPreview();
        });
        item.appendChild(removeBtn);
        const altInput = document.createElement('input');
        altInput.type = 'text'; altInput.className = 'compose-alt-input';
        altInput.placeholder = 'Alt text (optional)'; altInput.value = entry.altText || '';
        altInput.addEventListener('input', () => { entry.altText = altInput.value; });
        item.appendChild(altInput);
        imgPreviewEl.appendChild(item);
      });
    }

    function clearReplyVideo() {
      if (replyVideo?.objectUrl) URL.revokeObjectURL(replyVideo.objectUrl);
      replyVideo = null;
      videoPreviewEl.hidden = true;
      videoPlayer.pause(); videoPlayer.src = '';
      videoBtn.disabled = false;
    }

    function clearGifEmbed() {
      replyGifEmbed = null;
      gifPreviewEl.innerHTML = ''; gifPreviewEl.hidden = true;
    }

    function clearReplyLinkPreview() {
      replyLinkEmbed = null;
      clearTimeout(replyLinkTimer);
      linkPreviewEl.innerHTML = '';
    }

    function renderReplyLinkPreviewCard(hostname) {
      const { title, description, _thumbUrl } = replyLinkEmbed;
      linkPreviewEl.innerHTML = `
        <div class="compose-link-preview">
          ${_thumbUrl ? `
            <div style="position:relative;">
              <img class="compose-link-preview-thumb" src="${escHtml(_thumbUrl)}" alt="" loading="lazy">
              <button type="button" class="compose-link-preview-change-thumb" title="Change thumbnail"
                      style="position:absolute;bottom:6px;right:6px;background:rgba(0,0,0,0.5);color:#fff;border:none;border-radius:4px;font-size:11px;padding:2px 6px;cursor:pointer;">
                Change
              </button>
            </div>` : `
            <button type="button" class="compose-link-preview-change-thumb" title="Set thumbnail"
                    style="display:block;width:100%;padding:8px;background:none;border:none;color:var(--color-accent);font-size:0.8rem;cursor:pointer;text-align:left;">
              + Set thumbnail image
            </button>`}
          <div class="compose-link-preview-body">
            <input class="compose-link-preview-input compose-link-preview-title"
                   value="${escHtml(title)}" placeholder="Title" maxlength="300" aria-label="Link title">
            <input class="compose-link-preview-input compose-link-preview-desc"
                   value="${escHtml(description)}" placeholder="Description (optional)" maxlength="500" aria-label="Link description">
            <span class="compose-link-preview-host">${escHtml(hostname)}</span>
          </div>
          <button type="button" class="compose-link-preview-dismiss" aria-label="Remove link preview">✕</button>
        </div>
      `;
      linkPreviewEl.querySelector('.compose-link-preview-title').addEventListener('input', (e) => { replyLinkEmbed.title = e.target.value; });
      linkPreviewEl.querySelector('.compose-link-preview-desc').addEventListener('input', (e) => { replyLinkEmbed.description = e.target.value; });
      linkPreviewEl.querySelector('.compose-link-preview-dismiss').addEventListener('click', clearReplyLinkPreview);
      linkPreviewEl.querySelector('.compose-link-preview-change-thumb')?.addEventListener('click', () => {
        const newUrl = prompt('Enter image URL for thumbnail:', replyLinkEmbed._thumbUrl || '');
        if (newUrl !== null) { replyLinkEmbed._thumbUrl = newUrl.trim() || null; renderReplyLinkPreviewCard(hostname); }
      });
    }

    async function fetchReplyLinkPreview(url) {
      if (replyLinkEmbed || replyGifEmbed) return;
      try {
        const res  = await fetch(`https://api.allorigins.win/get?url=${encodeURIComponent(url)}`);
        const data = await res.json();
        if (!data.contents) return;
        const doc    = new DOMParser().parseFromString(data.contents, 'text/html');
        const getOg  = (name) => doc.querySelector(`meta[property="${name}"], meta[name="${name}"]`)?.getAttribute('content') || '';
        const title    = (getOg('og:title') || doc.title || '').trim();
        const desc     = (getOg('og:description') || getOg('description') || '').trim();
        const thumb    = getOg('og:image') || getOg('twitter:image') || '';
        const hostname = (() => { try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return url; } })();
        replyLinkEmbed = { uri: url, title, description: desc, _thumbUrl: thumb };
        renderReplyLinkPreviewCard(hostname);
      } catch { /* silently ignore */ }
    }

    function selectGifEmbed(gifUrl, thumbUrl, alt) {
      replyImages.forEach((img) => { try { URL.revokeObjectURL(img.previewUrl); } catch {} });
      replyImages = [];
      refreshImgPreview();
      clearReplyVideo();
      clearReplyLinkPreview();
      replyGifEmbed = { uri: gifUrl, title: alt, description: '', _thumbUrl: thumbUrl || null };
      gifPanel.hidden = true;
      gifPreviewEl.innerHTML = `
        <div class="compose-link-preview compose-gif-preview">
          <img class="compose-gif-preview-img" src="${escHtml(gifUrl)}" alt="${escHtml(alt)}">
          <button type="button" class="compose-link-preview-dismiss" aria-label="Remove GIF">✕</button>
        </div>`;
      gifPreviewEl.hidden = false;
      gifPreviewEl.querySelector('.compose-link-preview-dismiss').addEventListener('click', clearGifEmbed);
    }

    // ---- Event handlers ----

    textarea.addEventListener('input', () => {
      const rem = 300 - textarea.value.length;
      countSpan.textContent = rem;
      countSpan.style.color = rem < 20 ? 'var(--color-error-text)' : '';
      clearTimeout(replyLinkTimer);
      if (replyLinkEmbed || replyGifEmbed) return;
      const matches = textarea.value.match(/https?:\/\/[^\s]+/g);
      if (!matches) return;
      replyLinkTimer = setTimeout(() => fetchReplyLinkPreview(matches[0]), 300);
    });
    textarea.addEventListener('paste', () => {
      if (replyLinkEmbed || replyGifEmbed) return;
      clearTimeout(replyLinkTimer);
      replyLinkTimer = setTimeout(() => {
        const matches = textarea.value.match(/https?:\/\/[^\s]+/g);
        if (matches) fetchReplyLinkPreview(matches[0]);
      }, 0);
    });

    imgBtn.addEventListener('click', () => {
      if (replyImages.length >= 4 || replyGifEmbed || replyVideo) return;
      imgFileInput.value = ''; imgFileInput.click();
    });

    imgFileInput.addEventListener('change', async () => {
      const files = [...(imgFileInput.files || [])].slice(0, 4 - replyImages.length);
      imgFileInput.value = '';
      for (const file of files) {
        if (replyImages.length >= 4) break;
        if (!file.type.startsWith('image/')) continue;
        let processed = file;
        if (file.size > 950_000) { try { processed = await resizeImageFile(file); } catch { continue; } }
        replyImages.push({ file: processed, previewUrl: URL.createObjectURL(processed), altText: '' });
        clearGifEmbed();
      }
      refreshImgPreview();
    });

    videoBtn.addEventListener('click', () => {
      if (replyVideo) return;
      videoFileInput.value = ''; videoFileInput.click();
    });

    videoFileInput.addEventListener('change', async () => {
      const file = videoFileInput.files?.[0];
      videoFileInput.value = '';
      if (!file) return;
      const { video, error } = await validateAndLoadVideo(file);
      if (error) { errorEl.textContent = error; errorEl.hidden = false; return; }
      replyImages.forEach((img) => { try { URL.revokeObjectURL(img.previewUrl); } catch {} });
      replyImages = []; refreshImgPreview();
      clearGifEmbed();
      replyVideo = video;
      videoPlayer.src = video.objectUrl; videoPlayer.load();
      if (videoNameEl) videoNameEl.textContent = file.name;
      if (videoDurEl)  videoDurEl.textContent  = video.duration != null ? `${Math.round(video.duration)}s` : '';
      videoPreviewEl.hidden = false;
      videoBtn.disabled = true;
      imgBtn.disabled   = true;
    });

    videoRemove.addEventListener('click', () => {
      clearReplyVideo();
      imgBtn.disabled = false;
    });

    gifBtn.addEventListener('click', () => {
      gifPanel.hidden = !gifPanel.hidden;
      if (!gifPanel.hidden) gifInput.focus();
    });
    gifSearchBtn.addEventListener('click', () => {
      const q = gifInput.value.trim();
      if (q) searchKlipyGifs(q, gifGrid, selectGifEmbed);
    });
    gifInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); gifSearchBtn.click(); }
    });

    function cleanup() {
      replyImages.forEach((img) => { try { URL.revokeObjectURL(img.previewUrl); } catch {} });
      if (replyVideo?.objectUrl) URL.revokeObjectURL(replyVideo.objectUrl);
      clearTimeout(replyLinkTimer);
    }

    cancelBtn.addEventListener('click', () => { cleanup(); box.remove(); });
    box.addEventListener('keydown', (e) => { if (e.key === 'Escape') { cleanup(); box.remove(); } });

    submitBtn.addEventListener('click', async () => {
      const replyText = textarea.value.trim();
      if (!replyText && replyImages.length === 0 && !replyGifEmbed && !replyVideo) return;

      errorEl.hidden        = true;
      submitBtn.disabled    = true;
      submitBtn.textContent = 'Posting…';

      const replyRef = {
        root:   { uri: effectiveRoot.uri, cid: effectiveRoot.cid },
        parent: { uri: post.uri,          cid: post.cid },
      };

      try {
        let uploadedImages = [];
        if (replyImages.length > 0) {
          uploadedImages = await Promise.all(
            replyImages.map(async (img) => ({ blob: await API.uploadBlob(img.file), alt: img.altText || '' }))
          );
        }

        let videoEmbed = null;
        if (replyVideo) {
          const videoBlobRef = await API.uploadBlob(replyVideo.file, replyVideo.file.type || 'video/mp4');
          videoEmbed = {
            $type: 'app.bsky.embed.video',
            video: videoBlobRef,
            alt:   videoAltEl?.value.trim() || '',
          };
          if (replyVideo.duration)    videoEmbed.video.duration = replyVideo.duration;
          if (replyVideo.aspectRatio) videoEmbed.aspectRatio    = replyVideo.aspectRatio;
        }

        // Use GIF embed or link preview card as the external embed (mutually exclusive)
        let externalEmbed = null;
        const embedSource = replyGifEmbed || (uploadedImages.length === 0 && !videoEmbed ? replyLinkEmbed : null);
        if (embedSource) {
          externalEmbed = { ...embedSource };
          if (externalEmbed._thumbUrl) {
            try {
              const thumbRes  = await fetch(externalEmbed._thumbUrl);
              const thumbBlob = await thumbRes.blob();
              const thumbFile = new File([thumbBlob], 'thumb.jpg', { type: thumbBlob.type || 'image/jpeg' });
              externalEmbed.thumb = await API.uploadBlob(thumbFile);
            } catch { /* non-fatal */ }
          }
        }

        await API.createPost(replyText, replyRef, uploadedImages, null, externalEmbed, videoEmbed, buildFacets(replyText));
        cleanup(); box.remove();
        if (onSuccess) {
          onSuccess();
        } else {
          showLoading();
          const data = await API.getPostThread(effectiveRoot.uri);
          renderThread(data.thread, currentThread?.authorHandle || '');
        }
      } catch (err) {
        errorEl.textContent   = err.message || 'Failed to post reply.';
        errorEl.hidden        = false;
        submitBtn.disabled    = false;
        submitBtn.textContent = 'Reply';
      } finally {
        hideLoading();
      }
    });
  }

  /* ================================================================
     COMPOSE — IMAGE ATTACHMENT
  ================================================================ */
  /** Clear all pending compose images and hide the preview area. */
  function clearComposeImages() {
    composeImages.forEach(({ previewUrl }) => URL.revokeObjectURL(previewUrl));
    composeImages = [];
    composeImagesPreview.innerHTML = '';
    composeImagesPreview.hidden = true;
    composeImgBtn.disabled = false;
  }

  /** Re-render the compose image preview grid from composeImages state. */
  function refreshComposePreview() {
    composeImagesPreview.innerHTML = '';
    composeImagesPreview.hidden = composeImages.length === 0;
    composeImgBtn.disabled = composeImages.length >= 4;

    composeImages.forEach((entry, idx) => {
      const item = document.createElement('div');
      item.className = 'compose-image-item';

      const thumb = document.createElement('img');
      thumb.src       = entry.previewUrl;
      thumb.alt       = '';
      thumb.className = 'compose-image-thumb';
      item.appendChild(thumb);

      const removeBtn = document.createElement('button');
      removeBtn.type      = 'button';
      removeBtn.className = 'compose-image-remove';
      removeBtn.setAttribute('aria-label', 'Remove image');
      removeBtn.textContent = '×';
      removeBtn.addEventListener('click', () => {
        URL.revokeObjectURL(entry.previewUrl);
        composeImages.splice(idx, 1);
        refreshComposePreview();
      });
      item.appendChild(removeBtn);

      const altInput = document.createElement('textarea');
      altInput.className   = 'compose-alt-input';
      altInput.placeholder = 'Alt text (describe image)…';
      altInput.rows        = 2;
      altInput.maxLength   = 1000;
      altInput.value       = entry.alt || '';
      altInput.addEventListener('input', () => { entry.alt = altInput.value; });
      item.appendChild(altInput);

      composeImagesPreview.appendChild(item);
    });
  }

  /* ================================================================
     M42 — VIDEO UPLOAD HELPERS
  ================================================================ */

  function getVideoDailyCount() {
    try {
      const stored = JSON.parse(localStorage.getItem(VIDEO_DAILY_KEY) || 'null');
      const today  = new Date().toISOString().slice(0, 10);
      if (stored?.date === today) return stored.count || 0;
    } catch {}
    return 0;
  }

  function incrementVideoDailyCount() {
    const today = new Date().toISOString().slice(0, 10);
    const count = getVideoDailyCount() + 1;
    localStorage.setItem(VIDEO_DAILY_KEY, JSON.stringify({ date: today, count }));
  }

  /** Clear compose video state and hide the preview element. */
  function clearComposeVideo() {
    if (composeVideo?.objectUrl) URL.revokeObjectURL(composeVideo.objectUrl);
    composeVideo = null;
    const wrap = $('compose-video-preview');
    if (wrap) wrap.hidden = true;
    const player = $('compose-video-player');
    if (player) { player.pause(); player.src = ''; }
    const videoBtnEl = $('compose-video-btn');
    if (videoBtnEl) videoBtnEl.disabled = false;
  }

  /** Render the compose video preview given current composeVideo state. */
  function renderComposeVideoPreview() {
    const wrap   = $('compose-video-preview');
    const player = $('compose-video-player');
    const name   = $('compose-video-name');
    const dur    = $('compose-video-dur');
    const removeBtn = $('compose-video-remove');
    if (!wrap || !player) return;

    if (!composeVideo) { wrap.hidden = true; return; }

    player.src  = composeVideo.objectUrl;
    player.load();
    if (name) name.textContent = composeVideo.file.name;
    if (dur)  dur.textContent  = composeVideo.duration != null
      ? `${Math.floor(composeVideo.duration)}s`
      : '';
    wrap.hidden = false;

    if (removeBtn) {
      removeBtn.onclick = () => {
        clearComposeVideo();
        composeImgBtn.disabled = false;
      };
    }
  }

  /** Clear quote modal video state and hide the preview element. */
  function clearQuoteVideo() {
    if (quoteVideo?.objectUrl) URL.revokeObjectURL(quoteVideo.objectUrl);
    quoteVideo = null;
    const wrap = $('quote-video-preview');
    if (wrap) wrap.hidden = true;
    const player = $('quote-video-player');
    if (player) { player.pause(); player.src = ''; }
    const videoBtnEl = $('quote-video-btn');
    if (videoBtnEl) videoBtnEl.disabled = false;
  }

  /** Render the quote video preview given current quoteVideo state. */
  function renderQuoteVideoPreview() {
    const wrap   = $('quote-video-preview');
    const player = $('quote-video-player');
    const name   = $('quote-video-name');
    const dur    = $('quote-video-dur');
    const removeBtn = $('quote-video-remove');
    if (!wrap || !player) return;

    if (!quoteVideo) { wrap.hidden = true; return; }

    player.src  = quoteVideo.objectUrl;
    player.load();
    if (name) name.textContent = quoteVideo.file.name;
    if (dur)  dur.textContent  = quoteVideo.duration != null
      ? `${Math.floor(quoteVideo.duration)}s`
      : '';
    wrap.hidden = false;

    if (removeBtn) {
      removeBtn.onclick = () => clearQuoteVideo();
    }
  }

  /**
   * Validate a chosen video file and populate the given state object.
   * Returns an error string on failure, or null on success.
   * @param {File} file
   * @returns {Promise<{video: object, error: string|null}>}
   */
  async function validateAndLoadVideo(file) {
    const MAX_BYTES = 50 * 1024 * 1024; // 50 MB
    const MAX_SECS  = 180;              // 3 minutes

    if (!file.type.startsWith('video/')) {
      return { video: null, error: 'Please choose a video file.' };
    }
    if (file.size > MAX_BYTES) {
      return { video: null, error: `Video is too large (${(file.size / 1024 / 1024).toFixed(1)} MB). Maximum is 50 MB.` };
    }
    if (getVideoDailyCount() >= DAILY_VIDEO_LIMIT) {
      return { video: null, error: `You have reached the daily video limit of ${DAILY_VIDEO_LIMIT} uploads. Try again tomorrow.` };
    }

    const objectUrl = URL.createObjectURL(file);
    const duration  = await new Promise((resolve) => {
      const vid = document.createElement('video');
      vid.preload = 'metadata';
      vid.onloadedmetadata = () => {
        URL.revokeObjectURL(vid.src);
        resolve(vid.duration);
      };
      vid.onerror = () => { URL.revokeObjectURL(vid.src); resolve(null); };
      vid.src = objectUrl;
    });

    if (duration != null && duration > MAX_SECS) {
      URL.revokeObjectURL(objectUrl);
      return { video: null, error: `Video is too long (${Math.floor(duration)}s). Maximum is 3 minutes (180s).` };
    }

    const aspectRatio = await new Promise((resolve) => {
      const vid = document.createElement('video');
      vid.preload = 'metadata';
      vid.onloadedmetadata = () => {
        const w = vid.videoWidth;
        const h = vid.videoHeight;
        resolve(w && h ? { width: w, height: h } : null);
      };
      vid.onerror = () => resolve(null);
      vid.src = URL.createObjectURL(file);
    });

    return {
      video: { file, objectUrl, duration, aspectRatio },
      error: null,
    };
  }

  /* ---- Compose video button + input handlers ---- */
  const composeVideoBtn   = $('compose-video-btn');
  const composeVideoInput = $('compose-video-input');

  if (composeVideoBtn && composeVideoInput) {
    composeVideoBtn.addEventListener('click', () => {
      if (composeVideo) return; // already have one
      composeVideoInput.value = '';
      composeVideoInput.click();
    });

    composeVideoInput.addEventListener('change', async () => {
      const file = composeVideoInput.files?.[0];
      composeVideoInput.value = '';
      if (!file) return;

      const { video, error } = await validateAndLoadVideo(file);
      if (error) { showError(composeError, error); return; }

      // Video is mutually exclusive with images and link/GIF embeds
      clearComposeImages();
      clearLinkPreview();
      composeVideo = video;
      renderComposeVideoPreview();
      composeImgBtn.disabled = true;
    });
  }

  /* ---- Quote modal video button + input handlers ---- */
  const quoteVideoBtn   = $('quote-video-btn');
  const quoteVideoInput = $('quote-video-input');

  if (quoteVideoBtn && quoteVideoInput) {
    quoteVideoBtn.addEventListener('click', () => {
      if (quoteVideo) return;
      quoteVideoInput.value = '';
      quoteVideoInput.click();
    });

    quoteVideoInput.addEventListener('change', async () => {
      const file = quoteVideoInput.files?.[0];
      quoteVideoInput.value = '';
      if (!file) return;

      const { video, error } = await validateAndLoadVideo(file);
      if (error) { showError(quoteModalError, error); return; }

      clearQuoteImages();
      clearQuoteLinkPreview();
      quoteVideo = video;
      renderQuoteVideoPreview();
      quoteImgBtn.disabled = true;
    });
  }

  /**
   * Resize/recompress an image File to fit within maxBytes using the Canvas API.
   * - Files already under the limit are returned unchanged.
   * - Large images are scaled to a max of 2048px on the longest side, then
   *   JPEG quality is iteratively reduced until the target size is met.
   * - Transparent PNGs get a white background before conversion to JPEG.
   *
   * @param {File}   file
   * @param {number} maxBytes  target ceiling (default: 950 000 — just under AT Protocol's 1 MB)
   * @returns {Promise<File>}
   */
  function resizeImageFile(file, maxBytes = 950_000) {
    if (file.size <= maxBytes) return Promise.resolve(file);

    return new Promise((resolve, reject) => {
      const img = new Image();
      const objectUrl = URL.createObjectURL(file);

      img.onload = () => {
        URL.revokeObjectURL(objectUrl);

        const MAX_DIM = 2048;
        let w = img.naturalWidth;
        let h = img.naturalHeight;

        // Scale so the longest side fits within MAX_DIM
        if (w > MAX_DIM || h > MAX_DIM) {
          const scale = Math.min(MAX_DIM / w, MAX_DIM / h);
          w = Math.round(w * scale);
          h = Math.round(h * scale);
        }

        const canvas = document.createElement('canvas');
        const ctx    = canvas.getContext('2d');

        // Encode at the given dimensions+quality; reduce until size target is met
        const tryEncode = (width, height, quality) => {
          canvas.width  = width;
          canvas.height = height;
          ctx.fillStyle = '#ffffff'; // white bg for transparent PNGs
          ctx.fillRect(0, 0, width, height);
          ctx.drawImage(img, 0, 0, width, height);

          canvas.toBlob((blob) => {
            if (!blob) { reject(new Error('Image encoding failed.')); return; }

            if (blob.size <= maxBytes) {
              // Success — wrap in a File so api.js sees a proper type
              resolve(new File(
                [blob],
                file.name.replace(/\.[^.]+$/, '.jpg'),
                { type: 'image/jpeg' }
              ));
            } else if (quality > 0.45) {
              // Drop quality in steps of 0.1
              tryEncode(width, height, quality - 0.1);
            } else {
              // Quality floor reached — shrink dimensions proportionally
              const scale = Math.sqrt(maxBytes / blob.size) * 0.9;
              tryEncode(
                Math.max(64, Math.round(width  * scale)),
                Math.max(64, Math.round(height * scale)),
                0.82
              );
            }
          }, 'image/jpeg', quality);
        };

        tryEncode(w, h, 0.85);
      };

      img.onerror = () => {
        URL.revokeObjectURL(objectUrl);
        reject(new Error('Could not read image.'));
      };

      img.src = objectUrl;
    });
  }

  // Clicking the attach button triggers the hidden file input
  composeImgBtn.addEventListener('click', () => {
    if (composeImages.length >= 4) return;
    composeImgInput.click();
  });

  composeImgInput.addEventListener('change', async () => {
    const files = Array.from(composeImgInput.files || []);
    const available = 4 - composeImages.length;
    composeImgInput.value = ''; // reset so same file can be re-selected

    // Disable button and show brief processing state
    composeImgBtn.disabled = true;
    composeImagesPreview.hidden = false;

    for (const file of files.slice(0, available)) {
      if (!file.type.startsWith('image/')) continue;
      try {
        const resized    = await resizeImageFile(file);
        const previewUrl = URL.createObjectURL(resized);
        composeImages.push({ file: resized, previewUrl, alt: '' });
        refreshComposePreview();
      } catch (err) {
        showError(composeError, `Could not process image "${file.name}": ${err.message}`);
      }
    }

    refreshComposePreview();
  });

  /* ================================================================
     M41 — COMPOSE: LINK PREVIEW, GIF PICKER, POST SETTINGS
  ================================================================ */
  const composeGifBtn        = $('compose-gif-btn');
  const composeGifPanel      = $('compose-gif-panel');
  const composeGifInput      = $('compose-gif-input');
  const composeGifGrid       = $('compose-gif-grid');
  const composeGifSearchBtn  = $('compose-gif-search-btn');
  const composeSettingsBtn   = $('compose-settings-btn');
  const composeSettingsPanel = $('compose-settings-panel');
  const composeReplyGate     = $('compose-reply-gate');
  const composeQuoteGate     = $('compose-quote-gate');
  const composeLinkWrap      = $('compose-link-preview-wrap');

  // Klipy GIF API — key is a path segment: https://api.klipy.com/api/v1/{key}/gifs/search
  const KLIPY_KEY = 'g1rqkiKBPyzWEydf5K3syROxIGAFxusrnd6yD5Dj2TT8C8U3k9dtTD7qlClmHdNz';
  let composeLinkEmbed    = null;  // { uri, title, description } or null
  let linkPreviewTimer    = null;

  // GIF panel toggle
  composeGifBtn.addEventListener('click', () => {
    const willOpen = composeGifPanel.hidden;
    composeGifPanel.hidden     = !willOpen;
    composeSettingsPanel.hidden = true;
    if (willOpen) composeGifInput.focus();
  });

  // Settings panel toggle
  composeSettingsBtn.addEventListener('click', () => {
    composeSettingsPanel.hidden = !composeSettingsPanel.hidden;
    composeGifPanel.hidden = true;
  });

  // GIF search via Klipy — accepts target grid element and selection callback
  // Response: { result: true, data: { data: [ { title, file: { xs, gif, hd } } ] } }
  async function searchKlipyGifs(q, gridEl, onSelect) {
    gridEl.innerHTML = '<p class="compose-gif-empty">Searching…</p>';
    try {
      const res  = await fetch(`https://api.klipy.com/api/v1/${encodeURIComponent(KLIPY_KEY)}/gifs/search?q=${encodeURIComponent(q)}&per_page=16`);
      const data = await res.json();
      const items = data?.data?.data;
      if (!items?.length) {
        gridEl.innerHTML = '<p class="compose-gif-empty">No results. Try a different search.</p>';
        return;
      }
      gridEl.innerHTML = '';
      items.forEach((item) => {
        const thumbUrl = item.file?.xs?.jpg?.url || item.file?.xs?.gif?.url;
        // Best available animated URL — no upload needed, so size is not a constraint
        const gifUrl = item.file?.hd?.gif?.url || item.file?.gif?.url || item.file?.xs?.gif?.url;
        // Use a medium-quality animated preview for the grid (better than xs thumbnail)
        const previewUrl = item.file?.md?.gif?.url || item.file?.sm?.gif?.url || gifUrl;
        if (!gifUrl) return;
        const wrap = document.createElement('div');
        wrap.className = 'compose-gif-item-wrap';
        const img = document.createElement('img');
        img.src       = previewUrl;
        img.alt       = item.title || '';
        img.className = 'compose-gif-item';
        img.loading   = 'lazy';
        const watermark = document.createElement('img');
        watermark.src       = 'assets/klipy-watermark.svg';
        watermark.alt       = '';
        watermark.className = 'compose-gif-item-watermark';
        watermark.setAttribute('aria-hidden', 'true');
        wrap.appendChild(img);
        wrap.appendChild(watermark);
        wrap.addEventListener('click', () => onSelect(gifUrl, thumbUrl, item.title || ''));
        gridEl.appendChild(wrap);
      });
    } catch (err) {
      gridEl.innerHTML = `<p class="compose-gif-empty">Search failed: ${escHtml(err.message)}</p>`;
    }
  }

  composeGifSearchBtn.addEventListener('click', () => {
    const q = composeGifInput.value.trim();
    if (q) searchKlipyGifs(q, composeGifGrid, selectGif);
  });
  composeGifInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); composeGifSearchBtn.click(); }
  });

  /**
   * Attach a Klipy GIF to the compose form as an external embed.
   *
   * BlueSky's CDN transcodes every uploaded image blob to JPEG, stripping GIF
   * animation. The correct approach (matching the official app's Tenor/Giphy
   * integration) is to store the CDN URL as app.bsky.embed.external so the GIF
   * is served directly from Klipy — no upload, no re-encoding, animation intact.
   *
   * @param {string}      gifUrl   Direct Klipy animated GIF URL
   * @param {string|null} thumbUrl Static xs.jpg thumbnail URL (uploaded as blob at post time
   *                               so native Bluesky shows an image card instead of a text link)
   * @param {string}      alt      GIF title / alt text
   */
  function selectGif(gifUrl, thumbUrl, alt) {
    // Clear any existing images, video, or link preview — GIF is mutually exclusive
    composeImages.forEach((img) => { try { URL.revokeObjectURL(img.previewUrl); } catch {} });
    composeImages = [];
    refreshComposePreview();
    clearComposeVideo();

    // _thumbUrl is a private hint used by the submit handler to upload a static
    // preview blob — it is not sent to the AT Protocol API directly.
    composeLinkEmbed = { uri: gifUrl, title: alt, description: '', _thumbUrl: thumbUrl || null };

    // Show an animated preview in the link-preview slot with a dismiss button
    composeLinkWrap.innerHTML = `
      <div class="compose-link-preview compose-gif-preview">
        <img class="compose-gif-preview-img" src="${escHtml(gifUrl)}" alt="${escHtml(alt)}">
        <button type="button" class="compose-link-preview-dismiss" aria-label="Remove GIF">✕</button>
      </div>
    `;
    composeLinkWrap.querySelector('.compose-link-preview-dismiss')
      .addEventListener('click', clearLinkPreview);

    composeGifPanel.hidden = true;
    composeGifGrid.innerHTML = '<p class="compose-gif-empty">Type above to search for GIFs</p>';
    composeGifInput.value = '';
  }

  /**
   * Build AT Protocol facets for a post body.
   * Generates `app.bsky.richtext.facet#link` entries for every HTTP/HTTPS URL and
   * `app.bsky.richtext.facet#tag` entries for #hashtags using correct UTF-8 byte offsets.
   * Without facets, URLs appear as plain unclickable text in the native Bluesky app.
   */
  function buildFacets(text) {
    if (!text) return undefined;
    const encoder = new TextEncoder();
    const facets  = [];

    // URL facets — strip trailing punctuation that isn't part of the URL
    const urlRe = /https?:\/\/[^\s\u0000-\u001f<>"{}|\\^`[\]]+/g;
    let m;
    while ((m = urlRe.exec(text)) !== null) {
      let url = m[0].replace(/[.,;:!?)"']+$/, ''); // trim trailing punctuation
      const byteStart = encoder.encode(text.slice(0, m.index)).length;
      const byteEnd   = byteStart + encoder.encode(url).length;
      facets.push({ index: { byteStart, byteEnd }, features: [{ $type: 'app.bsky.richtext.facet#link', uri: url }] });
    }

    // Hashtag facets
    const tagRe = /(?<![&\w])#([a-zA-Z][a-zA-Z0-9_]*)/g;
    while ((m = tagRe.exec(text)) !== null) {
      const full      = m[0];
      const byteStart = encoder.encode(text.slice(0, m.index)).length;
      const byteEnd   = byteStart + encoder.encode(full).length;
      facets.push({ index: { byteStart, byteEnd }, features: [{ $type: 'app.bsky.richtext.facet#tag', tag: m[1] }] });
    }

    facets.sort((a, b) => a.index.byteStart - b.index.byteStart);
    return facets.length ? facets : undefined;
  }

  // Link preview helpers
  function clearLinkPreview() {
    composeLinkEmbed = null;
    composeLinkWrap.innerHTML = '';
  }

  async function fetchLinkPreview(url) {
    if (composeLinkEmbed) return;
    try {
      const res  = await fetch(`https://api.allorigins.win/get?url=${encodeURIComponent(url)}`);
      const data = await res.json();
      if (!data.contents) return;
      const parser = new DOMParser();
      const doc    = parser.parseFromString(data.contents, 'text/html');
      const getOg  = (name) =>
        doc.querySelector(`meta[property="${name}"]`)?.content ||
        doc.querySelector(`meta[name="${name}"]`)?.content || '';
      const title    = (getOg('og:title')       || doc.title || '').trim();
      const desc     = (getOg('og:description') || getOg('description') || '').trim();
      const thumb    = getOg('og:image')        || getOg('twitter:image') || '';
      const hostname = (() => { try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return url; } })();
      // Store thumb as _thumbUrl so the submit handler uploads it as a blob ref
      composeLinkEmbed = { uri: url, title, description: desc, _thumbUrl: thumb };
      renderLinkPreviewCard(hostname);
    } catch {
      // Silently ignore — link preview is best-effort
    }
  }

  function renderLinkPreviewCard(hostname) {
    const { title, description, _thumbUrl } = composeLinkEmbed;
    composeLinkWrap.innerHTML = `
      <div class="compose-link-preview">
        ${_thumbUrl ? `
          <div style="position:relative;">
            <img class="compose-link-preview-thumb" src="${escHtml(_thumbUrl)}" alt="" loading="lazy">
            <button type="button" class="compose-link-preview-change-thumb" title="Change thumbnail image"
                    style="position:absolute;bottom:6px;right:6px;background:rgba(0,0,0,0.5);color:#fff;border:none;border-radius:4px;font-size:11px;padding:2px 6px;cursor:pointer;">
              Change
            </button>
          </div>` : `
          <button type="button" class="compose-link-preview-change-thumb" title="Set thumbnail image"
                  style="display:block;width:100%;padding:8px;background:none;border:none;color:var(--color-accent);font-size:0.8rem;cursor:pointer;text-align:left;">
            + Set thumbnail image
          </button>`}
        <div class="compose-link-preview-body">
          <input class="compose-link-preview-input compose-link-preview-title"
                 value="${escHtml(title)}" placeholder="Title" maxlength="300" aria-label="Link title">
          <input class="compose-link-preview-input compose-link-preview-desc"
                 value="${escHtml(description)}" placeholder="Description (optional)" maxlength="500" aria-label="Link description">
          <span class="compose-link-preview-host">${escHtml(hostname)}</span>
        </div>
        <button type="button" class="compose-link-preview-dismiss" aria-label="Remove link preview">✕</button>
      </div>
    `;
    composeLinkWrap.querySelector('.compose-link-preview-title').addEventListener('input', (e) => {
      composeLinkEmbed.title = e.target.value;
    });
    composeLinkWrap.querySelector('.compose-link-preview-desc').addEventListener('input', (e) => {
      composeLinkEmbed.description = e.target.value;
    });
    composeLinkWrap.querySelector('.compose-link-preview-dismiss').addEventListener('click', clearLinkPreview);
    composeLinkWrap.querySelector('.compose-link-preview-change-thumb')?.addEventListener('click', () => {
      const newUrl = prompt('Enter image URL for thumbnail:', composeLinkEmbed._thumbUrl || '');
      if (newUrl !== null) {
        composeLinkEmbed._thumbUrl = newUrl.trim() || null;
        renderLinkPreviewCard(hostname); // re-render with new thumb
      }
    });
  }

  // M61: attach @mention autocomplete to main compose textarea
  attachMentionAutocomplete(composeText);

  /* ================================================================
     COMPOSE — SUBMIT
  ================================================================ */
  composeText.addEventListener('input', () => {
    updateCharCount(composeText, composeCount);
    clearTimeout(linkPreviewTimer);
    if (composeLinkEmbed) return;
    const matches = composeText.value.match(/https?:\/\/[^\s]+/g);
    if (!matches) return;
    linkPreviewTimer = setTimeout(() => fetchLinkPreview(matches[0]), 300);
  });
  // Trigger immediately on paste so the card appears as soon as the URL lands
  composeText.addEventListener('paste', () => {
    if (composeLinkEmbed) return;
    clearTimeout(linkPreviewTimer);
    linkPreviewTimer = setTimeout(() => {
      const matches = composeText.value.match(/https?:\/\/[^\s]+/g);
      if (matches) fetchLinkPreview(matches[0]);
    }, 0);
  });

  composeForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideError(composeError);
    const text = composeText.value.trim();
    if (!text && composeImages.length === 0 && !composeVideo) return;

    const btn = composeForm.querySelector('button[type="submit"]');
    btn.disabled = true;
    btn.textContent = 'Posting…';
    composeImgBtn.disabled = true;

    try {
      // Upload any attached images first
      let uploadedImages = [];
      if (composeImages.length > 0) {
        btn.textContent = `Uploading ${composeImages.length} image${composeImages.length > 1 ? 's' : ''}…`;
        uploadedImages = await Promise.all(
          composeImages.map(async ({ file, alt }) => {
            const blob = await API.uploadBlob(file);
            return { blob, alt: alt || '' };
          })
        );
      }

      // M42: upload video if attached (mutually exclusive with images)
      let videoEmbed = null;
      if (composeVideo && uploadedImages.length === 0) {
        btn.textContent = 'Uploading video…';
        const altText = $('compose-video-alt')?.value?.trim() || '';
        const videoBlobRef = await API.uploadBlob(composeVideo.file, composeVideo.file.type || 'video/mp4');
        videoEmbed = {
          $type: 'app.bsky.embed.video',
          video: videoBlobRef,
          ...(altText ? { alt: altText } : {}),
          ...(composeVideo.aspectRatio ? { aspectRatio: composeVideo.aspectRatio } : {}),
        };
        incrementVideoDailyCount();
      }

      // M41: external embed only when no images or video are attached
      const linkEmbed = uploadedImages.length === 0 && !videoEmbed ? composeLinkEmbed : null;

      // If the external embed is a GIF, upload the static xs.jpg thumbnail so
      // native Bluesky renders an image card rather than a bare text link.
      if (linkEmbed?._thumbUrl) {
        try {
          btn.textContent = 'Uploading GIF preview…';
          const thumbRes  = await fetch(linkEmbed._thumbUrl);
          const thumbBlob = await thumbRes.blob();
          const thumbFile = new File([thumbBlob], 'thumb.jpg', { type: thumbBlob.type || 'image/jpeg' });
          linkEmbed.thumb = await API.uploadBlob(thumbFile);
        } catch {
          // Non-fatal — post without thumbnail if the upload fails
        }
      }

      btn.textContent = 'Posting…';
      const result = await API.createPost(text, null, uploadedImages, null, linkEmbed, videoEmbed, buildFacets(text));

      // M41: apply thread gate and quote gate records if non-default
      const replyGateVal = composeReplyGate.value;
      const quoteGateVal = composeQuoteGate.value;
      if (result.uri && (replyGateVal !== 'everyone' || quoteGateVal === 'nobody')) {
        const session  = AUTH.getSession();
        const postRkey = result.uri.split('/').pop();
        if (replyGateVal !== 'everyone') {
          const allow = replyGateVal === 'mentioned'
            ? [{ $type: 'app.bsky.feed.threadgate#mentionRule' }]
            : [{ $type: 'app.bsky.feed.threadgate#followingRule' }];
          await API.putRecord(session.did, 'app.bsky.feed.threadgate', postRkey, {
            $type:     'app.bsky.feed.threadgate',
            post:      result.uri,
            allow,
            createdAt: new Date().toISOString(),
          });
        }
        if (quoteGateVal === 'nobody') {
          await API.putRecord(session.did, 'app.bsky.feed.postgate', postRkey, {
            $type:                 'app.bsky.feed.postgate',
            post:                  result.uri,
            detachedEmbeddingUris: [],
            embeddingRules:        [{ $type: 'app.bsky.feed.postgate#disableRule' }],
            createdAt:             new Date().toISOString(),
          });
        }
      }

      composeForm.reset();
      composeCount.textContent = '300';
      clearComposeImages();
      clearComposeVideo();
      clearLinkPreview();
      composeGifPanel.hidden      = true;
      composeSettingsPanel.hidden = true;
      composeReplyGate.value = 'everyone';
      composeQuoteGate.value = 'everyone';
      composeSuccess.hidden = false;

      // M51: wire "View post →" button to open the new post in-app
      if (result.uri && ownProfile) {
        const postLink = $('compose-post-link');
        const newUri   = result.uri;
        postLink.onclick = (e) => {
          e.preventDefault();
          composeSuccess.hidden = true;
          openThread(newUri, result.cid || '', ownProfile.handle);
        };
        // Auto-dismiss after 4 seconds
        const timer = setTimeout(() => { composeSuccess.hidden = true; }, 4000);
        postLink.addEventListener('click', () => clearTimeout(timer), { once: true });
      }
    } catch (err) {
      showError(composeError, err.message || 'Failed to post.');
    } finally {
      btn.disabled = false;
      btn.textContent = 'Post';
      composeImgBtn.disabled = composeImages.length >= 4;
    }
  });

  /* ================================================================
     UTILITIES
  ================================================================ */
  function updateCharCount(textarea, countEl) {
    const remaining = 300 - textarea.value.length;
    countEl.textContent = remaining;
    countEl.className = 'char-count' +
      (remaining <= 0  ? ' over' :
       remaining <= 20 ? ' warn' : '');
  }

  /**
   * Escape HTML special characters.
   */
  function escHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  /**
   * Render post text, using AT Protocol facets for accurate link/hashtag/mention
   * detection. Falls back to URL-only regex when no facets are present.
   *
   * Facets use UTF-8 byte offsets; we convert using TextEncoder/TextDecoder.
   * All output is HTML-escaped before insertion into innerHTML.
   *
   * @param {string}       text   - raw post text
   * @param {Array|null}   facets - record.facets from the AT Protocol post record
   */
  function renderPostText(text, facets) {
    if (!facets || facets.length === 0) {
      // No facets: escape and linkify bare URLs only
      return escHtml(text).replace(
        /(https?:\/\/[^\s<>"]+)/g,
        '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>'
      );
    }

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();
    const bytes   = encoder.encode(text);

    // Sort facets by byteStart ascending; skip invalid/backwards ones
    const sorted = [...facets]
      .filter((f) => f.index?.byteStart != null && f.index.byteEnd > f.index.byteStart)
      .sort((a, b) => a.index.byteStart - b.index.byteStart);

    let html    = '';
    let bytePos = 0;

    for (const facet of sorted) {
      const { byteStart, byteEnd } = facet.index;
      if (byteStart < bytePos) continue; // skip overlapping facets

      // Plain text before this facet
      if (byteStart > bytePos) {
        html += escHtml(decoder.decode(bytes.slice(bytePos, byteStart)));
      }

      const segText = decoder.decode(bytes.slice(byteStart, byteEnd));
      const feature = facet.features?.[0];

      if (!feature) {
        html += escHtml(segText);
      } else if (feature.$type === 'app.bsky.richtext.facet#link') {
        const href = escHtml(feature.uri || segText);
        html += `<a href="${href}" target="_blank" rel="noopener noreferrer">${escHtml(segText)}</a>`;
      } else if (feature.$type === 'app.bsky.richtext.facet#tag') {
        const tag = escHtml(feature.tag || segText.replace(/^#/, ''));
        html += `<a href="#" class="hashtag-link" data-hashtag="${tag}">${escHtml(segText)}</a>`;
      } else if (feature.$type === 'app.bsky.richtext.facet#mention') {
        const did = escHtml(feature.did || '');
        html += `<span class="mention-text mention-link" role="button" tabindex="0" data-mention-did="${did}">${escHtml(segText)}</span>`;
      } else {
        html += escHtml(segText);
      }

      bytePos = byteEnd;
    }

    // Remaining plain text after last facet
    if (bytePos < bytes.length) {
      html += escHtml(decoder.decode(bytes.slice(bytePos)));
    }

    return html;
  }

  function formatTimestamp(isoString) {
    if (!isoString) return '';
    try {
      const d = new Date(isoString);
      const now = new Date();
      const diff = now - d;

      if (diff < 60_000)          return 'just now';
      if (diff < 3_600_000)       return `${Math.floor(diff / 60_000)}m`;
      if (diff < 86_400_000)      return `${Math.floor(diff / 3_600_000)}h`;
      if (diff < 7 * 86_400_000)  return `${Math.floor(diff / 86_400_000)}d`;

      return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    } catch {
      return '';
    }
  }

  function formatCount(n) {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000)     return `${(n / 1_000).toFixed(1)}K`;
    return String(n);
  }

  function parseFmtCount(s) {
    const n = parseFloat(s);
    if (s.endsWith('K')) return Math.round(n * 1_000);
    if (s.endsWith('M')) return Math.round(n * 1_000_000);
    return isNaN(n) ? 0 : n;
  }

  /* ================================================================
     M22 — ANALYTICS DASHBOARD
  ================================================================ */
  (() => {
    let analyticsActor    = null; // handle/DID currently shown
    let analyticsPosts    = [];   // raw post objects fetched
    let analyticsSort     = 'likes'; // current top-posts sort key
    let analyticsChart    = null; // active canvas rendering context

    const actorForm       = $('analytics-actor-form');
    const actorInput      = $('analytics-actor-input');
    const ownBtn          = $('analytics-own-btn');
    const profileStrip    = $('analytics-profile-strip');
    const errEl           = $('analytics-error');
    const loadingEl       = $('analytics-loading');
    const contentEl       = $('analytics-content');
    const heatmapEl       = $('analytics-heatmap');
    const topPostsEl      = $('analytics-top-posts');
    const engCanvas       = $('analytics-engagement-chart');

    function showAnalyticsError(msg) {
      errEl.textContent = msg;
      errEl.hidden = false;
      loadingEl.hidden = true;
      contentEl.hidden = true;
      profileStrip.hidden = true;
    }

    /* -- Canvas bar chart -- */
    function drawEngagementChart(posts) {
      if (!engCanvas) return;
      const ctx = engCanvas.getContext('2d');
      const dpr = window.devicePixelRatio || 1;
      const W   = engCanvas.offsetWidth  || 300;
      const H   = 180;
      engCanvas.width  = W * dpr;
      engCanvas.height = H * dpr;
      ctx.scale(dpr, dpr);

      const data = posts.slice(0, 25).map((p) => ({
        likes:   p.likeCount   || 0,
        reposts: p.repostCount || 0,
        date:    p.record?.createdAt || p.indexedAt || '',
      })).reverse(); // oldest first → left to right

      const maxVal = Math.max(...data.map((d) => d.likes + d.reposts), 1);
      const padL = 32, padR = 8, padT = 8, padB = 28;
      const chartW = W - padL - padR;
      const chartH = H - padT - padB;
      const barGroup = chartW / data.length;
      const barW     = Math.max(barGroup * 0.38, 2);
      const gap      = Math.max(barGroup * 0.05, 1);

      // Background
      ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--color-surface').trim() || '#fff';
      ctx.fillRect(0, 0, W, H);

      // Y gridlines
      ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--color-border').trim() || '#e0e0e0';
      ctx.lineWidth = 1;
      for (let i = 0; i <= 4; i++) {
        const y = padT + chartH - (chartH * i / 4);
        ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(W - padR, y); ctx.stroke();
        ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--color-text-muted').trim() || '#555';
        ctx.font = '9px Inter, sans-serif';
        ctx.textAlign = 'right';
        ctx.fillText(formatCount(Math.round(maxVal * i / 4)), padL - 3, y + 3);
      }

      const accent = getComputedStyle(document.documentElement).getPropertyValue('--color-accent').trim() || '#0047FF';
      const green  = '#00B37D';

      data.forEach((d, i) => {
        const x      = padL + i * barGroup + gap;
        const likeH  = (d.likes   / maxVal) * chartH;
        const rpH    = (d.reposts / maxVal) * chartH;
        const totalH = ((d.likes + d.reposts) / maxVal) * chartH;

        // Repost bar (bottom)
        ctx.fillStyle = green;
        ctx.fillRect(x, padT + chartH - rpH, barW, rpH);
        // Like bar (stacked on top)
        ctx.fillStyle = accent;
        ctx.fillRect(x, padT + chartH - totalH, barW, likeH);

        // X label (every 5th)
        if (i % 5 === 0 && d.date) {
          const label = new Date(d.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
          ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--color-text-muted').trim() || '#555';
          ctx.font = '8px Inter, sans-serif';
          ctx.textAlign = 'center';
          ctx.fillText(label, x + barW / 2, H - 4);
        }
      });

      // Legend
      const legendX = W - padR - 120;
      ctx.fillStyle = accent;
      ctx.fillRect(legendX, padT, 10, 8);
      ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--color-text').trim() || '#0a0a0a';
      ctx.font = '9px Inter, sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText('Likes', legendX + 13, padT + 8);
      ctx.fillStyle = green;
      ctx.fillRect(legendX + 50, padT, 10, 8);
      ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--color-text').trim() || '#0a0a0a';
      ctx.fillText('Reposts', legendX + 63, padT + 8);
    }

    /* -- GitHub-style heatmap -- */
    function renderHeatmap(posts) {
      if (!heatmapEl) return;
      heatmapEl.innerHTML = '';

      const now     = new Date();
      const days    = 84; // 12 weeks
      const counts  = {};

      posts.forEach((p) => {
        const d = p.record?.createdAt || p.indexedAt;
        if (!d) return;
        const key = new Date(d).toISOString().slice(0, 10);
        counts[key] = (counts[key] || 0) + 1;
      });

      const maxCount = Math.max(...Object.values(counts), 1);

      // Day-of-week labels (Mon first column)
      const dowLabels = ['M', '', 'W', '', 'F', '', ''];
      const labelCol  = document.createElement('div');
      labelCol.className = 'heatmap-dow-labels';
      dowLabels.forEach((l) => {
        const s = document.createElement('span');
        s.textContent = l;
        labelCol.appendChild(s);
      });
      heatmapEl.appendChild(labelCol);

      // Grid: weeks × 7 days
      const grid = document.createElement('div');
      grid.className = 'heatmap-grid';

      const startDate = new Date(now);
      startDate.setDate(startDate.getDate() - days + 1);

      for (let w = 0; w < 12; w++) {
        const col = document.createElement('div');
        col.className = 'heatmap-col';
        for (let d = 0; d < 7; d++) {
          const cellDate = new Date(startDate);
          cellDate.setDate(startDate.getDate() + w * 7 + d);
          const key   = cellDate.toISOString().slice(0, 10);
          const count = counts[key] || 0;
          const cell  = document.createElement('span');
          cell.className = 'analytics-heatmap-cell heatmap-cell';
          cell.title = `${key}: ${count} post${count !== 1 ? 's' : ''}`;
          const level = count === 0 ? 0 : count <= 2 ? 1 : count <= 4 ? 2 : count <= 7 ? 3 : 4;
          cell.dataset.level = level;
          col.appendChild(cell);
        }
        grid.appendChild(col);
      }
      heatmapEl.appendChild(grid);
    }

    /* -- Top posts table -- */
    function renderTopPosts(posts, sort) {
      if (!topPostsEl) return;
      topPostsEl.innerHTML = '';
      const sorted = [...posts].sort((a, b) => {
        if (sort === 'reposts') return (b.repostCount || 0) - (a.repostCount || 0);
        if (sort === 'replies') return (b.replyCount  || 0) - (a.replyCount  || 0);
        return (b.likeCount || 0) - (a.likeCount || 0);
      }).slice(0, 15);

      if (!sorted.length) {
        topPostsEl.innerHTML = '<p class="feed-empty-text">No posts found.</p>';
        return;
      }

      sorted.forEach((post, idx) => {
        const text = post.record?.text || '';
        const row  = document.createElement('div');
        row.className = 'analytics-top-row';
        row.setAttribute('role', 'listitem');
        row.innerHTML = `
          <div class="analytics-top-rank">#${idx + 1}</div>
          <div class="analytics-top-body">
            <div class="analytics-top-text">${escHtml(text.slice(0, 120))}${text.length > 120 ? '…' : ''}</div>
            <div class="analytics-top-stats">
              <span class="analytics-top-stat" title="Likes">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12" aria-hidden="true"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
                ${formatCount(post.likeCount || 0)}
              </span>
              <span class="analytics-top-stat" title="Reposts">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
                ${formatCount(post.repostCount || 0)}
              </span>
              <span class="analytics-top-stat" title="Replies">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                ${formatCount(post.replyCount || 0)}
              </span>
              <span class="analytics-top-date">${formatTimestamp(post.record?.createdAt || post.indexedAt)}</span>
            </div>
          </div>`;
        row.addEventListener('click', () => {
          const author = post.author?.handle || '';
          openThread(post.uri, post.cid, author);
        });
        topPostsEl.appendChild(row);
      });
    }

    /* -- Main load function -- */
    window.loadAnalytics = async function loadAnalytics(actorOverride) {
      const actor = actorOverride || analyticsActor || ownProfile?.handle;
      if (!actor) return;
      analyticsActor = actor;

      errEl.hidden     = true;
      contentEl.hidden = true;
      profileStrip.hidden = true;
      loadingEl.hidden = false;

      try {
        const [profileData, feedData] = await Promise.all([
          API.getActorProfile(actor),
          API.getAuthorFeed(actor, 100),
        ]);

        analyticsPosts = feedData.feed?.filter((item) => !item.reason || item.reason.$type !== 'app.bsky.feed.defs#reasonRepost').map((item) => item.post).filter(Boolean) || [];

        // Populate profile strip
        $('analytics-profile-avatar').src = profileData.avatar || '';
        $('analytics-profile-avatar').alt = profileData.displayName || profileData.handle || '';
        $('analytics-profile-name').textContent   = profileData.displayName || profileData.handle || '';
        $('analytics-profile-handle').textContent = `@${profileData.handle || ''}`;
        $('analytics-followers').textContent   = formatCount(profileData.followersCount || 0);
        $('analytics-following').textContent   = formatCount(profileData.followsCount   || 0);
        $('analytics-posts-count').textContent = formatCount(profileData.postsCount     || 0);
        profileStrip.hidden = false;

        loadingEl.hidden = true;
        contentEl.hidden = false;

        drawEngagementChart(analyticsPosts);
        renderHeatmap(analyticsPosts);
        renderTopPosts(analyticsPosts, analyticsSort);
      } catch (err) {
        showAnalyticsError(`Could not load analytics: ${err.message}`);
      }
    };

    // Own profile button
    if (ownBtn) {
      ownBtn.addEventListener('click', () => {
        if (ownProfile) loadAnalytics(ownProfile.handle);
      });
    }

    // Actor search form
    if (actorForm) {
      actorForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const val = actorInput.value.trim();
        if (val) loadAnalytics(val);
      });
    }

    // Sort buttons
    if (contentEl) {
      contentEl.addEventListener('click', (e) => {
        const btn = e.target.closest('.analytics-sort-btn');
        if (!btn) return;
        contentEl.querySelectorAll('.analytics-sort-btn').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        analyticsSort = btn.dataset.sort;
        renderTopPosts(analyticsPosts, analyticsSort);
      });
    }

    // Redraw canvas on resize
    let resizeTimer;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        if (!viewAnalytics.hidden && analyticsPosts.length) {
          drawEngagementChart(analyticsPosts);
        }
      }, 150);
    });
  })();

  /* ================================================================
     TIMELINE (M13)
  ================================================================ */
  // Each zoom level: [windowMs, label, minEngagement]
  // windowMs = total time window shown; minEngagement = min likes+reposts+replies to show post
  const TL_ZOOM_LEVELS = [
    [7 * 86400000,   '7d',  50],   // 0: 7 days   — top posts only
    [3 * 86400000,   '3d',  25],   // 1: 3 days
    [1 * 86400000,   '1d',  10],   // 2: 1 day    ← default
    [12 * 3600000,   '12h',  5],   // 3: 12 hours
    [4  * 3600000,   '4h',   2],   // 4: 4 hours
    [1  * 3600000,   '1h',   0],   // 5: 1 hour   — show all
    [20 * 60000,     '20m',  0],   // 6: 20 minutes
  ];

  let tlZoomLevel = 2;       // default: 1 day
  let tlAllPosts  = [];      // posts for the current window
  let tlQuery     = '';
  let tlWindowEnd = Date.now();                               // right edge (ms)
  let tlWindowStart = tlWindowEnd - TL_ZOOM_LEVELS[2][0];   // left edge (ms)

  function tlUpdateZoomLabel() {
    $('timeline-zoom-label').textContent = TL_ZOOM_LEVELS[tlZoomLevel][1];
  }

  function tlSyncDateInputs() {
    const fmt = (ms) => {
      const d = new Date(ms);
      const pad = (n) => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    };
    $('timeline-start-input').value = fmt(tlWindowStart);
    $('timeline-end-input').value   = fmt(tlWindowEnd);
  }

  $('timeline-zoom-in-btn').addEventListener('click', () => {
    if (!tlQuery) return;
    if (tlZoomLevel < TL_ZOOM_LEVELS.length - 1) {
      tlZoomLevel++;
      // Keep the right (most-recent) edge fixed so we stay in daytime hours
      tlWindowStart = tlWindowEnd - TL_ZOOM_LEVELS[tlZoomLevel][0];
      tlUpdateZoomLabel();
      tlSyncDateInputs();
      tlFetch();
    }
  });

  $('timeline-zoom-out-btn').addEventListener('click', () => {
    if (!tlQuery) return;
    if (tlZoomLevel > 0) {
      tlZoomLevel--;
      tlWindowStart = tlWindowEnd - TL_ZOOM_LEVELS[tlZoomLevel][0];
      tlUpdateZoomLabel();
      tlSyncDateInputs();
      tlFetch();
    }
  });

  // Auto-apply when either datetime input changes
  const tlApplyRange = () => {
    const s = new Date($('timeline-start-input').value).getTime();
    const e = new Date($('timeline-end-input').value).getTime();
    if (!isNaN(s) && !isNaN(e) && s < e && tlQuery) {
      tlWindowStart = s;
      tlWindowEnd   = e;
      const span = e - s;
      let best = 0;
      TL_ZOOM_LEVELS.forEach((z, i) => {
        if (Math.abs(z[0] - span) < Math.abs(TL_ZOOM_LEVELS[best][0] - span)) best = i;
      });
      tlZoomLevel = best;
      tlUpdateZoomLabel();
      tlFetch();
    }
  };
  $('timeline-start-input').addEventListener('change', tlApplyRange);
  $('timeline-end-input').addEventListener('change',   tlApplyRange);

  $('timeline-search-btn').addEventListener('click', tlDoSearch);
  $('timeline-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') tlDoSearch();
  });

  async function tlDoSearch() {
    const raw = $('timeline-search-input').value.trim();
    if (!raw) return;
    tlQuery = raw;
    // Reset window to default zoom (1 day ending now)
    tlZoomLevel   = 2;
    tlWindowEnd   = Date.now();
    tlWindowStart = tlWindowEnd - TL_ZOOM_LEVELS[2][0];
    tlUpdateZoomLabel();
    tlSyncDateInputs();
    tlFetch();
  }

  async function tlFetch() {
    if (!tlQuery) return;

    const loadingEl = $('timeline-loading');
    const errorEl   = $('timeline-error');
    const emptyEl   = $('timeline-empty');
    const wrapEl    = $('timeline-canvas-wrap');

    loadingEl.hidden = false;
    errorEl.hidden   = true;
    emptyEl.hidden   = true;
    wrapEl.hidden    = true;
    tlAllPosts = [];

    try {
      let posts = [];
      const raw = tlQuery;

      if (raw.startsWith('@')) {
        // Author feed: walk pages until all posts are before window start
        const handle = raw.replace(/^@/, '');
        let cursor;
        outer: for (let i = 0; i < 6; i++) {
          const data = await API.getAuthorFeedFull(handle, 50, cursor);
          const items = (data.feed || []).filter(item =>
            !item.reason || item.reason.$type !== 'app.bsky.feed.defs#reasonRepost'
          );
          for (const item of items) {
            const t = new Date(item.post?.record?.createdAt || 0).getTime();
            if (t < tlWindowStart) break outer; // newest-first feed; past the window
            if (t <= tlWindowEnd) posts.push(item.post);
          }
          cursor = data.cursor;
          if (!cursor || items.length < 50) break;
        }
      } else {
        // Search: fetch latest + top, client-filter to window
        const [r1, r2] = await Promise.allSettled([
          API.searchPosts(raw, 'latest', 100),
          API.searchPosts(raw, 'top', 100),
        ]);
        const all = [
          ...(r1.status === 'fulfilled' ? r1.value.posts || [] : []),
          ...(r2.status === 'fulfilled' ? r2.value.posts || [] : []),
        ];
        const seen = new Set();
        for (const p of all) {
          if (seen.has(p.uri)) continue;
          seen.add(p.uri);
          const t = new Date(p.record?.createdAt || 0).getTime();
          if (t >= tlWindowStart && t <= tlWindowEnd) posts.push(p);
        }
      }

      if (!posts.length) {
        emptyEl.hidden = false;
      } else {
        tlAllPosts = posts;
        wrapEl.hidden = false;
        requestAnimationFrame(tlRender);
      }
    } catch (err) {
      errorEl.hidden = false;
      errorEl.textContent = 'Error: ' + (err.message || 'Failed to load');
    } finally {
      loadingEl.hidden = true;
    }
  }

  function tlRender() {
    const scrollInner = $('timeline-scroll-inner');
    const wrapEl      = $('timeline-canvas-wrap');
    scrollInner.innerHTML = '';

    const [, , minEngagement] = TL_ZOOM_LEVELS[tlZoomLevel];

    // Sort by engagement descending, then apply minEngagement filter
    // Show top-N posts that fit in the available lanes — most engaged always visible
    let allSorted = [...tlAllPosts].sort((a, b) =>
      ((b.likeCount||0) + (b.repostCount||0) + (b.replyCount||0)) -
      ((a.likeCount||0) + (a.repostCount||0) + (a.replyCount||0))
    );

    // If minEngagement > 0, keep only posts meeting threshold (fall back to all if none)
    let filtered = allSorted.filter(p =>
      (p.likeCount||0) + (p.repostCount||0) + (p.replyCount||0) >= minEngagement
    );
    if (!filtered.length) filtered = allSorted;
    if (!filtered.length) return;

    // Sort filtered posts chronologically for placement
    const posts = [...filtered].sort((a, b) =>
      new Date(a.record?.createdAt||0) - new Date(b.record?.createdAt||0)
    );

    // Time axis uses the explicit window
    const timeStart  = tlWindowStart;
    const timeEnd    = tlWindowEnd;
    const totalSpan  = timeEnd - timeStart || 3600000;

    const wrapW  = wrapEl.clientWidth  || 600;
    const wrapH  = wrapEl.clientHeight || Math.max(300, Math.round(window.innerHeight * 0.65));

    // Pixel-per-ms: fit totalSpan into wrapW with min density
    const MIN_PX_PER_HOUR = 40;
    const minW = Math.round((totalSpan / 3600000) * MIN_PX_PER_HOUR);
    const containerW = Math.max(wrapW, minW);
    const pxPerMs    = containerW / totalSpan;

    const CARD_W   = 158;
    // CARD_H must match the actual CSS-rendered card height exactly.
    // Card = border(4) + padding(8) + author-row(18) + gap(2) + text-2lines(28) + footer(12) = 72px
    const CARD_H   = 72;
    const LANE_H   = CARD_H + 4;  // 76px per lane — 4px breathing room between adjacent lanes
    const GAP_AXIS = 6;            // gap between axis line and nearest card edge
    // Tick labels sit at AXIS_Y+18; allow 26px below axis before cards start
    const TICK_H   = 26;
    const AXIS_Y   = Math.round(wrapH / 2);

    // Compute max lanes separately for above vs below, using actual available space
    const MAX_LANES_ABOVE = Math.max(1, Math.floor((AXIS_Y - GAP_AXIS) / LANE_H));
    const MAX_LANES_BELOW = Math.max(1, Math.floor((wrapH - AXIS_Y - TICK_H) / LANE_H));

    scrollInner.style.width  = containerW + 'px';
    scrollInner.style.height = wrapH + 'px';

    // ── SVG: axis + ticks + connectors + dots ──
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width',  containerW);
    svg.setAttribute('height', wrapH);
    svg.style.cssText = 'position:absolute;top:0;left:0;pointer-events:none;z-index:1';

    const axisLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    axisLine.setAttribute('x1', 0); axisLine.setAttribute('y1', AXIS_Y);
    axisLine.setAttribute('x2', containerW); axisLine.setAttribute('y2', AXIS_Y);
    axisLine.setAttribute('stroke', '#0A0A0A'); axisLine.setAttribute('stroke-width', '2');
    svg.appendChild(axisLine);

    // Smart tick interval
    const TICK_CANDIDATES = [60000, 300000, 600000, 900000, 1800000, 3600000,
                              7200000, 21600000, 43200000, 86400000];
    const targetTicks   = Math.max(4, Math.min(10, Math.floor(containerW / 80)));
    const idealInterval = totalSpan / targetTicks;
    const tickInterval  = TICK_CANDIDATES.reduce((best, iv) =>
      Math.abs(iv - idealInterval) < Math.abs(best - idealInterval) ? iv : best
    );

    const firstTick = Math.ceil(timeStart / tickInterval) * tickInterval;
    for (let t = firstTick; t <= timeEnd; t += tickInterval) {
      const x = Math.round((t - timeStart) * pxPerMs);
      if (x < 0 || x > containerW) continue;

      const tick = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      tick.setAttribute('x1', x); tick.setAttribute('y1', AXIS_Y - 6);
      tick.setAttribute('x2', x); tick.setAttribute('y2', AXIS_Y + 6);
      tick.setAttribute('stroke', '#0A0A0A'); tick.setAttribute('stroke-width', '1');
      svg.appendChild(tick);

      const d    = new Date(t);
      const h12  = d.getHours() % 12 || 12;
      const ampm = d.getHours() >= 12 ? 'PM' : 'AM';
      const mm   = String(d.getMinutes()).padStart(2, '0');
      let lbl;
      if (tickInterval >= 86400000)      lbl = `${d.getMonth()+1}/${d.getDate()}`;
      else if (d.getMinutes() === 0)     lbl = `${h12}${ampm}`;
      else                               lbl = `${h12}:${mm}${ampm}`;

      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      label.setAttribute('x', x); label.setAttribute('y', AXIS_Y + 18);
      label.setAttribute('text-anchor', 'middle');
      label.setAttribute('font-size', '10');
      label.setAttribute('fill', '#555');
      label.setAttribute('font-family', 'Inter, sans-serif');
      label.textContent = lbl;
      svg.appendChild(label);
    }

    scrollInner.appendChild(svg);

    // ── Cards: strict non-overlap placement ──
    // Each lane tracks the x right-edge of its last placed card.
    // Above and below have independent lane counts from available space.
    const laneAboveEnd = new Array(MAX_LANES_ABOVE).fill(-Infinity);
    const laneBelowEnd = new Array(MAX_LANES_BELOW).fill(-Infinity);
    const CARD_MARGIN  = 6; // min px gap between horizontally adjacent cards in same lane
    let preferAbove = true;

    posts.forEach(post => {
      const t   = new Date(post.record?.createdAt || 0).getTime();
      const cx  = Math.round((t - timeStart) * pxPerMs);
      const cardLeft  = Math.max(0, Math.min(cx - Math.floor(CARD_W / 2), containerW - CARD_W));
      const cardRight = cardLeft + CARD_W;

      const freeAbove = () => {
        for (let i = 0; i < MAX_LANES_ABOVE; i++)
          if (cardLeft >= laneAboveEnd[i] + CARD_MARGIN) return i;
        return -1;
      };
      const freeBelow = () => {
        for (let i = 0; i < MAX_LANES_BELOW; i++)
          if (cardLeft >= laneBelowEnd[i] + CARD_MARGIN) return i;
        return -1;
      };

      let isAbove, laneIdx;
      if (preferAbove) {
        laneIdx = freeAbove();
        if (laneIdx >= 0) { isAbove = true; }
        else { laneIdx = freeBelow(); isAbove = false; }
      } else {
        laneIdx = freeBelow();
        if (laneIdx >= 0) { isAbove = false; }
        else { laneIdx = freeAbove(); isAbove = true; }
      }
      preferAbove = !preferAbove;

      if (laneIdx < 0) return; // no lanes free — skip (zoom in to see this post)

      if (isAbove) laneAboveEnd[laneIdx] = cardRight;
      else         laneBelowEnd[laneIdx] = cardRight;

      // Y position: above counts from axis upward, below starts after tick-label zone
      const cardY = isAbove
        ? AXIS_Y - GAP_AXIS - CARD_H - laneIdx * LANE_H   // above: grows upward
        : AXIS_Y + TICK_H + laneIdx * LANE_H;              // below: starts after tick labels

      // Connector and dot — only for this card
      const connY = isAbove ? cardY + CARD_H : cardY;
      const conn = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      conn.setAttribute('x1', cx); conn.setAttribute('y1', AXIS_Y);
      conn.setAttribute('x2', cx); conn.setAttribute('y2', connY);
      conn.setAttribute('stroke', '#0047FF');
      conn.setAttribute('stroke-width', '1.5');
      conn.setAttribute('stroke-dasharray', '3 2');
      svg.appendChild(conn);

      const dot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      dot.setAttribute('cx', cx); dot.setAttribute('cy', AXIS_Y);
      dot.setAttribute('r', '4');
      dot.setAttribute('fill', '#FF5C35');
      dot.setAttribute('stroke', '#0A0A0A');
      dot.setAttribute('stroke-width', '1.5');
      svg.appendChild(dot);

      // Card
      const author = post.author || {};
      const record = post.record || {};
      const text   = (record.text || '').slice(0, 70) + ((record.text||'').length > 70 ? '…' : '');
      const eng    = (post.likeCount||0) + (post.repostCount||0) + (post.replyCount||0);

      const card = document.createElement('div');
      card.className = 'timeline-post-card';
      card.style.cssText = `position:absolute;left:${cardLeft}px;top:${cardY}px;width:${CARD_W}px;z-index:2`;
      card.innerHTML = `
        <div class="timeline-card-author">
          <img src="${escHtml(author.avatar || window._bskyAvatarFallback)}" class="timeline-card-avatar" alt="" onerror="this.onerror=null;this.src=window._bskyAvatarFallback">
          <span class="timeline-card-handle">@${escHtml(author.handle||'')}</span>
        </div>
        <div class="timeline-card-text">${escHtml(text)}</div>
        <div class="timeline-card-footer">
          <span class="timeline-card-eng">♥ ${formatCount(post.likeCount||0)} ↺ ${formatCount(post.repostCount||0)}</span>
        </div>
      `;
      card.addEventListener('click', () => openThread(post.uri, post.cid, author.handle));
      scrollInner.appendChild(card);
    });

    // Scroll to right edge (most recent) after render
    requestAnimationFrame(() => {
      wrapEl.scrollLeft = Math.max(0, containerW - wrapW);
    });
  }

  // Save timeline as channel
  $('timeline-save-btn').addEventListener('click', () => {
    if (!tlQuery) return;
    const name = prompt('Save timeline as channel:', tlQuery);
    if (!name?.trim()) return;
    const list = channelsLoad();
    if (list.some(c => c.query === tlQuery && c.type === 'timeline')) {
      showBanner('Already saved!');
      return;
    }
    const id = String(Date.now());
    list.push({
      id, name: name.trim(), query: tlQuery, type: 'timeline',
      lastSeenAt: new Date().toISOString(), unreadCount: 0,
    });
    channelsSave(list);
    renderChannelsSidebar();
    showBanner('Saved to channels!');
  });

  // Re-render timeline on resize (recalculates wrapH and containerW)
  let tlResizeTimer;
  window.addEventListener('resize', () => {
    if (!tlAllPosts.length) return;
    clearTimeout(tlResizeTimer);
    tlResizeTimer = setTimeout(tlRender, 150);
  });

  // Attach autocomplete to timeline search
  attachMentionAutocomplete($('timeline-search-input'));

  /* ================================================================
     BOOT
  ================================================================ */
  init();
})();
