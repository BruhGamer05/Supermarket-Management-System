// js/charts.js — minimal SVG line and bar charts with axis labels and a table fallback
// No external libraries. Inline SVG only.

import { esc } from './escape.js?v=3';

const CHART_ACCENT  = '#1f5fa8';
const CHART_MUTED   = '#d8dce3';
const CHART_TEXT    = '#5b6676';
const CHART_SUCCESS = '#1a7f37';

/**
 * Render a bar chart into `container`.
 *
 * @param {HTMLElement} container
 * @param {Array<{label: string, value: number}>} data
 * @param {object} [opts]
 * @param {string} [opts.color]        Bar colour (default accent blue)
 * @param {string} [opts.valuePrefix]  e.g. "₹"
 * @param {number} [opts.height]       SVG height (default 200)
 * @param {boolean} [opts.showTable]   Also render an accessible table (default true)
 */
export function barChart(container, data, opts = {}) {
  if (!data || data.length === 0) {
    container.innerHTML = '<div class="state-block"><div class="state-block__desc">No data available.</div></div>';
    return;
  }

  const W           = container.clientWidth  || 600;
  const H           = opts.height            || 220;
  const PADDING     = { top: 20, right: 16, bottom: 50, left: 56 };
  const color       = opts.color             || CHART_ACCENT;
  const prefix      = opts.valuePrefix       || '';
  const showTable   = opts.showTable !== false;

  const maxVal = Math.max(...data.map(d => d.value), 0);
  const chartW = W - PADDING.left - PADDING.right;
  const chartH = H - PADDING.top  - PADDING.bottom;

  const barW   = Math.max(4, (chartW / data.length) - 4);
  const gap    = (chartW - barW * data.length) / (data.length + 1);

  // Y axis steps
  const yMax   = _niceMax(maxVal);
  const ySteps = 4;

  let svgLines = '';

  // Y gridlines + labels
  for (let i = 0; i <= ySteps; i++) {
    const val = (yMax / ySteps) * i;
    const y   = PADDING.top + chartH - (val / yMax) * chartH;
    svgLines += `<line x1="${PADDING.left}" y1="${y}" x2="${W - PADDING.right}" y2="${y}"
      stroke="${CHART_MUTED}" stroke-width="1"/>`;
    svgLines += `<text x="${PADDING.left - 6}" y="${y + 4}" text-anchor="end"
      font-size="10" fill="${CHART_TEXT}">${prefix}${_shortNum(val)}</text>`;
  }

  // Bars + X labels
  data.forEach((d, i) => {
    const barH = maxVal > 0 ? (d.value / yMax) * chartH : 0;
    const x    = PADDING.left + gap + i * (barW + gap);
    const y    = PADDING.top + chartH - barH;

    svgLines += `<rect x="${x}" y="${y}" width="${barW}" height="${barH}"
      fill="${color}" rx="2"/>`;

    // X label (rotate if many)
    const labelX = x + barW / 2;
    const rotate = data.length > 8 ? `transform="rotate(-35, ${labelX}, ${PADDING.top + chartH + 14})"` : '';
    svgLines += `<text x="${labelX}" y="${PADDING.top + chartH + 14}" text-anchor="${data.length > 8 ? 'end' : 'middle'}"
      font-size="10" fill="${CHART_TEXT}" ${rotate}>${esc(String(d.label))}</text>`;
  });

  const svg = `<svg width="100%" height="${H}" viewBox="0 0 ${W} ${H}" overflow="visible" aria-hidden="true">
    ${svgLines}
  </svg>`;

  const tableHtml = showTable ? _makeTable(data, prefix) : '';
  container.innerHTML = svg + tableHtml;
}

/**
 * Render a line chart into `container`.
 *
 * @param {HTMLElement} container
 * @param {Array<{label: string, value: number}>} data
 * @param {object} [opts]
 * @param {string} [opts.color]
 * @param {string} [opts.valuePrefix]
 * @param {number} [opts.height]
 * @param {boolean} [opts.showTable]
 */
