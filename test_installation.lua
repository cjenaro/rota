-- Test Rota installation
local rota = require("foguete.rota")

print("🚀 Testing Rota installation...")
print("Version:", rota.VERSION)

-- Create a simple router
local router = rota.new()

router:get("/test", function(req)
    return { status = 200, body = "Installation successful!" }
end)

-- Test the router
local request = { method = "GET", path = "/test" }
local response = router:dispatch(request)

print("Status:", response.status)
print("Body:", response.body)
print("✅ Rota is working correctly!") 