/**
 * auth.js — BlueSky authentication management
 *
 * Handles login via app-password, session persistence in localStorage,
 * and session retrieval/destruction.
 *
 * Nothing in this file contacts any server other than bsky.social.
 * Credentials are never forwarded to any third party.
 */

const AUTH = (() => {
  const SESSION_KEY = 'bsky_session';
  const BSKY_BASE   = 'https://bsky.social/xrpc';

  /**
   * Attempt to create a new BlueSky session.
   * @param {string} identifier - handle or DID (e.g. "you.bsky.social")
   * @param {string} password   - app password
   * @returns {Promise<object>} - session object from API
   */
  async function login(identifier, password) {
    const res = await fetch(`${BSKY_BASE}/com.atproto.server.createSession`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier, password }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || `Login failed (${res.status})`);
    }

    const session = await res.json();
    saveSession(session);
    return session;
  }

  /**
   * Attempt to refresh an existing session using its refreshJwt.
   * Updates the stored session on success.
   * @param {string} refreshJwt
   * @returns {Promise<object>} - refreshed session
   */
  async function refreshSession(refreshJwt) {
    const res = await fetch(`${BSKY_BASE}/com.atproto.server.refreshSession`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${refreshJwt}`,
      },
    });

    if (!res.ok) {
      throw new Error('Session refresh failed — please sign in again.');
    }

    const session = await res.json();
    // Preserve DID and handle from the stored session since refresh may omit them
    const stored = getSession();
    if (stored) {
      session.did    = session.did    || stored.did;
      session.handle = session.handle || stored.handle;
    }
    saveSession(session);
    return session;
  }

  /**
   * Save a session object to localStorage.
   * @param {object} session
   */
  function saveSession(session) {
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  }

  /**
   * Retrieve the stored session, or null if none.
   * @returns {object|null}
   */
  function getSession() {
    try {
      const raw = localStorage.getItem(SESSION_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  /**
   * Remove the stored session (sign out).
   */
  function clearSession() {
    localStorage.removeItem(SESSION_KEY);
  }

  /**
   * Return true if a session is stored (does not validate the token).
   * @returns {boolean}
   */
  function isLoggedIn() {
    const s = getSession();
    return !!(s && s.accessJwt);
  }

  return { login, refreshSession, saveSession, getSession, clearSession, isLoggedIn };
})();
