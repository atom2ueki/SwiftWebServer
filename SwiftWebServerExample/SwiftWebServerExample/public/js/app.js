// SwiftWebServer Example JavaScript

let authToken = null;
let currentUser = null;
let API_BASE = ''; // Will be loaded from config

// Initialize the app
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();

    // Check for existing auth token in cookies
    authToken = getCookie('auth_token');
    if (authToken) {
        showUserInfo();
    } else {
        // If no auth token and this is the admin page, redirect to login
        if (window.location.pathname.includes('admin.html')) {
            window.location.href = '/login.html';
            return;
        }
    }

    // Load initial data
    loadServerInfo();
    loadUsers();
    loadPosts();

    // Set up auto-refresh for logs
    setInterval(loadLogs, 5000);

    // Load initial logs
    loadLogs();
});

// Load configuration from frontend server
async function loadConfig() {
    try {
        const response = await fetch('/api/config');
        const config = await response.json();
        API_BASE = config.backendUrl || 'http://localhost:8080';
        console.log('Backend API URL:', API_BASE);
    } catch (error) {
        console.error('Failed to load config, using default backend URL:', error);
        API_BASE = 'http://localhost:8080';
    }
}

// Tab Management
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Remove active class from all buttons
    document.querySelectorAll('.tab-button').forEach(button => {
        button.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(tabName + '-tab').classList.add('active');
    
    // Add active class to clicked button
    event.target.classList.add('active');
    
    // Load data for specific tabs
    if (tabName === 'users') {
        loadUsers();
    } else if (tabName === 'posts') {
        loadPosts();
    } else if (tabName === 'comments') {
        loadComments();
    } else if (tabName === 'logs') {
        loadLogs();
    } else if (tabName === 'overview') {
        loadServerInfo();
    }
}

// Authentication
async function login() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    
    if (!username || !password) {
        alert('Please enter username and password');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/api/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            authToken = data.token;
            currentUser = data.user;
            showUserInfo();
            showCreateButtons();
            alert('Login successful!');
        } else {
            alert('Login failed: ' + data.error);
        }
    } catch (error) {
        alert('Login error: ' + error.message);
    }
}

async function logout() {
    try {
        await fetch(`${API_BASE}/api/auth/logout`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });
    } catch (error) {
        console.error('Logout error:', error);
    }
    
    authToken = null;
    currentUser = null;
    showLoginForm();
    hideCreateButtons();
    alert('Logged out successfully');
}

function showUserInfo() {
    document.getElementById('login-form').style.display = 'none';
    document.getElementById('user-info').style.display = 'flex';
    if (currentUser) {
        document.getElementById('user-name').textContent = `Welcome, ${currentUser.firstName}!`;
    }
}

function showLoginForm() {
    document.getElementById('login-form').style.display = 'flex';
    document.getElementById('user-info').style.display = 'none';
    document.getElementById('username').value = '';
    document.getElementById('password').value = '';
}

function showCreateButtons() {
    const createPostBtn = document.getElementById('create-post-btn');
    if (createPostBtn) {
        createPostBtn.style.display = 'inline-block';
    }
}

function hideCreateButtons() {
    const createPostBtn = document.getElementById('create-post-btn');
    if (createPostBtn) {
        createPostBtn.style.display = 'none';
    }
}

// Server Info
async function loadServerInfo() {
    try {
        const [healthResponse, infoResponse] = await Promise.all([
            fetch(`${API_BASE}/api/health`),
            fetch(`${API_BASE}/api/info`)
        ]);
        
        const healthData = await healthResponse.json();
        const infoData = await infoResponse.json();
        
        // Update server status
        const statusElement = document.getElementById('server-status');
        if (healthData.status === 'healthy') {
            statusElement.textContent = '🟢 Online';
            statusElement.className = 'status-indicator online';
        } else {
            statusElement.textContent = '🔴 Offline';
            statusElement.className = 'status-indicator offline';
        }
        
        // Update statistics
        if (infoData.statistics) {
            document.getElementById('total-users').textContent = infoData.statistics.total_users;
            document.getElementById('published-posts').textContent = infoData.statistics.published_posts;
            document.getElementById('approved-comments').textContent = infoData.statistics.approved_comments;
        }
        
    } catch (error) {
        console.error('Error loading server info:', error);
        document.getElementById('server-status').textContent = '🔴 Error';
        document.getElementById('server-status').className = 'status-indicator offline';
    }
}

