-- Tests for Rota routing engine
package.path = "src/?.lua;" .. package.path
local rota = require("init")

describe("Rota", function()
    local router
    
    before_each(function()
        router = rota.new()
    end)
    
    describe("new()", function()
        it("should create a new router instance", function()
            assert.is_not_nil(router)
            assert.are.same({}, router.routes)
            assert.are.same({}, router.middleware)
        end)
    end)
    
    describe("HTTP method routing", function()
        it("should add GET routes", function()
            local handler = function() end
            router:get("/test", handler)
            
            assert.are.equal(1, #router.routes)
            assert.are.equal("GET", router.routes[1].method)
            assert.are.equal("/test", router.routes[1].path)
        end)
        
        it("should add POST routes", function()
            local handler = function() end
            router:post("/test", handler)
            
            assert.are.equal("POST", router.routes[1].method)
        end)
        
        it("should add PUT routes", function()
            local handler = function() end
            router:put("/test", handler)
            
            assert.are.equal("PUT", router.routes[1].method)
        end)
        
        it("should add DELETE routes", function()
            local handler = function() end
            router:delete("/test", handler)
            
            assert.are.equal("DELETE", router.routes[1].method)
        end)
        
        it("should add wildcard routes", function()
            local handler = function() end
            router:any("/test", handler)
            
            assert.are.equal("*", router.routes[1].method)
        end)
    end)
    
    describe("middleware", function()
        it("should add middleware functions", function()
            local middleware = function() end
            router:use(middleware)
            
            assert.are.equal(1, #router.middleware)
            assert.are.equal(middleware, router.middleware[1])
        end)
        
        it("should reject non-function middleware", function()
            assert.has_error(function()
                router:use("not a function")
            end, "Middleware must be a function")
        end)
        
        it("should chain middleware calls", function()
            local calls = {}
            
            local middleware1 = function(req, next)
                table.insert(calls, "middleware1")
                return next()
            end
            
            local middleware2 = function(req, next)
                table.insert(calls, "middleware2")
                return next()
            end
            
            local handler = function(req)
                table.insert(calls, "handler")
                return { status = 200, body = "test" }
            end
            
            router:use(middleware1)
            router:use(middleware2)
            router:get("/test", handler)
            
            local request = { method = "GET", path = "/test" }
            local response = router:dispatch(request)
            
            assert.are.same({"middleware1", "middleware2", "handler"}, calls)
            assert.are.equal(200, response.status)
        end)
    end)
    
    describe("route matching", function()
        it("should match exact paths", function()
            local handler = function() return { status = 200, body = "test" } end
            router:get("/test", handler)
            
            local request = { method = "GET", path = "/test" }
            local response = router:dispatch(request)
            
            assert.are.equal(200, response.status)
            assert.are.equal("test", response.body)
        end)
        
        it("should return 404 for unmatched routes", function()
            local request = { method = "GET", path = "/nonexistent" }
            local response = router:dispatch(request)
            
            assert.are.equal(404, response.status)
            assert.are.equal("Not Found", response.body)
        end)
        
        it("should match routes with named parameters", function()
            local captured_params = {}
            local handler = function(req)
                captured_params = req.params
                return { status = 200, body = "test" }
            end
            
            router:get("/users/:id", handler)
            
            local request = { method = "GET", path = "/users/123" }
            local response = router:dispatch(request)
            
            assert.are.equal(200, response.status)
            assert.are.equal("123", captured_params.id)
        end)
        
        it("should match routes with multiple parameters", function()
            local captured_params = {}
            local handler = function(req)
                captured_params = req.params
                return { status = 200, body = "test" }
            end
            
            router:get("/users/:user_id/posts/:post_id", handler)
            
            local request = { method = "GET", path = "/users/123/posts/456" }
            local response = router:dispatch(request)
            
            assert.are.equal(200, response.status)
            assert.are.equal("123", captured_params.user_id)
            assert.are.equal("456", captured_params.post_id)
        end)
        
        it("should match wildcard routes", function()
            local captured_params = {}
            local handler = function(req)
                captured_params = req.params
                return { status = 200, body = "test" }
            end
            
            router:get("/files/*path", handler)
            
            local request = { method = "GET", path = "/files/docs/readme.txt" }
            local response = router:dispatch(request)
            
            assert.are.equal(200, response.status)
            assert.are.equal("docs/readme.txt", captured_params.path)
        end)
    end)
    
    describe("route groups", function()
        it("should create route groups with prefixes", function()
            local handler = function() return { status = 200, body = "test" } end
            
            router:group("/api", function(api)
                api:get("/users", handler)
                api:post("/users", handler)
            end)
            
            assert.are.equal(2, #router.routes)
            assert.are.equal("/api/users", router.routes[1].path)
            assert.are.equal("/api/users", router.routes[2].path)
            assert.are.equal("GET", router.routes[1].method)
            assert.are.equal("POST", router.routes[2].method)
        end)
        
        it("should create nested route groups", function()
            local handler = function() return { status = 200, body = "test" } end
            
            router:group("/api", function(api)
                api:group("/v1", function(v1)
                    v1:get("/users", handler)
                end)
            end)
            
            assert.are.equal(1, #router.routes)
            assert.are.equal("/api/v1/users", router.routes[1].path)
        end)
    end)
    
    describe("RESTful resources", function()
        it("should create standard REST routes", function()
            local controller = {
                index = function() return { status = 200, body = "index" } end,
                show = function() return { status = 200, body = "show" } end,
                create = function() return { status = 201, body = "created" } end,
                update = function() return { status = 200, body = "updated" } end,
                destroy = function() return { status = 204, body = "" } end
            }
            
            router:resources("users", controller)
            
            -- Should create 5 routes
            assert.are.equal(5, #router.routes)
            
            -- Test index route
            local response = router:dispatch({ method = "GET", path = "/users" })
            assert.are.equal(200, response.status)
            assert.are.equal("index", response.body)
            
            -- Test show route
            response = router:dispatch({ method = "GET", path = "/users/123" })
            assert.are.equal(200, response.status)
            assert.are.equal("show", response.body)
            
            -- Test create route
            response = router:dispatch({ method = "POST", path = "/users" })
            assert.are.equal(201, response.status)
            assert.are.equal("created", response.body)
            
            -- Test update route
            response = router:dispatch({ method = "PUT", path = "/users/123" })
            assert.are.equal(200, response.status)
            assert.are.equal("updated", response.body)
            
            -- Test destroy route
            response = router:dispatch({ method = "DELETE", path = "/users/123" })
            assert.are.equal(204, response.status)
        end)
    end)
    
    describe("handler integration", function()
        it("should return a handler function compatible with Motor", function()
            local handler_func = router:handler()
            assert.is_function(handler_func)
            
            router:get("/test", function() 
                return { status = 200, body = "test" } 
            end)
            
            local request = { method = "GET", path = "/test" }
            local response = handler_func(request)
            
            assert.are.equal(200, response.status)
            assert.are.equal("test", response.body)
        end)
    end)
    
    describe("path pattern compilation", function()
        it("should compile simple paths", function()
            local pattern = rota._compile_path_pattern("/test")
            assert.are.equal("^/test$", pattern.pattern)
            assert.are.same({}, pattern.param_names)
        end)
        
        it("should compile paths with named parameters", function()
            local pattern = rota._compile_path_pattern("/users/:id")
            assert.are.equal("^/users/([^/]+)$", pattern.pattern)
            assert.are.same({"id"}, pattern.param_names)
        end)
        
        it("should compile paths with wildcards", function()
            local pattern = rota._compile_path_pattern("/files/*path")
            assert.are.equal("^/files/(.*)$", pattern.pattern)
            assert.are.same({"path"}, pattern.param_names)
        end)
    end)
    
    describe("path pattern matching", function()
        it("should match simple paths", function()
            local pattern = rota._compile_path_pattern("/test")
            local params = rota._match_path_pattern(pattern, "/test")
            assert.are.same({}, params)
        end)
        
        it("should not match different paths", function()
            local pattern = rota._compile_path_pattern("/test")
            local params = rota._match_path_pattern(pattern, "/other")
            assert.is_nil(params)
        end)
        
        it("should extract named parameters", function()
            local pattern = rota._compile_path_pattern("/users/:id")
            local params = rota._match_path_pattern(pattern, "/users/123")
            assert.are.same({id = "123"}, params)
        end)
        
        it("should extract wildcard parameters", function()
            local pattern = rota._compile_path_pattern("/files/*path")
            local params = rota._match_path_pattern(pattern, "/files/docs/readme.txt")
            assert.are.same({path = "docs/readme.txt"}, params)
        end)
    end)
    
    describe("error handling", function()
        it("should reject routes without handlers", function()
            assert.has_error(function()
                router:get("/test")
            end, "Route must have at least one handler")
        end)
        
        it("should reject non-function handlers", function()
            assert.has_error(function()
                router:get("/test", "not a function")
            end, "Handler 1 must be a function")
        end)
        
        it("should reject invalid group parameters", function()
            assert.has_error(function()
                router:group(123, function() end)
            end, "Group prefix must be a string")
            
            assert.has_error(function()
                router:group("/api", "not a function")
            end, "Group callback must be a function")
        end)
        
        it("should reject invalid resource parameters", function()
            assert.has_error(function()
                router:resources(123, {})
            end, "Resource name must be a string")
            
            assert.has_error(function()
                router:resources("users", "not a table")
            end, "Controller must be a table")
        end)
    end)
end) 