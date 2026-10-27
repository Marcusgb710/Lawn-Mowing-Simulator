-- Copies the organized Lawn Mowing kit out of a saved place file into assets/Kit so Rojo syncs it
-- into ServerStorage.Assets.Kit.
--
--   lune run scripts/export-kit [place file]
--
-- Run scripts/OrganizeLawnKit.luau in Studio first and save the place. It reads
-- ServerStorage.LawnKitExport.Kit from the place and writes assets/Kit/<asset>.rbxm. Afterwards
-- run `lune run scripts/build-kit-tools` to rebuild the shop tools from those templates, and
-- delete ServerStorage.LawnKitExport in Studio so the place doesn't keep a second copy.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or `{process.env.HOME}/Documents/LawnMowingSimulator.rbxl`
local game = roblox.deserializePlace(fs.readFile(placePath))
local export = game:GetService("ServerStorage"):FindFirstChild("LawnKitExport")
assert(export, `{placePath} has no ServerStorage.LawnKitExport. Run OrganizeLawnKit.luau in Studio and save first.`)
local kit = export:FindFirstChild("Kit")
assert(kit, "LawnKitExport has no Kit folder")

if not fs.isDir("assets/Kit") then
	fs.writeDir("assets/Kit")
end
for _, model in kit:GetChildren() do
	fs.writeFile(`assets/Kit/{model.Name}.rbxm`, roblox.serializeModel({ model }))
	print(`wrote assets/Kit/{model.Name}.rbxm`)
end
