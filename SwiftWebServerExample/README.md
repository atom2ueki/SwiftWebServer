# SwiftWebServer Example Application

A comprehensive demonstration of the SwiftWebServer framework capabilities, featuring a full-stack web application with SwiftUI console interface, REST API, and interactive web frontend.

## 🚀 Features Demonstrated

### Core Framework Features
- **Middleware Architecture**: Chained middleware with request/response processing
- **Routing System**: Path parameters, query parameters, and HTTP methods
- **Authentication**: Bearer token authentication with protected routes
- **Static File Serving**: HTML, CSS, JavaScript, and asset delivery
- **Real-time Logging**: Comprehensive request/response logging with filtering

### Middleware Components
- **LoggerMiddleware**: Configurable logging with custom output
- **CORSMiddleware**: Cross-origin resource sharing with flexible configuration
- **CookieMiddleware**: Cookie parsing and management with security attributes
- **BodyParser**: JSON, form-urlencoded, and multipart data parsing
- **ETagMiddleware**: Conditional requests with 304 Not Modified responses
- **BearerTokenMiddleware**: JWT and custom token authentication

### Data Management
- **SwiftData Integration**: Modern data persistence with relationships
- **Observation Framework**: Real-time UI updates with @Observable
- **CRUD Operations**: Complete Create, Read, Update, Delete functionality
- **Data Validation**: Input validation with proper error handling

### Advanced Features
- **File Upload Simulation**: Multipart form data handling demonstration
- **Cookie Management**: Various cookie types with security attributes
- **ETag Caching**: Conditional request handling for performance
- **Error Handling**: Comprehensive error responses with proper HTTP status codes
- **API Testing Interface**: Built-in API testing with live requests

## 📋 Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- SwiftWebServer framework (included as local dependency)

## 🛠 Installation & Setup

1. **Clone or Download** the SwiftWebServer project
2. **Open** `SwiftWebServerExample.xcodeproj` in Xcode
3. **Build and Run** the project (⌘+R)

The application will automatically:
- Initialize the SwiftData model container
- Set up the data manager with Observation framework
- Configure the web server with all middleware
- Create sample data if none exists

## 🎯 How to Use

### 1. SwiftUI Console Interface

The main application window provides:

#### Server Control Panel
- **Start/Stop Server**: Control server lifecycle
- **Port Configuration**: Customize server port (default: 8080)
- **Real-time Statistics**: Live data counts and server status
- **Quick Actions**: Open web interface, clear logs

#### Console Tab
- **Real-time Logs**: Live server activity with color-coded log levels
- **Log Filtering**: Filter by log level (Info, Success, Warning, Error)
- **Search Functionality**: Search through log messages
- **Auto-scroll**: Automatic scrolling to latest logs

#### Data Tab
- **User Management**: View all users with statistics
- **Post Management**: Browse posts with metadata
- **Comment Management**: Review comments with approval status
- **Real-time Updates**: Live data updates using Observation framework

#### Web Interface Tab
- **Embedded Browser**: Preview the web interface within the app
- **Direct Access**: Open in external browser

#### API Testing Tab
- **Interactive Testing**: Test any API endpoint
- **Method Selection**: Support for GET, POST, PUT, DELETE
- **Authentication**: Bearer token authentication testing
- **Response Viewer**: Formatted JSON response display

### 2. Web Interface

The server binds to all network interfaces (0.0.0.0), making it accessible from:
- **Local access**: `http://localhost:8080` (or your configured port)
- **Network access**: `http://[your-ip]:8080` (accessible from other devices on the same network)
- **iPad Split View**: Perfect for side-by-side development with Safari

#### Overview Dashboard
- Server status and statistics
- Feature showcase with active middleware
- Real-time data metrics

#### User Management
- Create new users with validation
- View user profiles and statistics
- Demonstrates user CRUD operations

#### Post Management
- Create and manage blog posts
- Publish/unpublish functionality
- View counts and engagement metrics

#### API Testing
- Interactive API endpoint testing
- Live request/response viewer
- Authentication demonstration

#### Server Logs
- Real-time log display (simulated)
- Log filtering and search

### 3. API Endpoints

#### Authentication
```
POST /api/auth/login
POST /api/auth/logout
```

#### Users
```
GET    /api/users
POST   /api/users
GET    /api/users/{id}
PUT    /api/users/{id}
DELETE /api/users/{id}
```

#### Posts
```
GET    /api/posts
POST   /api/posts          (auth required)
GET    /api/posts/{id}
PUT    /api/posts/{id}     (auth required)
DELETE /api/posts/{id}     (auth required)
```

#### Comments
```
GET    /api/posts/{postId}/comments
POST   /api/posts/{postId}/comments  (auth required)
GET    /api/comments/{id}
PUT    /api/comments/{id}            (auth required)
DELETE /api/comments/{id}            (auth required)
```

