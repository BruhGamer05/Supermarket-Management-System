// js/format.js — display formatting helpers (money, dates, quantities)
// Use these everywhere. Never print a raw ISO date or unformatted decimal.

/**
 * Format a number as Indian Rupees: ₹1,23,456.78
 * @param {number|string|null} n
 * @returns {string}
 */
export function inr(n) {
  if (n == null || n === '') return '—';
  const num = typeof n === 'string' ? parseFloat(n) : n;
  if (isNaN(num)) return '—';
  return '₹' + num.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

/**
 * Format a date as "05 Oct 2026"
 * @param {string|Date|null} d
 * @returns {string}
 */
export function date(d) {
  if (!d) return '—';
  const dt = d instanceof Date ? d : new Date(d);
  if (isNaN(dt)) return String(d);
  return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

/**
 * Format a datetime as "05 Oct 2026, 14:32" (IST)
 * @param {string|Date|null} d
 * @returns {string}
 */
export function dateTime(d) {
  if (!d) return '—';
  const dt = d instanceof Date ? d : new Date(d);
  if (isNaN(dt)) return String(d);
  return dt.toLocaleString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: false,
    timeZone: 'Asia/Kolkata'
  });
}

/**
 * Format a quantity with optional unit: "12 kg", "150 packets"
 * @param {number|null} n
 * @param {string} [unit]
 * @returns {string}
 */
export function qty(n, unit) {
  if (n == null) return '—';
  const num = typeof n === 'string' ? parseFloat(n) : n;
  if (isNaN(num)) return '—';
  const str = num.toLocaleString('en-IN');
  return unit ? `${str} ${unit}` : str;
}

/**
 * Format a number as a percentage: "18.00%"
 * @param {number|string|null} n
 * @param {number} [decimals=2]
 * @returns {string}
 */
export function percent(n, decimals = 2) {
  if (n == null) return '—';
  const num = typeof n === 'string' ? parseFloat(n) : n;
  if (isNaN(num)) return '—';
  return num.toFixed(decimals) + '%';
}

/**
 * Format a plain number with Indian grouping, no currency symbol.
 * @param {number|string|null} n
 * @param {number} [decimals=0]
 * @returns {string}
 */
export function num(n, decimals = 0) {
  if (n == null) return '—';
  const val = typeof n === 'string' ? parseFloat(n) : n;
  if (isNaN(val)) return '—';
  return val.toLocaleString('en-IN', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

