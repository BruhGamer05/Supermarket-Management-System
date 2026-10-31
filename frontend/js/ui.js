// js/ui.js — shared UI helpers: toasts, modals, confirm dialogs, state blocks

// ── Toast notifications ─────────────────────────────────────────────────────

/**
 * Show a toast notification. Only for completed actions.
 * Errors that block a form should appear inline next to the form.
 * @param {string} message
 * @param {'success'|'error'|'info'|'warning'} [type]
 * @param {number} [durationMs]
 */
export function toast(message, type = 'info', durationMs = 3500) {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    document.body.appendChild(container);
  }

  const el = document.createElement('div');
  el.className = `toast toast--${type}`;
  el.textContent = message;
  container.appendChild(el);

  setTimeout(() => {
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 200);
  }, durationMs);
}

// ── Confirm dialog ──────────────────────────────────────────────────────────

/**
 * Show a confirm dialog. Returns a Promise that resolves to true/false.
 * Focus is trapped inside; Escape cancels.
 * @param {string} title
 * @param {string} message
 * @param {string} [confirmLabel]   Label for the confirm button (default "Confirm")
 * @param {boolean} [isDangerous]   If true, confirm button is red
 * @returns {Promise<boolean>}
 */
export function confirmDialog(title, message, confirmLabel = 'Confirm', isDangerous = false) {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay confirm-dialog';
    overlay.innerHTML = `
      <div class="modal" role="dialog" aria-modal="true" aria-labelledby="cd-title">
        <div class="modal__header">
          <span class="modal__title" id="cd-title">${_escHtml(title)}</span>
        </div>
        <div class="modal__body">
          <p>${_escHtml(message)}</p>
        </div>
        <div class="modal__footer">
          <button class="btn btn-secondary" id="cd-cancel">Cancel</button>
          <button class="btn ${isDangerous ? 'btn-danger-filled' : 'btn-primary'}" id="cd-ok">${_escHtml(confirmLabel)}</button>
        </div>
      </div>`;

    document.body.appendChild(overlay);

    const ok     = overlay.querySelector('#cd-ok');
    const cancel = overlay.querySelector('#cd-cancel');

    const cleanup = (result) => {
      overlay.remove();
      resolve(result);
    };

    ok.addEventListener('click',     () => cleanup(true));
    cancel.addEventListener('click', () => cleanup(false));
    overlay.addEventListener('click', (e) => { if (e.target === overlay) cleanup(false); });

    document.addEventListener('keydown', function handler(e) {
      if (e.key === 'Escape') { cleanup(false); document.removeEventListener('keydown', handler); }
    });

    ok.focus();
  });
}

// ── Modal ───────────────────────────────────────────────────────────────────

/**
 * Open a modal with a title, content HTML and footer HTML.
 * Returns { el, close } so the caller can control it.
 * @param {string} title
 * @param {string} contentHTML
 * @param {string} [footerHTML]
 * @param {object} [opts]
 * @param {boolean} [opts.large]
 * @returns {{ el: HTMLElement, close: () => void }}
 */
export function modal(title, contentHTML, footerHTML = '', opts = {}) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `
    <div class="modal${opts.large ? ' modal--lg' : ''}" role="dialog" aria-modal="true" aria-labelledby="m-title">
      <div class="modal__header">
        <span class="modal__title" id="m-title">${_escHtml(title)}</span>
        <button class="modal__close" aria-label="Close">&times;</button>
      </div>
      <div class="modal__body">${contentHTML}</div>
      ${footerHTML ? `<div class="modal__footer">${footerHTML}</div>` : ''}
    </div>`;

  document.body.appendChild(overlay);

  const close = () => overlay.remove();

  overlay.querySelector('.modal__close').addEventListener('click', close);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
  document.addEventListener('keydown', function handler(e) {
    if (e.key === 'Escape') { close(); document.removeEventListener('keydown', handler); }
  });

  // Move focus into modal
  const firstFocusable = overlay.querySelector('button, input, select, textarea, [tabindex="0"]');
  if (firstFocusable) firstFocusable.focus();

  return { el: overlay, close };
}

