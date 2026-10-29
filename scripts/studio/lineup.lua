-- Lineup: reads pairs.json from the local server and stands each row's "now" model beside its
-- candidates, labelled, with a camera stop per row saved on the Lineup folder for camera.lua.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LOG = {}
local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	table.insert(LOG, table.concat(parts, " "))
	print(...)
end

local ok, err = pcall(function()
	local rows = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8765/pairs.json"))
	local assets = game:GetService("ServerStorage"):WaitForChild("Assets")
	local old = workspace:FindFirstChild("Lineup")
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "Lineup"
	root.Parent = workspace
	local Y = 600
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(400, 1, 60 + 60 * #rows)
	floor.Position = Vector3.new(0, Y - 0.5, 30 * #rows)
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(86, 140, 60)
	floor.Parent = root

	local function label(model, text, color)
		local cf, size = model:GetBoundingBox()
		local att = Instance.new("Part")
		att.Name = "Label"
		att.Anchored = true
		att.Transparency = 1
		att.CanCollide = false
		att.Size = Vector3.new(1, 1, 1)
		att.Position = cf.Position + Vector3.new(0, size.Y / 2 + 1.5, 0)
		att.Parent = model
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(0, 150, 0, 24)
		gui.AlwaysOnTop = true
		gui.Parent = att
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 0.25
		t.BackgroundColor3 = Color3.new(0, 0, 0)
		t.TextColor3 = color
		t.TextScaled = true
		t.Font = Enum.Font.GothamBold
		t.Text = text
		t.Parent = gui
	end

	local function place(model, x, z, text, color)
		model.Parent = root
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				parts += 1
			end
		end
		local cf, size = model:GetBoundingBox()
		local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
		model:PivotTo(model:GetPivot() + (Vector3.new(x, Y, z) - bottom))
		label(model, text, color)
		log(("placed %s parts=%d size=%.1fx%.1fx%.1f"):format(model.Name, parts, size.X, size.Y, size.Z))
		return size
	end

	local NOW = Color3.fromRGB(255, 200, 80)
	local NEW = Color3.fromRGB(120, 255, 140)

	local function current(path, x, z)
		local src = assets
		for name in path:gmatch("[^/]+") do
			src = src and src:FindFirstChild(name)
		end
		if not src then
			log("WARN no current model " .. path)
			return Vector3.new(2, 2, 2)
		end
		local m = src:Clone()
		if not m:IsA("Model") then
			local mm = Instance.new("Model")
			for _, c in m:GetChildren() do
				c.Parent = mm
			end
			if #mm:GetChildren() == 0 then m.Parent = mm end
			m = mm
		end
		m.Name = "Now_" .. path:gsub("/", "_")
		return place(m, x, z, "NOW", NOW)
	end

	local function store(id, x, z, tag)
		local ok2, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if not ok2 or not objs or #objs == 0 then
			log("WARN insert failed " .. id .. ": " .. tostring(objs))
			return Vector3.new(2, 2, 2)
		end
		local got = objs[1]
		if #objs > 1 or not got:IsA("Model") then
			got = Instance.new("Model")
			for _, o in objs do o.Parent = got end
		end
		local subs = {}
		for _, c in got:GetChildren() do
			if c:IsA("Model") then table.insert(subs, c) end
		end
		if #subs >= 3 and #subs == #got:GetChildren() then
			table.sort(subs, function(a, b) return a.Name < b.Name end)
			local names = {}
			for i, s in subs do names[i] = s.Name end
			log("set " .. id .. ": " .. table.concat(names, ", "))
			for i = 2, #subs do subs[i]:Destroy() end
		end
		got.Name = "Store_" .. id
		return place(got, x, z, tag, NEW)
	end

	local stops = {}
	local z = 0
	for r, row in rows do
		local x = -150
		local sizes = {}
		table.insert(sizes, current(row.now, x, z))
		for i, id in row.store do
			x += row.gap or 14
			table.insert(sizes, store(id, x, z, "#" .. i))
		end
		local width = x + 150 + 10
		local tall = 0
		for _, s in sizes do tall = math.max(tall, s.Y) end
		local dist = math.max(row.dist or 0, width * 0.55, tall * 2.5)
		local cx = -150 + (x + 150) / 2
		table.insert(stops, { row.name, cx, Y + dist * 0.4, z + dist, cx, Y + tall * 0.4, z })
		z += row.step or 60
	end
	root:SetAttribute("Stops", HttpService:JSONEncode(stops))
	log("LINEUP DONE rows " .. #rows)
end)
if not ok then
	log("ERROR", err)
end
pcall(function()
	HttpService:PostAsync("http://127.0.0.1:8765/log", table.concat(LOG, "\n"), Enum.HttpContentType.TextPlain)
end)
