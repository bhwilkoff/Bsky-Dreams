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
  const navProfileBtn  = $('nav-profile-btn');
  const navAvatar      = $('nav-avatar');
  const navHandle      = $('nav-handle');

  const viewFeed          = $('view-feed');
  const viewSearch        = $('view-search');
  const viewCompose       = $('view-compose');
  const viewThread        = $('view-thread');
  const viewProfile       = $('view-profile');
  const viewNotifications = $('view-notifications');

  const feedResults    = $('feed-results');
  const feedRefreshBtn = $('feed-refresh-btn');
  const feedLoadMore   = $('feed-load-more');
  const feedLoadMoreBtn = $('feed-load-more-btn');

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

  const imageLightbox    = $('image-lightbox');
  const lightboxImg      = $('lightbox-img');
  const lightboxCaption  = $('lightbox-caption');
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
  let currentThread      = null;  // { rootUri, rootCid, replyToUri, replyToCid, replyToHandle }
  let ownProfile         = null;
  let hideAdultContent   = true;
  let lastSearchResults  = [];   // cached for toggle re-renders
  let lastSearchType     = null; // 'posts' | 'actors'
  let feedCursor         = null; // pagination cursor for home feed
  let feedLoaded         = false; // true after first load
  let profileActor       = null; // handle/DID currently shown in profile view
  let profileCursor      = null; // pagination cursor for profile feed
  let notifCursor        = null; // pagination cursor for notifications
  let notifLoaded        = false;
  let composeImages      = [];   // array of { file, previewUrl, altInput } for pending uploads

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
     IMAGE LIGHTBOX
  ================================================================ */
  function openLightbox(src, alt) {
    lightboxImg.src              = src;
    lightboxImg.alt              = alt || '';
    lightboxCaption.textContent  = alt || '';
    lightboxCaption.hidden       = !alt;
    imageLightbox.hidden         = false;
    document.body.style.overflow = 'hidden';
    lightboxCloseBtn.focus();
  }

  function closeLightbox() {
    imageLightbox.hidden         = true;
    lightboxImg.src              = '';
    document.body.style.overflow = '';
  }

  lightboxCloseBtn.addEventListener('click', closeLightbox);

  imageLightbox.addEventListener('click', (e) => {
    if (e.target === imageLightbox) closeLightbox();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !imageLightbox.hidden) closeLightbox();
  });

  /* ================================================================
     INIT — check stored session on page load
  ================================================================ */
  async function init() {
    // Seed history so the first Back press can return here
    history.replaceState({ view: 'search' }, '');

    if (AUTH.isLoggedIn()) {
      await enterApp();
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
      await enterApp();
    } catch (err) {
      showError(authError, err.message || 'Sign in failed. Check your handle and app password.');
    } finally {
      authSubmit.disabled = false;
      authSubmit.textContent = 'Sign in';
    }
  });

  async function enterApp() {
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
    showView('search');
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
    };
    const navBtns = {
      feed:          navFeedBtn,
      search:        navSearchBtn,
      compose:       navComposeBtn,
      notifications: navNotifBtn,
    };

    Object.entries(views).forEach(([n, el]) => {
      el.hidden  = n !== name;
      el.classList.toggle('active', n === name);
    });

    Object.entries(navBtns).forEach(([n, btn]) => {
      btn.classList.toggle('active', n === name);
      btn.setAttribute('aria-current', n === name ? 'page' : 'false');
    });

    // Reset compose state when switching to compose view
    if (name === 'compose') {
      composeForm.reset();
      composeCount.textContent = '300';
      hideError(composeError);
      composeSuccess.hidden = true;
      clearComposeImages();
    }

    if (!fromHistory) {
      const state = { view: name };
      if (name === 'search') {
        state.query  = searchInput.value;
        state.filter = activeFilter;
      }
      history.pushState(state, '');
    }
  }

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

  // Use browser history for the Back button so Forward/Back both work
  threadBackBtn.addEventListener('click',  () => history.back());
  profileBackBtn.addEventListener('click', () => history.back());

  // Restore state on browser Back/Forward
  window.addEventListener('popstate', async (e) => {
    if (!AUTH.isLoggedIn()) return;
    const state = e.state || { view: 'search' };
    if (state.view === 'thread' && state.uri) {
      await openThread(state.uri, state.cid, state.handle, { fromHistory: true });
    } else if (state.view === 'profile' && state.actor) {
      await openProfile(state.actor, { fromHistory: true });
    } else {
      const view = state.view || 'search';
      showView(view, true);
      if (view === 'search' && state.query) searchInput.value = state.query;
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
  });

  // Advanced panel toggle
  advToggleBtn.addEventListener('click', () => {
    const open = advPanel.hidden;
    advPanel.hidden = !open;
    advToggleBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
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

  searchForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const q = searchInput.value.trim();
    if (!q) return;

    showLoading();
    searchResults.innerHTML = '<div class="feed-loading">Searching…</div>';

    try {
      if (activeFilter === 'users') {
        const data = await API.searchActors(q);
        lastSearchResults = data.actors || [];
        lastSearchType    = 'actors';
        renderActorResults(lastSearchResults);
      } else {
        const sort = activeFilter === 'latest' ? 'latest' : 'top';

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

        const data = await API.searchPosts(q, sort, 25, undefined, opts);
        lastSearchResults = data.posts || [];
        lastSearchType    = 'posts';
        renderPostFeed(lastSearchResults, searchResults);
      }
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

  /* ================================================================
     HOME / FOLLOWING FEED
  ================================================================ */
  async function loadFeed(append = false) {
    if (!append) {
      feedCursor  = null;
      feedLoaded  = false;
      feedResults.innerHTML = '<div class="feed-loading">Loading your feed…</div>';
      feedLoadMore.hidden   = true;
    }

    showLoading();
    try {
      const data   = await API.getTimeline(50, append ? feedCursor : undefined);
      const items  = data.feed || [];
      feedCursor   = data.cursor || null;
      feedLoaded   = true;

      if (!append) feedResults.innerHTML = '';

      if (!items.length && !append) {
        feedResults.innerHTML = '<div class="feed-empty"><p>No posts yet. Follow some people to see their posts here.</p></div>';
      } else {
        renderFeedItems(items, feedResults, append);
      }

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

  feedRefreshBtn.addEventListener('click',    () => loadFeed(false));
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
        bar.innerHTML = `
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
          Reposted by ${escHtml(by.displayName || by.handle || 'someone')}
        `;
        wrapper.appendChild(bar);
      }

      // Reply context
      if (item.reply?.parent?.author) {
        const parentAuthor = item.reply.parent.author;
        const bar = document.createElement('div');
        bar.className = 'feed-reply-bar';
        bar.innerHTML = `
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
          Replying to @${escHtml(parentAuthor.handle || '')}
        `;
        wrapper.appendChild(bar);
      }

      const card = buildPostCard(post, { clickable: true });
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
      history.pushState({ view: 'profile', actor }, '');
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
  function renderPostFeed(posts, container) {
    container.innerHTML = '';
    const filtered = posts.filter((p) => !hasAdultContent(p));
    if (!filtered.length) {
      container.innerHTML = '<div class="feed-empty"><p>No results found.</p></div>';
      return;
    }
    filtered.forEach((post) => {
      const card = buildPostCard(post, { clickable: true });
      container.appendChild(card);
    });
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
    const ts = record.createdAt ? formatTimestamp(record.createdAt) : '';
    card.innerHTML = `
      <div class="post-header">
        <img src="${escHtml(author.avatar || '')}" alt="" class="post-avatar author-link" loading="lazy" title="View @${escHtml(author.handle || '')}">
        <div class="post-meta author-link" title="View @${escHtml(author.handle || '')}">
          <div class="post-display-name">${escHtml(author.displayName || author.handle || '')}</div>
          <div class="post-handle">@${escHtml(author.handle || '')}</div>
        </div>
        <time class="post-timestamp" datetime="${escHtml(record.createdAt || '')}">${ts}</time>
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

    // Embedded media — images, video, external links, and quoted+media
    const embedType = embed.$type;
    if (embedType === 'app.bsky.embed.images#view' && embed.images?.length) {
      card.appendChild(buildImageGrid(embed.images));
    } else if (embedType === 'app.bsky.embed.video#view') {
      card.appendChild(buildVideoEmbed(embed));
    } else if (embedType === 'app.bsky.embed.external#view' && embed.external) {
      const extEl = buildExternalEmbed(embed.external);
      if (extEl) card.appendChild(extEl);
    } else if (embedType === 'app.bsky.embed.recordWithMedia#view') {
      const media = embed.media || {};
      if (media.$type === 'app.bsky.embed.images#view' && media.images?.length) {
        card.appendChild(buildImageGrid(media.images));
      } else if (media.$type === 'app.bsky.embed.video#view') {
        card.appendChild(buildVideoEmbed(media));
      } else if (media.$type === 'app.bsky.embed.external#view' && media.external) {
        const extEl = buildExternalEmbed(media.external);
        if (extEl) card.appendChild(extEl);
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
    card.appendChild(actions);

    // Wire up click to open thread
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
        // Regular links and action buttons → let them handle their own events
        if (e.target.closest('a') || e.target.closest('button')) return;
        openThread(post.uri, post.cid, author.handle);
      });
    }

    // Reply button → open thread and focus reply area
    actions.querySelector('.reply-action-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      openThread(post.uri, post.cid, author.handle, { focusReply: true });
    });

    // Like button
    actions.querySelector('.like-action-btn').addEventListener('click', async (e) => {
      e.stopPropagation();
      const btn     = e.currentTarget;
      const uri     = btn.dataset.uri;
      const cid     = btn.dataset.cid;
      const likeUri = btn.dataset.likeUri;
      const countEl = btn.querySelector('.action-count');
      const isLiked = btn.classList.contains('liked');

      btn.disabled = true;
      try {
        if (isLiked && likeUri) {
          await API.unlikePost(likeUri);
          btn.classList.remove('liked');
          btn.dataset.likeUri = '';
          countEl.textContent = formatCount(Math.max(0, parseFmtCount(countEl.textContent) - 1));
          btn.querySelector('svg').setAttribute('fill', 'none');
        } else {
          const result = await API.likePost(uri, cid);
          btn.classList.add('liked');
          btn.dataset.likeUri = result.uri || '';
          countEl.textContent = formatCount(parseFmtCount(countEl.textContent) + 1);
          btn.querySelector('svg').setAttribute('fill', 'currentColor');
        }
      } catch (err) {
        console.error('Like error:', err.message);
      } finally {
        btn.disabled = false;
      }
    });

    // Repost button (toggle repost/unrepost)
    actions.querySelector('.repost-action-btn').addEventListener('click', async (e) => {
      e.stopPropagation();
      const btn       = e.currentTarget;
      const uri       = btn.dataset.uri;
      const cid       = btn.dataset.cid;
      const repostUri = btn.dataset.repostUri;
      const countEl   = btn.querySelector('.action-count');
      const isReposted = btn.classList.contains('reposted');

      btn.disabled = true;
      try {
        if (isReposted && repostUri) {
          await API.unrepost(repostUri);
          btn.classList.remove('reposted');
          btn.dataset.repostUri = '';
          countEl.textContent = formatCount(Math.max(0, parseFmtCount(countEl.textContent) - 1));
        } else {
          const result = await API.repost(uri, cid);
          btn.classList.add('reposted');
          btn.dataset.repostUri = result.uri || '';
          countEl.textContent = formatCount(parseFmtCount(countEl.textContent) + 1);
        }
      } catch (err) {
        console.error('Repost error:', err.message);
      } finally {
        btn.disabled = false;
      }
    });

    return card;
  }

  /* ================================================================
     IMAGE GRID
  ================================================================ */
  function buildImageGrid(images) {
    const grid = document.createElement('div');
    grid.className = `post-images count-${Math.min(images.length, 4)}`;

    images.slice(0, 4).forEach((img) => {
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

      // Click/keyboard to open full-size in lightbox
      const fullsrc = img.fullsize || img.thumb || '';
      wrap.addEventListener('click', (e) => {
        e.stopPropagation();
        openLightbox(fullsrc, img.alt || '');
      });
      wrap.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          e.stopPropagation();
          openLightbox(fullsrc, img.alt || '');
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
     THREAD VIEW
  ================================================================ */
  async function openThread(uri, cid, handle, opts = {}) {
    showLoading();
    try {
      const data = await API.getPostThread(uri);
      renderThread(data.thread, handle);
      currentThread = {
        rootUri:       uri,
        rootCid:       cid,
        replyToUri:    uri,
        replyToCid:    cid,
        replyToHandle: handle,
      };
      setupReplyArea(uri, cid, handle);
      // Switch to thread view without adding a second history entry;
      // push the thread state ourselves so Back/Forward knows the URI.
      showView('thread', true);
      if (!opts.fromHistory) {
        history.pushState({ view: 'thread', uri, cid, handle }, '');
      }
      if (opts.focusReply) {
        setTimeout(() => replyText.focus(), 150);
      }
    } catch (err) {
      threadContent.innerHTML = `<div class="feed-empty"><p>Could not load thread: ${escHtml(err.message)}</p></div>`;
      showView('thread', true);
      if (!opts.fromHistory) {
        history.pushState({ view: 'thread', uri, cid, handle }, '');
      }
    } finally {
      hideLoading();
    }
  }

  /**
   * Recursively render a thread node returned by getPostThread.
   * @param {object} node  - thread node ({ post, replies, ... })
   * @param {HTMLElement} container - target container
   * @param {boolean} isRoot
   */
  function renderThread(node, authorHandle, container, isRoot = true) {
    if (!container) {
      container = threadContent;
      container.innerHTML = '';
    }

    if (!node || !node.post) return;

    const card = buildPostCard(node.post, {
      isRoot,
      onReply: () => {
        setupReplyArea(node.post.uri, node.post.cid, node.post.author.handle);
        replyText.focus();
      },
    });

    // Make reply button set this post as the reply target
    const replyBtn = card.querySelector('.reply-action-btn');
    replyBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      setupReplyArea(node.post.uri, node.post.cid, node.post.author.handle);
      threadReplyArea.hidden = false;
      replyText.focus();
    }, { capture: true }); // override the existing listener

    container.appendChild(card);

    // Render replies recursively
    if (node.replies && node.replies.length) {
      const group = document.createElement('div');
      group.className = 'reply-group';

      const connector = document.createElement('div');
      connector.className = 'reply-thread-connector';
      group.appendChild(connector);

      // Collapse long reply lists
      const MAX_VISIBLE = 5;
      const replies = node.replies.filter((r) => r.$type !== 'app.bsky.feed.defs#blockedPost');

      replies.slice(0, MAX_VISIBLE).forEach((reply) => {
        renderThread(reply, authorHandle, group, false);
      });

      if (replies.length > MAX_VISIBLE) {
        const remaining = replies.length - MAX_VISIBLE;
        const toggle = document.createElement('button');
        toggle.className = 'collapse-toggle';
        toggle.textContent = `Show ${remaining} more repl${remaining === 1 ? 'y' : 'ies'}`;
        toggle.addEventListener('click', () => {
          replies.slice(MAX_VISIBLE).forEach((reply) => {
            renderThread(reply, authorHandle, group, false);
          });
          toggle.remove();
        });
        group.appendChild(toggle);
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
     COMPOSE — SUBMIT
  ================================================================ */
  composeText.addEventListener('input', () => {
    updateCharCount(composeText, composeCount);
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

      const result = await API.createPost(text, null, uploadedImages);
      composeForm.reset();
      composeCount.textContent = '300';
      clearComposeImages();
      composeSuccess.hidden = false;

      // Build a shareable bsky.app link from the AT URI
      if (result.uri && ownProfile) {
        const rkey = result.uri.split('/').pop();
        const postLink = $('compose-post-link');
        postLink.href = `https://bsky.app/profile/${ownProfile.handle}/post/${rkey}`;
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
        html += `<span class="mention-text">${escHtml(segText)}</span>`;
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
