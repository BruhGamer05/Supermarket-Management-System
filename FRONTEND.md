# FRONTEND.md - design and structure rules for the web interface

Read this before writing or changing any file under `frontend/`.
The current interface looks like a template: dark glass panels, glow effects, emoji headings and only four pages.
The target is the opposite: **a plain, dependable business application**, the kind of software a shop owner
or cashier would use all day. Calm, dense where it should be, and boring in the good sense.

---

## 1. Look and feel

**Do**
- Light theme. Off-white page background, white surfaces, thin grey borders.
- One accent colour (a muted blue or green) used for primary buttons, links and the active menu item. Everything else is neutral grey.
- Status colours only for meaning: green (OK or paid), amber (warning or expiring), red (error or expired), blue (info). Always as small badges or text, never large coloured blocks.
- Tables as the main way to show data. Cards only for the KPI strip on dashboards.
- Plain business wording in sentence case: "Receive stock", "Pending requests", "Amount payable".
- A visible page title with a short description line, and the main action button on the right of the title.
- Numbers right-aligned in tables, with units (kg, packet) and the rupee sign.

**Do not**
- No emoji anywhere in the interface (headings, buttons, table cells, toasts).
- No gradients, glassmorphism, blur, neon glow, animated backgrounds, bouncing or sliding effects.
- No marketing language ("Supercharge", "Seamless", "Unlock"). No taglines on app pages.
- No oversized hero areas, giant icons, or decorative illustrations.
- No more than one shadow style, and only a very light one (modals and dropdowns only).
- No icon on every button. Use text labels; a small icon is allowed only where it saves space (sort arrows, close, print).

## 2. Design tokens (put in `css/tokens.css`; every other stylesheet uses only these)

```css
:root {
  --bg: #f5f6f8;            --surface: #ffffff;      --surface-alt: #f0f2f5;
  --border: #d8dce3;        --border-strong: #b9c0cb;
  --text: #1c2430;          --text-muted: #5b6676;   --text-faint: #8791a0;
  --accent: #1f5fa8;        --accent-hover: #184c88; --accent-soft: #e8f0fa;
  --success: #1a7f37;       --success-soft: #e6f4ea;
  --warning: #9a5b00;       --warning-soft: #fdf3e0;
  --danger: #b42318;        --danger-soft: #fdecea;
  --info: #175cd3;          --info-soft: #e8f0fe;
  --radius: 4px;            --radius-lg: 6px;
  --space-1: 4px; --space-2: 8px; --space-3: 12px; --space-4: 16px; --space-5: 24px; --space-6: 32px;
  --font: system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
  --font-mono: ui-monospace, "SFMono-Regular", Consolas, monospace;
  --shadow-pop: 0 4px 16px rgba(16, 24, 40, 0.12);
}
```
- Base font size 14px, line height 1.5. Page title 22px semibold, section title 16px semibold, table text 14px, helper text 12.5px.
- Spacing only from the scale above. Page content max width 1280px, centred; the POS page uses the full width.
- Colour contrast at least 4.5:1 for text. Visible focus ring on every interactive element (2px accent outline).
- Transitions at most 120ms on colour and background. Nothing moves.
- **No external network requests at runtime.** No Google Fonts, no CDN scripts. The demo laptop may be offline.
  If a chart library is wanted, download the minified file into `frontend/vendor/` and load it from there;
  otherwise draw simple charts with inline SVG in `js/charts.js`.

## 3. Folder structure

```
frontend/
  index.html                  login (public)
  signup.html                 customer sign-up (public)
  invoice.html                shared printable invoice, ?id=<bill id>, any role (server scopes access)
  403.html  404.html  session-expired.html
  css/  tokens.css  base.css  layout.css  components.css  print.css
  js/   api.js      auth.js   shell.js    ui.js   format.js   table.js   forms.js   charts.js   escape.js
  vendor/                     only if a library is really needed
  customer/  home.html catalog.html bills.html loyalty.html requests.html profile.html
  staff/     home.html pos.html bills.html inventory.html customers.html requests.html profile.html
  owner/     dashboard.html items.html batches.html suppliers.html employees.html customers.html
             bills.html requests.html feedback.html reports.html marketing.html loyalty.html
             tax.html accounts.html settings.html
```
- Multi-page site (one HTML file per screen), plain HTML, CSS and JavaScript modules. No framework, no build step.
- Detail views (one item, supplier, employee, customer, bill) can be a drawer or modal on the list page instead of a separate file, if that is simpler.
  Every feature ID in `FEATURES.md` must still be reachable.
- Each page: `<script type="module">` that imports from `js/`. No inline `onclick="..."` attributes; attach listeners in JavaScript.

## 4. Shared JavaScript (write once, reuse everywhere)

