// js/shell.js — renders the top bar and sidebar for the logged-in role

import { currentUser, currentRole, logout } from './auth.js?v=3';
import { esc } from './escape.js?v=3';

// ── Navigation config ───────────────────────────────────────────────────────

const NAV = {
  Owner: [
    {
      label: null, // no group heading for single item
      items: [{ label: 'Dashboard', href: '/app/owner/dashboard.html' }]
    },
    {
      label: 'Sales',
      items: [
        { label: 'Bills',   href: '/app/owner/bills.html' },
        { label: 'Reports', href: '/app/owner/reports.html' },
      ]
    },
    {
      label: 'Catalog',
      items: [
        { label: 'Items',        href: '/app/owner/items.html' },
        { label: 'Batches & stock', href: '/app/owner/batches.html' },
        { label: 'HSN & GST',   href: '/app/owner/tax.html' },
      ]
    },
    {
      label: 'Purchasing',
      items: [
        { label: 'Suppliers',      href: '/app/owner/suppliers.html' },
        { label: 'Stock requests', href: '/app/owner/requests.html' },
      ]
    },
    {
      label: 'People',
      items: [
        { label: 'Customers', href: '/app/owner/customers.html' },
        { label: 'Employees', href: '/app/owner/employees.html' },
        { label: 'Feedback',  href: '/app/owner/feedback.html' },
        { label: 'Loyalty',   href: '/app/owner/loyalty.html' },
      ]
    },
    {
      label: 'Admin',
      items: [
        { label: 'Accounts', href: '/app/owner/accounts.html' },
        { label: 'Settings', href: '/app/owner/settings.html' },
      ]
    },
  ],
  Employee: [
    {
      label: 'Billing',
      items: [{ label: 'Point of sale', href: '/app/staff/pos.html' }]
    },
    {
      label: null,
      items: [
        { label: 'Bills',          href: '/app/staff/bills.html' },
        { label: 'Inventory',      href: '/app/staff/inventory.html' },
        { label: 'Customers',      href: '/app/staff/customers.html' },
        { label: 'Stock requests', href: '/app/staff/requests.html' },
        { label: 'My profile',     href: '/app/staff/profile.html' },
      ]
    },
  ],
  Customer: [
    {
      label: null,
      items: [
        { label: 'Home',      href: '/app/customer/home.html' },
        { label: 'Catalog',   href: '/app/customer/catalog.html' },
        { label: 'My bills',  href: '/app/customer/bills.html' },
        { label: 'Loyalty',   href: '/app/customer/loyalty.html' },
        { label: 'Requests',  href: '/app/customer/requests.html' },
        { label: 'Profile',   href: '/app/customer/profile.html' },
      ]
    },
  ],
};

// ── Render ──────────────────────────────────────────────────────────────────

/**
 * Render the full shell (top bar + sidebar) and wire up the user menu and logout.
 * Call this at the top of every page's <script type="module">.
 *
 * Usage:
 *   import { renderShell } from '../js/shell.js?v=3';
 *   renderShell();
 */
export function renderShell() {
  const role = currentRole();
  const user = currentUser();
  const name = user?.username || role || 'User';
  const currentPath = window.location.pathname;

  // ── Top bar ──
  const topbar = document.getElementById('topbar');
  if (topbar) {
    topbar.innerHTML = `
      <a class="topbar__brand" href="${_homeHref(role)}">Supermarket System</a>
      <div class="topbar__user" id="userMenu">
        <span class="topbar__user-name">${esc(name)} <span class="text-faint">(${esc(role)})</span></span>
        <div class="topbar__menu" id="userMenuDropdown">
          ${_profileHref(role) ? `<a class="topbar__menu-item" href="${_profileHref(role)}">My profile</a>` : ''}
          <button class="topbar__menu-item topbar__menu-item--danger" id="logoutBtn">Sign out</button>
        </div>
      </div>`;

    // Toggle dropdown
    const menuTrigger  = topbar.querySelector('#userMenu');
    const menuDropdown = topbar.querySelector('#userMenuDropdown');
    menuTrigger.addEventListener('click', (e) => {
      menuDropdown.classList.toggle('is-open');
      e.stopPropagation();
    });
    document.addEventListener('click', () => menuDropdown.classList.remove('is-open'));
    topbar.querySelector('#logoutBtn')?.addEventListener('click', logout);
  }

  // ── Sidebar ──
  const sidebar = document.getElementById('sidebar');
  if (sidebar && role && NAV[role]) {
    const groups = NAV[role].map(group => {
      const heading = group.label
        ? `<div class="nav-group"><span class="nav-group__label">${esc(group.label)}</span></div>`
        : '<div style="margin-top:8px;"></div>';

      const links = group.items.map(item => {
        const isActive = currentPath === item.href ||
                         currentPath.startsWith(item.href.replace('.html', ''));
        return `<a class="nav-item${isActive ? ' is-active' : ''}" href="${esc(item.href)}">${esc(item.label)}</a>`;
      }).join('');

      return heading + links;
    }).join('');

    sidebar.innerHTML = groups;
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function _homeHref(role) {
  if (role === 'Owner')    return '/app/owner/dashboard.html';
  if (role === 'Employee') return '/app/staff/pos.html';
  if (role === 'Customer') return '/app/customer/home.html';
  return '/app/index.html';
}

function _profileHref(role) {
  if (role === 'Employee') return '/app/staff/profile.html';
  if (role === 'Customer') return '/app/customer/profile.html';
  return null; // Owner profile not yet built
}

