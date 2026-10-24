-- Placing yard decorations in first person (docs/GAME_DESIGN.md, "Decorations"), and the bits of
-- them that move.
--
-- While you're placing one (the server sets your PlacingDecor attribute, see DecorService), a
-- see-through copy stands where you look, green if it can go there and red if not (the same
-- rules the server checks, from the plot's DecorArea attribute and the decorations already there).
-- R turns it, E puts it down, Q puts it back, and the business's owner can send one back with F
-- for part of its price; on a phone there are buttons. Fence sections, edging, paths and beds snap to
-- a piece like them when their ends come close (SnapL on one meets SnapR on the other).
--
-- Windmill sails (`<Id>__Spinner`) turn about their own Z axis on every screen.

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local DecorPlacement = require(Shared.DecorPlacement)
local Decorations = require(Shared.Config.Decorations)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

-- How far away you can put something down.
local REACH = 28
-- Each press of R turns it this much.
local TURN_STEP = math.rad(15)
-- Positions snap to this grid (studs), and joining pieces snap together this close.
local GRID = 0.25
local SNAP_DISTANCE = 2
-- A piece's end that's already joined to another doesn't take a third.
local JOINED = 0.3
-- Sails turn this fast (radians a second), when they're this close to the camera.
local SPIN_SPEED = 1.6
local SPIN_DISTANCE = 150
local GHOST_FITS = Color3.fromRGB(120, 220, 90)
local GHOST_BLOCKED = Color3.fromRGB(230, 70, 60)

local DecorController = {}

local placingId: string? = nil
local turn = 0
local ghost: Model? = nil
local highlight: Highlight
local prompt: UI.Prompt
local buttons: Frame
local returnButton: TextButton? = nil
local spot: { x: number, z: number, turn: number, fits: boolean, reason: string? }? = nil
local busy = false
local excludeAt = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- [business Model] = { raw = attribute JSON, area = decoded }
local areaCache = setmetatable({}, { __mode = "k" })
-- [id] = { SnapL = CFrame?, SnapR = CFrame? } relative to the model's origin
local snapCache = {}
-- [part] = its resting pivot, for the parts that spin
local spinners = setmetatable({}, { __mode = "k" })

local function invoke(name: string, ...): (boolean?, string?)
	local ok, result, message = pcall(Net.func(name).InvokeServer, Net.func(name), ...)
	if not ok then
		return false, nil
	end
	return result, message
end

local function crewLeaderId(): number
	local party = ClientState.party
	return if party then party.leader.UserId else player.UserId
end

-- The plot's frame and where decorations may go on it.
local function plotArea(): (CFrame?, any)
	local business = ClientState.crewBusiness()
	local frame = business and business:GetAttribute("PlotFrame")
	local raw = business and business:GetAttribute("DecorArea")
	if not (business and typeof(frame) == "CFrame" and typeof(raw) == "string") then
		return nil, nil
	end
	local cached = areaCache[business]
	if not cached or cached.raw ~= raw then
		local ok, area = pcall(HttpService.JSONDecode, HttpService, raw)
		cached = { raw = raw, area = if ok then area else nil }
		areaCache[business] = cached
	end
	return frame, cached.area
end

-- Where a decoration's SnapL and SnapR sit relative to its origin.
local function snapsOf(id: string)
	local known = snapCache[id]
	if not known then
		known = {}
		local model = Assets.decoration(id)
		Assets.placeDecoration(model, CFrame.identity)
		for _, name in { "SnapL", "SnapR" } do
			local marker = model:FindFirstChild(name, true)
			if marker and marker:IsA("Attachment") then
				known[name] = marker.WorldCFrame
			end
		end
		snapCache[id] = known
		model:Destroy()
	end
	return known
end

local function flatLook(frame: CFrame): Vector3
	local look = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
	return if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
end

-- Joins the ghost (standing at `world`) to a placed piece like it, if one of its ends is close to
-- a free end of that piece. Returns where it should stand instead.
local function snapped(id: string, world: CFrame): CFrame?
	local own = snapsOf(id)
	if not (own.SnapL and own.SnapR) then
		return nil
	end
	local owned = workspace:FindFirstChild("Decorations")
	local mine = owned and owned:FindFirstChild("Decor_" .. crewLeaderId())
	if not mine then
		return nil
	end
	-- Every end of every piece like this one.
	local ends = {}
	for _, model in mine:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("DecorId") == id then
			for _, name in { "SnapL", "SnapR" } do
				local marker = model:FindFirstChild(name, true)
				if marker and marker:IsA("Attachment") then
					table.insert(ends, { name = name, frame = marker.WorldCFrame })
				end
			end
		end
	end
	local best, bestDistance = nil, SNAP_DISTANCE
	for _, other in ends do
		-- Our SnapL goes on their SnapR, and our SnapR on their SnapL.
		local mineName = if other.name == "SnapR" then "SnapL" else "SnapR"
		local ours = world * own[mineName]
		local distance = (ours.Position - other.frame.Position).Magnitude
		if distance >= bestDistance then
			continue
		end
		local taken = false
		for _, another in ends do
			if another ~= other and (another.frame.Position - other.frame.Position).Magnitude < JOINED then
				taken = true
				break
			end
		end
		if not taken then
			local point = other.frame.Position
			local meeting = CFrame.lookAt(point, point - flatLook(other.frame))
			best, bestDistance = meeting * own[mineName]:Inverse(), distance
		end
	end
	return best
end

local function clearGhost()
	if ghost then
		highlight.Parent = nil
		ghost:Destroy()
		ghost = nil
	end
	spot = nil
end

local function makeGhost(id: string): Model
	local model = Assets.decoration(id)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = math.max(part.Transparency, 0.5)
		end
	end
	highlight.Adornee = model
	highlight.Parent = model
	return model
end

-- Where the ghost goes this frame, and whether it can.
local function update()
	local id = placingId
	local decoration = id and Decorations.get(id)
	local camera = workspace.CurrentCamera
	local frame, area = plotArea()
	if not (id and decoration and camera and frame and area) then
		if ghost then
			ghost.Parent = nil
		end
		spot = nil
		return
	end
	-- Everyone's characters, looked up again now and then rather than every frame.
	if os.clock() - excludeAt > 0.5 then
		excludeAt = os.clock()
		local exclude: { Instance } = { workspace.CurrentCamera }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(exclude, other.Character)
			end
		end
		rayParams.FilterDescendantsInstances = exclude
	end
	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * REACH, rayParams)
	if not result then
		if ghost then
			ghost.Parent = nil
		end
		spot = nil
		prompt.set({ { text = `Look at the ground where you want the {decoration.name}.` } })
		return
	end

	local here = frame:PointToObjectSpace(result.Position)
	local x = math.round(here.X / GRID) * GRID
	local z = math.round(here.Z / GRID) * GRID
	local spin = turn
	local world = frame * CFrame.new(x, 0, z) * CFrame.Angles(0, spin, 0)
	if decoration.snaps then
		local joined = snapped(id, world)
		if joined then
			world = joined
			local relative = frame:ToObjectSpace(joined)
			local look = relative.LookVector
			x, z, spin = relative.Position.X, relative.Position.Z, math.atan2(-look.X, -look.Z)
		end
	end

	-- The other decorations in the yard (the one being moved is gone from it while it's moved).
	local others = {}
	local yard = workspace:FindFirstChild("Decorations")
	local mine = yard and yard:FindFirstChild("Decor_" .. crewLeaderId())
	for _, model in if mine then mine:GetChildren() else {} do
		local otherId, ox, oz, oturn =
			model:GetAttribute("DecorId"),
			model:GetAttribute("DecorX"),
			model:GetAttribute("DecorZ"),
			model:GetAttribute("DecorTurn")
		local other = Decorations.get(otherId)
		if other and typeof(ox) == "number" and typeof(oz) == "number" and typeof(oturn) == "number" then
			local ax, az, aw, ad = Assets.decorFootprint(other.id)
			table.insert(
				others,
				{ rect = DecorPlacement.footprint(ox, oz, oturn, ax, az, aw, ad), holds = other.holds }
			)
		end
	end
	local offsetX, offsetZ, width, depth = Assets.decorFootprint(id)
	local rect = DecorPlacement.footprint(x, z, spin, offsetX, offsetZ, width, depth)
	local fits, reason = DecorPlacement.check(
		rect,
		area.width,
		area.depth,
		area.blocked,
		area.lawn,
		decoration.onLawn,
		others,
		decoration.holds
	)
	spot = { x = x, z = z, turn = spin, fits = fits, reason = reason }

	if not ghost then
		ghost = makeGhost(id)
	end
	local model = ghost :: Model
	Assets.placeDecoration(model, world)
	model.Parent = workspace.CurrentCamera
	highlight.FillColor = if fits then GHOST_FITS else GHOST_BLOCKED
	highlight.OutlineColor = highlight.FillColor
	local own = player:GetAttribute("PlacingOwn") == true
	local keys = if UserInputService.KeyboardEnabled
		then "[E] Put it here   [R] Turn   [Q] Put it back" .. (if own then "   [F] Send it back" else "")
		elseif UserInputService.GamepadEnabled then "[X] Put it here   [Y] Turn   [B] Put it back"
		else ""
	local lines: { UI.PromptLine } =
		{ { text = if fits then decoration.name else `{decoration.name}: {reason}`, blocked = not fits } }
	if keys ~= "" then
		table.insert(lines, { text = keys })
	end
	prompt.set(lines)
end

local function place()
	local target = spot
	if busy or not target then
		return
	end
	if not target.fits then
		UI.notify(target.reason or "It won't go there.")
		return
	end
	busy = true
	task.spawn(function()
		local _, message = invoke("PlaceDecor", target.x, target.z, target.turn)
		if typeof(message) == "string" then
			UI.notify(message)
		end
		busy = false
	end)
end

local function putBack()
	task.spawn(invoke, "CancelDecor")
end

-- Sends it back for part of its price (the business's owner only).
local function sendBack()
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local _, message = invoke("ReturnDecor")
		if typeof(message) == "string" then
			UI.notify(message)
		end
		busy = false
	end)
end

local function turnBy(step: number)
	turn = DecorPlacement.wrap(turn + step)
end

local function onAction(name: string, state: Enum.UserInputState, input: InputObject)
	-- Not while a menu, the computer or the trip cutscene has the screen.
	if state ~= Enum.UserInputState.Begin or not placingId or UI.needsCursor() or not UI.getScreen().Enabled then
		return Enum.ContextActionResult.Pass
	end
	if name == "DecorPlace" then
		place()
	elseif name == "DecorTurn" then
		local back = input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		turnBy(if back then -TURN_STEP else TURN_STEP)
	elseif name == "DecorReturn" then
		if player:GetAttribute("PlacingOwn") ~= true then
			return Enum.ContextActionResult.Pass
		end
		sendBack()
	else
		putBack()
	end
	return Enum.ContextActionResult.Sink
end

local function setPlacing(id: string?)
	if id == placingId then
		return
	end
	clearGhost()
	placingId = id
	prompt.frame.Visible = id ~= nil
	buttons.Visible = id ~= nil and UserInputService.TouchEnabled
	if returnButton then
		returnButton.Visible = player:GetAttribute("PlacingOwn") == true
	end
	if id then
		-- Turned the way it stood, when it's being moved.
		local startTurn = player:GetAttribute("PlacingTurn")
		turn = if typeof(startTurn) == "number" then startTurn else 0
		-- Above the look-at keys (see InteractController), so E puts it down.
		local priority = Enum.ContextActionPriority.High.Value + 1
		ContextActionService:BindActionAtPriority(
			"DecorPlace",
			onAction,
			false,
			priority,
			Enum.KeyCode.E,
			Enum.KeyCode.ButtonX
		)
		ContextActionService:BindActionAtPriority(
			"DecorTurn",
			onAction,
			false,
			priority,
			Enum.KeyCode.R,
			Enum.KeyCode.ButtonY
		)
		ContextActionService:BindActionAtPriority(
			"DecorBack",
			onAction,
			false,
			priority,
			Enum.KeyCode.Q,
			Enum.KeyCode.ButtonB
		)
		ContextActionService:BindActionAtPriority("DecorReturn", onAction, false, priority, Enum.KeyCode.F)
	else
		for _, name in { "DecorPlace", "DecorTurn", "DecorBack", "DecorReturn" } do
			ContextActionService:UnbindAction(name)
		end
	end
end

local function trackSpinner(part: Instance)
	if part:IsA("BasePart") and string.sub(part.Name, -9) == "__Spinner" then
		spinners[part] = part:GetPivot()
	end
end

function DecorController:Start()
	local screen = UI.new("ScreenGui", {
		Name = "Decorating",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	prompt = UI.prompt({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 22),
		Visible = false,
		Parent = screen,
	})
	-- Phone buttons, on the right where the look-at button usually is, clear of the jump button.
	buttons = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.4, 0),
		Size = UDim2.fromOffset(110, 240),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	}, { UI.list(8) })
	for index, entry in
		{
			{ "Place", place, "Place" },
			{
				"Turn",
				function()
					turnBy(TURN_STEP)
				end,
				"Turn",
			},
			{ "Put back", putBack, "PutBack" },
			{ "Send back", sendBack, "Back" },
		}
	do
		local made = UI.button(entry[1], entry[2], {
			LayoutOrder = index,
			Size = UDim2.fromOffset(110, if index == 1 then 80 else 44),
			TextSize = if index == 1 then 22 else 16,
			Style = if index == 1 then "Primary" else "Neutral",
			Icon = entry[3],
			IconSize = if index == 1 then 26 else 18,
			Parent = buttons,
		})
		if index == 4 then
			returnButton = made
		end
	end

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded

	local function onPlacingChanged()
		local id = player:GetAttribute("PlacingDecor")
		setPlacing(if typeof(id) == "string" and Decorations.get(id) then id else nil)
	end
	player:GetAttributeChangedSignal("PlacingDecor"):Connect(onPlacingChanged)
	player:GetAttributeChangedSignal("PlacingOwn"):Connect(function()
		if returnButton then
			returnButton.Visible = player:GetAttribute("PlacingOwn") == true
		end
	end)
	onPlacingChanged()

	task.spawn(function()
		local decorations = workspace:WaitForChild("Decorations")
		decorations.DescendantAdded:Connect(trackSpinner)
		for _, descendant in decorations:GetDescendants() do
			trackSpinner(descendant)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if placingId then
			update()
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local angle = os.clock() * SPIN_SPEED
		for part, rest in spinners do
			if not part.Parent then
				spinners[part] = nil
			elseif
				part:IsDescendantOf(workspace)
				and (rest.Position - camera.CFrame.Position).Magnitude < SPIN_DISTANCE
			then
				part:PivotTo(rest * CFrame.Angles(0, 0, angle))
			end
		end
	end)
end

return DecorController