#### Advanced Features Demo
```
GET  /api/demo/etag      - ETag caching demonstration
GET  /api/demo/cookies   - Cookie management demo
POST /api/demo/upload    - File upload simulation
GET  /api/demo/cors      - CORS headers demonstration
GET  /api/demo/error     - Error handling demo
```

#### System
```
GET /api/health          - Health check
GET /api/info            - Server information
GET /api/admin/stats     - Admin statistics (auth required)
```

## 🔐 Authentication

The example includes a simple authentication system:

### Default Users
- **Username**: `johndoe`, **Password**: `password123`
- **Username**: `janedoe`, **Password**: `password123`

### Authentication Flow
1. **Login**: POST to `/api/auth/login` with username/password
2. **Token**: Receive bearer token in response
3. **Usage**: Include `Authorization: Bearer <token>` header
4. **Logout**: POST to `/api/auth/logout` to clear session

## 🧪 Testing the Features

### 1. Middleware Testing

#### CORS
```bash
curl -H "Origin: https://example.com" http://localhost:8080/api/demo/cors
```

#### Cookies
```bash
curl -c cookies.txt -b cookies.txt http://localhost:8080/api/demo/cookies
```

#### ETag
```bash
# First request
curl -i http://localhost:8080/api/demo/etag

# Second request with ETag
curl -H "If-None-Match: <etag-value>" http://localhost:8080/api/demo/etag
```

### 2. Authentication Testing

```bash
# Login
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"johndoe","password":"password123"}' \
  http://localhost:8080/api/auth/login

# Use token
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/posts
```

### 3. CRUD Operations

```bash
# Create user
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123","firstName":"Test","lastName":"User"}' \
  http://localhost:8080/api/users

# Create post (requires auth)
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"title":"Test Post","content":"This is a test post","isPublished":true}' \
  http://localhost:8080/api/posts
```

## 📁 Project Structure

```
SwiftWebServerExample/
├── SwiftWebServerExample/
│   ├── Models/
│   │   ├── User.swift              # SwiftData user model
│   │   ├── Post.swift              # SwiftData post model
│   │   └── Comment.swift           # SwiftData comment model
│   ├── Services/
│   │   ├── DataManager.swift       # Data management with Observation
│   │   ├── WebServerManager.swift  # Server configuration and control
│   │   ├── WebServerRequestHandlers.swift    # Basic API handlers
│   │   ├── WebServerPostHandlers.swift       # Post/Comment handlers
│   │   └── WebServerAdvancedHandlers.swift   # Advanced feature demos
│   ├── Views/
│   │   ├── MainView.swift          # Main SwiftUI interface with toolbar
│   │   ├── ServerConsoleView.swift # Real-time console logs
│   │   ├── DataOverviewView.swift  # Data management interface
│   │   ├── ContentManagementView.swift # CMS interface for content
│   │   ├── CMSComponents.swift     # CMS row components and badges
│   │   ├── CMSForms.swift          # CMS forms for creating/editing
│   │   └── APITestingView.swift    # API testing interface
│   ├── ContentView.swift           # Root view with initialization
│   └── SwiftWebServerExampleApp.swift  # App entry point
└── public/
    ├── index.html                  # Main web interface
    ├── css/styles.css              # Responsive styling
    ├── js/app.js                   # Interactive JavaScript
    └── favicon.ico                 # Site icon
```

## 🎨 Architecture Highlights

### Observation Framework Integration
- Real-time UI updates without manual refresh
- Automatic data synchronization between views
- Modern Swift concurrency patterns

### Middleware Chain
```
Request → Logger → CORS → Cookie → BodyParser → ETag → Auth → Route Handler
Response ← Logger ← CORS ← Cookie ← BodyParser ← ETag ← Auth ← Route Handler
```

### Data Flow
```
SwiftUI Views ↔ DataManager (Observable) ↔ SwiftData ↔ WebServer ↔ API Clients
```

## 🔧 Customization

### Adding New Endpoints
1. Add route in `WebServerManager.configureRoutes()`
2. Implement handler method
3. Update web interface if needed

### Adding New Middleware
1. Create middleware class implementing `Middleware` protocol
2. Add to middleware chain in `WebServerManager.configureMiddleware()`
3. Configure options as needed

### Extending Data Models
1. Update SwiftData models with new properties
2. Add validation in request/response models
3. Update DataManager methods
4. Refresh UI components

## 📚 Learning Resources

This example demonstrates:
- Modern Swift web development patterns
- SwiftData for persistence
- Observation framework for reactive UIs
- Middleware architecture design
- RESTful API best practices
- Authentication and authorization
- Error handling and validation
- Real-time logging and monitoring

## 🤝 Contributing

This example is part of the SwiftWebServer framework. Contributions and improvements are welcome!

## 📄 License

This project is licensed under the MIT License - see the main SwiftWebServer LICENSE file for details.
