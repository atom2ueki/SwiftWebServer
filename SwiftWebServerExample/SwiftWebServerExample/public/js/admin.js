// SwiftWebServer Admin JavaScript

let authToken = null;
let currentUser = null;
let API_BASE = ''; // Will be loaded from config

// Initialize the admin page
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();

    // Check for existing auth token in localStorage
    authToken = localStorage.getItem('auth_token');
    if (!authToken) {
        // If no auth token, redirect to login
        console.log('No auth token found, redirecting to login');
        window.location.href = '/login';
        return;
    }

    // Validate the auth token with the backend
    console.log('Auth token from localStorage:', authToken);
    const isValid = await validateAuthToken();
    if (!isValid) {
        console.log('Auth token invalid, redirecting to login');
        // Clear invalid token
        localStorage.removeItem('auth_token');
        window.location.href = '/login';
        return;
    }

    // Show user info and load initial data
    showUserInfo();
    loadPosts();
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

// Global variables for post management
let currentPostId = null;

// Authentication
async function validateAuthToken() {
    if (!authToken) {
        return false;
    }

    try {
        console.log('Validating auth token with backend...');
        const response = await fetch(`${API_BASE}/api/auth/token-info`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        console.log('Auth validation response status:', response.status);

        if (response.ok) {
            const tokenInfo = await response.json();
            console.log('Token info:', tokenInfo);

            // Check if token is expired or about to expire (within 5 minutes)
            const expiresIn = tokenInfo.expiresIn;
            if (expiresIn <= 0) {
                console.log('Token has expired');
                handleTokenExpired();
                return false;
            } else if (expiresIn <= 300) { // 5 minutes
                console.log(`Token expires in ${Math.floor(expiresIn / 60)} minutes`);
                showTokenExpirationWarning(expiresIn);
            }

            console.log('Auth token is valid');
            return true;
        } else {
            const errorData = await response.json().catch(() => ({}));
            if (errorData.code === 'TOKEN_INVALID') {
                console.log('Token is invalid or expired');
                handleTokenExpired();
            } else {
                console.log('Auth token validation failed');
            }
            return false;
        }
    } catch (error) {
        console.error('Error validating auth token:', error);
        return false;
    }
}

// Handle token expiration
function handleTokenExpired() {
    console.log('Handling token expiration...');

    // Clear token from localStorage
    localStorage.removeItem('auth_token');
    authToken = null;
    currentUser = null;

    // Show user-friendly message
    alert('Your session has expired. Please log in again.');

    // Redirect to login
    window.location.href = '/login';
}

// Show token expiration warning
function showTokenExpirationWarning(expiresIn) {
    const minutes = Math.floor(expiresIn / 60);
    const seconds = expiresIn % 60;

    // Create or update warning banner
    let warningBanner = document.getElementById('token-warning-banner');
    if (!warningBanner) {
        warningBanner = document.createElement('div');
        warningBanner.id = 'token-warning-banner';
        warningBanner.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            background: #ff9500;
            color: white;
            padding: 10px;
            text-align: center;
            z-index: 1000;
            font-weight: bold;
        `;
        document.body.insertBefore(warningBanner, document.body.firstChild);
    }

    warningBanner.innerHTML = `
        ⚠️ Your session expires in ${minutes}:${seconds.toString().padStart(2, '0')}.
        <button onclick="refreshToken()" style="margin-left: 10px; padding: 5px 10px; background: white; color: #ff9500; border: none; border-radius: 3px; cursor: pointer;">
            Extend Session
        </button>
    `;
}

// Refresh/extend token (placeholder - would need backend support)
async function refreshToken() {
    // For now, just validate the token again
    const isValid = await validateAuthToken();
    if (isValid) {
        // Remove warning banner
        const warningBanner = document.getElementById('token-warning-banner');
        if (warningBanner) {
            warningBanner.remove();
        }
        alert('Session refreshed successfully!');
    }
}

// Enhanced fetch wrapper that handles token expiration
async function authenticatedFetch(url, options = {}) {
    // Add auth header if token exists
    if (authToken) {
        options.headers = {
            ...options.headers,
            'Authorization': `Bearer ${authToken}`
        };
    }

    try {
        const response = await fetch(url, options);

        // Check for token expiration
        if (response.status === 401) {
            const errorData = await response.json().catch(() => ({}));
            if (errorData.code === 'TOKEN_INVALID') {
                handleTokenExpired();
                return null;
            }
        }

        return response;
    } catch (error) {
        console.error('Fetch error:', error);
        throw error;
    }
}

async function logout() {
    try {
        await fetch(`${API_BASE}/api/auth/logout`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });
    } catch (error) {
        console.error('Logout error:', error);
    }
    
    // Clear token from localStorage
    localStorage.removeItem('auth_token');
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
        const response = await fetch(`${API_BASE}/api/posts`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const posts = await response.json();

        const postsList = document.getElementById('posts-list');
        postsList.innerHTML = '';

        // Check if posts is an array or if it's wrapped in an object
        const postsArray = Array.isArray(posts) ? posts : (posts.posts || posts.data || []);

        if (postsArray.length === 0) {
            postsList.innerHTML = `
                <div class="post-item">
                    <div class="post-header">
                        <h3 class="post-title">No posts found</h3>
                    </div>
                    <p class="post-excerpt">Create your first post to get started!</p>
                </div>
            `;
            return;
        }

        postsArray.forEach(post => {
            const postElement = document.createElement('div');
            postElement.className = 'post-item';
            postElement.onclick = () => openPostModal(post.id);

            // Use excerpt from PostSummaryResponse (content is not available in summary)
            const excerpt = post.excerpt || 'No excerpt available';

            postElement.innerHTML = `
                <div class="post-header">
                    <h3 class="post-title">${escapeHtml(post.title || 'Untitled')}</h3>
                    <span class="post-status ${post.isPublished ? 'status-published' : 'status-draft'}">
                        ${post.isPublished ? 'Published' : 'Draft'}
                    </span>
                </div>
                <p class="post-excerpt">${escapeHtml(excerpt)}</p>
                <div class="post-meta">
                    <div class="post-stats">
                        <span>👁️ ${post.viewCount || 0} views</span>
                        <span>💬 ${post.commentsCount || 0} comments</span>
                        <span>⏱️ ${post.readingTime || 1} min read</span>
                    </div>
                    <div class="post-date">
                        ${post.isPublished && post.publishedAt
                            ? `Published: ${new Date(post.publishedAt).toLocaleDateString()}`
                            : post.createdAt
                                ? `Created: ${new Date(post.createdAt).toLocaleDateString()}`
                                : 'Date unknown'
                        }
                    </div>
                </div>
            `;
            postsList.appendChild(postElement);
        });

    } catch (error) {
        console.error('Error loading posts:', error);
        const postsList = document.getElementById('posts-list');
        postsList.innerHTML = `
            <div class="post-item">
                <div class="post-header">
                    <h3 class="post-title">Error loading posts</h3>
                </div>
                <p class="post-excerpt">Error: ${error.message}. Please try refreshing the page.</p>
            </div>
        `;
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
        } else {
            alert('Error creating post: ' + data.error);
        }
    } catch (error) {
        alert('Error creating post: ' + error.message);
    }
}

// Post Modal Management
async function openPostModal(postId) {
    currentPostId = postId;

    try {
        const response = await fetch(`${API_BASE}/api/posts/${postId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });

        const post = await response.json();

        if (response.ok) {
            // Update modal content
            document.getElementById('modal-post-title').textContent = post.title;
            document.getElementById('modal-post-content').innerHTML = `
                <div class="post-content">
                    <p><strong>Status:</strong> ${post.isPublished ? 'Published' : 'Draft'}</p>
                    <p><strong>Author:</strong> ${post.authorName}</p>
                    <p><strong>Views:</strong> ${post.viewCount || 0} | <strong>Reading Time:</strong> ${post.readingTime || 1} min</p>
                    <p><strong>Created:</strong> ${new Date(post.createdAt).toLocaleDateString()}</p>
                    ${post.publishedAt ? `<p><strong>Published:</strong> ${new Date(post.publishedAt).toLocaleDateString()}</p>` : ''}
                    <hr style="margin: 1rem 0;">
                    <div class="post-body">${post.content.replace(/\n/g, '<br>')}</div>
                </div>
            `;

            // Update toggle status button
            const toggleBtn = document.getElementById('toggle-status-btn');
            toggleBtn.textContent = post.isPublished ? 'Make Draft' : 'Publish';

            // Load comments for this post
            loadPostComments(postId);

            // Show modal
            document.getElementById('post-detail-modal').style.display = 'flex';
        } else {
            alert('Error loading post: ' + post.error);
        }
    } catch (error) {
        alert('Error loading post: ' + error.message);
    }
}

