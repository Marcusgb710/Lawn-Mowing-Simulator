-- Checks the model files against the contract (src/shared/Assets.luau, assets/README.md):
--   lune run scripts/check-models [--assets DIR] [--manifest FILE]
--   lune run scripts/check-models --self-test
-- Run it from the repo root. It prints `Models OK`, or a `FAIL <id>: <reason>` line for every
-- problem and exits with an error. `--self-test` builds small broken models in a temp folder and
-- checks the gate finds exactly the problems they have.
--
-- For every manifest entry that isn't `kept` it reads assets/<Folder>/<id>.rbxm and checks:
--   * the file is there (until `complete` is true, a store entry without one is `pending <id>`);
--   * a `Handle` (Tools) or `Root` (everything else), at least one visible part, and the lowest
--     visible point on the ground, within 0.1 stud;
--   * the `fit` side of the visible parts' box is within 10% of `fit.studs`;
--   * no scripts or sounds, and no more parts than the entry's `budget` (or the folder's);
--   * the markers the folder needs: Trucks `BedArea` and `<id>__Body`, Trailers `BedArea`,
--     `EquipmentTrailer` its `EquipmentTrailer__Ramp` and two `BaySpot`, `Props/House` its `Porch`
--     and `Driveway`.
-- Every other .rbxm under assets/ is only checked for scripts and sounds. Then it checks that
-- scripts/ImportStoreModels.luau compiles and, once `complete` is true, that every id in
-- Config/Tools.luau, Items.luau (trucks, trailers, buildings) and Decorations.luau has a model
-- file or a `kept` entry.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

type Report = { failures: { string }, pending: { string } }
type IdGroup = { ids: { string }, folders: { string } }

local FOLDERS = "Tools, Trucks, Trailers, Buildings, Props, Decorations, Story"
-- How many parts a model may have when its manifest entry sets no `budget`.
local DEFAULT_BUDGET = {
	Tools = 120,
	Trucks = 160,
	Trailers = 80,
	Buildings = 400,
	Props = 300,
	Decorations = 40,
	Story = 300,
}
local GROUND_TOLERANCE = 0.1 -- studs
local FIT_TOLERANCE = 0.1 -- share of `fit.studs`
-- Which side of the box each fit axis measures, with the front toward -Z (as in ImportStoreModels).
local FIT_SIDE = { height = "Y", width = "X", length = "Z" }
-- What no model may hold. Script and LocalScript are BaseScripts.
local FORBIDDEN = { "BaseScript", "ModuleScript", "Sound" }
-- The ids in these Config files, and the asset folders a model for each can be in.
local COVERED = {
	{ file = "Tools", folders = { "Tools" } },
	{ file = "Items", folders = { "Trucks", "Trailers", "Buildings" } },
	{ file = "Decorations", folders = { "Decorations", "Props" } },
}

-- The model files ---------------------------------------------------------------------------------

local function readModel(path: string): { Instance }
	return roblox.deserializeModel(fs.readFile(path))
end

-- The roots and everything below them.
local function everything(roots: { Instance }): { Instance }
	local list = {}
	for _, root in roots do
		table.insert(list, root)
		for _, descendant in root:GetDescendants() do
			table.insert(list, descendant)
		end
	end
	return list
end

-- The box round these parts' corners, as seen from `frame` (the file's own origin if none).
local function bounds(list: { BasePart }, frame: CFrame?): (Vector3, Vector3)
	local into = if frame then frame:Inverse() else CFrame.identity
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in list do
		local half = part.Size / 2
		local place = into * part.CFrame
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = place * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	return low, high
end

