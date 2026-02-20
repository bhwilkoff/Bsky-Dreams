/**
 * api.js — BlueSky AT Protocol HTTP API wrapper
 *
 * All network calls to bsky.social go through this module.
 * No other file should call fetch() against bsky.social directly.
 *
 * AT Protocol XRPC reference: https://docs.bsky.app/docs/category/http-reference
 */

const API = (() => {
  const BASE = 'https://bsky.social/xrpc';

  /* ----------------------------------------------------------------
     Internal helpers
  ---------------------------------------------------------------- */

  /**
   * Make an authenticated GET request.
   * Automatically retries once with a refreshed token on 401.
   */
  async function authGet(lexicon, params = {}) {
    return withAuth((token) => get(lexicon, params, token));
  }

  /**
   * Make an authenticated POST request.
   * Automatically retries once with a refreshed token on 401.
   */
  async function authPost(lexicon, body = {}) {
    return withAuth((token) => post(lexicon, body, token));
  }

  /**
   * Wraps an API call with automatic token refresh on 401.
   */
  async function withAuth(apiFn) {
    const session = AUTH.getSession();
    if (!session) throw new Error('Not authenticated.');

    try {
      return await apiFn(session.accessJwt);
    } catch (err) {
      if (err.status === 401 && session.refreshJwt) {
        const refreshed = await AUTH.refreshSession(session.refreshJwt);
        return apiFn(refreshed.accessJwt);
      }
      throw err;
    }
  }

  async function get(lexicon, params = {}, token = null) {
    const url = new URL(`${BASE}/${lexicon}`);
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== null) url.searchParams.set(k, v);
    }
    const headers = {};
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const res = await fetch(url.toString(), { headers });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const e = new Error(err.message || `API error ${res.status}`);
      e.status = res.status;
      throw e;
    }
    return res.json();
  }

  async function post(lexicon, body = {}, token = null) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const res = await fetch(`${BASE}/${lexicon}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const e = new Error(err.message || `API error ${res.status}`);
      e.status = res.status;
      throw e;
    }
    // Some endpoints return 200 with no body
    const text = await res.text();
    return text ? JSON.parse(text) : {};
  }

  /* ----------------------------------------------------------------
     Public API surface
  ---------------------------------------------------------------- */

  /**
   * Search posts (app.bsky.feed.searchPosts)
   * @param {string} query        - search term or advanced query
   * @param {string} sort         - "top" | "latest" (default: "top")
   * @param {number} limit        - results per page (default: 25)
   * @param {string} cursor       - pagination cursor
   * @param {object} opts         - additional filters
   * @param {string} opts.author  - restrict to posts by this handle
   * @param {string} opts.mentions - restrict to posts mentioning this handle
   * @param {string} opts.lang    - language code (e.g. "en")
   * @param {string} opts.domain  - posts linking to this domain
   * @param {string} opts.url     - posts linking to this exact URL
   * @param {string} opts.tag     - posts with this hashtag (without #)
   * @param {string} opts.since   - ISO 8601 datetime lower bound
   * @param {string} opts.until   - ISO 8601 datetime upper bound
   */
  async function searchPosts(query, sort = 'top', limit = 25, cursor, opts = {}) {
    return authGet('app.bsky.feed.searchPosts', {
      q:        query,
      sort,
      limit,
      cursor,
      author:   opts.author   || undefined,
      mentions: opts.mentions || undefined,
      lang:     opts.lang     || undefined,
      domain:   opts.domain   || undefined,
      url:      opts.url      || undefined,
      tag:      opts.tag      || undefined,
      since:    opts.since    || undefined,
      until:    opts.until    || undefined,
    });
  }

  /**
   * Search actors/users (app.bsky.actor.searchActors)
   */
  async function searchActors(query, limit = 25, cursor) {
    return authGet('app.bsky.actor.searchActors', { q: query, limit, cursor });
  }

  /**
   * Get a post thread (app.bsky.feed.getPostThread)
   * @param {string} uri    - AT URI of the root post (at://did/collection/rkey)
   * @param {number} depth  - reply depth to fetch (default: 10)
   */
  async function getPostThread(uri, depth = 10) {
    return authGet('app.bsky.feed.getPostThread', { uri, depth });
  }

  /**
   * Get a post by its AT URI (returns a single-post thread).
   */
  async function getPost(uri) {
    return getPostThread(uri, 0);
  }

  /**
   * Create a new post (com.atproto.repo.createRecord)
   * @param {string} text          - post text (max 300 chars)
   * @param {object|null} replyRef - { root: {uri,cid}, parent: {uri,cid} }
   */
  async function createPost(text, replyRef = null) {
    const session = AUTH.getSession();
    if (!session) throw new Error('Not authenticated.');

    const record = {
      $type:     'app.bsky.feed.post',
      text:      text.trim(),
      createdAt: new Date().toISOString(),
      langs:     ['en'],
    };
    if (replyRef) record.reply = replyRef;

    return authPost('com.atproto.repo.createRecord', {
      repo:       session.did,
      collection: 'app.bsky.feed.post',
      record,
    });
  }

  /**
   * Like a post (com.atproto.repo.createRecord → app.bsky.feed.like)
   * @param {string} uri
   * @param {string} cid
   */
  async function likePost(uri, cid) {
    const session = AUTH.getSession();
    return authPost('com.atproto.repo.createRecord', {
      repo:       session.did,
      collection: 'app.bsky.feed.like',
      record: {
        $type:     'app.bsky.feed.like',
        subject:   { uri, cid },
        createdAt: new Date().toISOString(),
      },
    });
  }

  /**
   * Unlike a post by deleting the like record.
   * @param {string} likeUri - AT URI of the like record
   */
  async function unlikePost(likeUri) {
    const session = AUTH.getSession();
    const parts = likeUri.split('/');
    return authPost('com.atproto.repo.deleteRecord', {
      repo:       session.did,
      collection: 'app.bsky.feed.like',
      rkey:       parts[parts.length - 1],
    });
  }

  /**
   * Unrepost by deleting the repost record.
   * @param {string} repostUri - AT URI of the repost record
   */
  async function unrepost(repostUri) {
    const session = AUTH.getSession();
    const parts = repostUri.split('/');
    return authPost('com.atproto.repo.deleteRecord', {
      repo:       session.did,
      collection: 'app.bsky.feed.repost',
      rkey:       parts[parts.length - 1],
    });
  }

  /**
   * Repost (com.atproto.repo.createRecord → app.bsky.feed.repost)
   */
  async function repost(uri, cid) {
    const session = AUTH.getSession();
    return authPost('com.atproto.repo.createRecord', {
      repo:       session.did,
      collection: 'app.bsky.feed.repost',
      record: {
        $type:     'app.bsky.feed.repost',
        subject:   { uri, cid },
        createdAt: new Date().toISOString(),
      },
    });
  }

  /**
   * Get the logged-in user's profile (app.bsky.actor.getProfile)
   */
  async function getOwnProfile() {
    const session = AUTH.getSession();
    return authGet('app.bsky.actor.getProfile', { actor: session.did });
  }

  /**
   * Convert a bsky.app post URL to an AT URI.
   * e.g. https://bsky.app/profile/alice.bsky.social/post/3abc123
   * → at://alice.bsky.social/app.bsky.feed.post/3abc123
   *
   * Resolves handle to DID if needed for full AT URI.
   */
  async function resolvePostUrl(url) {
    const m = url.match(/bsky\.app\/profile\/([^/]+)\/post\/([^/?#]+)/);
    if (!m) throw new Error('Not a recognized bsky.app post URL.');
    const handle = m[1];
    const rkey   = m[2];

    // Resolve handle → DID
    const identity = await get('com.atproto.identity.resolveHandle', { handle });
    return `at://${identity.did}/app.bsky.feed.post/${rkey}`;
  }

  return {
    searchPosts,
    searchActors,
    getPostThread,
    getPost,
    createPost,
    likePost,
    unlikePost,
    repost,
    unrepost,
    getOwnProfile,
    resolvePostUrl,
  };
})();
