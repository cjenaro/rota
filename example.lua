#!/usr/bin/env lua

-- Example of using Rota with Motor
-- This demonstrates the integration between the HTTP server and routing engine

local motor = require("motor")
local rota = require("src.init")

-- Create a new router
local router = rota.new()

-- Add some global middleware
router:use(function(req, next)
    print(string.format("[%s] %s %s", os.date("%Y-%m-%d %H:%M:%S"), req.method, req.path))
    local start_time = os.clock()
    
    local response = next()
    
    local duration = (os.clock() - start_time) * 1000
    print(string.format("  -> %d (%d ms)", response.status, math.floor(duration)))
    
    return response
end)

-- Add CORS middleware for API routes
local function cors_middleware(req, next)
    local response = next()
    
    response.headers = response.headers or {}
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    
    return response
end

-- Basic routes
router:get("/", function(req)
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/html" },
        body = [[
<!DOCTYPE html>
<html>
<head>
    <title>Foguete + Rota Example</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .endpoint { margin: 10px 0; padding: 10px; background: #f5f5f5; }
        code { background: #eee; padding: 2px 4px; }
    </style>
</head>
<body>
    <h1>🚀 Foguete + Rota Example</h1>
    <p>This server demonstrates the integration between Motor (HTTP server) and Rota (routing engine).</p>
    
    <h2>Available Endpoints:</h2>
    <div class="endpoint">
        <strong>GET /</strong> - This welcome page
    </div>
    <div class="endpoint">
        <strong>GET /hello</strong> - Simple greeting
    </div>
    <div class="endpoint">
        <strong>GET /hello/:name</strong> - Personalized greeting
    </div>
    <div class="endpoint">
        <strong>GET /api/users</strong> - List users (JSON)
    </div>
    <div class="endpoint">
        <strong>GET /api/users/:id</strong> - Get user by ID (JSON)
    </div>
    <div class="endpoint">
        <strong>POST /api/users</strong> - Create user (JSON)
    </div>
    <div class="endpoint">
        <strong>GET /files/*path</strong> - Wildcard file paths
    </div>
    
    <h2>Try these:</h2>
    <ul>
        <li><a href="/hello">GET /hello</a></li>
        <li><a href="/hello/World">GET /hello/World</a></li>
        <li><a href="/api/users">GET /api/users</a></li>
        <li><a href="/api/users/123">GET /api/users/123</a></li>
        <li><a href="/files/docs/readme.txt">GET /files/docs/readme.txt</a></li>
    </ul>
</body>
</html>
        ]]
    }
end)

-- Simple greeting
router:get("/hello", function(req)
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/plain" },
        body = "Hello, Foguete!"
    }
end)

-- Parameterized greeting
router:get("/hello/:name", function(req)
    local name = req.params.name or "World"
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/plain" },
        body = "Hello, " .. name .. "!"
    }
end)

-- API routes with CORS
router:group("/api", function(api)
    api:use(cors_middleware)
    
    -- Mock users data
    local users = {
        { id = 1, name = "Alice", email = "alice@example.com" },
        { id = 2, name = "Bob", email = "bob@example.com" },
        { id = 3, name = "Charlie", email = "charlie@example.com" }
    }
    
    -- List users
    api:get("/users", function(req)
        local user_json = {}
        for _, user in ipairs(users) do
            table.insert(user_json, string.format('{"id": %d, "name": "%s", "email": "%s"}', 
                user.id, user.name, user.email))
        end
        
        return {
            status = 200,
            headers = { ["Content-Type"] = "application/json" },
            body = string.format('{"users": [%s]}', table.concat(user_json, ", "))
        }
    end)
    
    -- Get user by ID
    api:get("/users/:id", function(req)
        local user_id = tonumber(req.params.id)
        if not user_id then
            return {
                status = 400,
                headers = { ["Content-Type"] = "application/json" },
                body = '{"error": "Invalid user ID"}'
            }
        end
        
        local user = nil
        for _, u in ipairs(users) do
            if u.id == user_id then
                user = u
                break
            end
        end
        
        if not user then
            return {
                status = 404,
                headers = { ["Content-Type"] = "application/json" },
                body = '{"error": "User not found"}'
            }
        end
        
        return {
            status = 200,
            headers = { ["Content-Type"] = "application/json" },
            body = string.format('{"id": %d, "name": "%s", "email": "%s"}', 
                user.id, user.name, user.email)
        }
    end)
    
    -- Create user (mock)
    api:post("/users", function(req)
        return {
            status = 201,
            headers = { ["Content-Type"] = "application/json" },
            body = '{"id": 4, "name": "New User", "email": "newuser@example.com", "message": "User created successfully"}'
        }
    end)
end)

-- Wildcard route for files
router:get("/files/*path", function(req)
    local file_path = req.params.path or ""
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/plain" },
        body = string.format("You requested file: %s\nThis is a demo - no actual file serving implemented.", file_path)
    }
end)

-- Create RESTful resource for posts
local posts_controller = {
    index = function(req)
        return {
            status = 200,
            headers = { ["Content-Type"] = "application/json" },
            body = '{"posts": [{"id": 1, "title": "Hello World", "content": "This is a test post"}]}'
        }
    end,
    
    show = function(req)
        local post_id = req.params.id
        return {
            status = 200,
            headers = { ["Content-Type"] = "application/json" },
            body = string.format('{"id": "%s", "title": "Post %s", "content": "Content for post %s"}', 
                post_id, post_id, post_id)
        }
    end,
    
    create = function(req)
        return {
            status = 201,
            headers = { ["Content-Type"] = "application/json" },
            body = '{"id": "new", "title": "New Post", "content": "This is a new post", "message": "Post created"}'
        }
    end
}

router:resources("posts", posts_controller)

-- 404 handler (this should be last)
router:any("*", function(req)
    return {
        status = 404,
        headers = { ["Content-Type"] = "text/html" },
        body = [[
<!DOCTYPE html>
<html>
<head><title>404 - Not Found</title></head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The requested URL <code>]] .. req.path .. [[</code> was not found on this server.</p>
    <p><a href="/">← Back to Home</a></p>
</body>
</html>
        ]]
    }
end)

-- Start the server with the router
print("🚀 Starting Foguete server with Rota routing...")
print("Available at: http://localhost:8080")
print("Press Ctrl+C to stop")

motor.serve({
    host = "127.0.0.1",
    port = 8080
}, router:handler()) 