-- Copies models staged by scripts/PrepareChatGPTModels.luau into assets/<Folder>/<id>.rbxm so Rojo
-- syncs them into ReplicatedStorage.Assets.
--
--   lune run scripts/export-models [file]
--
-- Run PrepareChatGPTModels.luau in Studio first. Then either save ServerStorage.ModelImport with
-- right-click > Save / Export > Save to File (works in Team Create) and pass that .rbxm, or save a
-- local copy of the place and pass the .rbxl. Existing asset files are never overwritten.
-- Afterwards delete ServerStorage.ModelImport in Studio so the place doesn't keep a second copy.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or `{process.env.HOME}/Documents/ModelImport.rbxm`
local staging
if path:match("%.rbxm$") then
	staging = roblox.deserializeModel(fs.readFile(path))[1]
else
	staging = roblox.deserializePlace(fs.readFile(path)):GetService("ServerStorage"):FindFirstChild("ModelImport")
end
assert(staging and staging.Name == "ModelImport", `{path} has no ModelImport folder. Run PrepareChatGPTModels.luau first.`)

local written, skipped = 0, 0
for _, folder in staging:GetChildren() do
	local outDir = `assets/{folder.Name}`
	if not fs.isDir(outDir) then
		fs.writeDir(outDir)
	end
	for _, model in folder:GetChildren() do
		local out = `{outDir}/{model.Name}.rbxm`
		if fs.isFile(out) or fs.isFile(`{outDir}/{model.Name}.rbxmx`) then
			print(`skipped {out}: already exists`)
			skipped += 1
		else
			fs.writeFile(out, roblox.serializeModel({ model }))
			written += 1
		end
	end
end
print(`wrote {written} models, skipped {skipped}`)
