-- Rota - Routing Engine for Foguete
-- Provides URL routing and middleware chain management

local rota = {}

-- Package version
rota.VERSION = "0.0.1"

-- Router class
local Router = {}
Router.__index = Router

-- Create a new router instance
function rota.new()
    local router = setmetatable({
        routes = {},
        middleware = {},
        groups = {}
    }, Router)
    
    return router
end

-- Add middleware to the router
function Router:use(middleware)
    if type(middleware) ~= "function" then
        error("Middleware must be a function")
    end
    
    table.insert(self.middleware, middleware)
    return self
end

-- HTTP method route definitions
function Router:get(path, ...)
    return self:add_route("GET", path, ...)
end

function Router:post(path, ...)
    return self:add_route("POST", path, ...)
end

function Router:put(path, ...)
    return self:add_route("PUT", path, ...)
end

function Router:delete(path, ...)
    return self:add_route("DELETE", path, ...)
end

function Router:patch(path, ...)
    return self:add_route("PATCH", path, ...)
end

function Router:head(path, ...)
    return self:add_route("HEAD", path, ...)
end

function Router:options(path, ...)
    return self:add_route("OPTIONS", path, ...)
end

function Router:any(path, ...)
    return self:add_route("*", path, ...)
end

-- Add a route with method, path, and handlers
function Router:add_route(method, path, ...)
    local handlers = {...}
    if #handlers == 0 then
        error("Route must have at least one handler")
    end
    
    -- Validate all handlers are functions
    for i, handler in ipairs(handlers) do
        if type(handler) ~= "function" then
            error("Handler " .. i .. " must be a function")
        end
    end
    
    -- Parse path pattern
    local pattern = rota._compile_path_pattern(path)
    
    -- Create route entry
    local route = {
        method = method,
        path = path,
        pattern = pattern,
        handlers = handlers,
        param_names = pattern.param_names
    }
    
    table.insert(self.routes, route)
    return self
end

-- Route group functionality
function Router:group(prefix, callback)
    if type(prefix) ~= "string" then
        error("Group prefix must be a string")
    end
    
    if type(callback) ~= "function" then
        error("Group callback must be a function")
    end
    
    -- Create grouped router
    local group_router = rota.new()
    group_router._prefix = prefix
    group_router._parent = self
    
    -- Execute group callback
    callback(group_router)
    
    -- Merge routes from group into main router
    for _, route in ipairs(group_router.routes) do
        -- Prefix the route path
        local prefixed_path = prefix .. route.path
        self:add_route(route.method, prefixed_path, table.unpack(route.handlers))
    end
    
    return self
end

-- RESTful resource routes
function Router:resources(name, controller)
    if type(name) ~= "string" then
        error("Resource name must be a string")
    end
    
    if type(controller) ~= "table" then
        error("Controller must be a table")
    end
    
    local base_path = "/" .. name
    
    -- Standard REST routes
    if controller.index then
        self:get(base_path, controller.index)
    end
    
    if controller.new then
        self:get(base_path .. "/new", controller.new)
    end
    
    if controller.create then
        self:post(base_path, controller.create)
    end
    
    if controller.show then
        self:get(base_path .. "/:id", controller.show)
    end
    
    if controller.edit then
        self:get(base_path .. "/:id/edit", controller.edit)
    end
    
    if controller.update then
        self:put(base_path .. "/:id", controller.update)
    end
    
    if controller.destroy then
        self:delete(base_path .. "/:id", controller.destroy)
    end
    
    return self
end

-- Main route handler - returns a function compatible with Motor
function Router:handler()
    return function(request)
        return self:dispatch(request)
    end
end

-- Dispatch a request through the router
function Router:dispatch(request)
    -- Find matching route
    local route, params = self:match_route(request.method, request.path)
    
    if not route then
        return {
            status = 404,
            headers = { ["Content-Type"] = "text/plain" },
            body = "Not Found"
        }
    end
    
    -- Add route parameters to request
    request.params = params or {}
    
    -- Build middleware chain
    local middleware_chain = {}
    
    -- Add global middleware
    for _, middleware in ipairs(self.middleware) do
        table.insert(middleware_chain, middleware)
    end
    
    -- Add route handlers (last one is the actual handler)
    for _, handler in ipairs(route.handlers) do
        table.insert(middleware_chain, handler)
    end
    
    -- Execute middleware chain
    return self:execute_middleware_chain(middleware_chain, request)
end

-- Execute middleware chain
function Router:execute_middleware_chain(chain, request)
    local index = 1
    
    local function next()
        if index <= #chain then
            local middleware = chain[index]
            index = index + 1
            
            -- Call middleware with request and next function
            return middleware(request, next)
        else
            -- End of chain - return default response
            return {
                status = 200,
                headers = { ["Content-Type"] = "text/plain" },
                body = ""
            }
        end
    end
    
    return next()
end

-- Match a route against method and path
function Router:match_route(method, path)
    for _, route in ipairs(self.routes) do
        -- Check method match (or wildcard)
        if route.method == method or route.method == "*" then
            -- Check path match
            local params = rota._match_path_pattern(route.pattern, path)
            if params then
                return route, params
            end
        end
    end
    
    return nil, nil
end

-- Compile a path pattern into a matching pattern
function rota._compile_path_pattern(path)
    local param_names = {}
    local pattern = path
    
    -- Escape special regex characters first (but not * yet)
    pattern = string.gsub(pattern, "%-", "%%-")
    pattern = string.gsub(pattern, "%.", "%%.")
    
    -- Handle named parameters (:param)
    pattern = string.gsub(pattern, ":([%w_]+)", function(param_name)
        table.insert(param_names, param_name)
        return "([^/]+)"
    end)
    
    -- Handle wildcard parameters (*param)
    pattern = string.gsub(pattern, "%*([%w_]*)", function(param_name)
        if param_name ~= "" then
            table.insert(param_names, param_name)
        else
            -- If no name provided, use a default name
            table.insert(param_names, "splat")
        end
        return "(.*)"
    end)
    
    -- Handle optional parameters - this is more complex and would need proper implementation
    -- For now, let's skip this feature
    
    -- Add anchors
    pattern = "^" .. pattern .. "$"
    
    return {
        pattern = pattern,
        param_names = param_names
    }
end

-- Match a path against a compiled pattern
function rota._match_path_pattern(compiled_pattern, path)
    local matches = {string.match(path, compiled_pattern.pattern)}
    
    if #matches == 0 then
        return nil
    end
    
    -- Build params table
    local params = {}
    for i, param_name in ipairs(compiled_pattern.param_names) do
        if matches[i] then
            params[param_name] = matches[i]
        end
    end
    
    return params
end

return rota 