function closePostModal() {
    document.getElementById('post-detail-modal').style.display = 'none';
    currentPostId = null;
}

async function togglePostStatus() {
    if (!currentPostId) return;

    console.log('togglePostStatus called with authToken:', authToken);
    console.log('currentPostId:', currentPostId);

    try {
        // First get the current post data
        const getResponse = await fetch(`${API_BASE}/api/posts/${currentPostId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });

        const currentPost = await getResponse.json();
        if (!getResponse.ok) {
            alert('Error getting post data: ' + currentPost.error);
            return;
        }

        // Toggle the published status
        const updateData = {
            isPublished: !currentPost.isPublished
        };

        console.log('Sending PUT request with authToken:', authToken);
        console.log('Update data:', updateData);

        const response = await fetch(`${API_BASE}/api/posts/${currentPostId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },

            body: JSON.stringify(updateData)
        });

        if (response.ok) {
            // Refresh the modal and posts list
            openPostModal(currentPostId);
            loadPosts();
        } else {
            const data = await response.json();
            alert('Error updating post: ' + data.error);
        }
    } catch (error) {
        alert('Error updating post: ' + error.message);
    }
}

function editPost() {
    // For now, just show an alert. This could be expanded to show an edit form
    alert('Edit functionality coming soon! For now, you can delete and recreate the post.');
}

