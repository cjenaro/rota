rockspec_format = "3.0"
package = "rota"
version = "0.0.1-1"

source = {
   url = "git+https://github.com/foguete/rota.git",
   tag = "v" .. version:match("^([^-]+)")
}

description = {
   summary = "Rota - Routing Engine for Foguete",
   detailed = [[
      Rota is the flexible routing and middleware system that handles 
      URL dispatching in Foguete applications. It provides fast route 
      matching, parameter extraction, middleware chains, RESTful 
      conventions, route groups, and method overrides.
   ]],
   homepage = "https://github.com/foguete/rota",
   license = "MIT"
}

dependencies = {
   "lua >= 5.1, < 5.5"
}

build = {
   type = "builtin",
   modules = {
      ["rota"] = "src/init.lua"
   }
}

test = {
   type = "busted",
   flags = {
      "--verbose"
   }
} 