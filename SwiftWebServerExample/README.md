# SwiftWebServer Example Application

A comprehensive demonstration of the SwiftWebServer framework capabilities, featuring a full-stack web application with SwiftUI console interface, dual-server architecture, and interactive blog platform.

## 🚀 Features Demonstrated

### Core Framework Features
- **Middleware Architecture**: Chained middleware with request/response processing and next() calls
- **Routing System**: Path parameters (`/post/{id}`), query parameters, and HTTP methods
- **Authentication**: Bearer token authentication with JWT tokens and protected routes
- **Static File Serving**: HTML, CSS, JavaScript, and asset delivery with proper MIME types
- **Real-time Logging**: Comprehensive request/response logging with filtering and haptic feedback
- **CORS Support**: Cross-origin resource sharing with configurable headers
- **Body Parsing**: JSON request body parsing middleware
- **Cookie Management**: Cookie parsing and setting with secure options
- **ETag Caching**: HTTP caching with ETag generation for performance
- **Error Handling**: Custom error responses with proper HTTP status codes

### Application Architecture
- **Dual Server Setup**: Separate backend API server (port 8080) and frontend static server (port 3000)
- **SwiftUI Dashboard**: Native iOS interface with dashboard cards and server controls
- **SwiftData Integration**: Modern data persistence with Observation framework
- **Responsive Web UI**: Mobile-first blog interface with admin panel
- **Session Management**: Token-based authentication with automatic cleanup

## 📱 SwiftUI Console Interface

### Dashboard Layout
The main interface features a dashboard-style layout with:

#### Server Status Cards
- **Backend Server**: API server control with port configuration
- **Frontend Server**: Static file server control with separate port
- **Real-time Status**: Live server status with haptic feedback
- **Quick Actions**: Start/stop servers with consistent UI heights

#### Data Management Cards
- **Users Management**: User creation, editing, and statistics
- **Posts Management**: Blog post creation with publish/draft status
- **Comments Management**: Comment moderation and approval
- **Sessions Management**: Active authentication token monitoring

#### Console View
- **Live Logging**: Real-time request/response logs with timestamps
- **Log Filtering**: Filter by request type, status code, or search terms
- **Log Management**: Clear logs with confirmation and haptic feedback
- **Export Options**: Copy logs to clipboard with haptic feedback

## 🌐 Web Interface Features

### Blog Platform
The frontend serves a complete blog platform at `http://localhost:3000`:

#### Public Blog (`/`)
- **Responsive Design**: Mobile-first layout with clean typography
- **Post Listings**: Published posts with metadata (author, date, reading time)
- **Post Statistics**: View counts, comment counts, and reading time estimates
- **Authentication UI**: Dynamic login/admin button in header
- **Post Navigation**: Path parameter URLs (`/post/{id}`) for individual posts

#### Post Detail Pages (`/post/{id}`)
- **Full Content Display**: Complete post content with proper formatting
- **Comment System**: Interactive commenting with approval workflow
- **Navigation**: Back button and admin access for authenticated users
- **Responsive Layout**: Full-width content with consistent header/footer

#### Admin Panel (`/admin`)
- **Authentication Required**: Protected routes with token validation
- **Post Management**: Create, edit, publish/unpublish posts
- **Comment Moderation**: Approve/reject comments per post
- **User Information**: Display current admin user details
- **Logout Functionality**: Secure session termination

#### Login System (`/login`)
- **Clean Interface**: Focused login form with error handling
- **Token Storage**: localStorage-based JWT token management
- **Automatic Redirect**: Redirect to admin panel after successful login
- **Error Feedback**: Clear error messages for failed attempts

## 🛠 Technical Implementation

### Backend API (Port 8080)
The backend server provides a comprehensive REST API:

#### Authentication Endpoints
- `POST /api/auth/login` - User authentication with JWT token generation
- `POST /api/auth/logout` - Token invalidation and session cleanup