| File | Responsibility |
|---|---|
| `api.js` | `api.get/post/patch/put/delete`; adds the token; turns errors into one `ApiError {status, message}`; on 401 clears the session and redirects to `session-expired.html`; never shows a toast by itself (callers decide) |
| `auth.js` | read and clear the session; `requireRole(['Owner'])` at the top of every page; `currentUser()` |
| `shell.js` | renders top bar and sidebar for the logged-in role from one nav config; marks the active item; user menu with Profile, Change password, Sign out; collapses on narrow screens |
| `ui.js` | `toast()`, `confirmDialog()`, `modal()`, `setLoading()`, empty / error / loading blocks with a Retry button |
| `format.js` | `inr(n)` (Indian grouping, 2 decimals), `date(d)` (05 Oct 2026), `dateTime(d)` (IST), `qty(n, unit)`, `percent(n)` |
| `table.js` | sortable, paginated table builder; empty state; sticky header; row click handler; CSV export helper |
| `forms.js` | field validation helpers and inline error rendering; phone, PIN, GSTIN, HSN patterns |
| `escape.js` | `esc(value)` for HTML text and attributes. **Every dynamic value inserted into HTML must pass through `esc()`** or be set with `textContent` |
| `charts.js` | small line and bar chart helpers in SVG with axis labels and a table fallback |

## 5. Component rules

- **Buttons:** primary (filled accent), secondary (outlined), danger (outlined red; filled only inside a confirm dialog), link. One primary button per view. Disabled and "Saving..." states while a request is running.
- **Forms:** label above the input, helper text below, error text in red below the input, required marked with an asterisk. Validate on blur and on submit; never rely on the browser alert. Group related fields; two columns on wide screens.
- **Tables:** header row grey, 1px row borders, hover highlight, compact rows (40px). Always provide: loading, empty ("No bills match these filters."), and error with Retry. Pagination at the bottom with the total count. Filters sit in one row above the table.
- **Badges:** small, rounded 3px, soft background plus dark text (Pending, Approved, Fulfilled, Rejected, Cancelled, OK, Expiring, Expired, Empty, Inactive).
- **Modals:** title, content, footer with Cancel and the action; closes on Escape; focus moves inside and returns afterward. Use for confirmations and short forms; long forms get a page.
- **Toasts:** only for completed actions ("Bill 1042 created"). Errors that block a form appear inline next to that form.
- **Destructive actions** (deactivate, write off stock, reject) always use a confirm dialog that states what will happen.
- **Dates and money:** use `format.js` everywhere. Never print a raw ISO date or an unformatted decimal.

## 6. Navigation by role

**Owner:** Dashboard | Sales (Bills, Reports, Marketing) | Catalog (Items, Batches and stock, HSN and GST) |
Purchasing (Suppliers, Stock requests) | People (Customers, Employees, Feedback, Loyalty) | Admin (Accounts, Settings)

**Staff (Employee):** Billing (POS) | Bills | Inventory | Customers | Stock requests | My profile

**Customer:** Home | Catalog | My bills | Loyalty | Requests | Profile

Sidebar groups use small grey headings; the active page has an accent left border and soft accent background.
The top bar shows the shop name on the left and `Name (Role)` with a menu on the right.

## 7. Page specifications

For every page: show a loading state, an empty state and an error state; escape all data; call only the endpoints
listed; hide actions the role may not perform (the server still enforces them).

### Public
- **index.html (login):** centred 380px panel on the page background. Fields Username, Password, button Sign in, link "New customer? Create an account". No demo-credential box in the final build (move that to README and DEMO.md).
- **signup.html:** first name, last name, phone, username, password, confirm password. Explains that existing customers should ask the counter to create a login. (AUTH-06)

### Staff
- **staff/pos.html (the most important screen).** Two columns.
  Left: search box (focused on load) with category dropdown; results as a compact table: Item, Category, Unit, Price (ex-GST), GST %, In stock, Add button. Expired, inactive and zero-stock rows are greyed with the reason. Up to 50 results, search runs on a short delay and calls the server. (POS-01, POS-02)
  Right (sticky): "Current bill". Customer phone field with a Look up button; below it the customer's name and points balance, or "New customer: enter name" with name field. Cart table: Item, Qty (editable number), Rate, GST, Amount, remove. Totals block: Subtotal, GST, Points discount, Amount payable. Redeem points field showing "Available 134, up to 120 usable" and the rupee value. Payment method select. Buttons: Clear, Checkout (primary). All totals come from `POST /bills/preview`, re-requested (debounced) whenever the cart, phone or points change. (POS-03 to POS-08, POS-11)
  After checkout: a confirmation panel with bill number, amount, points earned, and buttons Print invoice, New bill. (POS-08, POS-09)
- **staff/bills.html:** my bills table (date, bill no, customer, amount, payment); search by bill number; click opens `invoice.html?id=`. (POS-10)
- **staff/inventory.html:** tabs All items, Low stock, Expiring, Expired; table with sellable stock, unit, price, nearest expiry; no cost or supplier. (STF-01, STF-02)
- **staff/customers.html:** search by name or phone; table with name, phone, points, city; Edit drawer (name and address), button "Create login". (STF-03, STF-04, AUTH-11)
- **staff/requests.html:** table of requests (read only) and a "Log a request" form: customer phone, item picker or new product name, quantity. (STF-05, STF-06)
- **staff/home.html:** four small KPIs (my bills today, my sales today, low stock in my category, expiring in my category) and a short recent-bills table. (STF-09)
- **staff/profile.html:** details, my feedback summary, change-password form. (STF-07, STF-08)

