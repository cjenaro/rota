-- Rota - Routing Engine for Foguete
-- Provides URL routing and middleware chain management

local rota = {}

-- Package version
rota.VERSION = "0.0.1"

-- Router class
local Router = {}
Router.__index = Router

-- Create a new router instance
function rota.new(options)
	options = options or {}
	local router = setmetatable({
		routes = {},
		middleware = {},
		groups = {},
		hot_reload_mode = options.hot_reload_mode or false,
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

-- Enable hot reload mode for development
function Router:enable_hot_reload()
	self.hot_reload_mode = true
	return self
end

-- Disable hot reload mode
function Router:disable_hot_reload()
	self.hot_reload_mode = false
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
	local handlers = { ... }
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
		param_names = pattern.param_names,
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

	-- Support both controller table/function and module path string
	if type(controller) ~= "table" and type(controller) ~= "function" and type(controller) ~= "string" then
		error("Controller must be a table, function, or module path string")
	end

	local base_path = "/" .. name

	-- Helper function to create controller instance and call method
	local function create_handler(method_name)
		return function(request, next)
			local controller_class

			if type(controller) == "string" then
				-- Module path string - handle caching based on hot reload mode
				if self.hot_reload_mode then
					-- In hot reload mode, require fresh each time
					controller_class = require(controller)
				else
					-- In production mode, cache the controller
					if not self._controller_cache then
						self._controller_cache = {}
					end
					if not self._controller_cache[controller] then
						self._controller_cache[controller] = require(controller)
					end
					controller_class = self._controller_cache[controller]
				end
			elseif type(controller) == "function" then
				-- Factory function - call it to get fresh controller
				controller_class = controller()
			else
				-- Direct controller table
				controller_class = controller
			end

			local controller_instance = controller_class:new(request)
			return controller_instance[method_name](controller_instance)
		end
	end

	-- Get controller class to check available methods
	local controller_class
	if type(controller) == "string" then
		-- For module path, require it to check methods
		controller_class = require(controller)
	elseif type(controller) == "function" then
		-- If it's a factory function, call it to get the controller class
		controller_class = controller()
	else
		controller_class = controller
	end

	-- Standard REST routes
	if controller_class.index then
		self:get(base_path, create_handler("index"))
	end

	if controller_class.new_action then
		self:get(base_path .. "/new", create_handler("new_action"))
	elseif controller_class.new then
		self:get(base_path .. "/new", create_handler("new"))
	end

	if controller_class.create then
		self:post(base_path, create_handler("create"))
	end

	if controller_class.show then
		self:get(base_path .. "/:id", create_handler("show"))
	end

	if controller_class.edit then
		self:get(base_path .. "/:id/edit", create_handler("edit"))
	end

	if controller_class.update then
		self:put(base_path .. "/:id", create_handler("update"))
	end

	if controller_class.destroy then
		self:delete(base_path .. "/:id", create_handler("destroy"))
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
			body = "Not Found",
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
				body = "",
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
		param_names = param_names,
	}
end

-- Match a path against a compiled pattern
function rota._match_path_pattern(compiled_pattern, path)
	local matches = { string.match(path, compiled_pattern.pattern) }

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
