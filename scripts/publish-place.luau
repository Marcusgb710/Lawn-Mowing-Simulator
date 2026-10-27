-- Makes the place file that scripts/publish.py sends to Roblox, without Studio:
--
--   lune run scripts/publish-place <base.rbxl> <code.rbxl> <out.rbxl>
--   lune run scripts/publish-place --make-base <autosave.rbxl> <out.rbxl>
--
-- The base place holds what Studio made and Rojo doesn't manage: Workspace's Terrain, Baseplate
-- and SpawnLocation (with StreamingEnabled on), Lighting's Sky and effects, and every service's
-- settings. code.rbxl is `rojo build` of default.project.json. Every tree Rojo manages (MANAGED
-- below) is taken out of the base and replaced with the build's, the properties the project sets
-- outside those trees (StarterPlayer.CameraMode) are copied over, and Rojo's
-- ServerStorage.__Rojo_SessionLock is dropped. It refuses a base with a 3D import's leftovers in it
-- (ServerStorage.ModelImport, Workspace.Scene), and fails if a managed tree or a Studio piece is
-- missing. Then it prints a short check and writes <out.rbxl>.
--
-- --make-base writes a base place from a Studio save (normally the AutoRecovery file): the same
-- clean-up and checks, with the managed trees taken out and nothing put back. That's how
-- place/base.rbxl was made, so publishing doesn't need Studio to have run.
--
-- It reads default.project.json from the current folder (run it from the repo root) to check
-- MANAGED still matches the project and to find the properties the project sets.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

-- Every tree Rojo builds from the repo, by its path in the game: a node with a $path, or a folder
-- made of them (ReplicatedStorage.Assets, the models clients need, picked from assets/). Keep it
-- in step with default.project.json (the script checks).
local MANAGED = {
	"ReplicatedFirst.First",
	"ReplicatedStorage.Shared",
	"ReplicatedStorage.Assets",
	"ServerStorage.Assets",
	"ServerScriptService.Server",
	"StarterPlayer.StarterPlayerScripts.Client",
}

-- What the base must have that only Studio makes.
local STUDIO_PIECES = {
	Workspace = { "Terrain", "Baseplate", "SpawnLocation" },
	Lighting = { "Sky", "Atmosphere", "Bloom", "DepthOfField", "SunRays" },
}

-- Leftovers from a 3D import that must never go live.
local LEFTOVERS = { "ServerStorage.ModelImport", "Workspace.Scene" }

local SESSION_LOCK = "ServerStorage.__Rojo_SessionLock"
local PROJECT = "default.project.json"

local function fail(message: string): never
	stdio.ewrite(`publish-place: {message}\n`)
	process.exit(1)
	error(message)
end

local function usage(): never
	fail(
		"usage: lune run scripts/publish-place <base.rbxl> <code.rbxl> <out.rbxl>\n"
			.. "       lune run scripts/publish-place --make-base <autosave.rbxl> <out.rbxl>"
	)
end

local function readPlace(path: string)
	if not fs.isFile(path) then
		fail(`can't find {path}`)
	end
	local ok, place = pcall(roblox.deserializePlace, fs.readFile(path))
	if not ok then
		fail(`{path} isn't a place file: {place}`)
	end
	return place
end

local function split(path: string): { string }
	return string.split(path, ".")
end

-- The instance at a dotted path ("StarterPlayer.StarterPlayerScripts.Client"), or nil.
local function find(game, path: string)
	local parts = split(path)
	local current = game:FindService(parts[1])
	for index = 2, #parts do
		if not current then
			return nil
		end
		current = current:FindFirstChild(parts[index])
	end
	return current
end

local function parentPath(path: string): string
	local parts = split(path)
	table.remove(parts)
	return table.concat(parts, ".")
end