export function lineChart(container, data, opts = {}) {
  if (!data || data.length === 0) {
    container.innerHTML = '<div class="state-block"><div class="state-block__desc">No data available.</div></div>';
    return;
  }

  const W         = container.clientWidth || 600;
  const H         = opts.height           || 220;
  const PADDING   = { top: 20, right: 16, bottom: 50, left: 56 };
  const color     = opts.color            || CHART_ACCENT;
  const prefix    = opts.valuePrefix      || '';
  const showTable = opts.showTable !== false;

  const maxVal = Math.max(...data.map(d => d.value), 0);
  const chartW = W - PADDING.left - PADDING.right;
  const chartH = H - PADDING.top  - PADDING.bottom;
  const yMax   = _niceMax(maxVal);
  const ySteps = 4;

  let svgLines = '';

  // Y gridlines + labels
  for (let i = 0; i <= ySteps; i++) {
    const val = (yMax / ySteps) * i;
    const y   = PADDING.top + chartH - (val / yMax) * chartH;
    svgLines += `<line x1="${PADDING.left}" y1="${y}" x2="${W - PADDING.right}" y2="${y}"
      stroke="${CHART_MUTED}" stroke-width="1"/>`;
    svgLines += `<text x="${PADDING.left - 6}" y="${y + 4}" text-anchor="end"
      font-size="10" fill="${CHART_TEXT}">${prefix}${_shortNum(val)}</text>`;
  }

  // Points + polyline
  const pts = data.map((d, i) => {
    const x = PADDING.left + (i / (data.length - 1 || 1)) * chartW;
    const y = PADDING.top + chartH - (maxVal > 0 ? (d.value / yMax) * chartH : 0);
    return `${x},${y}`;
  });

  svgLines += `<polyline points="${pts.join(' ')}"
    fill="none" stroke="${color}" stroke-width="2" stroke-linejoin="round"/>`;

  // Dots
  data.forEach((d, i) => {
    const [x, y] = pts[i].split(',');
    svgLines += `<circle cx="${x}" cy="${y}" r="3" fill="${color}"/>`;
    // X labels
    const rotate = data.length > 10 ? `transform="rotate(-35, ${x}, ${PADDING.top + chartH + 14})"` : '';
    svgLines += `<text x="${x}" y="${PADDING.top + chartH + 14}" text-anchor="${data.length > 10 ? 'end' : 'middle'}"
      font-size="10" fill="${CHART_TEXT}" ${rotate}>${esc(String(d.label))}</text>`;
  });

  const svg = `<svg width="100%" height="${H}" viewBox="0 0 ${W} ${H}" overflow="visible" aria-hidden="true">
    ${svgLines}
  </svg>`;

  const tableHtml = showTable ? _makeTable(data, prefix) : '';
  container.innerHTML = svg + tableHtml;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function _niceMax(val) {
  if (val === 0) return 10;
  const magnitude = Math.pow(10, Math.floor(Math.log10(val)));
  return Math.ceil(val / magnitude) * magnitude;
}

function _shortNum(n) {
  if (n >= 1e7) return (n / 1e7).toFixed(1) + 'Cr';
  if (n >= 1e5) return (n / 1e5).toFixed(1) + 'L';
  if (n >= 1e3) return (n / 1e3).toFixed(0) + 'K';
  return n.toFixed(0);
}

function _makeTable(data, prefix) {
  const rows = data.map(d =>
    `<tr><td>${esc(String(d.label))}</td><td class="text-right">${prefix}${Number(d.value).toLocaleString('en-IN', {maximumFractionDigits:2})}</td></tr>`
  ).join('');
  return `<details class="text-faint" style="margin-top:8px;font-size:12px;">
    <summary>View as table</summary>
    <table style="margin-top:4px;"><thead><tr><th>Label</th><th class="text-right">Value</th></tr></thead>
    <tbody>${rows}</tbody></table>
  </details>`;
}

