-- Checks the model files against the contract (src/shared/Assets.luau, assets/README.md):
--   lune run scripts/check-models [--assets DIR] [--manifest FILE]
--   lune run scripts/check-models --self-test
-- Run it from the repo root. It prints `Models OK`, or a `FAIL <id>: <reason>` line for every
-- problem and exits with an error. `--self-test` builds small broken models in a temp folder and
-- checks the gate finds exactly the problems they have.
--
-- For every manifest entry that isn't `kept` it reads assets/<Folder>/<id>.rbxm (or .rbxmx) and
-- checks:
--   * the file is there (until `complete` is true, a store entry without one is `pending <id>`);
--   * Tools: a `Handle` part with `GripLeft` and `GripRight` attachments on it. Everything else: a
--     `Root` part that is the model's PrimaryPart, invisible, unturned and at (0, 0.5, 0), where
--     Assets.placeAt expects it (it puts the model's origin 0.5 below the Root);
--   * at least one visible part, and the lowest visible point on the ground (y = 0 in the file),
--     within 0.1 stud;
--   * the `fit` side of the visible parts' box is within 10% of `fit.studs`;
--   * no scripts or sounds, and no more parts than the entry's `budget` (or the folder's);
--   * the markers the folder needs: Trucks `BedArea`, `<id>__Body` and a `DriverSeat` attachment,
--     Trailers `BedArea`, `EquipmentTrailer` its `EquipmentTrailer__Ramp` and two `BaySpot`,
--     `Props/House` its `Porch` and `Driveway` attachments.
-- Every other model file under assets/ is only checked for scripts and sounds. Then it checks that
-- scripts/ImportStoreModels.luau compiles and, once `complete` is true, that every id in
-- Config/Tools.luau, Items.luau (trucks, trailers, buildings) and Decorations.luau has a model
-- file or a `kept` entry in one of its folders.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

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
local ROOT_AT = Vector3.new(0, 0.5, 0)
local ROOT_TOLERANCE = 0.1 -- studs
local ROOT_TURN = 0.01 -- how far the Root's look and up vectors may stray from -Z and +Y
local EPSILON = 0.0001 -- slack for the float32 maths in the file
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

