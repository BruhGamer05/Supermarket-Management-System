// js/forms.js — inline field validation helpers

/**
 * Validate a field and show/clear its inline error.
 * Returns true if valid, false if not.
 *
 * @param {HTMLElement} field  The input/select/textarea element
 * @param {string|null} errorMsg  Error message to show, or null/'' if valid
 * @returns {boolean}
 */
export function setFieldError(field, errorMsg) {
  const group = field.closest('.form-group');
  if (!group) return !errorMsg;

  const errEl = group.querySelector('.form-error');

  if (errorMsg) {
    group.classList.add('has-error');
    if (errEl) errEl.textContent = errorMsg;
    return false;
  } else {
    group.classList.remove('has-error');
    if (errEl) errEl.textContent = '';
    return true;
  }
}

/**
 * Validate all .form-group fields inside `form`.
 * Each field is checked against its `data-validate` attribute (comma-separated rules).
 * Returns true if all valid.
 *
 * Rules:
 *   required      — must not be empty
 *   phone         — 10-digit Indian mobile
 *   pin           — 6-digit PIN code
 *   gstin         — 15-char GSTIN format
 *   hsn           — 4 or 8 digit HSN code
 *   email         — basic email check
 *   min:N         — numeric min value
 *   max:N         — numeric max value
 *   minlen:N      — minimum string length
 *
 * @param {HTMLFormElement} form
 * @returns {boolean}
 */
export function validateForm(form) {
  let valid = true;
  form.querySelectorAll('[data-validate]').forEach(field => {
    const rules = field.dataset.validate.split(',').map(r => r.trim());
    const result = _runRules(field, rules);
    if (!setFieldError(field, result)) valid = false;
  });
  return valid;
}

/**
 * Attach blur-time validation to all fields with data-validate in the form.
 * @param {HTMLFormElement} form
 */
export function attachValidation(form) {
  form.querySelectorAll('[data-validate]').forEach(field => {
    field.addEventListener('blur', () => {
      const rules = field.dataset.validate.split(',').map(r => r.trim());
      setFieldError(field, _runRules(field, rules));
    });
  });
}

function _runRules(field, rules) {
  const val = field.value.trim();

  for (const rule of rules) {
    if (rule === 'required' && !val) return 'This field is required.';

    if (rule === 'phone') {
      if (val && !/^[6-9]\d{9}$/.test(val))
        return 'Enter a valid 10-digit mobile number.';
    }

    if (rule === 'pin') {
      if (val && !/^\d{6}$/.test(val))
        return 'PIN code must be 6 digits.';
    }

    if (rule === 'gstin') {
      if (val && !/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/.test(val))
        return 'Enter a valid 15-character GSTIN.';
    }

    if (rule === 'hsn') {
      if (val && !/^\d{4}(\d{4})?$/.test(val))
        return 'HSN code must be 4 or 8 digits.';
    }

    if (rule === 'email') {
      if (val && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val))
        return 'Enter a valid email address.';
    }

    if (rule.startsWith('min:')) {
      const min = parseFloat(rule.slice(4));
      if (val !== '' && parseFloat(val) < min)
        return `Minimum value is ${min}.`;
    }

    if (rule.startsWith('max:')) {
      const max = parseFloat(rule.slice(4));
      if (val !== '' && parseFloat(val) > max)
        return `Maximum value is ${max}.`;
    }

    if (rule.startsWith('minlen:')) {
      const min = parseInt(rule.slice(7));
      if (val.length < min)
        return `Must be at least ${min} characters.`;
    }
  }

  return null; // valid
}

/**
 * Show a form-level error banner (not field-specific).
 * The banner element must have class "form-error-banner" inside the form.
 * @param {HTMLElement} form
 * @param {string} message
 */
export function showFormError(form, message) {
  const banner = form.querySelector('.form-error-banner');
  if (!banner) return;
  banner.textContent = message;
  banner.classList.add('is-visible');
}

/**
 * Clear the form-level error banner.
 * @param {HTMLElement} form
 */
export function clearFormError(form) {
  const banner = form.querySelector('.form-error-banner');
  if (banner) banner.classList.remove('is-visible');
}