// Users Management
async function loadUsers() {
    try {
        const response = await fetch(`${API_BASE}/api/users`);
        const users = await response.json();
        
        const usersList = document.getElementById('users-list');
        usersList.innerHTML = '';
        
        users.forEach(user => {
            const userElement = document.createElement('div');
            userElement.className = 'data-item';
            userElement.innerHTML = `
                <h4>${user.fullName} (@${user.username})</h4>
                <p><strong>Email:</strong> ${user.email}</p>
                <p><strong>Status:</strong> ${user.isActive ? 'Active' : 'Inactive'}</p>
                <p><strong>Posts:</strong> ${user.postsCount} | <strong>Comments:</strong> ${user.commentsCount}</p>
                <div class="meta">
                    Created: ${new Date(user.createdAt).toLocaleDateString()}
                </div>
            `;
            usersList.appendChild(userElement);
        });
        
    } catch (error) {
        console.error('Error loading users:', error);
    }
}

function showCreateUserForm() {
    document.getElementById('create-user-form').style.display = 'block';
}

function hideCreateUserForm() {
    document.getElementById('create-user-form').style.display = 'none';
    // Clear form
    document.getElementById('new-username').value = '';
    document.getElementById('new-email').value = '';
    document.getElementById('new-password').value = '';
    document.getElementById('new-firstname').value = '';
    document.getElementById('new-lastname').value = '';
}

async function createUser(event) {
    event.preventDefault();
    
    const userData = {
        username: document.getElementById('new-username').value,
        email: document.getElementById('new-email').value,
        password: document.getElementById('new-password').value,
        firstName: document.getElementById('new-firstname').value,
        lastName: document.getElementById('new-lastname').value
    };
    
    try {
        const response = await fetch(`${API_BASE}/api/users`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(userData)
        });
        
        const data = await response.json();
        
        if (response.ok) {
            alert('User created successfully!');
            hideCreateUserForm();
            loadUsers();
            loadServerInfo(); // Refresh stats
        } else {
            alert('Error creating user: ' + data.error);
        }
    } catch (error) {
        alert('Error creating user: ' + error.message);
    }
}

// Posts Management
async function loadPosts() {
    try {
        const response = await fetch(`${API_BASE}/api/posts`);
        const posts = await response.json();
        
        const postsList = document.getElementById('posts-list');
        postsList.innerHTML = '';
        
        posts.forEach(post => {
            const postElement = document.createElement('div');
            postElement.className = 'data-item';
            postElement.innerHTML = `
                <h4>${post.title}</h4>
                <p>${post.excerpt}</p>
                <p><strong>Author:</strong> ${post.authorName}</p>
                <p><strong>Status:</strong> ${post.isPublished ? 'Published' : 'Draft'}</p>
                <p><strong>Views:</strong> ${post.viewCount} | <strong>Comments:</strong> ${post.commentsCount}</p>
                <p><strong>Reading Time:</strong> ${post.readingTime} min</p>
                <div class="meta">
                    Created: ${new Date(post.createdAt).toLocaleDateString()}
                    ${post.publishedAt ? ` | Published: ${new Date(post.publishedAt).toLocaleDateString()}` : ''}
                </div>
                <div class="actions">
                    <button class="btn btn-secondary" onclick="viewPost('${post.id}')">View</button>
                </div>
            `;
            postsList.appendChild(postElement);
        });
        
    } catch (error) {
        console.error('Error loading posts:', error);
    }
}

function showCreatePostForm() {
    if (!authToken) {
        alert('Please login to create posts');
        return;
    }
    document.getElementById('create-post-form').style.display = 'block';
}

function hideCreatePostForm() {
    document.getElementById('create-post-form').style.display = 'none';
    // Clear form
    document.getElementById('new-post-title').value = '';
    document.getElementById('new-post-content').value = '';
    document.getElementById('new-post-published').checked = false;
}