// ── Loading state ───────────────────────────────────────────────────────────

/**
 * Set a button into loading state (disabled + "Saving..." text) and return a restore function.
 * @param {HTMLButtonElement} btn
 * @param {string} [loadingText]
 * @returns {() => void}  Call to restore the button
 */
export function setLoading(btn, loadingText = 'Saving...') {
  const original = btn.textContent;
  btn.disabled = true;
  btn.textContent = loadingText;
  return () => {
    btn.disabled = false;
    btn.textContent = original;
  };
}

// ── State blocks (loading / empty / error) ──────────────────────────────────

/**
 * Replace the content of `container` with a loading spinner.
 * @param {HTMLElement} container
 * @param {string} [colspan]  For <tbody> cells
 */
export function showLoading(container, colspan) {
  if (container.tagName === 'TBODY') {
    container.innerHTML = `<tr><td colspan="${colspan || 99}" class="state-block">
      <span class="spinner"></span>
    </td></tr>`;
  } else {
    container.innerHTML = `<div class="state-block"><span class="spinner"></span></div>`;
  }
}

/**
 * Replace the content of `container` with an empty state message.
 * @param {HTMLElement} container
 * @param {string} message
 * @param {string} [colspan]
 */
export function showEmpty(container, message, colspan) {
  if (container.tagName === 'TBODY') {
    container.innerHTML = `<tr><td colspan="${colspan || 99}" class="state-block">
      <div class="state-block__title">No results</div>
      <div class="state-block__desc">${_escHtml(message)}</div>
    </td></tr>`;
  } else {
    container.innerHTML = `<div class="state-block">
      <div class="state-block__title">No results</div>
      <div class="state-block__desc">${_escHtml(message)}</div>
    </div>`;
  }
}

/**
 * Replace the content of `container` with an error state and optional Retry button.
 * @param {HTMLElement} container
 * @param {string} message
 * @param {Function} [onRetry]
 * @param {string} [colspan]
 */
export function showError(container, message, onRetry, colspan) {
  const retryBtn = onRetry
    ? `<button class="btn btn-secondary btn-sm" id="retry-btn">Retry</button>`
    : '';

  if (container.tagName === 'TBODY') {
    container.innerHTML = `<tr><td colspan="${colspan || 99}" class="state-block">
      <div class="state-block__title text-danger">Failed to load</div>
      <div class="state-block__desc">${_escHtml(message)}</div>
      ${retryBtn}
    </td></tr>`;
  } else {
    container.innerHTML = `<div class="state-block">
      <div class="state-block__title text-danger">Failed to load</div>
      <div class="state-block__desc">${_escHtml(message)}</div>
      ${retryBtn}
    </div>`;
  }

  if (onRetry) {
    container.querySelector('#retry-btn')?.addEventListener('click', onRetry);
  }
}

// ── Status badge ────────────────────────────────────────────────────────────

const BADGE_MAP = {
  'Pending':   'badge-pending',
  'Approved':  'badge-approved',
  'Fulfilled': 'badge-fulfilled',
  'Rejected':  'badge-rejected',
  'Cancelled': 'badge-cancelled',
  'OK':        'badge-ok',
  'Expiring':  'badge-expiring',
  'Expired':   'badge-expired',
  'Empty':     'badge-empty',
  'Low':       'badge-low',
  'Inactive':  'badge-inactive',
  'In stock':  'badge-instock',
  'Out of stock': 'badge-outofstock',
};

/**
 * Return an HTML string for a status badge.
 * @param {string} status
 * @returns {string}
 */
export function badge(status) {
  const cls = BADGE_MAP[status] || 'badge-cancelled';
  return `<span class="badge ${cls}">${_escHtml(status)}</span>`;
}

// ── Internal helpers ────────────────────────────────────────────────────────

function _escHtml(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

