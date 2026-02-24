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

  /**
   * Upload a raw binary blob (image file) to the repo.
   * Uses binary POST — NOT JSON-encoded.
   * @param {File} file
   * @param {string} token
   * @returns {{ blob: object }} — AT Protocol blob reference
   */
  async function uploadBlobRaw(file, token) {
    const res = await fetch(`${BASE}/com.atproto.repo.uploadBlob`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': file.type || 'application/octet-stream',
      },
      body: file,
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const e = new Error(err.message || `Upload error ${res.status}`);
      e.status = res.status;
      throw e;
    }
    return res.json();
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
   * Upload an image file to the AT Protocol blob store.
   * @param {File} file - image file (JPEG, PNG, GIF, WEBP; max 1 MB)
   * @returns {object} - AT Protocol blob reference object
   */
  async function uploadBlob(file) {
    const data = await withAuth((token) => uploadBlobRaw(file, token));
    return data.blob;
  }

  /**
   * Create a new post (com.atproto.repo.createRecord)
   * @param {string}      text     - post text (max 300 chars)
   * @param {object|null} replyRef - { root: {uri,cid}, parent: {uri,cid} }
   * @param {Array}       images   - optional array of { blob, alt } objects
   *                                 where blob is the result of uploadBlob()
   */
  async function createPost(text, replyRef = null, images = [], embedRef = null) {
    const session = AUTH.getSession();
    if (!session) throw new Error('Not authenticated.');

    const record = {
      $type:     'app.bsky.feed.post',
      text:      text.trim(),
      createdAt: new Date().toISOString(),
      langs:     ['en'],
    };
    if (replyRef) record.reply = replyRef;
    if (images.length > 0) {
      record.embed = {
        $type:  'app.bsky.embed.images',
        images: images.map(({ blob, alt }) => ({ image: blob, alt: alt || '' })),
      };
    } else if (embedRef) {
      record.embed = {
        $type:  'app.bsky.embed.record',
        record: { uri: embedRef.uri, cid: embedRef.cid },
      };
    }

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
   * Get the home / following timeline (app.bsky.feed.getTimeline)
   * @param {number} limit  - results per page (default: 50)
   * @param {string} cursor - pagination cursor
   */
  async function getTimeline(limit = 50, cursor) {
    return authGet('app.bsky.feed.getTimeline', { limit, cursor });
  }

  /**
   * Get posts from an algorithmic feed generator (app.bsky.feed.getFeed)
   * @param {string} feed   - AT URI of the feed generator (e.g. Discover)
   * @param {number} limit  - results per page (default: 50)
   * @param {string} cursor - pagination cursor
   */
  async function getFeed(feed, limit = 50, cursor) {
    return authGet('app.bsky.feed.getFeed', { feed, limit, cursor });
  }

  /**
   * Follow an actor (com.atproto.repo.createRecord → app.bsky.graph.follow)
   * @param {string} subjectDid - DID of the actor to follow
   * @returns {object} - { uri, cid } of the created follow record
   */
  async function followActor(subjectDid) {
    const session = AUTH.getSession();
    return authPost('com.atproto.repo.createRecord', {
      repo:       session.did,
      collection: 'app.bsky.graph.follow',
      record: {
        $type:     'app.bsky.graph.follow',
        subject:   subjectDid,
        createdAt: new Date().toISOString(),
      },
    });
  }

  /**
   * Unfollow an actor by deleting the follow record.
   * @param {string} followUri - AT URI of the follow record
   */
  async function unfollowActor(followUri) {
    const session = AUTH.getSession();
    const parts = followUri.split('/');
    return authPost('com.atproto.repo.deleteRecord', {
      repo:       session.did,
      collection: 'app.bsky.graph.follow',
      rkey:       parts[parts.length - 1],
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
   * Get any actor's full profile (app.bsky.actor.getProfile).
   * @param {string} actor - handle or DID
   */
  async function getActorProfile(actor) {
    return authGet('app.bsky.actor.getProfile', { actor });
  }

  /**
   * Get an actor's post feed (app.bsky.feed.getAuthorFeed).
   * Excludes replies to keep the profile feed focused on their own content.
   * @param {string} actor  - handle or DID
   * @param {number} limit
   * @param {string} cursor - pagination cursor
   */
  async function getAuthorFeed(actor, limit = 25, cursor) {
    return authGet('app.bsky.feed.getAuthorFeed', {
      actor, limit, cursor, filter: 'posts_no_replies',
    });
  }

  /**
   * List notifications for the logged-in user (app.bsky.notification.listNotifications).
   * Reasons: like, repost, follow, mention, reply, quote.
   * @param {number} limit  - max results (default 50)
   * @param {string} cursor - pagination cursor
   */
  async function listNotifications(limit = 50, cursor) {
    return authGet('app.bsky.notification.listNotifications', { limit, cursor });
  }

  /**
   * Mark all notifications as seen up to the given timestamp.
   * @param {string} seenAt - ISO 8601 timestamp (default: now)
   */
  async function updateSeen(seenAt = new Date().toISOString()) {
    return authPost('app.bsky.notification.updateSeen', { seenAt });
  }

  /**
   * Convert a bsky.app post URL to an AT URI.
   * e.g. https://bsky.app/profile/alice.bsky.social/post/3abc123
   * → at://alice.bsky.social/app.bsky.feed.post/3abc123
   *
   * Resolves handle to DID if needed for full AT URI.
   */
  /**
   * Submit a moderation report (com.atproto.moderation.createReport).
   * @param {object} subject      - { $type, uri, cid } for a post, or { $type, did } for an account
   * @param {string} reasonType   - com.atproto.moderation.defs#reason* constant
   * @param {string} [reason]     - optional free-text elaboration
   */
  async function createReport(subject, reasonType, reason = '') {
    const body = { subject, reasonType };
    if (reason && reason.trim()) body.reason = reason.trim();
    return authPost('com.atproto.moderation.createReport', body);
  }

  /**
   * Read a record from the AT Protocol repo (M20 cross-device sync).
   * @param {string} repo       - DID of the repo owner
   * @param {string} collection - collection NSID
   * @param {string} rkey       - record key
   */
  async function getRecord(repo, collection, rkey) {
    return authGet('com.atproto.repo.getRecord', { repo, collection, rkey });
  }

  /**
   * Write (create/replace) a record in the AT Protocol repo (M20).
   * @param {string} repo       - DID of the repo owner
   * @param {string} collection - collection NSID
   * @param {string} rkey       - record key
   * @param {object} record     - the record value (must include $type)
   */
  async function putRecord(repo, collection, rkey, record) {
    return authPost('com.atproto.repo.putRecord', { repo, collection, rkey, record });
  }

  /**
   * Create a quote post (post with an embedded record reference) (M30).
   * @param {string} text
   * @param {{ uri: string, cid: string }} embedRef - the quoted post's AT URI and CID
   */
  async function createQuotePost(text, embedRef) {
    return createPost(text, null, [], embedRef);
  }

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
    getTimeline,
    getFeed,
    getPostThread,
    getPost,
    uploadBlob,
    createPost,
    likePost,
    unlikePost,
    repost,
    unrepost,
    followActor,
    unfollowActor,
    getOwnProfile,
    getActorProfile,
    getAuthorFeed,
    listNotifications,
    updateSeen,
    resolvePostUrl,
    createReport,
    getRecord,
    putRecord,
    createQuotePost,
  };
})();