#### Content Management API
- `GET /api/posts` - List posts with optional `published=true` filter
- `GET /api/posts/{id}` - Get individual post with view count increment
- `POST /api/posts` - Create new posts (authenticated)
- `PUT /api/posts/{id}` - Update posts including publish status (authenticated)
- `DELETE /api/posts/{id}` - Delete posts (authenticated)

#### Comment System API
- `GET /api/posts/{id}/comments` - Get approved comments for a post
- `POST /api/posts/{id}/comments` - Submit new comments (authenticated)
- `PUT /api/comments/{id}/approve` - Approve comments (authenticated)
- `DELETE /api/comments/{id}` - Delete comments (authenticated)

#### User Management API
- `GET /api/users` - List all users (authenticated)
- `POST /api/users` - Create new users (authenticated)
- `PUT /api/users/{id}` - Update user information (authenticated)
- `DELETE /api/users/{id}` - Delete users (authenticated)

#### System Information
- `GET /api/health` - Server health check
- `GET /api/info` - Server information and statistics

### Frontend Server (Port 3000)
Serves static files from the `public` folder:
- HTML pages with responsive design
- CSS stylesheets with mobile-first approach
- JavaScript modules with modern ES6+ features
- Static assets (favicon, images)

### Data Models
Built with SwiftData for modern Swift persistence:

#### User Model
- Unique ID, username, email validation
- Password hashing with secure storage
- Relationships to posts, comments, and auth tokens
- Activity status and timestamp tracking

#### Post Model
- Title, content, and author relationships
- Publish/draft status with publication timestamps
- View count tracking and reading time calculation
- Comment relationships with cascade deletion

#### Comment Model
- Content with author and post relationships
- Approval workflow for moderation
- Timestamp tracking for creation and updates

#### AuthToken Model
- JWT token storage with expiration
- User relationship for session management
- Automatic cleanup of expired tokens

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later
- SwiftWebServer package (included as local dependency)

### Installation
1. Open `SwiftWebServerExample.xcodeproj` in Xcode
2. Build and run the project on iOS Simulator or device
3. The app will automatically initialize SwiftData and configure servers

### Usage
1. **Start Servers**: Use the dashboard cards to start backend and frontend servers
2. **Access Web Interface**: Tap "Open Frontend" to view the blog in Safari
3. **Create Content**: Use the SwiftUI interface to create users and posts
4. **Admin Access**: Login via web interface to access admin features
5. **Monitor Activity**: View real-time logs and statistics in the console

## 📁 Project Structure

```
SwiftWebServerExample/
├── SwiftWebServerExample/
│   ├── Models/
│   │   ├── User.swift              # SwiftData user model with relationships
│   │   ├── Post.swift              # SwiftData post model with publishing
│   │   ├── Comment.swift           # SwiftData comment model with approval
│   │   └── AuthToken.swift         # JWT token model with expiration
│   ├── Services/
│   │   ├── DataManager.swift       # Data management with Observation
│   │   ├── WebServerManager.swift  # Backend server configuration
│   │   ├── FrontendServerManager.swift # Frontend server management
│   │   ├── WebServerRequestHandlers.swift    # Basic API handlers
│   │   ├── WebServerPostHandlers.swift       # Post/Comment handlers
│   │   └── WebServerAdvancedHandlers.swift   # Advanced feature demos
│   ├── Views/
│   │   ├── MainView.swift          # Dashboard-style main interface
│   │   ├── DashboardGrid.swift     # Grid layout for dashboard cards
│   │   ├── DashboardCard.swift     # Reusable dashboard card component
│   │   ├── ServerStatusCard.swift  # Server control cards
│   │   ├── ConsoleView.swift       # Real-time logging interface
│   │   ├── UsersManagementView.swift    # User management interface
│   │   ├── PostsManagementView.swift    # Post management interface
│   │   ├── CommentsManagementView.swift # Comment management interface
│   │   └── SessionsManagementView.swift # Session management interface
│   ├── public/                     # Frontend static files
│   │   ├── index.html             # Blog homepage
│   │   ├── post.html              # Post detail page
│   │   ├── login.html             # Admin login page
│   │   ├── admin.html             # Admin dashboard
│   │   ├── 404.html               # Custom 404 error page
│   │   ├── css/                   # Stylesheets
│   │   │   ├── blog.css           # Blog styling
│   │   │   ├── post.css           # Post detail styling
│   │   │   ├── login.css          # Login page styling
│   │   │   └── admin.css          # Admin panel styling
│   │   └── js/                    # JavaScript modules
│   │       ├── blog.js            # Blog functionality
│   │       ├── post.js            # Post detail functionality
│   │       ├── login.js           # Login functionality
│   │       └── admin.js           # Admin panel functionality
│   ├── SwiftWebServerExampleApp.swift # App entry point with SwiftData
│   └── ContentView.swift         # Root view with manager initialization
└── README.md                     # This documentation
```

