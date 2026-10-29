-- Small models and their manifest, written to a folder for the self-test in scripts/check-models:
--   lune run scripts/check-models --self-test
-- Each model breaks one rule of the model contract (or none), so the self-test can say exactly
-- which failure the gate has to report for it. Nothing here touches assets/.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame = roblox.CFrame
local Instance = roblox.Instance
local Vector3 = roblox.Vector3

local Fixtures = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- A part centred on `at`. A hidden one is an invisible marker (Handle, Root, BedArea...).
local function part(name: string, at: Vector3, size: Vector3, hidden: boolean?): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.CFrame = CFrame.new(at)
	made.Transparency = if hidden then 1 else 0
	return made
end

local function attachment(name: string): Attachment
	local made = Instance.new("Attachment")
	made.Name = name
	return made
end

-- A model of these children. `primary` names the child to make its PrimaryPart.
local function model(name: string, children: { Instance }, primary: string?): Model
	local made = Instance.new("Model")
	made.Name = name
	for _, child in children do
		child.Parent = made
	end
	if primary then
		made.PrimaryPart = made:FindFirstChild(primary)
	end
	return made
end

-- The invisible Handle a tool is held by, and the Root everything else is found by.
local function handle(at: Vector3?): Part
	return part("Handle", at or v(0, 1.5, 0), v(0.5, 0.5, 0.5), true)
end

local function root(at: Vector3?): Part
	return part("Root", at or v(0, 0.5, 0), v(1, 1, 1), true)
end

-- A visible block with its bottom `bottom` studs up, at x = z = 0.
local function block(name: string, size: Vector3, bottom: number?): Part
	return part(name, v(0, (bottom or 0) + size.Y / 2, 0), size)
end

local function hidden(name: string, at: Vector3?): Part
	return part(name, at or v(0, 1, 2), v(1, 1, 1), true)
end

local function inside(parent: Instance, child: Instance): Instance
	child.Parent = parent
	return child
end

local function store(id: string, folder: string, extra: { [string]: any }?)
	local made = {
		id = id,
		folder = folder,
		source = { kind = "store", assetId = 1, name = "fixture", creator = "fixture" },
	}
	for key, value in extra or {} do
		made[key] = value
	end
	return made
end

-- Writes `files` ({ folder, model }) under `<dir>/assets` and the manifest of `entries` to
-- `<dir>/models.json`. Returns the assets folder and the manifest file.
local function write(dir: string, files: { { any } }, entries: { any }): (string, string)
	local assets, manifest = `{dir}/assets`, `{dir}/models.json`
	fs.writeDir(assets)
	for _, file in files do
		local folder, made = file[1], file[2]
		fs.writeDir(`{assets}/{folder}`)
		fs.writeFile(`{assets}/{folder}/{made.Name}.rbxm`, roblox.serializeModel({ made }))
	end
	fs.writeFile(manifest, serde.encode("json", { version = 1, complete = false, models = entries }, true))
	return assets, manifest
end

-- The five models from the task: one good tool and four that each break a rule.
function Fixtures.basic(dir: string): (string, string)
	local scripted = model("Scripted", { block("Body", v(2, 2, 2)), root() }, "Root")
	inside(scripted, Instance.new("Script"))

	return write(dir, {
		{ "Tools", model("GoodTool", { block("Body", v(2, 3, 4)), handle() }, "Handle") },
		{ "Tools", model("NoHandle", { block("Body", v(2, 3, 4)) }) },
		{ "Trucks", model("NoBody", { block("Chassis", v(4, 2, 8)), root(), hidden("BedArea") }, "Root") },
		{ "Props", scripted },
		{ "Tools", model("Floating", { block("Body", v(2, 2, 2), 2), handle(v(0, 3, 0)) }, "Handle") },
	}, {
		store("GoodTool", "Tools", { fit = { axis = "height", studs = 3 } }),
		store("NoHandle", "Tools"),
		store("NoBody", "Trucks"),
		store("Scripted", "Props"),
		store("Floating", "Tools"),
	})
end

-- One model per rule the five don't reach, a few that must pass, a store entry with no file, a
-- kept entry, and a file the manifest doesn't list.
function Fixtures.more(dir: string): (string, string)
	local noisy = model("Noisy", { block("Body", v(2, 2, 2)), handle() }, "Handle")
	inside(noisy, Instance.new("Script"))
	inside(noisy:FindFirstChild("Body"), Instance.new("Script"))
	inside(noisy, Instance.new("Sound"))

	local kept = model("Kept", { block("Body", v(2, 2, 2), 3) })
	inside(kept, Instance.new("Script"))

	local loud = model("Loud", { block("Body", v(2, 2, 2)) })
	inside(loud, Instance.new("Sound"))

	-- The Porch is an attachment in a folder, as markers may be anywhere below the model.
	local house = model("House", { block("Body", v(8, 6, 8)), root() }, "Root")
	inside(inside(house, Instance.new("Folder")), attachment("Porch"))

	return write(dir, {
		{ "Tools", model("Hollow", { handle() }, "Handle") },
		{ "Tools", model("TooTall", { block("Body", v(2, 4, 4)), handle() }, "Handle") },
		{ "Tools", model("NearFit", { block("Body", v(2, 3.2, 4)), handle() }, "Handle") },
		{ "Tools", noisy },
		{ "Tools", kept },
		{ "Kit", loud },
		{ "Props", model("Sunk", { block("Body", v(2, 2, 2), -0.5), root() }, "Root") },
		{ "Props", model("Moved", { block("Body", v(2, 2, 2), 10), root(v(30, 10.5, 5)) }, "Root") },
		{ "Props", model("Lifted", { block("Body", v(2, 2, 2), 10), root(v(0, 12.5, 0)) }, "Root") },
		{ "Props", house },
		{
			"Trucks",
			model(
				"Heavy",
				{ block("Heavy__Body", v(4, 2, 8)), block("Wheel", v(1, 1, 1)), root(), hidden("BedArea") },
				"Root"
			),
		},
		{ "Trailers", model("NoBed", { block("Frame", v(4, 1, 8)), root() }, "Root") },
		{
			"Trailers",
			model(
				"EquipmentTrailer",
				{ block("Frame", v(4, 1, 8)), root(), hidden("BedArea"), hidden("BaySpot") },
				"Root"
			),
		},
	}, {
		store("Hollow", "Tools"),
		store("TooTall", "Tools", { fit = { axis = "height", studs = 3 } }),
		store("NearFit", "Tools", { fit = { axis = "height", studs = 3 } }),
		store("Noisy", "Tools"),
		{ id = "Kept", folder = "Tools", source = { kind = "kept" } },
		store("Sunk", "Props"),
		store("Moved", "Props"),
		store("Lifted", "Props"),
		store("House", "Props"),
		store("Heavy", "Trucks", { budget = 3 }),
		store("NoBed", "Trailers"),
		store("EquipmentTrailer", "Trailers"),
		store("Ghost", "Tools"),
	})
end

return Fixtures