async function deleteCurrentPost() {
    if (!currentPostId) return;

    if (!confirm('Are you sure you want to delete this post? This action cannot be undone.')) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE}/api/posts/${currentPostId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });

        if (response.ok) {
            closePostModal();
            loadPosts();
            alert('Post deleted successfully!');
        } else {
            const data = await response.json();
            alert('Error deleting post: ' + data.error);
        }
    } catch (error) {
        alert('Error deleting post: ' + error.message);
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
async function loadPostComments(postId) {
    try {
        const response = await fetch(`${API_BASE}/api/posts/${postId}/comments`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });

        const comments = await response.json();
        const commentsList = document.getElementById('post-comments');

        if (!response.ok) {
            commentsList.innerHTML = '<p>Error loading comments</p>';
            return;
        }

        if (comments.length === 0) {
            commentsList.innerHTML = '<p>No comments yet.</p>';
            return;
        }

        commentsList.innerHTML = comments.map(comment => `
            <div class="comment-item">
                <div class="comment-author">${escapeHtml(comment.authorName || 'Anonymous')}</div>
                <div class="comment-content">${escapeHtml(comment.content)}</div>
                <div class="comment-meta">
                    ${new Date(comment.createdAt).toLocaleDateString()} •
                    Status: ${comment.isApproved ? 'Approved' : 'Pending'}
                    ${!comment.isApproved ?
                        `<button class="btn btn-secondary" style="margin-left: 1rem; padding: 0.25rem 0.5rem; font-size: 0.8rem;" onclick="approveComment('${comment.id}')">Approve</button>`
                        : ''
                    }
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading comments:', error);
        document.getElementById('post-comments').innerHTML = '<p>Error loading comments</p>';
    }
}

async function approveComment(commentId) {
    try {
        const response = await fetch(`${API_BASE}/api/comments/${commentId}/approve`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${authToken}`
            },

        });

        if (response.ok) {
            // Reload comments for current post
            if (currentPostId) {
                loadPostComments(currentPostId);
            }
        } else {
            const data = await response.json();
            alert('Error approving comment: ' + data.error);
        }
    } catch (error) {
        alert('Error approving comment: ' + error.message);
    }
}

// Utility Functions

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Close modal when clicking outside
document.addEventListener('click', function(event) {
    const modal = document.getElementById('post-detail-modal');
    if (event.target === modal) {
        closePostModal();
    }
});

// Close modal with Escape key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closePostModal();
    }
});
