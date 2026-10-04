// frontend/js/api.js
// Handles communication with the FastAPI backend.

const API_BASE_URL = "http://localhost:8000";

// --- Toast Notifications ---
function showToast(message, type = 'info') {
    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        document.body.appendChild(container);
    }
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'fadeOut 0.3s ease-out forwards';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// --- API Fetch Wrapper ---
async function apiFetch(endpoint, options = {}) {
    const token = localStorage.getItem('token');
    
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };

    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }

    const config = {
        ...options,
        headers
    };

    try {
        const response = await fetch(`${API_BASE_URL}${endpoint}`, config);
        const data = await response.json().catch(() => null);

        if (!response.ok) {
            const errorMsg = data?.detail || 'An error occurred';
            // Only redirect to login page if we aren't already there and trying to log in
            if (response.status === 401 && !endpoint.includes('/auth/login')) {
                localStorage.removeItem('token');
                localStorage.removeItem('role');
                window.location.href = 'index.html';
            }
            throw new Error(errorMsg);
        }

        return data;
    } catch (error) {
        showToast(error.message, 'error');
        throw error;
    }
}

// --- Auth Helper ---
function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('role');
    window.location.href = 'index.html';
}

function checkAuth(allowedRoles = []) {
    const token = localStorage.getItem('token');
    const role = localStorage.getItem('role');
    
    if (!token) {
        window.location.href = 'index.html';
        return false;
    }
    
    if (allowedRoles.length > 0 && !allowedRoles.includes(role)) {
        showToast('Access denied', 'error');
        setTimeout(() => {
            if (role === 'Owner') window.location.href = 'owner.html';
            else if (role === 'Employee') window.location.href = 'cashier.html';
            else window.location.href = 'index.html';
        }, 1000);
        return false;
    }
    return true;
}
