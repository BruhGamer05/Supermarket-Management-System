// js/escape.js — HTML escaping; every dynamic value inserted into HTML must use esc()

/**
 * Escape a value for safe insertion as HTML text or attribute value.
 * Always prefer setting element.textContent over innerHTML;
 * use esc() only when building HTML strings.
 * @param {*} value
 * @returns {string}
 */
export function esc(value) {
  if (value == null) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

