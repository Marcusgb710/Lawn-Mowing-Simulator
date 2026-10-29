-- Copies models staged under ServerStorage.ModelImport into assets/<Folder>/<id>.rbxm so Rojo
-- syncs them into ServerStorage.Assets. scripts/ImportStoreModels.luau stages them, generated from
-- assets/manifest/models.json (its header says how); the older ChatGPT mesh packs are staged the
-- same way by scripts/PrepareChatGPTModels.luau.
--
--   lune run scripts/export-models [file] [--overwrite]
--
-- Run ImportStoreModels.luau in Studio first. Then either save ServerStorage.ModelImport with
-- right-click > Save / Export > Save to File (works in Team Create) and pass that .rbxm, or save a
-- local copy of the place and pass the .rbxl. Existing asset files are kept unless you pass
-- --overwrite (for a pass that replaces models, like the high-poly one).
-- Afterwards delete ServerStorage.ModelImport in Studio so the place doesn't keep a second copy.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path, overwrite = nil, false
for _, arg in process.args do
	if arg == "--overwrite" then
		overwrite = true
	else
		path = arg
	end
end
path = path or `{process.env.HOME}/Documents/ModelImport.rbxm`

local staging
if path:match("%.rbxm$") then
	staging = roblox.deserializeModel(fs.readFile(path))[1]
else
	staging = roblox.deserializePlace(fs.readFile(path)):GetService("ServerStorage"):FindFirstChild("ModelImport")
end
assert(staging and staging.Name == "ModelImport", `{path} has no ModelImport folder. Run ImportStoreModels.luau in Studio first.`)

local written, replaced, skipped = 0, 0, 0
for _, folder in staging:GetChildren() do
	local outDir = `assets/{folder.Name}`
	if not fs.isDir(outDir) then
		fs.writeDir(outDir)
		-- Like the other asset folders, so Rojo leaves anything added in Studio alone.
		fs.writeFile(`{outDir}/init.meta.json`, '{\n  "ignoreUnknownInstances": true\n}\n')
	end
	for _, model in folder:GetChildren() do
		local out = `{outDir}/{model.Name}.rbxm`
		local exists = fs.isFile(out) or fs.isFile(`{outDir}/{model.Name}.rbxmx`)
		if exists and not overwrite then
			print(`skipped {out}: already exists (pass --overwrite to replace it)`)
			skipped += 1
			continue
		end
		if fs.isFile(`{outDir}/{model.Name}.rbxmx`) then
			fs.removeFile(`{outDir}/{model.Name}.rbxmx`)
		end
		fs.writeFile(out, roblox.serializeModel({ model }))
		if exists then
			replaced += 1
		else
			written += 1
		end
	end
end
print(`wrote {written} new models, replaced {replaced}, skipped {skipped}`)