-- The box round these parts' corners, in the file's own frame.
local function bounds(list: { BasePart }): (Vector3, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in list do
		local half = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	return low, high
end

-- The ways a model's Root (the part Assets.placeAt finds its origin by: 0.5 below the Root's
-- centre) isn't the one the importer makes: an invisible PrimaryPart at (0, 0.5, 0), unturned.
-- With the Root there, the file's own y = 0 is the ground the game stands the model on.
local function rootProblems(model: Instance, root: BasePart): { string }
	local reasons = {}
	local primary = if model:IsA("Model") then model.PrimaryPart else nil
	if primary ~= root then
		table.insert(reasons, "Root is not the PrimaryPart")
	end
	if root.Transparency < 1 then
		table.insert(reasons, "Root is visible")
	end
	local at = root.CFrame.Position
	local off = at - ROOT_AT
	if off.Magnitude > ROOT_TOLERANCE + EPSILON then
		if math.abs(off.X) <= ROOT_TOLERANCE and math.abs(off.Z) <= ROOT_TOLERANCE then
			table.insert(reasons, `Root is at y {string.format("%.1f", at.Y)}, not {ROOT_AT.Y}`)
		else
			local where = string.format("%.1f, %.1f, %.1f", at.X, at.Y, at.Z)
			table.insert(reasons, `Root is at ({where}), not (0, {ROOT_AT.Y}, 0)`)
		end
	end
	local look, up = root.CFrame.LookVector, root.CFrame.UpVector
	if (look - Vector3.new(0, 0, -1)).Magnitude > ROOT_TURN or (up - Vector3.new(0, 1, 0)).Magnitude > ROOT_TURN then
		table.insert(reasons, "Root is rotated")
	end
	return reasons
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
	-- How many things of this class have this name, anywhere in the file.
	local function count(name: string, class: string): number
		local n = 0
		for _, instance in instances do
			if instance.Name == name and instance:IsA(class) then
				n += 1
			end
		end
		return n
	end

	if entry.folder == "Tools" then
		local handle = model:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			for _, grip in { "GripLeft", "GripRight" } do
				local found = handle:FindFirstChild(grip)
				need(found ~= nil and found:IsA("Attachment"), `no {grip} on the Handle`)
			end
		else
			need(false, "no Handle")
		end
	else
		local root = model:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			for _, reason in rootProblems(model, root) do
				table.insert(reasons, reason)
			end
		else
			need(false, "no Root")
		end
	end

	if #visible == 0 then
		need(false, "no visible parts")
	else
		-- Where the lowest visible point is, so how far the file's origin (the ground) is below it.
		local gap = bounds(visible).Y
		need(
			math.abs(gap) <= GROUND_TOLERANCE + EPSILON,
			`pivot is {string.format("%.1f", math.abs(gap))} {if gap > 0 then "above" else "below"} the ground`
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
		need(count("BedArea", "BasePart") > 0, "no BedArea")
		need(count(`{entry.id}__Body`, "BasePart") > 0, `no {entry.id}__Body`)
		need(count("DriverSeat", "Attachment") > 0, "no DriverSeat attachment")
	elseif entry.folder == "Trailers" then
		need(count("BedArea", "BasePart") > 0, "no BedArea")
		if entry.id == "EquipmentTrailer" then
			need(count("EquipmentTrailer__Ramp", "BasePart") > 0, "no EquipmentTrailer__Ramp")
			local spots = count("BaySpot", "BasePart")
			need(spots == 2, `has {spots} BaySpot{if spots == 1 then "" else "s"}, wants 2`)
		end
	elseif entry.folder == "Props" and entry.id == "House" then
		-- Attachments, as GloriaService only takes the house's Porch and Driveway if they are.
		need(count("Porch", "Attachment") > 0, "no Porch attachment")
		need(count("Driveway", "Attachment") > 0, "no Driveway attachment")
	end
	return reasons
end

-- The first line of an error, without the traceback Lune adds.
local function firstLine(err: any): string
	local text = tostring(err)
	return text:match("[^\n]+") or text
end

-- A model's file, as a path from the assets folder: its .rbxm, or its .rbxmx if it is saved as XML.
local function findModel(assetsDir: string, folder: string, id: string): string?
	for _, extension in { "rbxm", "rbxmx" } do
		local file = `{folder}/{id}.{extension}`
		if fs.isFile(`{assetsDir}/{file}`) then
			return file
		end
	end
	return nil
end

-- Every .rbxm and .rbxmx below `dir`, as paths from it ("Tools/GasPushMower.rbxm"), in order.
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
		elseif name:match("%.rbxmx?$") then
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
		local file = findModel(assetsDir, entry.folder, entry.id)
		if file then
			checked[file] = true
		end
		if not DEFAULT_BUDGET[entry.folder] then
			fail(entry.id, `folder {entry.folder} isn't one of {FOLDERS}`)
		elseif not file then
			if manifest.complete then
				fail(entry.id, `no file {entry.folder}/{entry.id}.rbxm`)
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
				fail(entry.id, `can't read {file}: {firstLine(roots)}`)
			end
		end
	end

	for _, file in modelFiles(assetsDir) do
		if not checked[file] then
			local label = file:gsub("%.rbxmx?$", "")
			local ok, roots = pcall(readModel, `{assetsDir}/{file}`)
			if ok then
				for _, reason in unwanted(everything(roots)) do
					fail(label, reason)
				end
			else
				fail(label, `can't read {file}: {firstLine(roots)}`)
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
	return tostring(err):match("syntax error[^\n]*") or firstLine(err)
end

-- Each id needs a file in one of its group's folders, or a `kept` manifest entry in one of them.
local function checkCoverage(assetsDir: string, manifest: any, groups: { IdGroup }): { string }
	local kept = {}
	for _, entry in manifest.models do
		if entry.source and entry.source.kind == "kept" then
			kept[`{entry.folder}/{entry.id}`] = true
		end
	end
	local failures = {}
	for _, group in groups do
		for _, id in group.ids do
			local covered = false
			for _, folder in group.folders do
				covered = covered or findModel(assetsDir, folder, id) ~= nil or kept[`{folder}/{id}`] == true
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

	-- A file Lune can't read is reported on one line, whatever Lune says; its reason isn't ours to
	-- assert, so these lines are set aside and only their start is checked.
	local function withoutUnreadable(lines: { string }): { string }
		local rest, starts = {}, {}
		for _, line in lines do
			if line:find(": can't read ", 1, true) then
				check(not line:find("\n"), `unreadable: {line} runs over several lines`)
				check(line:match(": can't read [^:]+: .") ~= nil, `unreadable: {line} gives no reason`)
				table.insert(starts, (line:match("^(.-: can't read [^:]+: )")))
			else
				table.insert(rest, line)
			end
		end
		expect("unreadable", starts, {
			"FAIL Corrupt: can't read Props/Corrupt.rbxm: ",
			"FAIL Kit/Garbled: can't read Kit/Garbled.rbxm: ",
		})
		return rest
	end

	-- One model for each other rule, and the ones that must pass (NearFit is 7% over its fit, Kept is
	-- left alone but for its Script).
	assets, manifestFile = Fixtures.more(`{dir}/more`)
	local manifest = loadManifest(manifestFile)
	local expected = {
		"FAIL Hollow: no visible parts",
		"FAIL TooTall: height is 4.0 studs, but fit wants 3 (10% allowed)",
		"FAIL HalfGripped: no GripRight on the Handle",
		"FAIL NoGrips: no GripLeft on the Handle",
		"FAIL NoGrips: no GripRight on the Handle",
		"FAIL Noisy: has 2 Scripts",
		"FAIL Noisy: has a Sound",
		"FAIL XmlTool: has a Script",
		"FAIL Tools/Kept: has a Script",
		"FAIL Kit/Loud: has a Sound",
		"FAIL Kit/XmlLoud: has a Sound",
		"FAIL Sunk: pivot is 0.5 below the ground",
		"FAIL RootHigh: Root is at y 5.0, not 0.5",
		"FAIL RootDrift: Root is at (3.0, 0.5, 0.0), not (0, 0.5, 0)",
		"FAIL RootShown: Root is visible",
		"FAIL RootTurned: Root is rotated",
		"FAIL RootLoose: Root is not the PrimaryPart",
		"FAIL House: no Driveway attachment",
		"FAIL Heavy: has 4 parts, over its budget of 3",
		"FAIL NoSeat: no DriverSeat attachment",
		"FAIL NoBed: no BedArea",
		"FAIL EquipmentTrailer: no EquipmentTrailer__Ramp",
		"FAIL EquipmentTrailer: has 1 BaySpot, wants 2",
	}
	report = checkModels(assets, manifest)
	expect("more", withoutUnreadable(report.failures), expected)
	expect("more pending", report.pending, { "Ghost" })

	-- A store entry with no file stops being pending once the manifest is complete.
	manifest.complete = true
	report = checkModels(assets, manifest)
	table.insert(expected, "FAIL Ghost: no file Tools/Ghost.rbxm")
	expect("complete", withoutUnreadable(report.failures), expected)
	expect("complete pending", report.pending, {})

	-- Every id needs a file (.rbxm or .rbxmx) or a kept entry, in a folder of its group.
	expect(
		"coverage",
		checkCoverage(assets, manifest, {
			{ ids = { "KeptGhost", "NearFit", "XmlTool", "Ghost", "Nothing" }, folders = { "Tools" } },
			{ ids = { "KeptGhost" }, folders = { "Props", "Trucks" } },
		}),
		{
			"FAIL Ghost: no model file in Tools and no kept entry",
			"FAIL Nothing: no model file in Tools and no kept entry",
			"FAIL KeptGhost: no model file in Props/Trucks and no kept entry",
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
