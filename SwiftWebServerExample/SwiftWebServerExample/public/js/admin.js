// SwiftWebServer Admin JavaScript

let authToken = null;
let currentUser = null;
let API_BASE = ''; // Will be loaded from config

// Initialize the admin page
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();

    // Check for existing auth token in cookies
    authToken = getCookie('auth_token');
    if (!authToken) {
        // If no auth token, redirect to login
        console.log('No auth token found, redirecting to login');
        window.location.href = '/login';
        return;
    }

    // Validate the auth token with the backend
    console.log('Auth token from cookie:', authToken);
    const isValid = await validateAuthToken();
    if (!isValid) {
        console.log('Auth token invalid, redirecting to login');
        // Clear invalid token with proper domain and path
        document.cookie = 'auth_token=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=localhost;';
        window.location.href = '/login';
        return;
    }

    // Show user info and load initial data
    showUserInfo();
    loadPosts();

    // Set default tab to posts
    showTab('posts');
});

// Load configuration from frontend server
async function loadConfig() {
    try {
        const response = await fetch('/config.json');
        if (response.ok) {
            const config = await response.json();
            API_BASE = config.apiBase || config.backendUrl || 'http://localhost:8080';
        } else {
            API_BASE = 'http://localhost:8080';
        }
    } catch (error) {
        console.log('Using fallback API base');
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
    if (tabName === 'posts') {
        loadPosts();
    } else if (tabName === 'comments') {
        loadComments();
    }
}

// Authentication
async function validateAuthToken() {
    if (!authToken) {
        return false;
    }

    try {
        console.log('Validating auth token with backend...');
        const response = await fetch(`${API_BASE}/api/admin/stats`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authToken}`
            },
            credentials: 'include' // Include cookies in cross-origin requests
        });

        console.log('Auth validation response status:', response.status);

        if (response.ok) {
            console.log('Auth token is valid');
            return true;
        } else {
            console.log('Auth token is invalid');
            return false;
        }
    } catch (error) {
        console.error('Error validating auth token:', error);
        return false;
    }
}

async function logout() {
    try {
        await fetch(`${API_BASE}/api/auth/logout`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`
            },
            credentials: 'include' // Include cookies in cross-origin requests
        });
    } catch (error) {
        console.error('Logout error:', error);
    }
    
    authToken = null;
    currentUser = null;

    // Redirect to login page
    window.location.href = '/login';
}

function showUserInfo() {
    const userInfoDiv = document.getElementById('user-info');
    const userNameSpan = document.getElementById('user-name');
    
    if (authToken) {
        userInfoDiv.style.display = 'flex';
        userNameSpan.textContent = 'Welcome, Admin!';
    } else {
        userInfoDiv.style.display = 'none';
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
                    <button class="btn btn-danger" onclick="deletePost('${post.id}')">Delete</button>
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
            credentials: 'include', // Include cookies in cross-origin requests
            body: JSON.stringify(postData)
        });
        
        const data = await response.json();
        
        if (response.ok) {
            alert('Post created successfully!');
            hideCreatePostForm();
            loadPosts();
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

async function deletePost(postId) {
    if (!confirm('Are you sure you want to delete this post?')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/api/posts/${postId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`
            },
            credentials: 'include' // Include cookies in cross-origin requests
        });
        
        if (response.ok) {
            alert('Post deleted successfully!');
            loadPosts();
        } else {
            const data = await response.json();
            alert('Error deleting post: ' + data.error);
        }
    } catch (error) {
        alert('Error deleting post: ' + error.message);
    }
}

// Comments Management
async function loadComments() {
    // For simplicity, we'll show a message about comments
    const commentsList = document.getElementById('comments-list');
    commentsList.innerHTML = `
        <div class="data-item">
            <h4>💬 Comments Management</h4>
            <p>Comments are managed per post. To manage comments:</p>
            <ol>
                <li>Go to the Posts tab</li>
                <li>Click "View" on any post to see its comments</li>
                <li>Comments can be moderated through the API</li>
            </ol>
            <p>Future versions will include a dedicated comments management interface.</p>
        </div>
    `;
}

// Utility Functions
function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
    return null;
}