async function createPost(event) {
    event.preventDefault();
    
    if (!authToken) {
        alert('Please login to create posts');
        return;
    }
    
    const postData = {
        title: document.getElementById('new-post-title').value,
        content: document.getElementById('new-post-content').value,
        isPublished: document.getElementById('new-post-published').checked
    };
    
    try {
        const response = await fetch(`${API_BASE}/api/posts`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify(postData)
        });
        
        const data = await response.json();
        
        if (response.ok) {
            alert('Post created successfully!');
            hideCreatePostForm();
            loadPosts();
            loadServerInfo(); // Refresh stats
        } else {
            alert('Error creating post: ' + data.error);
        }
    } catch (error) {
        alert('Error creating post: ' + error.message);
    }
}

async function viewPost(postId) {
    try {
        const response = await fetch(`${API_BASE}/api/posts/${postId}`);
        const post = await response.json();
        
        if (response.ok) {
            alert(`Post: ${post.title}\n\nContent: ${post.content}\n\nAuthor: ${post.author?.fullName}\nViews: ${post.viewCount}\nComments: ${post.commentsCount}`);
        } else {
            alert('Error loading post: ' + post.error);
        }
    } catch (error) {
        alert('Error loading post: ' + error.message);
    }
}

// Comments Management
async function loadComments() {
    // For simplicity, we'll show a message about comments
    const commentsList = document.getElementById('comments-list');
    commentsList.innerHTML = `
        <div class="data-item">
            <h4>💬 Comments Feature</h4>
            <p>Comments are managed per post. To view comments:</p>
            <ol>
                <li>Go to the Posts tab</li>
                <li>Click "View" on any post</li>
                <li>Comments will be displayed with the post details</li>
            </ol>
            <p>You can also test the comments API using the API Test tab with endpoints like:</p>
            <ul>
                <li><code>GET /api/posts/{postId}/comments</code></li>
                <li><code>POST /api/posts/{postId}/comments</code> (requires authentication)</li>
            </ul>
        </div>
    `;
}

// API Testing
async function testAPI() {
    const method = document.getElementById('api-method').value;
    const url = document.getElementById('api-url').value;
    const body = document.getElementById('api-body').value;
    
    if (!url) {
        alert('Please enter an API URL');
        return;
    }
    
    const options = {
        method: method,
        headers: {
            'Content-Type': 'application/json'
        }
    };
    
    if (authToken) {
        options.headers['Authorization'] = `Bearer ${authToken}`;
    }
    
    if (body && (method === 'POST' || method === 'PUT')) {
        options.body = body;
    }
    
    try {
        // Use API_BASE for relative URLs, or use the URL as-is if it's absolute
        const fullUrl = url.startsWith('/') ? `${API_BASE}${url}` : url;
        const response = await fetch(fullUrl, options);
        const responseText = await response.text();
        
        document.getElementById('response-status').textContent = `${response.status} ${response.statusText}`;
        
        try {
            const jsonData = JSON.parse(responseText);
            document.getElementById('response-body').textContent = JSON.stringify(jsonData, null, 2);
        } catch {
            document.getElementById('response-body').textContent = responseText;
        }
        
    } catch (error) {
        document.getElementById('response-status').textContent = 'Error';
        document.getElementById('response-body').textContent = error.message;
    }
}

// Logs Management
async function loadLogs() {
    // Since we can't directly access the SwiftUI logs from the web interface,
    // we'll simulate log display with API calls
    const logsContainer = document.getElementById('logs-container');
    
    if (!logsContainer) return;
    
    // Simulate log entries based on recent activity
    const logEntries = [
        { timestamp: new Date(), type: 'info', message: 'Server status check completed' },
        { timestamp: new Date(Date.now() - 30000), type: 'success', message: 'API request processed successfully' },
        { timestamp: new Date(Date.now() - 60000), type: 'info', message: 'User data loaded' },
        { timestamp: new Date(Date.now() - 90000), type: 'info', message: 'Posts data refreshed' }
    ];
    
    logsContainer.innerHTML = logEntries.map(entry => `
        <div class="log-entry ${entry.type}">
            <span class="log-timestamp">${entry.timestamp.toLocaleTimeString()}</span>
            <span class="log-message">${entry.message}</span>
        </div>
    `).join('');
}

function clearLogs() {
    const logsContainer = document.getElementById('logs-container');
    if (logsContainer) {
        logsContainer.innerHTML = '<div class="log-entry info"><span class="log-message">Logs cleared</span></div>';
    }
}

// Utility Functions
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
    return null;
}