### Customer
- **customer/home.html:** points balance and its rupee value, last 5 bills, request summary by status. (CUS-01, CUS-10)
- **customer/catalog.html:** search and filters; table with item, category, unit, price ex-GST, GST %, availability (In stock, Low, Out of stock). Out-of-stock rows have "Request this item". (CUS-02, CUS-07)
- **customer/bills.html:** table with date range filter; row opens invoice; "Rate service" link when no feedback yet. Feedback form is a modal: 1 to 5 selector and comment. (CUS-03, CUS-04, CUS-05)
- **customer/loyalty.html:** balance, rule explanation from settings, history table linking each row to its bill. (CUS-06, LOY-03)
- **customer/requests.html:** form (existing item or new product, quantity) and table with status badge, remarks, dates, Cancel for Pending. (CUS-07, CUS-08)
- **customer/profile.html:** edit name, phone, address; change password. (CUS-09, AUTH-07)

### Owner
- **owner/dashboard.html:** KPI strip (RPT-01), sales trend for the last 30 days, top 5 items, low-stock and expiring short lists with "View all" links, pending requests count with link. Date range control applies to the chart and top items. (RPT-01, RPT-02, RPT-05, INV-10, INV-11)
- **owner/items.html:** items table with filters; Add item and Edit as modal; Deactivate with confirm; per-item "Suppliers" button opens the link manager. (INV-01 to INV-05, INV-13, INV-14)
- **owner/batches.html:** tabs Batches, Expiry centre, Adjustments, Valuation. Batches table with status badges; buttons Receive stock (modal or page), Update price, Adjust stock. (INV-06 to INV-12)
- **owner/suppliers.html:** table, add and edit, deactivate; detail drawer with supplied items and purchase history. (SUP-01 to SUP-03)
- **owner/employees.html:** table, add and edit, deactivate, create login; detail drawer with performance and feedback. (EMP-01 to EMP-03)
- **owner/customers.html:** table with search and sort; detail drawer with bills, loyalty, requests; edit; create or reset login. (CST-01 to CST-03)
- **owner/bills.html:** filterable bills table, CSV export, invoice link. (BIL-01 to BIL-03)
- **owner/requests.html:** status tabs with counts; Approve and Reject open a remark modal; Fulfil opens a form (link existing item, or create item with category and unit); Demand summary tab. (REQ-01 to REQ-05)
- **owner/feedback.html:** filters and table; ratings below 3 highlighted; per-employee averages. (FBK-02, FBK-03)
- **owner/reports.html:** tabs Sales, Products, Profit, Employees, GST, Payments and hours; shared date range; each tab has a table, a simple chart where it helps, and Export CSV. (RPT-02 to RPT-13)
- **owner/marketing.html:** choose a segment type, set its parameters, preview, Export CSV. (MKT-01 to MKT-03)
- **owner/loyalty.html:** liability and top holders, monthly earned vs redeemed. (LOY-04)
- **owner/tax.html:** HSN table with usage counts; Add rate form with a note that rates are never edited. (SYS-01)
- **owner/accounts.html:** users table; create login; reset password; activate or deactivate. (AUTH-05, AUTH-08, SYS-03)
- **owner/settings.html:** loyalty rules, expiry warning days, shop details. (SYS-02, LOY-05)

### Shared
- **invoice.html:** screen view with Print button; print stylesheet hides the shell and prints a clean A4 tax invoice: shop name, address and GSTIN from settings; bill number, date, cashier, customer name and phone; lines with item, HSN, qty, unit, rate, taxable value, GST %, CGST, SGST, line total; totals; points redeemed and earned; payment method; "Thank you" line. For Uttar Pradesh sales, CGST and SGST are each half of the GST rate. (POS-09, CUS-04, BIL-02)

## 8. Review checklist (a page is not done until every line is true)

- [ ] No emoji, gradient, glow, or decorative animation anywhere on the page.
- [ ] Uses only tokens and shared components; no page-specific colours.
- [ ] Loading, empty and error states exist and were seen working.
- [ ] Every dynamic value is escaped. A name like `<img src=x onerror=alert(1)>` renders as plain text.
- [ ] Money and dates use `format.js`. Numbers are right-aligned.
- [ ] Forms validate inline, disable the button while saving, and show server errors next to the form.
- [ ] Keyboard only: can reach and operate every control; focus ring visible; modals close with Escape.
- [ ] Works at 1366x768 and at tablet width (768px) without horizontal page scroll.
- [ ] Nothing the role should not see (cost price, suppliers, profit) appears, even in the network response.
- [ ] No request leaves localhost (check the browser Network tab).
- [ ] Page title, headings and button wording are plain and consistent with the rest of the app.