-- How far the lowest visible point is above the ground (negative: below it), and a note on the
-- frame it was measured in. Models are saved at the origin, so the file's own y = 0 is the ground.
-- One saved elsewhere is measured from where the game puts its origin (Assets.placeAt: 0.5 below
-- the Root's centre) and the note says so.
local function groundGap(model: Instance, visible: { BasePart }): (number, string)
	local gap = bounds(visible).Y
	local primary = if model:IsA("Model") then model.PrimaryPart else nil
	if math.abs(gap) > GROUND_TOLERANCE and primary and primary.Name == "Root" then
		local fromRoot = bounds(visible, primary.CFrame * CFrame.new(0, -0.5, 0)).Y
		if math.abs(fromRoot - gap) > 0.001 then
			return fromRoot, " (measured from Root)"
		end
	end
	return gap, ""
end

-- One reason for each kind of script or sound in these, such as "has 2 Scripts".
local function unwanted(instances: { Instance }): { string }
	local counts = {}
	for _, instance in instances do
		for _, class in FORBIDDEN do
			if instance:IsA(class) then
				counts[instance.ClassName] = (counts[instance.ClassName] or 0) + 1
				break
			end
		end
	end
	local classes = {}
	for class in counts do
		table.insert(classes, class)
	end
	table.sort(classes)
	local reasons = {}
	for _, class in classes do
		table.insert(reasons, if counts[class] == 1 then `has a {class}` else `has {counts[class]} {class}s`)
	end
	return reasons
end

-- What's wrong with the model in a manifest entry's file, as reasons without the id.
local function problemsWith(entry: any, roots: { Instance }): { string }
	local reasons = {}
	local function need(ok: boolean, reason: string)
		if not ok then
			table.insert(reasons, reason)
		end
	end

	if #roots ~= 1 then
		return { `the file holds {#roots} top-level instances, not one model` }
	end
	local model = roots[1]
	local instances = everything(roots)
	local parts, visible = {}, {}
	for _, instance in instances do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
			if instance.Transparency < 1 then
				table.insert(visible, instance)
			end
		end
	end
	-- How many things have this name (only parts, if `partsOnly`).
	local function count(name: string, partsOnly: boolean): number
		local n = 0
		for _, instance in instances do
			if instance.Name == name and (not partsOnly or instance:IsA("BasePart")) then
				n += 1
			end
		end
		return n
	end

	local markerName = if entry.folder == "Tools" then "Handle" else "Root"
	local marker = model:FindFirstChild(markerName)
	need(marker ~= nil and marker:IsA("BasePart"), `no {markerName}`)

	if #visible == 0 then
		need(false, "no visible parts")
	else
		local gap, note = groundGap(model, visible)
		need(
			math.abs(gap) <= GROUND_TOLERANCE + 0.0001,
			`pivot is {string.format("%.1f", math.abs(gap))} {if gap > 0 then "above" else "below"} the ground{note}`
		)
		if entry.fit then
			local side = FIT_SIDE[entry.fit.axis]
			if side then
				local low, high = bounds(visible)
				local got = (high - low)[side]
				need(
					math.abs(got - entry.fit.studs) <= entry.fit.studs * FIT_TOLERANCE,
					`{entry.fit.axis} is {string.format("%.1f", got)} studs, but fit wants {entry.fit.studs} (10% allowed)`
				)
			else
				need(false, `fit axis {entry.fit.axis} isn't height, width or length`)
			end
		end
	end

	local budget = entry.budget or DEFAULT_BUDGET[entry.folder]
	need(#parts <= budget, `has {#parts} parts, over its budget of {budget}`)
	for _, reason in unwanted(instances) do
		table.insert(reasons, reason)
	end

	if entry.folder == "Trucks" then
		need(count("BedArea", true) > 0, "no BedArea")
		need(count(`{entry.id}__Body`, true) > 0, `no {entry.id}__Body`)
	elseif entry.folder == "Trailers" then
		need(count("BedArea", true) > 0, "no BedArea")
		if entry.id == "EquipmentTrailer" then
			need(count("EquipmentTrailer__Ramp", true) > 0, "no EquipmentTrailer__Ramp")
			local spots = count("BaySpot", true)
			need(spots == 2, `has {spots} BaySpot{if spots == 1 then "" else "s"}, wants 2`)
		end
	elseif entry.folder == "Props" and entry.id == "House" then
		need(count("Porch", false) > 0, "no Porch")
		need(count("Driveway", false) > 0, "no Driveway")
	end
	return reasons
end

-- Every .rbxm below `dir`, as paths from it ("Tools/GasPushMower.rbxm"), in order.
local function modelFiles(dir: string, prefix: string?): { string }
	local found = {}
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{prefix or ""}{name}`
		if fs.isDir(`{dir}/{name}`) then
			for _, inner in modelFiles(`{dir}/{name}`, `{path}/`) do
				table.insert(found, inner)
			end
		elseif name:match("%.rbxm$") then
			table.insert(found, path)
		end
	end
	return found
end

-- The entries' models, then every other model for scripts and sounds.
local function checkModels(assetsDir: string, manifest: any): Report
	local report = { failures = {}, pending = {} }
	local function fail(label: string, reason: string)
		table.insert(report.failures, `FAIL {label}: {reason}`)
	end

	local checked = {}
	for _, entry in manifest.models do
		if entry.source and entry.source.kind == "kept" then
			continue
		end
		local file = `{entry.folder}/{entry.id}.rbxm`
		checked[file] = true
		if not DEFAULT_BUDGET[entry.folder] then
			fail(entry.id, `folder {entry.folder} isn't one of {FOLDERS}`)
		elseif not fs.isFile(`{assetsDir}/{file}`) then
			if manifest.complete then
				fail(entry.id, `no file {file}`)
			else
				table.insert(report.pending, entry.id)
			end
		else
			local ok, roots = pcall(readModel, `{assetsDir}/{file}`)
			if ok then
				for _, reason in problemsWith(entry, roots) do
					fail(entry.id, reason)
				end
			else
				fail(entry.id, `can't read {file}: {roots}`)
			end
		end
	end

	for _, file in modelFiles(assetsDir) do
		if not checked[file] then
			local label = file:gsub("%.rbxm$", "")
			local ok, roots = pcall(readModel, `{assetsDir}/{file}`)
			if ok then
				for _, reason in unwanted(everything(roots)) do
					fail(label, reason)
				end
			else
				fail(label, `can't read {file}: {roots}`)
			end
		end
	end
	return report
end

-- The rest of the gate -----------------------------------------------------------------------------

-- The id of every `id = "..."` in some Luau source, in order. Comments are skipped.
local function readIds(source: string): { string }
	local ids = {}
	for line in source:gmatch("[^\n]+") do
		if not line:match("^%s*%-%-") then
			for id in line:gmatch('%f[%w_]id = "([%w_]+)"') do
				table.insert(ids, id)
			end
		end
	end
	return ids
end

-- The syntax error in some Luau source, or nil when it compiles.
local function compileError(source: string): string?
	local ok, err = pcall(luau.compile, source)
	if ok then
		return nil
	end
	local text = tostring(err)
	return text:match("syntax error[^\n]*") or text:match("[^\n]+") or text
end

-- Each id needs a file in one of its group's folders or a `kept` manifest entry.
local function checkCoverage(assetsDir: string, manifest: any, groups: { IdGroup }): { string }
	local kept = {}
	for _, entry in manifest.models do
		if entry.source and entry.source.kind == "kept" then
			kept[entry.id] = true
		end
	end
	local failures = {}
	for _, group in groups do
		for _, id in group.ids do
			local covered = kept[id] == true
			for _, folder in group.folders do
				covered = covered or fs.isFile(`{assetsDir}/{folder}/{id}.rbxm`)
			end
			if not covered then
				local where = table.concat(group.folders, "/")
				table.insert(failures, `FAIL {id}: no model file in {where} and no kept entry`)
			end
		end
	end
	return failures
end

local function loadManifest(path: string): any
	local manifest = serde.decode("json", fs.readFile(path))
	if type(manifest) ~= "table" or type(manifest.models) ~= "table" then
		error(`{path} isn't a manifest: it has no models list`, 0)
	end
	return manifest
end

-- The self-test -----------------------------------------------------------------------------------

local function selfTest()
	local Fixtures = require("./check-models-fixtures")
	local base = process.env.TEMP or process.env.TMPDIR or "/tmp"
	local dir = `{base}/check-models-self-test`
	if fs.isDir(dir) then
		fs.removeDir(dir)
	end
	fs.writeDir(dir)

	local problems = 0
	local function check(ok: boolean, message: string)
		if not ok then
			problems += 1
			print(message)
		end
	end
	-- The lines found are exactly the lines wanted, in any order.
	local function expect(label: string, got: { string }, want: { string })
		local wanted, found = {}, {}
		for _, line in want do
			wanted[line] = true
		end
		for _, line in got do
			found[line] = true
		end
		local before = problems
		for _, line in want do
			check(found[line] == true, `{label}: missing  {line}`)
		end
		for _, line in got do
			check(wanted[line] == true, `{label}: unexpected  {line}`)
		end
		if problems == before then
			check(#got == #want, `{label}: expected {#want} lines, got {#got}`)
		end
	end

	-- The five models from the task: only the four broken ones fail, each for its one reason.
	local assets, manifestFile = Fixtures.basic(`{dir}/basic`)
	local report = checkModels(assets, loadManifest(manifestFile))
	expect("basic", report.failures, {
		"FAIL NoHandle: no Handle",
		"FAIL NoBody: no NoBody__Body",
		"FAIL Scripted: has a Script",
		"FAIL Floating: pivot is 2.0 above the ground",
	})
	expect("basic pending", report.pending, {})

	-- One model for each other rule, and the ones that must pass (NearFit is 7% over its fit, Moved
	-- stands on its own origin, Kept is left alone but for its Script).
	assets, manifestFile = Fixtures.more(`{dir}/more`)
	local manifest = loadManifest(manifestFile)
	local expected = {
		"FAIL Hollow: no visible parts",
		"FAIL TooTall: height is 4.0 studs, but fit wants 3 (10% allowed)",
		"FAIL Noisy: has 2 Scripts",
		"FAIL Noisy: has a Sound",
		"FAIL Tools/Kept: has a Script",
		"FAIL Kit/Loud: has a Sound",
		"FAIL Sunk: pivot is 0.5 below the ground",
		"FAIL Lifted: pivot is 2.0 below the ground (measured from Root)",
		"FAIL House: no Driveway",
		"FAIL Heavy: has 4 parts, over its budget of 3",
		"FAIL NoBed: no BedArea",
		"FAIL EquipmentTrailer: no EquipmentTrailer__Ramp",
		"FAIL EquipmentTrailer: has 1 BaySpot, wants 2",
	}
	report = checkModels(assets, manifest)
	expect("more", report.failures, expected)
	expect("more pending", report.pending, { "Ghost" })

	-- A store entry with no file stops being pending once the manifest is complete.
	manifest.complete = true
	report = checkModels(assets, manifest)
	table.insert(expected, "FAIL Ghost: no file Tools/Ghost.rbxm")
	expect("complete", report.failures, expected)
	expect("complete pending", report.pending, {})

	-- Every id needs a file or a kept entry.
	expect(
		"coverage",
		checkCoverage(assets, manifest, { { ids = { "Kept", "NearFit", "Ghost", "Nothing" }, folders = { "Tools" } } }),
		{
			"FAIL Ghost: no model file in Tools and no kept entry",
			"FAIL Nothing: no model file in Tools and no kept entry",
		}
	)
	expect(
		"ids",
		readIds('-- id = "Comment"\nlocal x = {\n\t{ id = "A", ownerId = "No" },\n\t\tid = "B_2",\n}'),
		{ "A", "B_2" }
	)
	check(compileError("local x = = 1") ~= nil, "compile: a syntax error wasn't reported")
	check(compileError("local x = 1") == nil, "compile: a good script was reported")

	fs.removeDir(dir)
	if problems > 0 then
		print(`{problems} self-test mismatch(es)`)
		process.exit(1)
	end
	print("Self-test OK")
end

-- The gate ----------------------------------------------------------------------------------------

local function option(name: string): string?
	local at = table.find(process.args, name)
	return if at then process.args[at + 1] else nil
end

if table.find(process.args, "--self-test") then
	selfTest()
	process.exit(0)
end

local assetsDir = option("--assets") or "assets"
local manifestFile = option("--manifest") or `{assetsDir}/manifest/models.json`
local ok, manifest = pcall(loadManifest, manifestFile)
if not ok then
	print(`FAIL manifest: {manifest}`)
	process.exit(1)
end

local report = checkModels(assetsDir, manifest)
local failures = report.failures

local IMPORTER = "scripts/ImportStoreModels.luau"
local importError = compileError(fs.readFile(IMPORTER))
if importError then
	table.insert(failures, `FAIL ImportStoreModels: {IMPORTER} doesn't compile ({importError})`)
end

if manifest.complete then
	local groups = {}
	for _, source in COVERED do
		local ids = readIds(fs.readFile(`src/shared/Config/{source.file}.luau`))
		table.insert(groups, { ids = ids, folders = source.folders })
	end
	for _, failure in checkCoverage(assetsDir, manifest, groups) do
		table.insert(failures, failure)
	end
end

for _, id in report.pending do
	print(`pending {id}`)
end
if #failures > 0 then
	for _, failure in failures do
		print(failure)
	end
	process.exit(1)
end
print("Models OK")
