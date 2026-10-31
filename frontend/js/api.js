// js/api.js — HTTP client that wraps fetch, adds the JWT, and handles 401

// If running in browser over HTTP/HTTPS, use relative URL (same host/port).
// Otherwise (e.g. file:// or standalone), fallback to localhost:8000.
const API_BASE = (typeof window !== 'undefined' && window.location.protocol.startsWith('http'))
  ? ''
  : 'http://localhost:8000';

export class ApiError extends Error {
  /**
   * @param {number} status
   * @param {string} message
   */
  constructor(status, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

/**
 * Core fetch wrapper.
 * @param {'GET'|'POST'|'PUT'|'PATCH'|'DELETE'} method
 * @param {string} endpoint  e.g. '/items/'
 * @param {*} [body]         serialised as JSON if provided
 * @returns {Promise<any>}
 */
async function request(method, endpoint, body) {
  const token = localStorage.getItem('token');

  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const opts = { method, headers };
  if (body !== undefined) opts.body = JSON.stringify(body);

  let response;
  try {
    response = await fetch(`${API_BASE}${endpoint}`, opts);
  } catch (err) {
    throw new ApiError(0, 'Cannot reach the server. Check your connection.');
  }

  let data = null;
  try { data = await response.json(); } catch (_) { /* non-JSON body */ }

  if (!response.ok) {
    if (response.status === 401 && !endpoint.includes('/auth/login')) {
      localStorage.removeItem('token');
      localStorage.removeItem('role');
      localStorage.removeItem('user');
      window.location.href = _resolveRoot('session-expired.html');
    }
    const msg = data?.detail || `Request failed (${response.status})`;
    throw new ApiError(response.status, msg);
  }

  return data;
}

function _resolveRoot(path) {
  const base = window.location.pathname.split('/app/')[0] + '/app/';
  return base + path;
}

export const api = {
  get:    (endpoint)        => request('GET',    endpoint),
  post:   (endpoint, body)  => request('POST',   endpoint, body),
  put:    (endpoint, body)  => request('PUT',    endpoint, body),
  patch:  (endpoint, body)  => request('PATCH',  endpoint, body),
  delete: (endpoint)        => request('DELETE', endpoint),
};
