// js/auth.js — session helpers: read, guard, clear

/**
 * Return the decoded JWT payload stored in localStorage, or null.
 * @returns {{ sub: string, role: string, username: string }|null}
 */
export function currentUser() {
  const token = localStorage.getItem('token');
  if (!token) return null;
  try {
    // JWT payload is the second segment, base64url-encoded
    let b64 = token.split('.')[1];
    b64 = b64.replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4;
    if (pad) b64 += '='.repeat(4 - pad);
    return JSON.parse(atob(b64));
  } catch (_) {
    return null;
  }
}

/**
 * Return the role string ("Owner" | "Employee" | "Customer") or null.
 * @returns {string|null}
 */
export function currentRole() {
  return localStorage.getItem('role');
}

/**
 * Guard a page. Call at the top of every page script.
 * If the user is not logged in → login page.
 * If the user's role is not in allowedRoles → 403 page.
 * Returns true if access is allowed (so the page can continue loading).
 *
 * @param {string[]} allowedRoles  e.g. ['Owner'] or ['Owner','Employee']
 * @returns {boolean}
 */
export function requireRole(allowedRoles) {
  const token = localStorage.getItem('token');
  const role  = localStorage.getItem('role');

  if (!token) {
    window.location.href = _resolveRoot('index.html');
    return false;
  }

  if (allowedRoles.length > 0 && !allowedRoles.includes(role)) {
    window.location.href = _resolveRoot('403.html');
    return false;
  }

  return true;
}

/**
 * Clear the session and redirect to the login page.
 */
export function logout() {
  localStorage.removeItem('token');
  localStorage.removeItem('role');
  localStorage.removeItem('user');
  window.location.href = _resolveRoot('index.html');
}

/** Resolve a root-level path regardless of current subdirectory depth. */
function _resolveRoot(path) {
  const base = window.location.pathname.split('/app/')[0] + '/app/';
  return base + path;
}

