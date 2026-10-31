// js/table.js — sortable, paginated table builder with CSV export

import { esc } from './escape.js?v=3';

const PAGE_SIZE = 25;

/**
 * Build a sortable, paginated table inside `container`.
 *
 * @param {HTMLElement} container  Element that will receive the table (can be a <div>)
 * @param {Array<object>} data     Array of row objects
 * @param {Array<Column>} columns  Column definitions
 * @param {TableOptions} [opts]
 *
 * Column definition:
 *   key       - property name on data row
 *   label     - header text
 *   render    - optional (row) => htmlString (must escape values)
 *   sortable  - boolean (default true)
 *   className - extra class on <td>
 *   numeric   - right-align header and cell
 *
 * Options:
 *   pageSize  - rows per page (default 25)
 *   onRowClick - (row) => void; makes rows clickable
 *   emptyMsg  - message for empty state
 */
export function buildTable(container, data, columns, opts = {}) {
  const pageSize = opts.pageSize || PAGE_SIZE;
  let sortKey   = null;
  let sortDir   = 'asc'; // 'asc' | 'desc'
  let page      = 1;

  let rows = [...data];

  function sortedRows() {
    if (!sortKey) return rows;
    return [...rows].sort((a, b) => {
      const av = a[sortKey] ?? '';
      const bv = b[sortKey] ?? '';
      const cmp = typeof av === 'number'
        ? av - bv
        : String(av).localeCompare(String(bv), 'en-IN', { numeric: true });
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }

  function render() {
    const sorted  = sortedRows();
    const total   = sorted.length;
    const pages   = Math.max(1, Math.ceil(total / pageSize));
    if (page > pages) page = pages;
    const start   = (page - 1) * pageSize;
    const visible = sorted.slice(start, start + pageSize);

    // Header
    const theadCells = columns.map(col => {
      const align = col.numeric ? ' class="text-right"' : '';
      if (col.sortable === false) return `<th${align}>${esc(col.label)}</th>`;
      const isSorted = sortKey === col.key;
      const cls = [
        'sortable',
        col.numeric ? 'text-right' : '',
        isSorted ? `sort-${sortDir}` : ''
      ].filter(Boolean).join(' ');
      return `<th class="${cls}" data-key="${esc(col.key)}">${esc(col.label)}</th>`;
    }).join('');

    // Body
    let tbodyHtml = '';
    if (visible.length === 0) {
      tbodyHtml = `<tr><td colspan="${columns.length}" class="state-block">
        <div class="state-block__title">No results</div>
        <div class="state-block__desc">${esc(opts.emptyMsg || 'No records match the current filters.')}</div>
      </td></tr>`;
    } else {
      tbodyHtml = visible.map(row => {
        const cells = columns.map(col => {
          const val  = row[col.key];
          const html = col.render ? col.render(row) : esc(val ?? '—');
          const cls  = [col.className || '', col.numeric ? 'text-right' : ''].filter(Boolean).join(' ');
          return cls ? `<td class="${cls}">${html}</td>` : `<td>${html}</td>`;
        }).join('');
        const rowClass = opts.onRowClick ? ' class="is-clickable"' : '';
        return `<tr${rowClass} data-idx="${esc(start + visible.indexOf(row))}">${cells}</tr>`;
      }).join('');
    }

    // Pagination
    const from = total === 0 ? 0 : start + 1;
    const to   = Math.min(start + pageSize, total);
    const paginHtml = `
      <div class="pagination">
        <span>${total === 0 ? 'No results' : `Showing ${from}–${to} of ${total}`}</span>
        <div class="pagination__controls">
          <button class="btn btn-secondary btn-sm" id="pg-prev" ${page <= 1 ? 'disabled' : ''}>Previous</button>
          <span>Page ${page} of ${pages}</span>
          <button class="btn btn-secondary btn-sm" id="pg-next" ${page >= pages ? 'disabled' : ''}>Next</button>
        </div>
      </div>`;

    container.innerHTML = `
      <div class="table-wrap">
        <table>
          <thead><tr>${theadCells}</tr></thead>
          <tbody>${tbodyHtml}</tbody>
        </table>
      </div>
      ${paginHtml}`;

    // Sort listeners
    container.querySelectorAll('th.sortable').forEach(th => {
      th.addEventListener('click', () => {
        const key = th.dataset.key;
        if (sortKey === key) {
          sortDir = sortDir === 'asc' ? 'desc' : 'asc';
        } else {
          sortKey = key;
          sortDir = 'asc';
        }
        page = 1;
        render();
      });
    });

    // Row click listener
    if (opts.onRowClick) {
      container.querySelectorAll('tbody tr.is-clickable').forEach((tr, i) => {
        tr.addEventListener('click', () => {
          const idx = parseInt(tr.dataset.idx);
          opts.onRowClick(sorted[idx]);
        });
      });
    }

    // Pagination listeners
    container.querySelector('#pg-prev')?.addEventListener('click', () => { page--; render(); });
    container.querySelector('#pg-next')?.addEventListener('click', () => { page++; render(); });
  }

  render();

  return {
    /** Replace the underlying data and re-render. */
    update(newData) {
      rows = [...newData];
      page = 1;
      render();
    }
  };
}

/**
 * Export data as a CSV file download.
 * @param {Array<object>} data
 * @param {Array<{key: string, label: string}>} columns
 * @param {string} [filename]
 */
export function exportCsv(data, columns, filename = 'export.csv') {
  const header = columns.map(c => `"${String(c.label).replace(/"/g, '""')}"`).join(',');
  const body   = data.map(row =>
    columns.map(c => {
      const val = row[c.key] ?? '';
      return `"${String(val).replace(/"/g, '""')}"`;
    }).join(',')
  ).join('\n');

  const blob = new Blob([header + '\n' + body], { type: 'text/csv' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

