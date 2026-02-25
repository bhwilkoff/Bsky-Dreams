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

  const navFeedBtn     = $('nav-feed-btn');
  const navSearchBtn   = $('nav-search-btn');
  const navComposeBtn  = $('nav-compose-btn');
  const navNotifBtn    = $('nav-notif-btn');
  const navTvBtn       = $('nav-tv-btn');
  const navProfileBtn  = $('nav-profile-btn');
  const navAvatar      = $('nav-avatar');
  const navHandle      = $('nav-handle');

  const viewFeed          = $('view-feed');
  const viewSearch        = $('view-search');
  const viewCompose       = $('view-compose');
  const viewThread        = $('view-thread');
  const viewProfile       = $('view-profile');
  const viewNotifications = $('view-notifications');
  const viewTv            = $('view-tv');

  const feedResults    = $('feed-results');
  const ptrIndicator   = $('ptr-indicator');
  const feedLoadMore   = $('feed-load-more');
  const feedLoadMoreBtn = $('feed-load-more-btn');
  const feedTabFollowing = $('feed-tab-following');
  const feedTabDiscover  = $('feed-tab-discover');

  const profileHeaderEl    = $('profile-header');
  const profileFeedEl      = $('profile-feed');
  const profileLoadMore    = $('profile-load-more');
  const profileLoadMoreBtn = $('profile-load-more-btn');
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
  const notifLoadMore    = $('notif-load-more');
  const notifLoadMoreBtn = $('notif-load-more-btn');
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

  // M40 — Seen-posts deduplication
  const FEED_SEEN_KEY = 'bsky_feed_seen';
  const FEED_SEEN_MAX = 5000;
  let feedSeenMap     = loadFeedSeen();  // Map<uri, { seenAt, likeCount, repostCount }>
  let feedSeenBypass  = false;           // session flag: "show anyway" escape hatch

  // M20 — Cross-device prefs sync
  const PREFS_COLLECTION = 'app.bsky-dreams.prefs';
  const PREFS_RKEY       = 'self';
  let prefsSyncTimer     = null;

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

      const nameEl = document.createElement('span');
      nameEl.className   = 'channel-name';
      nameEl.textContent = ch.name;
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

    // Populate search input and set filter to "latest"
    searchInput.value = ch.query;
    filterChips.forEach((c) => c.classList.remove('active'));
    activeFilter = 'latest';
    const latestChip = document.querySelector('.filter-chip[data-filter="latest"]');
    if (latestChip) latestChip.classList.add('active');

    // Switch to search view and run the search
    showView('search');
    searchForm.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));

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
    appScreen.hidden  = true;
    authScreen.hidden = false;
    sidebarOwnProfile.hidden = true;
    ownProfile = null;
    feedLoaded = false;
    notifLoaded = false;
    notifBadge.hidden = true;
    closeSidebar();
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
  }

  function markFeedPostSeen(uri, likeCount, repostCount) {
    if (!uri || feedSeenMap.has(uri)) return;
    if (feedSeenMap.size >= FEED_SEEN_MAX) {
      feedSeenMap.delete(feedSeenMap.keys().next().value); // evict oldest (FIFO)
    }
    feedSeenMap.set(uri, { seenAt: Date.now(), likeCount: likeCount || 0, repostCount: repostCount || 0 });
    saveFeedSeen();
  }

  function isFeedPostSeen(uri, likeCount, repostCount) {
    if (feedSeenBypass) return false;
    const entry = feedSeenMap.get(uri);
    if (!entry) return false;
    // "Gone viral" threshold: resurface if engagement jumped by ≥ 50
    const delta = (likeCount || 0) + (repostCount || 0)
                - (entry.likeCount || 0) - (entry.repostCount || 0);
    return delta < 50;
  }

  function showFeedSeenHint(count) {
    document.querySelector('.feed-seen-hint')?.remove();
    const hint = document.createElement('div');
    hint.className = 'feed-seen-hint';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'btn btn-ghost feed-seen-hint-btn';
    btn.textContent = `${count} post${count === 1 ? '' : 's'} filtered as already seen (show anyway)`;
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

  /* ================================================================
     M32 — iOS SAFARI PWA SESSION PERSISTENCE
  ================================================================ */
  function getJwtExp(token) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      return typeof payload.exp === 'number' ? payload.exp * 1000 : null;
    } catch { return null; }
  }

  async function handleVisibilityChange() {
    if (document.hidden || !AUTH.isLoggedIn()) return;
    const session = AUTH.getSession();
    if (!session?.accessJwt || !session?.refreshJwt) return;

    const exp = getJwtExp(session.accessJwt);
    if (!exp) return;

    const msUntilExpiry = exp - Date.now();

    if (msUntilExpiry < 0) {
      // Access token expired — try to refresh using the refresh token
      try {
        await AUTH.refreshSession(session.refreshJwt);
      } catch {
        // Both tokens expired — return to auth screen with a message
        AUTH.clearSession();
        appScreen.hidden  = true;
        authScreen.hidden = false;
        showError(authError, 'Your session expired. Please sign in again.');
      }
    } else if (msUntilExpiry < 15 * 60 * 1000) {
      // Within 15 minutes of expiry — proactively refresh
      try { await AUTH.refreshSession(session.refreshJwt); } catch { /* non-fatal */ }
    }
  }

  document.addEventListener('visibilitychange', handleVisibilityChange);

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
  let lightboxImages  = [];   // [{ src, alt }, ...]
  let lightboxIndex   = 0;
  let lightboxTouchX  = null; // for swipe detection

  function openLightbox(images, startIndex = 0) {
    // Accept either an array of {src,alt} objects or a single {src,alt}
    lightboxImages = Array.isArray(images) ? images : [images];
    lightboxIndex  = Math.max(0, Math.min(startIndex, lightboxImages.length - 1));

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
    document.body.style.overflow = '';
  }

  lightboxCloseBtn.addEventListener('click', closeLightbox);
  lightboxPrevBtn.addEventListener('click', (e) => { e.stopPropagation(); goLightbox(lightboxIndex - 1); });
  lightboxNextBtn.addEventListener('click', (e) => { e.stopPropagation(); goLightbox(lightboxIndex + 1); });

  imageLightbox.addEventListener('click', (e) => {
    if (e.target === imageLightbox) closeLightbox();
  });

  document.addEventListener('keydown', (e) => {
    if (imageLightbox.hidden) return;
    if (e.key === 'Escape')      closeLightbox();
    if (e.key === 'ArrowLeft')   goLightbox(lightboxIndex - 1);
    if (e.key === 'ArrowRight')  goLightbox(lightboxIndex + 1);
  });

  // Touch swipe support
  imageLightbox.addEventListener('touchstart', (e) => {
    lightboxTouchX = e.touches[0].clientX;
  }, { passive: true });

  imageLightbox.addEventListener('touchend', (e) => {
    if (lightboxTouchX === null) return;
    const dx = e.changedTouches[0].clientX - lightboxTouchX;
    lightboxTouchX = null;
    if (Math.abs(dx) < 40) return; // ignore small swipes
    if (dx < 0) goLightbox(lightboxIndex + 1);  // swipe left → next
    else         goLightbox(lightboxIndex - 1);  // swipe right → prev
  }, { passive: true });

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
    loadPrefsFromCloud();     // M20: merge cloud prefs with localStorage

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
    };
    const navBtns = {
      feed:          navFeedBtn,
      search:        navSearchBtn,
      compose:       navComposeBtn,
      notifications: navNotifBtn,
      tv:            navTvBtn,
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
      // M41: clear link preview and toggle panels
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
    if (!feedLoaded) loadFeed();
  });
  navSearchBtn.addEventListener('click', () => showView('search'));
  navComposeBtn.addEventListener('click', () => showView('compose'));
  navNotifBtn.addEventListener('click', () => {
    showView('notifications');
    clearNotifBadge();
    if (!notifLoaded) loadNotifications();
  });
  navTvBtn.addEventListener('click', () => showView('tv'));

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
      if (view === 'feed' && !feedLoaded) loadFeed();
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

  menuSignOut.addEventListener('click', () => {
    AUTH.clearSession();
    appScreen.hidden  = true;
    authScreen.hidden = false;
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

  /* ---- M48: Append a "Load more" button below search results ---- */
  function appendSearchLoadMore(type) {
    const existing = document.querySelector('.search-load-more');
    if (existing) existing.remove();

    const wrap = document.createElement('div');
    wrap.className = 'search-load-more';

    const btn = document.createElement('button');
    btn.className   = 'btn btn-ghost';
    btn.textContent = 'Load more';

    btn.addEventListener('click', async () => {
      btn.disabled    = true;
      btn.textContent = 'Loading…';
      try {
        if (type === 'actors') {
          const data   = await API.searchActors(lastSearchQuery, 25, searchCursor);
          const actors = data.actors || [];
          searchCursor  = data.cursor || null;
          // Append actor cards directly without wiping the container
          actors.forEach((actor) => {
            const tmpContainer = document.createElement('div');
            // Build card outside of searchResults so we don't wipe
            lastSearchResults = [...(lastSearchResults || []), actor];
          });
          renderActorResultsAppend(actors);
        } else {
          const data = await API.searchPosts(lastSearchQuery, lastSearchSort, 25, searchCursor, lastSearchOpts);
          let posts  = data.posts || [];
          searchCursor = data.cursor || null;
          posts = applyMediaFilter(posts);
          lastSearchResults = [...(lastSearchResults || []), ...posts];
          renderPostFeed(posts, searchResults, true);
        }
        wrap.remove();
        if (searchCursor) appendSearchLoadMore(type);
      } catch (err) {
        btn.disabled    = false;
        btn.textContent = 'Load more';
        console.error('Search load more error:', err.message);
      }
    });

    wrap.appendChild(btn);
    searchResults.after(wrap);
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

      // M48+M49: reset cursor and media filters on new search
      searchCursor = null;
      lastSearchQuery = q;
      document.querySelector('.search-load-more')?.remove();

      if (activeFilter === 'users') {
        const data = await API.searchActors(q);
        lastSearchResults = data.actors || [];
        lastSearchType    = 'actors';
        searchCursor      = data.cursor || null;
        renderActorResults(lastSearchResults);
        if (searchCursor) appendSearchLoadMore('actors');
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
        if (searchCursor) appendSearchLoadMore('posts');
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
      avatar.src       = actor.avatar || '';
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
      av.src = actor.avatar || ''; av.alt = ''; av.className = 'post-avatar'; av.loading = 'lazy';
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
    if (!append) {
      feedCursor     = null;
      feedLoaded     = false;
      feedSeenBypass = false; // M40: reset bypass on fresh feed load
      feedResults.innerHTML = '<div class="feed-loading">Loading your feed…</div>';
      feedLoadMore.hidden   = true;
      document.querySelector('.feed-seen-hint')?.remove(); // M40: clear old hint
    }

    showLoading();
    try {
      const data = feedMode === 'discover'
        ? await API.getFeed(DISCOVER_FEED_URI, 50, append ? feedCursor : undefined)
        : await API.getTimeline(50, append ? feedCursor : undefined);
      const items  = data.feed || [];
      feedCursor   = data.cursor || null;
      feedLoaded   = true;

      if (!append) feedResults.innerHTML = '';

      // M40: filter out already-seen posts (unless bypass is active)
      let seenCount = 0;
      const displayItems = items.filter((item) => {
        const post = item.post;
        if (!post) return true;
        if (isFeedPostSeen(post.uri, post.likeCount, post.repostCount)) {
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

      // M40+M44: show filtered hint; seen-marking is now scroll-based (IntersectionObserver below)
      if (seenCount > 0) showFeedSeenHint(seenCount);

      // M44: attach IntersectionObserver for scroll-based seen tracking
      attachFeedSeenObserver(feedResults);

      // Show "Load more" only if there's a next page
      feedLoadMore.hidden = !feedCursor;
    } catch (err) {
      if (!append) {
        feedResults.innerHTML = `<div class="feed-empty"><p>Could not load feed: ${escHtml(err.message)}</p></div>`;
      }
    } finally {
      hideLoading();
    }
  }

  /* ---- M44: Scroll-based read indicator (IntersectionObserver) ---- */
  let feedSeenObserver = null;

  function attachFeedSeenObserver(container) {
    // Disconnect any previous observer before attaching a new one
    if (feedSeenObserver) { feedSeenObserver.disconnect(); feedSeenObserver = null; }

    feedSeenObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        // Mark as seen when the card has fully scrolled above the 80% viewport line
        if (!entry.isIntersecting && entry.boundingClientRect.top < 0) {
          const card = entry.target;
          const uri  = card.dataset.uri;
          if (!uri || card.classList.contains('post-seen')) return;
          const likeCount   = parseInt(card.querySelector('.like-action-btn .action-count')?.textContent || '0', 10);
          const repostCount = parseInt(card.querySelector('.repost-action-btn .action-count')?.textContent || '0', 10);
          markFeedPostSeen(uri, likeCount, repostCount);
          card.classList.add('post-seen');
          feedSeenObserver.unobserve(card); // each card only needs to be marked once
        }
      });
    }, {
      root: null,
      rootMargin: '0px 0px -80% 0px', // card must be in top 20% of viewport to trigger
      threshold: 0,
    });

    container.querySelectorAll('.post-card[data-uri]').forEach((card) => {
      if (!card.classList.contains('post-seen')) feedSeenObserver.observe(card);
    });
  }

  /* ---- Pull-to-refresh on the home feed ---- */
  (() => {
    const PTR_THRESHOLD = 96;  // M34: increased from 64px to reduce accidental triggers
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
    if (feedMode !== 'following') { setFeedMode('following'); loadFeed(); }
  });
  feedTabDiscover.addEventListener('click', () => {
    if (feedMode !== 'discover') { setFeedMode('discover'); loadFeed(); }
  });

  /* ---- M47: Pull-to-refresh on Search + Profile views ---- */
  (() => {
    const PTR_THRESHOLD = 96;
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
  })();

  /* ---- M34: Scroll-to-top button ---- */
  (() => {
    const SCROLL_SHOW_THRESHOLD = 300;
    const ALL_VIEWS = [viewFeed, viewSearch, viewCompose, viewThread, viewProfile, viewNotifications, viewTv];

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

  feedLoadMoreBtn.addEventListener('click',    () => loadFeed(true));
  profileLoadMoreBtn.addEventListener('click', () => loadProfileFeed(profileActor, true));
  notifRefreshBtn.addEventListener('click',    () => loadNotifications(false));
  notifLoadMoreBtn.addEventListener('click',   () => loadNotifications(true));

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
        if (by.avatar) {
          const avatar = document.createElement('img');
          avatar.src       = by.avatar;
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
    });
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
    profileLoadMore.hidden    = true;
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
    avatar.src       = profile.avatar || '';
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
      reportActorBtn.setAttribute('aria-label', `Report @${profile.handle}`);
      reportActorBtn.addEventListener('click', () => {
        openReportModal({
          subject: {
            $type: 'com.atproto.admin.defs#repoRef',
            did:   profile.did,
          },
          subtitle: `Account @${escHtml(profile.handle)}`,
        });
      });
      el.appendChild(reportActorBtn);
    }

    profileHeaderEl.innerHTML = '';
    profileHeaderEl.appendChild(el);
  }

  /** Load (or append) posts for the current profile view. */
  async function loadProfileFeed(actor, append = false) {
    if (!append) {
      profileCursor = null;
      profileFeedEl.innerHTML = '<div class="feed-loading">Loading posts…</div>';
      profileLoadMore.hidden  = true;
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
      profileLoadMore.hidden = !profileCursor;
    } catch (err) {
      if (!append) {
        profileFeedEl.innerHTML = `<div class="feed-empty"><p>Could not load posts: ${escHtml(err.message)}</p></div>`;
      }
    }
  }

  /* ================================================================
     NOTIFICATIONS VIEW
  ================================================================ */
  async function loadNotifications(append = false) {
    if (!append) {
      notifCursor  = null;
      notifLoaded  = false;
      notifList.innerHTML = '<div class="feed-loading">Loading notifications…</div>';
      notifLoadMore.hidden = true;
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

      notifLoadMore.hidden = !notifCursor;
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
      avatar.src       = author.avatar || '';
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

      // Click to open profile for follows; open thread for others
      item.addEventListener('click', () => {
        if (reason === 'follow') {
          openProfile(author.handle);
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

    function markSeen(uri) {
      if (!uri || tvSeen.has(uri)) return;
      tvSeen.add(uri);
      if (tvSeen.size > TV_SEEN_MAX) tvSeen.delete(tvSeen.values().next().value);
      saveSeen();
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

        const found = dedup(posts).filter((p) => hasVideo(p) && (tvAllowAdult || !isAdultPost(p)) && !tvSeen.has(p.uri));
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
        hls.on(Hls.Events.MANIFEST_PARSED, () => { vid.play().catch(() => {}); });
        hls.on(Hls.Events.ERROR, (ev, data) => {
          if (data.fatal) { destroyHls(s); if (s === tvSlot) advanceToNext(); }
        });
        tvHlsArr[s] = hls;
      } else if (vid.canPlayType('application/vnd.apple.mpegurl')) {
        vid.src = src;
        vid.play().catch(() => {});
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
      tvAuthorAvatar.src             = author.avatar || '';
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

      markSeen(post.uri);
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
      tvAllowAdult = $('tv-adult-toggle').checked;
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

    repostOpt.addEventListener('click', async () => {
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

    quoteOpt.addEventListener('click', () => {
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

  function closeQuoteModal() {
    quoteModal.hidden   = true;
    quoteModalPostRef   = null;
  }

  quoteModalClose.addEventListener('click', closeQuoteModal);
  quoteModalCancel.addEventListener('click', closeQuoteModal);
  quoteModal.addEventListener('click', (e) => { if (e.target === quoteModal) closeQuoteModal(); });
  quoteModalText.addEventListener('input', () => {
    const remaining = 300 - quoteModalText.value.length;
    quoteModalCount.textContent = remaining;
    quoteModalCount.className = 'char-count' +
      (remaining <= 0 ? ' over' : remaining <= 20 ? ' warn' : '');
  });

  quoteModalSubmit.addEventListener('click', async () => {
    if (!quoteModalPostRef) return;
    const text = quoteModalText.value.trim();
    if (!text) { quoteModalText.focus(); return; }

    quoteModalSubmit.disabled    = true;
    quoteModalSubmit.textContent = 'Posting…';
    quoteModalError.hidden = true;

    try {
      const result = await API.createPost(text, null, [], { uri: quoteModalPostRef.uri, cid: quoteModalPostRef.cid });
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
        // Fallback if no result.uri
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
        <img src="${escHtml(author.avatar || '')}" alt="" class="post-avatar author-link" loading="lazy" title="View @${escHtml(author.handle || '')}">
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

    // Report button (⋯ overflow → report post)
    const reportBtn = document.createElement('button');
    reportBtn.type      = 'button';
    reportBtn.className = 'action-btn report-action-btn';
    reportBtn.setAttribute('aria-label', 'Report post');
    reportBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18" aria-hidden="true"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>`;
    reportBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      openReportModal({
        subject: {
          $type: 'com.atproto.repo.strongRef',
          uri:   post.uri,
          cid:   post.cid,
        },
        subtitle: `Post by @${escHtml(author.handle || '')}`,
      });
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
    avatar.src       = author.avatar || '';
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
      await API.createPost(text, replyRef);
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

    const author = post.author  || {};
    const record = post.record  || {};
    const text   = record.text  || '';

    const box = document.createElement('div');
    box.className     = 'inline-reply-box';
    box.dataset.replyTo = post.uri;

    // ---- Mini quote of the parent post ----
    const quoteEl = document.createElement('div');
    quoteEl.className = 'inline-reply-quote';

    const quoteAv = document.createElement('img');
    quoteAv.src       = author.avatar || '';
    quoteAv.alt       = '';
    quoteAv.className = 'inline-reply-quote-avatar';
    quoteEl.appendChild(quoteAv);

    const quoteContent = document.createElement('div');
    quoteContent.className = 'inline-reply-quote-content';

    const quoteAuthor = document.createElement('span');
    quoteAuthor.className   = 'inline-reply-quote-author';
    quoteAuthor.textContent = `@${author.handle || ''}`;

    const quoteSnippet  = text.length > 120 ? text.slice(0, 120) + '…' : text;
    const quoteText     = document.createTextNode(' · ' + quoteSnippet);
    quoteContent.appendChild(quoteAuthor);
    quoteContent.appendChild(quoteText);
    quoteEl.appendChild(quoteContent);
    box.appendChild(quoteEl);

    // ---- Compose row ----
    const composeEl = document.createElement('div');
    composeEl.className = 'inline-reply-compose';

    const myAv = document.createElement('img');
    myAv.src       = ownProfile?.avatar || '';
    myAv.alt       = '';
    myAv.className = 'inline-reply-user-avatar';
    composeEl.appendChild(myAv);

    const body = document.createElement('div');
    body.className = 'inline-reply-body';

    const textarea = document.createElement('textarea');
    textarea.className   = 'compose-textarea inline-reply-textarea';
    textarea.placeholder = `Reply to @${author.handle || ''}…`;
    textarea.maxLength   = 300;
    textarea.rows        = 3;
    textarea.setAttribute('aria-label', 'Reply text');
    body.appendChild(textarea);

    const footer = document.createElement('div');
    footer.className = 'inline-reply-footer';

    const countSpan = document.createElement('span');
    countSpan.className   = 'char-count';
    countSpan.textContent = '300';

    const actionsEl = document.createElement('div');
    actionsEl.className = 'inline-reply-actions';

    const errorEl = document.createElement('div');
    errorEl.className = 'inline-reply-error';
    errorEl.hidden    = true;
    errorEl.setAttribute('role', 'alert');

    const cancelBtn = document.createElement('button');
    cancelBtn.type      = 'button';
    cancelBtn.className = 'btn btn-ghost';
    cancelBtn.textContent = 'Cancel';

    const submitBtn = document.createElement('button');
    submitBtn.type      = 'button';
    submitBtn.className = 'btn btn-primary';
    submitBtn.textContent = 'Reply';

    actionsEl.appendChild(errorEl);
    actionsEl.appendChild(cancelBtn);
    actionsEl.appendChild(submitBtn);
    footer.appendChild(countSpan);
    footer.appendChild(actionsEl);
    body.appendChild(footer);
    composeEl.appendChild(body);
    box.appendChild(composeEl);

    // Insert inline after the post card
    postCard.insertAdjacentElement('afterend', box);
    box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    textarea.focus();

    // ---- Event handlers ----
    textarea.addEventListener('input', () => {
      const remaining = 300 - textarea.value.length;
      countSpan.textContent = remaining;
      countSpan.style.color = remaining < 20 ? 'var(--color-error-text)' : '';
    });

    cancelBtn.addEventListener('click', () => box.remove());

    box.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') box.remove();
    });

    submitBtn.addEventListener('click', async () => {
      const replyText = textarea.value.trim();
      if (!replyText) return;

      errorEl.hidden        = true;
      submitBtn.disabled    = true;
      submitBtn.textContent = 'Posting…';

      const replyRef = {
        root:   { uri: effectiveRoot.uri, cid: effectiveRoot.cid },
        parent: { uri: post.uri,          cid: post.cid },
      };

      try {
        await API.createPost(replyText, replyRef);
        box.remove();
        if (onSuccess) {
          // Feed context: call success callback without reloading thread
          onSuccess();
        } else {
          // Thread context: reload the full thread
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

  // GIF search via Klipy
  // Response: { result: true, data: { data: [ { title, file: { xs, gif, hd } } ] } }
  async function searchKlipyGifs(q) {
    composeGifGrid.innerHTML = '<p class="compose-gif-empty">Searching…</p>';
    try {
      const res  = await fetch(`https://api.klipy.com/api/v1/${encodeURIComponent(KLIPY_KEY)}/gifs/search?q=${encodeURIComponent(q)}&per_page=16`);
      const data = await res.json();
      const items = data?.data?.data;
      if (!items?.length) {
        composeGifGrid.innerHTML = '<p class="compose-gif-empty">No results. Try a different search.</p>';
        return;
      }
      composeGifGrid.innerHTML = '';
      items.forEach((item) => {
        const thumbUrl = item.file?.xs?.gif?.url || item.file?.xs?.jpg?.url;
        // Build a priority list of GIF URLs: try smaller variants first to stay under 950 KB
        const gifUrls = [
          item.file?.hd?.gif?.url,
          item.file?.gif?.url,
          item.file?.xs?.gif?.url,
        ].filter(Boolean);
        if (!thumbUrl || !gifUrls.length) return;
        const img = document.createElement('img');
        img.src       = thumbUrl;
        img.alt       = item.title || '';
        img.className = 'compose-gif-item';
        img.loading   = 'lazy';
        img.addEventListener('click', () => selectGif(gifUrls, item.title || ''));
        composeGifGrid.appendChild(img);
      });
    } catch (err) {
      composeGifGrid.innerHTML = `<p class="compose-gif-empty">Search failed: ${escHtml(err.message)}</p>`;
    }
  }

  composeGifSearchBtn.addEventListener('click', () => {
    const q = composeGifInput.value.trim();
    if (q) searchKlipyGifs(q);
  });
  composeGifInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); composeGifSearchBtn.click(); }
  });

  /**
   * Download the best-fitting GIF from a prioritised URL list (hd → regular → xs).
   * Uses the first variant that fits under 950 KB. Shows an error if none fit.
   * @param {string[]} gifUrls  Priority-ordered array of GIF URLs
   * @param {string}   alt
   */
  async function selectGif(gifUrls, alt) {
    const MAX_BYTES = 950_000;
    composeGifGrid.innerHTML = '<p class="compose-gif-empty">Loading…</p>';
    try {
      for (const url of gifUrls) {
        const res  = await fetch(url);
        const blob = await res.blob();
        if (blob.size <= MAX_BYTES) {
          composeImages.forEach((img) => { try { URL.revokeObjectURL(img.previewUrl); } catch {} });
          composeImages = [{ file: new File([blob], 'animation.gif', { type: 'image/gif' }), previewUrl: url, alt }];
          refreshComposePreview();
          composeGifPanel.hidden = true;
          composeGifGrid.innerHTML = '<p class="compose-gif-empty">Type above to search for GIFs</p>';
          composeGifInput.value = '';
          return;
        }
      }
      composeGifGrid.innerHTML = '<p class="compose-gif-empty">This GIF is too large to post. Try a different one.</p>';
    } catch (err) {
      composeGifGrid.innerHTML = `<p class="compose-gif-empty">Could not load GIF: ${escHtml(err.message)}</p>`;
    }
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
      composeLinkEmbed = { uri: url, title, description: desc, thumb };
      renderLinkPreviewCard(hostname);
    } catch {
      // Silently ignore — link preview is best-effort
    }
  }

  function renderLinkPreviewCard(hostname) {
    const { title, description, thumb } = composeLinkEmbed;
    composeLinkWrap.innerHTML = `
      <div class="compose-link-preview">
        ${thumb ? `<img class="compose-link-preview-thumb" src="${escHtml(thumb)}" alt="" loading="lazy">` : ''}
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
  }

  /* ================================================================
     COMPOSE — SUBMIT
  ================================================================ */
  composeText.addEventListener('input', () => {
    updateCharCount(composeText, composeCount);
    // M41: debounced link preview detection
    clearTimeout(linkPreviewTimer);
    if (composeLinkEmbed) return;
    const matches = composeText.value.match(/https?:\/\/[^\s]+/g);
    if (!matches) return;
    linkPreviewTimer = setTimeout(() => fetchLinkPreview(matches[0]), 800);
  });

  composeForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideError(composeError);
    const text = composeText.value.trim();
    if (!text && composeImages.length === 0) return;

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

      // M41: external embed only when no images are attached
      const linkEmbed = uploadedImages.length === 0 ? composeLinkEmbed : null;
      const result = await API.createPost(text, null, uploadedImages, null, linkEmbed);

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
     BOOT
  ================================================================ */
  init();
})();