local function lastName(path: string): string
	local parts = split(path)
	return parts[#parts]
end

-- Takes every instance at `path` out of the place (there can be more than one with that name).
local function removeAll(game, path: string): number
	local parent = find(game, parentPath(path))
	local removed = 0
	if parent then
		for _, child in parent:GetChildren() do
			if child.Name == lastName(path) then
				child:Destroy()
				removed += 1
			end
		end
	end
	return removed
end

local function isManaged(path: string): boolean
	return table.find(MANAGED, path) ~= nil
end

-- default.project.json: checks the trees it builds are exactly MANAGED (and that nothing outside
-- them has a $path), and returns the properties it sets on everything else, as { path, names }.
local function readProject(): { { path: string, names: { string } } }
	if not fs.isFile(PROJECT) then
		fail(`can't find {PROJECT}: run this from the repo root`)
	end
	local project = serde.decode("json", fs.readFile(PROJECT))
	local found, properties = {}, {}
	local function walk(node, path: string?)
		if path and isManaged(path) then
			-- All of it comes from the build.
			table.insert(found, path)
			return
		end
		if path and node["$path"] then
			fail(`{PROJECT} builds {path}, which publish-place doesn't know about: add it to MANAGED`)
		end
		if path and node["$properties"] then
			local names = {}
			for name in node["$properties"] do
				table.insert(names, name)
			end
			table.sort(names)
			table.insert(properties, { path = path, names = names })
		end
		for key, child in node do
			if typeof(child) == "table" and string.sub(key, 1, 1) ~= "$" then
				walk(child, if path then `{path}.{key}` else key)
			end
		end
	end
	walk(project.tree, nil)
	for _, path in MANAGED do
		if not table.find(found, path) then
			fail(`MANAGED has {path}, but {PROJECT} doesn't build it any more: take it out of MANAGED`)
		end
	end
	return properties
end

-- Refuses import leftovers, drops Rojo's session lock and takes the managed trees out.
local function cleanBase(base, label: string): { string }
	for _, path in LEFTOVERS do
		if find(base, path) then
			fail(`{label} has {path} in it (left over from a 3D import). Delete it in Studio, or use another base`)
		end
	end
	local notes = {}
	local locks = removeAll(base, SESSION_LOCK)
	if locks > 0 then
		table.insert(notes, `removed {SESSION_LOCK}`)
	end
	for _, path in MANAGED do
		if not find(base, parentPath(path)) then
			fail(`{label} has no {parentPath(path)} to put {lastName(path)} in`)
		end
		removeAll(base, path)
	end
	return notes
end

local function childNames(instance): { string }
	local names = {}
	for _, child in instance:GetChildren() do
		table.insert(names, child.Name)
	end
	return names
end

-- Checks the Studio pieces are there and returns the check's lines about them.
local function checkStudioPieces(game, label: string): { string }
	local lines = {}
	for _, service in { "Workspace", "Lighting" } do
		local instance = game:GetService(service)
		for _, name in STUDIO_PIECES[service] do
			if not instance:FindFirstChild(name) then
				fail(`{label} has no {service}.{name}: is it the right place file?`)
			end
		end
		table.insert(lines, `{service} kept: {table.concat(childNames(instance), ", ")}`)
	end
	local streaming = game:GetService("Workspace").StreamingEnabled
	if streaming ~= true then
		fail(`{label} has Workspace.StreamingEnabled off: turn it on in Studio first`)
	end
	table.insert(lines, `StreamingEnabled: {streaming}`)
	if #game:GetService("Players"):GetChildren() > 0 then
		fail(`{label} has players in it: save it from Edit mode, not a playtest`)
	end
	return lines
end

local function under(instance, roots: { any }): boolean
	for _, root in roots do
		if instance == root or instance:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

-- Scripts outside the Rojo trees: there shouldn't be any, so name them.
local function strayScripts(game, roots: { any }): { string }
	local found = {}
	for _, instance in game:GetDescendants() do
		if instance:IsA("LuaSourceContainer") and not under(instance, roots) then
			table.insert(found, instance:GetFullName())
		end
	end
	return found
end

local function sizeText(bytes: number): string
	return string.format("%.1f MB", bytes / 1024 / 1024)
end

local function printCheck(lines: { string })
	print("Publish check")
	for _, line in lines do
		print(`  {line}`)
	end
end

local function write(game, path: string): number
	local data = roblox.serializePlace(game)
	fs.writeFile(path, data)
	return #data
end

-- --make-base -------------------------------------------------------------------------------------

local function makeBase(source: string, out: string)
	readProject()
	local base = readPlace(source)
	local lines = cleanBase(base, source)
	for _, line in checkStudioPieces(base, source) do
		table.insert(lines, line)
	end
	local stray = strayScripts(base, {})
	table.insert(lines, `Scripts: {if #stray == 0 then "none" else table.concat(stray, ", ")}`)
	local size = write(base, out)
	printCheck(lines)
	print(`Wrote {out} ({sizeText(size)}), a base place with the Rojo trees taken out.`)
end

-- Merging ----------------------------------------------------------------------------------------

local function guiArtLine(game): string
	local module = find(game, "ReplicatedStorage.Shared.Config.GuiArt")
	if not module then
		fail("the build has no ReplicatedStorage.Shared.Config.GuiArt")
	end
	local ok, art = pcall(function()
		return luau.load(module.Source, { debugName = "GuiArt" })()
	end)
	if not ok or typeof(art) ~= "table" or typeof(art.Images) ~= "table" then
		fail(`couldn't read GuiArt's ids: {art}`)
	end
	local filled, total = 0, 0
	for _, id in art.Images do
		total += 1
		if id ~= "" then
			filled += 1
		end
	end
	return `GuiArt ids filled: {filled} of {total}`
end

local function countModels(folder): number
	local models = 0
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			models += 1
		end
	end
	return models
end

local function storyLine(game): string
	local story = find(game, "ServerStorage.Assets.Story")
	if not story then
		fail("the build has no ServerStorage.Assets.Story")
	end
	return `Assets.Story models: {countModels(story)}`
end

-- The decorations' ids, from the build's Config/Decorations.
local function decorationIds(game): { string }
	local module = find(game, "ReplicatedStorage.Shared.Config.Decorations")
	if not module then
		fail("the build has no ReplicatedStorage.Shared.Config.Decorations")
	end
	local ok, config = pcall(function()
		return luau.load(module.Source, {
			debugName = "Decorations",
			environment = { Vector3 = roblox.Vector3, Color3 = roblox.Color3 },
		})()
	end)
	if not ok or typeof(config) ~= "table" or typeof(config.List) ~= "table" then
		fail(`couldn't read the decorations: {config}`)
	end
	local ids = {}
	for _, decoration in config.List do
		table.insert(ids, decoration.id)
	end
	return ids
end

-- Every model is in ServerStorage.Assets, and the copies every client downloads when it joins (the
-- ones client code clones) in ReplicatedStorage.Assets: how many, and how big that download is.
-- DecorController clones decorations on the screen, so every decoration the server has a model for
-- needs its copy there too (default.project.json lists the ones outside assets/Decorations).
local function assetsLine(game): string
	local counts = {}
	for _, path in { "ServerStorage.Assets", "ReplicatedStorage.Assets" } do
		local assets = find(game, path)
		if not assets then
			fail(`the build has no {path}`)
		end
		local models = 0
		for _, folder in assets:GetChildren() do
			models += countModels(folder)
		end
		table.insert(counts, { assets = assets, models = models })
	end
	local function has(root: string, id: string): boolean
		return find(game, `{root}.Decorations.{id}`) ~= nil or find(game, `{root}.Props.{id}`) ~= nil
	end
	local decorations = decorationIds(game)
	for _, id in decorations do
		if has("ServerStorage.Assets", id) and not has("ReplicatedStorage.Assets", id) then
			fail(
				`the decoration {id} has a model, but clients don't get it: add it to ReplicatedStorage.Assets in {PROJECT}`
			)
		end
	end
	local server, client = counts[1], counts[2]
	local download = #roblox.serializeModel({ client.assets })
	return `Assets: {server.models} models (ServerStorage), {client.models} of them sent to every client `
		.. `(ReplicatedStorage, {sizeText(download)}, with all {#decorations} decorations)`
end

local function merge(basePath: string, codePath: string, out: string)
	local properties = readProject()
	local base = readPlace(basePath)
	local code = readPlace(codePath)

	local lines = cleanBase(base, basePath)
	for _, line in checkStudioPieces(base, basePath) do
		table.insert(lines, line)
	end

	local roots = {}
	local replaced = {}
	for _, path in MANAGED do
		local from = find(code, path)
		if not from then
			fail(`{codePath} has no {path}: did rojo build work?`)
		end
		local count = #from:GetDescendants() + 1
		from.Parent = find(base, parentPath(path))
		table.insert(roots, from)
		table.insert(replaced, `{path} ({count})`)
	end
	table.insert(lines, `From the build: {table.concat(replaced, ", ")}`)

	for _, entry in properties do
		local from, to = find(code, entry.path), find(base, entry.path)
		if not from or not to then
			fail(`can't find {entry.path} to set {table.concat(entry.names, ", ")} on`)
		end
		local set = {}
		for _, name in entry.names do
			to[name] = from[name]
			table.insert(set, `{name} = {tostring(from[name])}`)
		end
		table.insert(lines, `{entry.path}: {table.concat(set, ", ")}`)
	end

	table.insert(lines, assetsLine(base))
	table.insert(lines, storyLine(base))
	table.insert(lines, guiArtLine(base))
	local studioTest = find(base, "ServerScriptService.Server.Services.StudioTestService")
	table.insert(
		lines,
		if studioTest
			then "StudioTestService: present (Studio only: its remote does nothing in a live game)"
			else "StudioTestService: not in this build"
	)
	local stray = strayScripts(base, roots)
	table.insert(
		lines,
		`Scripts outside the Rojo trees: {if #stray == 0 then "none" else `{table.concat(stray, ", ")} (check them!)`}`
	)

	local size = write(base, out)
	printCheck(lines)
	print(`Wrote {out} ({sizeText(size)})`)
end

-- Main -------------------------------------------------------------------------------------------

local args = process.args
if args[1] == "--make-base" then
	if #args ~= 3 then
		usage()
	end
	makeBase(args[2], args[3])
elseif #args == 3 and string.sub(args[1], 1, 2) ~= "--" then
	merge(args[1], args[2], args[3])
else
	usage()
end
