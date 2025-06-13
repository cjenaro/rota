# Rota - Routing Engine 🛣️

Rota is the flexible routing and middleware system that handles URL dispatching in Foguete applications.

## Features

- **Fast Route Matching** - Efficient trie-based lookup
- **Parameter Extraction** - Named and wildcard parameters
- **Middleware Chain** - Composable request processing
- **RESTful Conventions** - Built-in REST route patterns
- **Route Groups** - Organize routes with prefixes
- **Method Overrides** - Support for HTTP method overrides

## Quick Start

```lua
local rota = require("foguete.rota")
local router = rota.new()

-- Basic routes
router:get("/", function(req, res)
    return { status = 200, body = "Welcome!" }
end)

router:get("/users/:id", function(req, res)
    local user_id = req.params.id
    return { status = 200, body = "User " .. user_id }
end)

-- Middleware
router:use(function(req, res, next)
    print("Request to:", req.path)
    return next()
end)
```

## API Reference

### Route Definition
```lua
router:get(path, handler)     -- GET requests
router:post(path, handler)    -- POST requests  
router:put(path, handler)     -- PUT requests
router:delete(path, handler)  -- DELETE requests
router:patch(path, handler)   -- PATCH requests
router:any(path, handler)     -- Any HTTP method
```

### Route Patterns
```lua
-- Static routes
router:get("/about", handler)

-- Named parameters
router:get("/users/:id", handler)
router:get("/users/:id/posts/:post_id", handler)

-- Wildcard parameters
router:get("/files/*path", handler)

-- Optional parameters
router:get("/posts/:id?", handler)
```

### Middleware
```lua
-- Global middleware
router:use(middleware_function)

-- Route-specific middleware
router:get("/admin/*", auth_middleware, admin_handler)

-- Middleware groups
router:group("/api", function(api)
    api:use(api_middleware)
    api:get("/users", users_handler)
end)
```

### Route Groups
```lua
router:group("/api/v1", function(api)
    api:get("/users", controllers.users.index)
    api:post("/users", controllers.users.create)
    
    api:group("/admin", function(admin)
        admin:use(auth_middleware)
        admin:get("/stats", controllers.admin.stats)
    end)
end)
```

## RESTful Resources

Rota supports Rails-style resource routing:

```lua
-- Creates standard REST routes
router:resources("users", controllers.users)

-- Equivalent to:
-- GET    /users          -> controllers.users.index
-- GET    /users/new      -> controllers.users.new  
-- POST   /users          -> controllers.users.create
-- GET    /users/:id      -> controllers.users.show
-- GET    /users/:id/edit -> controllers.users.edit
-- PUT    /users/:id      -> controllers.users.update
-- DELETE /users/:id      -> controllers.users.destroy
```

## Middleware System

Middleware functions receive `(request, response, next)`:

```lua
local function logging_middleware(req, res, next)
    local start_time = os.clock()
    
    local result = next() -- Call next middleware/handler
    
    local duration = os.clock() - start_time
    print(string.format("%s %s - %dms", req.method, req.path, duration * 1000))
    
    return result
end
```

## Request Object

Routes receive a request object with:

```lua
{
    method = "GET",
    path = "/users/123",
    params = { id = "123" },      -- Route parameters
    query = { page = "1" },       -- Query string parameters
    headers = { ... },            -- HTTP headers
    body = "...",                 -- Request body
    cookies = { ... }             -- Parsed cookies
}
```

## Contributing

Follow Foguete conventions:
- Use efficient algorithms for route matching
- Support coroutine-based async middleware
- Maintain backward compatibility
- Include comprehensive tests
