// SwiftWebServer Post Detail JavaScript

let API_BASE = '';
let currentPost = null;
let authToken = null;

// Initialize the post page
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();
    
    // Check for auth token and update UI
    authToken = localStorage.getItem('auth_token');
    updateAuthButton();

    // Get post ID from URL path parameters
    const pathParts = window.location.pathname.split('/');
    const postId = pathParts[2]; // /post/{id} -> pathParts[2] is the ID

    if (postId && postId !== '') {
        await loadPost(postId);
        await loadComments(postId);
    } else {
        showError('No post ID specified');
    }
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

// Load individual post
async function loadPost(postId) {
    const articleContainer = document.getElementById('post-article');
    
    try {
        const response = await fetch(`${API_BASE}/api/posts/${postId}`, {
            credentials: 'include' // Include cookies in cross-origin requests
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const post = await response.json();
        currentPost = post;
        
        // Update page title
        document.title = `${post.title} - SwiftWebServer Blog`;
        
        // Render post
        articleContainer.innerHTML = createPostHTML(post);
        
        // Show comments section
        document.getElementById('comments-section').style.display = 'block';
        
    } catch (error) {
        console.error('Error loading post:', error);
        showError('Unable to load the post. Please try again.');
    }
}

// Create post HTML
function createPostHTML(post) {
    const publishedDate = new Date(post.publishedAt || post.createdAt);
    const formattedDate = isValidDate(publishedDate) ? publishedDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }) : 'Date unavailable';
    
    return `
        <div class="post-content-header">
            <h1 class="post-content-title">${escapeHtml(post.title)}</h1>
            <div class="post-content-meta">
                <div class="post-content-author">
                    <span>👤</span>
                    <span>${escapeHtml(post.author?.fullName || 'Anonymous')}</span>
                </div>
                <div class="post-content-date">
                    <span>📅</span>
                    <span>${formattedDate}</span>
                </div>
                <div class="post-content-stats">
                    <span>👁️ ${post.viewCount || 0} views</span>
                    <span>💬 ${post.commentsCount || 0} comments</span>
                    <span>⏱️ ${post.readingTime || 1} min read</span>
                </div>
            </div>
        </div>
        <div class="post-content-body">
            ${formatPostContent(post.content)}
        </div>
    `;
}

// Load comments for the post
async function loadComments(postId) {
    const commentsList = document.getElementById('comments-list');
    const commentsCount = document.getElementById('comments-count');

    try {
        // Check if user is authenticated to show pending comments
        const includeUnapproved = authToken ? '?include_unapproved=true' : '';
        const headers = authToken ? {
            'Authorization': `Bearer ${authToken}`
        } : {};

        const response = await fetch(`${API_BASE}/api/posts/${postId}/comments${includeUnapproved}`, {
            headers,
            credentials: 'include' // Include cookies in cross-origin requests
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const comments = await response.json();

        // Filter approved comments for count display
        const approvedComments = comments.filter(comment => comment.comment.isApproved);
        const count = approvedComments.length;
        commentsCount.textContent = `${count} comment${count !== 1 ? 's' : ''}`;

        if (comments.length === 0) {
            commentsList.innerHTML = '<div class="no-comments">No comments yet. Be the first to comment!</div>';
        } else {
            // Sort comments by date (oldest first)
            comments.sort((a, b) => new Date(a.comment.createdAt) - new Date(b.comment.createdAt));
            commentsList.innerHTML = comments.map(comment => createCommentHTML(comment.comment)).join('');
        }

        // Show/hide comment form based on authentication
        updateCommentFormVisibility();

    } catch (error) {
        console.error('Error loading comments:', error);
        commentsList.innerHTML = '<div class="no-comments">Unable to load comments.</div>';
    }
}

// Create comment HTML
function createCommentHTML(comment) {
    const commentDate = new Date(comment.createdAt);
    const formattedDate = isValidDate(commentDate) ? commentDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }) : 'Date unavailable';

    // Show pending status and approval button for admins
    const isAdmin = authToken; // Simple check - in a real app you'd verify admin role
    const statusBadge = !comment.isApproved ?
        `<span class="comment-status pending">Pending Approval</span>` : '';
    const approveButton = !comment.isApproved && isAdmin ?
        `<button class="btn btn-approve" onclick="approveComment('${comment.id}')">Approve</button>` : '';

    return `
        <div class="comment ${!comment.isApproved ? 'comment-pending' : ''}">
            <div class="comment-header">
                <div class="comment-author">${escapeHtml(comment.author?.fullName || 'Anonymous')}</div>
                <div class="comment-date">${formattedDate}</div>
                ${statusBadge}
            </div>
            <div class="comment-content">${escapeHtml(comment.content)}</div>
            ${approveButton ? `<div class="comment-actions">${approveButton}</div>` : ''}
        </div>
    `;
}

