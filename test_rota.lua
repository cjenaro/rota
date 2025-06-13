#!/usr/bin/env lua

-- Simple test script for Rota package
-- This is for manual testing, not part of the Busted test suite

package.path = "src/?.lua;" .. package.path

local rota = require("init") -- Load from src/init.lua

print("🧪 Testing Rota package...")

-- Test 1: Basic router creation
print("\n1. Testing router creation...")
local router = rota.new()
print("✓ Router created successfully")

-- Test 2: Adding routes
print("\n2. Testing route addition...")
router:get("/test", function(req)
    return { status = 200, body = "test response" }
end)

router:post("/users", function(req)
    return { status = 201, body = "user created" }
end)

print("✓ Routes added successfully")
print(string.format("  Total routes: %d", #router.routes))

-- Test 3: Route matching
print("\n3. Testing route matching...")

-- Test GET /test
local request = { method = "GET", path = "/test" }
local response = router:dispatch(request)
print(string.format("  GET /test -> %d: %s", response.status, response.body))
assert(response.status == 200, "Expected 200 status")
assert(response.body == "test response", "Expected correct body")

-- Test POST /users
request = { method = "POST", path = "/users" }
response = router:dispatch(request)
print(string.format("  POST /users -> %d: %s", response.status, response.body))
assert(response.status == 201, "Expected 201 status")

-- Test 404
request = { method = "GET", path = "/nonexistent" }
response = router:dispatch(request)
print(string.format("  GET /nonexistent -> %d: %s", response.status, response.body))
assert(response.status == 404, "Expected 404 status")

print("✓ Route matching works correctly")

-- Test 4: Parameters
print("\n4. Testing route parameters...")
router:get("/users/:id", function(req)
    return { 
        status = 200, 
        body = "user " .. req.params.id,
        params = req.params
    }
end)

request = { method = "GET", path = "/users/123" }
response = router:dispatch(request)
print(string.format("  GET /users/123 -> %d: %s", response.status, response.body))
assert(response.status == 200, "Expected 200 status")
assert(response.body == "user 123", "Expected correct body with parameter")

print("✓ Route parameters work correctly")

-- Test 5: Wildcard parameters
print("\n5. Testing wildcard parameters...")
router:get("/files/*path", function(req)
    return { 
        status = 200, 
        body = "file path: " .. req.params.path
    }
end)

request = { method = "GET", path = "/files/docs/readme.txt" }
response = router:dispatch(request)
print(string.format("  GET /files/docs/readme.txt -> %d: %s", response.status, response.body))
local param_keys = {}
for key, _ in pairs(request.params or {}) do
    table.insert(param_keys, key)
end
print(string.format("  Available params: %s", table.concat(param_keys, ", ")))
assert(response.status == 200, "Expected 200 status")
assert(response.body == "file path: docs/readme.txt", "Expected correct wildcard capture")

print("✓ Wildcard parameters work correctly")

-- Test 6: Middleware
print("\n6. Testing middleware...")
local middleware_calls = {}

local middleware1 = function(req, next)
    table.insert(middleware_calls, "middleware1")
    return next()
end

local middleware2 = function(req, next)
    table.insert(middleware_calls, "middleware2")
    return next()
end

router:use(middleware1)
router:use(middleware2)

router:get("/middleware-test", function(req)
    table.insert(middleware_calls, "handler")
    return { status = 200, body = "middleware test" }
end)

request = { method = "GET", path = "/middleware-test" }
response = router:dispatch(request)
print(string.format("  GET /middleware-test -> %d: %s", response.status, response.body))
print(string.format("  Middleware execution order: %s", table.concat(middleware_calls, " -> ")))

assert(response.status == 200, "Expected 200 status")
assert(middleware_calls[1] == "middleware1", "Expected middleware1 first")
assert(middleware_calls[2] == "middleware2", "Expected middleware2 second")  
assert(middleware_calls[3] == "handler", "Expected handler last")

print("✓ Middleware chain works correctly")

-- Test 7: Route groups
print("\n7. Testing route groups...")
local group_router = rota.new()

group_router:group("/api", function(api)
    api:get("/users", function(req)
        return { status = 200, body = "api users" }
    end)
    
    api:post("/users", function(req)
        return { status = 201, body = "api user created" }
    end)
end)

request = { method = "GET", path = "/api/users" }
response = group_router:dispatch(request)
print(string.format("  GET /api/users -> %d: %s", response.status, response.body))
assert(response.status == 200, "Expected 200 status")
assert(response.body == "api users", "Expected correct grouped route response")

print("✓ Route groups work correctly")

-- Test 8: RESTful resources
print("\n8. Testing RESTful resources...")
local rest_router = rota.new()

local users_controller = {
    index = function(req)
        return { status = 200, body = "users index" }
    end,
    
    show = function(req)
        return { status = 200, body = "user " .. req.params.id }
    end,
    
    create = function(req)
        return { status = 201, body = "user created" }
    end
}

rest_router:resources("users", users_controller)

-- Test index
request = { method = "GET", path = "/users" }
response = rest_router:dispatch(request)
print(string.format("  GET /users -> %d: %s", response.status, response.body))
assert(response.status == 200, "Expected 200 status")

-- Test show
request = { method = "GET", path = "/users/123" }
response = rest_router:dispatch(request)
print(string.format("  GET /users/123 -> %d: %s", response.status, response.body))
assert(response.status == 200, "Expected 200 status")
assert(response.body == "user 123", "Expected correct show response")

-- Test create
request = { method = "POST", path = "/users" }
response = rest_router:dispatch(request)
print(string.format("  POST /users -> %d: %s", response.status, response.body))
assert(response.status == 201, "Expected 201 status")

print("✓ RESTful resources work correctly")

-- Test 9: Handler function
print("\n9. Testing handler function...")
local handler_func = router:handler()
assert(type(handler_func) == "function", "Expected handler to return a function")

request = { method = "GET", path = "/test" }
response = handler_func(request)
print(string.format("  Handler function call -> %d: %s", response.status, response.body))
assert(response.status == 200, "Expected 200 status from handler function")

print("✓ Handler function works correctly")

print("\n🎉 All tests passed! Rota package is working correctly.")
print("\nTo run the full test suite, use: busted")
print("To run the example server, use: lua example.lua") 