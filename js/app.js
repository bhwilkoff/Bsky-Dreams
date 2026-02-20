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

  const navSearchBtn   = $('nav-search-btn');
  const navComposeBtn  = $('nav-compose-btn');
  const navProfileBtn  = $('nav-profile-btn');
  const navAvatar      = $('nav-avatar');
  const navHandle      = $('nav-handle');

  const viewSearch     = $('view-search');
  const viewCompose    = $('view-compose');
  const viewThread     = $('view-thread');

  const searchForm     = $('search-form');
  const searchInput    = $('search-input');
  const searchResults  = $('search-results');
  const filterChips    = document.querySelectorAll('.filter-chip');

  const composeForm    = $('compose-form');
  const composeText    = $('compose-text');
  const composeCount   = $('compose-char-count');
  const composeError   = $('compose-error');
  const composeSuccess = $('compose-success');
  const composeAvatar  = $('compose-avatar');

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

  /* ================================================================
     STATE
  ================================================================ */
  let currentView      = 'search';
  let activeFilter     = 'posts';
  let currentThread    = null;  // { rootPost, replyToUri, replyToCid, replyToHandle }
  let ownProfile       = null;

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
     INIT — check stored session on page load
  ================================================================ */
  async function init() {
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
  function showView(name) {
    currentView = name;

    const views = { search: viewSearch, compose: viewCompose, thread: viewThread };
    const navBtns = { search: navSearchBtn, compose: navComposeBtn };

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
    }
  }

  navSearchBtn.addEventListener('click', () => showView('search'));
  navComposeBtn.addEventListener('click', () => showView('compose'));

  threadBackBtn.addEventListener('click', () => showView('search'));

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

  searchForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const q = searchInput.value.trim();
    if (!q) return;
    showLoading();
    searchResults.innerHTML = '<div class="feed-loading">Searching…</div>';
    try {
      if (activeFilter === 'users') {
        const data = await API.searchActors(q);
        renderActorResults(data.actors || []);
      } else {
        const sort = activeFilter === 'latest' ? 'latest' : 'top';
        const data = await API.searchPosts(q, sort);
        renderPostFeed(data.posts || [], searchResults);
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
      const card = document.createElement('div');
      card.className = 'post-card';
      card.innerHTML = `
        <div class="post-header">
          <img src="${escHtml(actor.avatar || '')}" alt="" class="post-avatar">
          <div class="post-meta">
            <div class="post-display-name">${escHtml(actor.displayName || actor.handle)}</div>
            <div class="post-handle">@${escHtml(actor.handle)}</div>
          </div>
        </div>
        ${actor.description ? `<p class="post-text">${escHtml(actor.description)}</p>` : ''}
      `;
      searchResults.appendChild(card);
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
    if (!posts.length) {
      container.innerHTML = '<div class="feed-empty"><p>No results found.</p></div>';
      return;
    }
    posts.forEach((post) => {
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
        <img src="${escHtml(author.avatar || '')}" alt="" class="post-avatar" loading="lazy">
        <div class="post-meta">
          <div class="post-display-name">${escHtml(author.displayName || author.handle || '')}</div>
          <div class="post-handle">@${escHtml(author.handle || '')}</div>
        </div>
        <time class="post-timestamp" datetime="${escHtml(record.createdAt || '')}">${ts}</time>
      </div>
      <p class="post-text">${renderPostText(record.text || '')}</p>
    `;

    // Embedded images
    if (embed.$type === 'app.bsky.embed.images#view' && embed.images?.length) {
      const grid = buildImageGrid(embed.images);
      card.appendChild(grid);
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
      <button class="action-btn repost-action-btn" aria-label="Repost (${repostCount})" data-uri="${escHtml(post.uri)}" data-cid="${escHtml(post.cid)}">
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
        if (e.target.closest('button')) return; // don't intercept action button clicks
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

    // Repost button
    actions.querySelector('.repost-action-btn').addEventListener('click', async (e) => {
      e.stopPropagation();
      const btn     = e.currentTarget;
      const uri     = btn.dataset.uri;
      const cid     = btn.dataset.cid;
      const countEl = btn.querySelector('.action-count');

      btn.disabled = true;
      try {
        await API.repost(uri, cid);
        btn.classList.add('reposted');
        countEl.textContent = formatCount(parseFmtCount(countEl.textContent) + 1);
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

      grid.appendChild(wrap);
    });

    return grid;
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
        replyToUri:   uri,
        replyToCid:   cid,
        replyToHandle: handle,
      };
      setupReplyArea(uri, cid, handle);
      showView('thread');
      if (opts.focusReply) {
        setTimeout(() => replyText.focus(), 150);
      }
    } catch (err) {
      threadContent.innerHTML = `<div class="feed-empty"><p>Could not load thread: ${escHtml(err.message)}</p></div>`;
      showView('thread');
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
     COMPOSE
  ================================================================ */
  composeText.addEventListener('input', () => {
    updateCharCount(composeText, composeCount);
  });

  composeForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideError(composeError);
    const text = composeText.value.trim();
    if (!text) return;

    const btn = composeForm.querySelector('button[type="submit"]');
    btn.disabled = true;
    btn.textContent = 'Posting…';

    try {
      const result = await API.createPost(text);
      composeForm.reset();
      composeCount.textContent = '300';
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
   * Render post text with simple link detection.
   * Does NOT insert raw HTML from the API to prevent XSS.
   */
  function renderPostText(text) {
    // Escape first, then linkify URLs
    return escHtml(text).replace(
      /(https?:\/\/[^\s<>"]+)/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>'
    );
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
