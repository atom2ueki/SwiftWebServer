// SwiftWebServer Login JavaScript

let API_BASE = '';

// Initialize the login page
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();
    
    // Check if user is already logged in
    const authToken = getCookie('auth_token');
    if (authToken) {
        // Redirect to admin if already logged in
        window.location.href = '/admin.html';
        return;
    }
    
    // Focus on username field
    document.getElementById('username').focus();
    
    // Handle Enter key in password field
    document.getElementById('password').addEventListener('keypress', function(event) {
        if (event.key === 'Enter') {
            handleLogin(event);
        }
    });
});

// Load configuration from backend
async function loadConfig() {
    try {
        const response = await fetch('/config.json');
        if (response.ok) {
            const config = await response.json();
            API_BASE = config.apiBase || '';
        } else {
            API_BASE = window.location.origin;
        }
    } catch (error) {
        console.log('Using fallback API base');
        API_BASE = window.location.origin;
    }
}

// Handle login form submission
async function handleLogin(event) {
    event.preventDefault();
    
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;
    const loginBtn = document.getElementById('login-btn');
    const btnText = loginBtn.querySelector('.btn-text');
    const btnLoading = loginBtn.querySelector('.btn-loading');
    const errorDiv = document.getElementById('login-error');
    
    // Validate input
    if (!username || !password) {
        showError('Please enter both username and password.');
        return;
    }
    
    // Show loading state
    loginBtn.disabled = true;
    btnText.style.display = 'none';
    btnLoading.style.display = 'flex';
    hideError();
    
    try {
        const response = await fetch(`${API_BASE}/api/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username: username,
                password: password
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            // Login successful
            showSuccess('Login successful! Redirecting...');
            
            // Wait a moment then redirect to admin
            setTimeout(() => {
                window.location.href = '/admin.html';
            }, 1000);
            
        } else {
            // Login failed
            showError(data.error || 'Invalid username or password.');
        }
        
    } catch (error) {
        console.error('Login error:', error);
        showError('Unable to connect to server. Please try again.');
    } finally {
        // Reset button state
        loginBtn.disabled = false;
        btnText.style.display = 'inline';
        btnLoading.style.display = 'none';
    }
}

// Show error message
function showError(message) {
    const errorDiv = document.getElementById('login-error');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    errorDiv.style.backgroundColor = '#fee';
    errorDiv.style.borderColor = '#fcc';
    errorDiv.style.color = '#c33';
}

// Show success message
function showSuccess(message) {
    const errorDiv = document.getElementById('login-error');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    errorDiv.style.backgroundColor = '#efe';
    errorDiv.style.borderColor = '#cfc';
    errorDiv.style.color = '#3c3';
}

// Hide error/success message
function hideError() {
    const errorDiv = document.getElementById('login-error');
    errorDiv.style.display = 'none';
}

// Utility function to get cookie value
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
    return null;
}

// Handle demo credential buttons (if we want to add them later)
function fillDemoCredentials() {
    document.getElementById('username').value = 'johndoe';
    document.getElementById('password').value = 'password123';
}
