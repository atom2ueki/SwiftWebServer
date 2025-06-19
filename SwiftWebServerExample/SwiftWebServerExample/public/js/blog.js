// SwiftWebServer Blog JavaScript

let API_BASE = ''; // Will be loaded from config

// Initialize the blog
document.addEventListener('DOMContentLoaded', async function() {
    // Load configuration first
    await loadConfig();
    
    // Load published blog posts
    loadBlogPosts();
});

// Load configuration from backend
async function loadConfig() {
    try {
        const response = await fetch('/config.json');
        if (response.ok) {
            const config = await response.json();
            API_BASE = config.apiBase || '';
        } else {
            // Fallback to current origin
            API_BASE = window.location.origin;
        }
    } catch (error) {
        console.log('Using fallback API base');
        API_BASE = window.location.origin;
    }
}

// Load published blog posts
async function loadBlogPosts() {
    const postsContainer = document.getElementById('blog-posts');
    
    try {
        // Fetch only published posts
        const response = await fetch(`${API_BASE}/api/posts?published=true`);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const posts = await response.json();
        
        if (posts.length === 0) {
            postsContainer.innerHTML = `
                <div class="no-posts">
                    <h3>📝 No Posts Yet</h3>
                    <p>Check back soon for new content!</p>
                </div>
            `;
            return;
        }
        
        // Sort posts by published date (newest first)
        posts.sort((a, b) => new Date(b.publishedAt || b.createdAt) - new Date(a.publishedAt || a.createdAt));
        
        // Render posts
        postsContainer.innerHTML = posts.map(post => createPostCard(post)).join('');
        
    } catch (error) {
        console.error('Error loading blog posts:', error);
        postsContainer.innerHTML = `
            <div class="no-posts">
                <h3>⚠️ Unable to Load Posts</h3>
                <p>Please try refreshing the page.</p>
            </div>
        `;
    }
}

// Create a blog post card HTML
function createPostCard(post) {
    const publishedDate = new Date(post.publishedAt || post.createdAt);
    const formattedDate = publishedDate.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
    
    // Create excerpt if not provided
    const excerpt = post.excerpt || (post.content ? 
        post.content.substring(0, 200) + (post.content.length > 200 ? '...' : '') : 
        'No preview available'
    );
    
    return `
        <article class="blog-post" onclick="viewPost('${post.id}')">
            <div class="post-header">
                <h2 class="post-title">${escapeHtml(post.title)}</h2>
                <div class="post-meta">
                    <div class="post-author">
                        <span>👤</span>
                        <span>${escapeHtml(post.authorName || 'Anonymous')}</span>
                    </div>
                    <div class="post-date">
                        <span>📅</span>
                        <span>${formattedDate}</span>
                    </div>
                    <div class="post-stats">
                        <span>👁️ ${post.viewCount || 0}</span>
                        <span>💬 ${post.commentsCount || 0}</span>
                        <span>⏱️ ${post.readingTime || 1} min read</span>
                    </div>
                </div>
            </div>
            <div class="post-excerpt">
                <p>${escapeHtml(excerpt)}</p>
            </div>
            <div class="post-footer">
                <div class="post-tags">
                    <!-- Tags could be added here if available -->
                </div>
                <a href="#" class="read-more" onclick="event.stopPropagation(); viewPost('${post.id}')">
                    Read More <span>→</span>
                </a>
            </div>
        </article>
    `;
}

// View individual blog post
function viewPost(postId) {
    // Navigate to the post detail page
    window.location.href = `/post.html?id=${postId}`;
}

// Utility function to escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