## 🎯 Key Learning Points

### Middleware Architecture
- **Chained Processing**: Middleware functions that modify req/res and call next()
- **Order Matters**: Middleware execution order affects request processing
- **Error Handling**: Proper error responses with appropriate HTTP status codes
- **Authentication**: Bearer token validation with protected route patterns

### Modern Swift Patterns
- **Observation Framework**: Real-time UI updates with @Observable
- **SwiftData Integration**: Modern Core Data replacement with relationships
- **Async/Await**: Modern concurrency for network operations
- **Error Handling**: Comprehensive error types and validation

### Web Development Best Practices
- **Responsive Design**: Mobile-first CSS with flexible layouts
- **Progressive Enhancement**: JavaScript functionality that degrades gracefully
- **Security**: Token-based authentication with proper validation
- **Performance**: ETag caching and optimized asset delivery

### iOS Development Integration
- **Native UI**: SwiftUI dashboard with haptic feedback
- **Background Processing**: Server management without blocking UI
- **Data Persistence**: SwiftData with automatic relationship management
- **Cross-Platform**: Web interface accessible from any device

## 🔧 Customization

### Adding New API Endpoints
1. Add handler methods to appropriate handler files
2. Register routes in `WebServerManager.configureRoutes()`
3. Update frontend JavaScript to consume new endpoints

### Extending Data Models
1. Add properties to SwiftData models
2. Update API request/response structures
3. Modify frontend forms and displays accordingly

### Customizing UI
1. Modify SwiftUI views for native interface changes
2. Update CSS files for web interface styling
3. Add new dashboard cards for additional functionality

## 📚 Framework Features Showcased

This example demonstrates the full capabilities of SwiftWebServer:
- ✅ HTTP server with custom port configuration
- ✅ Middleware architecture with chaining support
- ✅ Static file serving with proper MIME types
- ✅ JSON API endpoints with request/response handling
- ✅ Path parameter routing (`/post/{id}`)
- ✅ Query parameter parsing
- ✅ Request body parsing (JSON)
- ✅ Authentication middleware with Bearer tokens
- ✅ CORS support for cross-origin requests
- ✅ Cookie parsing and management
- ✅ ETag caching for performance
- ✅ Custom error pages (404.html)
- ✅ Real-time logging with filtering
- ✅ Server lifecycle management
- ✅ Integration with SwiftUI and SwiftData

## 🤝 Contributing

This example serves as both a demonstration and a starting point for your own SwiftWebServer applications. Feel free to:
- Extend the functionality with new features
- Improve the UI/UX design
- Add additional middleware examples
- Enhance the blog platform capabilities

## 📄 License

This example application is provided as part of the SwiftWebServer framework for educational and demonstration purposes.

---

**Powered by [SwiftWebServer](https://github.com/atom2ueki/SwiftWebServer) with ❤️**