// Show comment form
function showCommentForm() {
    if (!authToken) {
        alert('Please login to post comments. Visit /console to login.');
        return;
    }
    
    document.getElementById('comment-form').style.display = 'block';
    document.getElementById('add-comment-btn').style.display = 'none';
    document.getElementById('comment-content').focus();
}

// Hide comment form
function hideCommentForm() {
    document.getElementById('comment-form').style.display = 'none';
    document.getElementById('add-comment-btn').style.display = 'block';
    document.getElementById('comment-content').value = '';
}

// Submit comment
async function submitComment(event) {
    event.preventDefault();
    
    if (!authToken) {
        alert('Please login to post comments.');
        return;
    }
    
    if (!currentPost) {
        alert('Post not loaded.');
        return;
    }
    
    const content = document.getElementById('comment-content').value.trim();
    if (!content) {
        alert('Please enter a comment.');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/api/posts/${currentPost.id}/comments`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            credentials: 'include', // Include cookies in cross-origin requests
            body: JSON.stringify({
                content,
                postId: currentPost.id
            })
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        // Reload comments
        await loadComments(currentPost.id);
        hideCommentForm();
        
        alert('Comment posted successfully!');
        
    } catch (error) {
        console.error('Error posting comment:', error);
        alert('Unable to post comment. Please try again.');
    }
}

// Update comment form visibility based on authentication
function updateCommentFormVisibility() {
    const addCommentBtn = document.getElementById('add-comment-btn');
    if (authToken) {
        addCommentBtn.style.display = 'block';
    } else {
        addCommentBtn.style.display = 'none';
    }
}

// Approve comment (admin function)
async function approveComment(commentId) {
    if (!authToken) {
        alert('Authentication required');
        return;
    }

    try {
        const response = await fetch(`${API_BASE}/api/comments/${commentId}/approve`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (response.ok) {
            // Reload comments to show updated status
            await loadComments(currentPost.id);
            alert('Comment approved successfully!');
        } else {
            const data = await response.json();
            alert('Error approving comment: ' + (data.error || 'Unknown error'));
        }
    } catch (error) {
        console.error('Error approving comment:', error);
        alert('Unable to approve comment. Please try again.');
    }
}

// Format post content (convert line breaks to paragraphs and handle basic formatting)
function formatPostContent(content) {
    if (!content) return '<p>No content available.</p>';
    
    // Simple formatting: convert double line breaks to paragraphs
    const paragraphs = content.split('\n\n').filter(p => p.trim());
    return paragraphs.map(p => {
        // Handle single line breaks within paragraphs
        const formatted = p.trim().replace(/\n/g, '<br>');
        return `<p>${escapeHtml(formatted)}</p>`;
    }).join('');
}

// Show error message
function showError(message) {
    const articleContainer = document.getElementById('post-article');
    articleContainer.innerHTML = `
        <div class="post-content-header">
            <h1 class="post-content-title">⚠️ Error</h1>
        </div>
        <div class="post-content-body">
            <p>${escapeHtml(message)}</p>
            <p><a href="/">← Back to Blog</a></p>
        </div>
    `;
}

// Utility functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}



function isValidDate(date) {
    return date instanceof Date && !isNaN(date.getTime());
}

// Update authentication button based on login status
function updateAuthButton() {
    const authBtn = document.getElementById('auth-btn');
    const authIcon = document.getElementById('auth-icon');

    if (authToken) {
        authIcon.textContent = '⚙️'; // Admin icon
        authBtn.title = 'Go to Admin';
    } else {
        authIcon.textContent = '👤'; // Login icon
        authBtn.title = 'Login';
    }
}

// Handle authentication button click
function handleAuthClick() {
    if (authToken) {
        // User is logged in, go to admin
        window.location.href = '/admin';
    } else {
        // User is not logged in, go to login
        window.location.href = '/login';
    }
}
