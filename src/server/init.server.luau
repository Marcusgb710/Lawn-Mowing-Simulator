-- Server entry point. Loads every service, then calls Init() on all of them, then Start().
-- Init is for setting up state and remotes, Start is for loops and player hooks.

local Services = script:WaitForChild("Services")

local LOAD_ORDER = {
	"DataService",
	"WorldService",
	"GloriaService",
	"PartyService",
	"LawnService",
	"DecorService",
	"HomeLawnService",
	"JobService",
	"ToolService",
	"TruckService",
	"DeliveryService",
	"ShopService",
	"MaintenanceService",
	"PremiumService",
	"StoryService",
	"TurfKingService",
}

local loaded = {}
for _, name in LOAD_ORDER do
	loaded[name] = require(Services:WaitForChild(name))
end

for _, name in LOAD_ORDER do
	local service = loaded[name]
	if service.Init then
		service:Init()
	end
end

for _, name in LOAD_ORDER do
	local service = loaded[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print("Lawn Mowing Simulator server started")
