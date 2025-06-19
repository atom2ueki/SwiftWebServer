// SwiftWebServer Post Detail JavaScript

let API_BASE = '';
let currentPost = null;
let authToken = null;

// Initialize the post page
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();
    
    // Check for auth token
    authToken = getCookie('auth_token');
    
    // Get post ID from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const postId = urlParams.get('id');
    
    if (postId) {
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
        const response = await fetch(`${API_BASE}/api/posts/${postId}`);
        
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
    const formattedDate = publishedDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
    
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
        const response = await fetch(`${API_BASE}/api/posts/${postId}/comments`);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const comments = await response.json();
        
        // Update comments count
        const count = comments.length;
        commentsCount.textContent = `${count} comment${count !== 1 ? 's' : ''}`;
        
        if (comments.length === 0) {
            commentsList.innerHTML = '<div class="no-comments">No comments yet. Be the first to comment!</div>';
        } else {
            // Sort comments by date (oldest first)
            comments.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
            commentsList.innerHTML = comments.map(comment => createCommentHTML(comment)).join('');
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
    const formattedDate = commentDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
    
    return `
        <div class="comment">
            <div class="comment-header">
                <div class="comment-author">${escapeHtml(comment.author?.fullName || 'Anonymous')}</div>
                <div class="comment-date">${formattedDate}</div>
            </div>
            <div class="comment-content">${escapeHtml(comment.content)}</div>
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
            body: JSON.stringify({ content })
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

function getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
    return null;
}
