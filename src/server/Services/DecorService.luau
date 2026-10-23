-- Yard decorations (docs/GAME_DESIGN.md, "Decorations"; the catalogue is Config/Decorations.luau).
--
-- Decorations belong to a business: whoever orders one on the shop computer pays, and it's for
-- their crew's shop (the leader's). It comes in a box at the delivery spot like a tool
-- (DeliveryService draws the boxes). Anyone in the crew can open it and place it, and pick up
-- placed ones to move them. Placing is in first person: the client shows a ghost where you look,
-- turns it and snaps fence sections, edging, paths and beds end to end; the server checks the
-- spot (on the plot, off the driveway, the building and what's around it, and big things off the
-- lawn; see DecorPlacement). Where everything stands is saved with the owner (data.decor):
--   placed  { key, id, x, z, turn (plot space), overgrown?, grown (seconds since trimmed) }
--   boxes   { key, id, arrives (os.time) } still to open
--
-- Markers on the models come to life here: `Light` lights up, `Fire` burns, the fountain's
-- `Spout` runs, `Seat`/`Seat1`-`Seat4` can be sat on, the mailbox's `Mailbox__Door` and
-- `Mailbox__Flag` open on their hinges, and shrubs show their `<Id>__Overgrowth` until they're
-- trimmed with a hedge tool (HomeLawnService passes the work on), then grow back while the owner
-- plays. What's placed (and how tidy) feeds the business's curb appeal (HomeLawn.decorShare).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local DecorPlacement = require(Shared.DecorPlacement)
local Decorations = require(Shared.Config.Decorations)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local HomeLawn = require(Shared.HomeLawn)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Sounds = require(Shared.Sounds)
local TaskTypes = require(Shared.Config.TaskTypes)

local DataService = require(script.Parent.DataService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

-- The most decorations (placed and boxed) one business can have.
local MAX_DECORATIONS = 60
-- How many unopened boxes a crewmate can have waiting at someone else's shop.
local MAX_GIFT_BOXES = 4
-- How far you can be from a decoration to pick it up, or from where you put it down.
local PICK_REACH = 10
local PLACE_REACH = 30
-- Wandering this far from the middle of the plot (or heading off on a job) puts it back.
local WANDER_DISTANCE = 80
-- How far from a shrub a hedge tool reaches it, and how much work trims one (as a hedge on a job).
local SHRUB_REACH = 2.5
local SHRUB_WORK = 6
-- Seconds between decoration requests from one player.
local COOLDOWN = 0.25
-- The mailbox's door drops open and its flag goes up, about each part's pivot X axis (degrees;
-- an OpenAngle attribute on the part changes it).
local MAILBOX_ANGLES = { Door = -95, Flag = 90 }
local MAILBOX_TIME = 0.4

local DecorService = {}
-- Fired with (owner) when what's placed, or how tidy it is, changes (curb appeal).
DecorService.Changed = Signal.new()
-- Fired with (owner) when their decoration boxes change (DeliveryService redraws them).
DecorService.BoxesChanged = Signal.new()

local folder: Folder
-- [owner] = { [key] = Model } for every placed decoration shown
local models = {}
-- [Player] = { owner: Player, id: string, box: number?, key: number? } while placing one
local placing = {}
-- [owner] = { [key] = work done } on overgrown shrubs this session
local trimWork = {}
-- [Player] = os.clock() of their last request
local lastRequest = {}
-- [Model] = true while a mailbox is open
local mailboxOpen = setmetatable({}, { __mode = "k" })

local function notify(player: Player, message: string)
	Net.event("Notify"):FireClient(player, message)
end

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function leaderOf(player: Player): Player
	local party = PartyService:GetParty(player)
	return if party then party.leader else player
end

-- The owner's decorations, made sound if the save holds something odd.
local function stateOf(data)
	local decor = data.decor
	if typeof(decor) ~= "table" then
		decor = {}
		data.decor = decor
	end
	decor.placed = if typeof(decor.placed) == "table" then decor.placed else {}
	decor.boxes = if typeof(decor.boxes) == "table" then decor.boxes else {}
	return decor
end

local function nextKey(decor): number
	local highest = 0
	for _, list in { decor.placed, decor.boxes } do
		for _, entry in list do
			highest = math.max(highest, tonumber(entry.key) or 0)
		end
	end
	return highest + 1
end

local function findEntry(list, key: number)
	for index, entry in list do
		if entry.key == key then
			return entry, index
		end
	end
	return nil, nil
end

local function ownerFolder(owner: Player): Folder
	local name = "Decor_" .. owner.UserId
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = folder
	return newFolder
end

-- Shows or hides a shrub's overgrowth.
local function showOvergrowth(model: Model, overgrown: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and string.sub(part.Name, -12) == "__Overgrowth" then
			if part:GetAttribute("ShownTransparency") == nil then
				part:SetAttribute("ShownTransparency", part.Transparency)
			end
			part.Transparency = if overgrown then part:GetAttribute("ShownTransparency") or 0 else 1
			part.CanQuery = overgrown
		end
	end
end

local function particles(parent: Instance, props)
	local emitter = Instance.new("ParticleEmitter")
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

-- Makes the Best Yard Trophy's cup shine: a warm glow and the odd glint.
local function shine(cup: BasePart)
	local glow = Instance.new("PointLight")
	glow.Range = 9
	glow.Brightness = 0.9
	glow.Color = Color3.fromRGB(255, 215, 120)
	glow.Shadows = false
	glow.Parent = cup
	particles(cup, {
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 200)),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.5, 0.8),
		Rate = 2,
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 90),
	})
end

-- Brings a decoration's markers to life: lamps, fire, running water and seats, and the trophy's
-- shine.
local function dress(model: Model)
	for _, marker in model:GetDescendants() do
		if marker:IsA("BasePart") and marker.Name == "BestYardTrophy__Cup" then
			shine(marker)
		end
		if not marker:IsA("Attachment") then
			continue
		end
		local name = marker.Name
		if name == "Light" then
			local light = Instance.new("PointLight")
			light.Range = 16
			light.Brightness = 1.4
			light.Color = Color3.fromRGB(255, 225, 170)
			light.Shadows = false
			light.Parent = marker
		elseif name == "Fire" then
			particles(marker, {
				Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(220, 60, 20)),
				LightEmission = 1,
				Size = NumberSequence.new(1.2, 0.2),
				Transparency = NumberSequence.new(0.2, 1),
				Lifetime = NumberRange.new(0.5, 0.9),
				Rate = 30,
				Speed = NumberRange.new(2, 4),
				SpreadAngle = Vector2.new(15, 15),
				EmissionDirection = Enum.NormalId.Top,
			})
			local glow = Instance.new("PointLight")
			glow.Range = 14
			glow.Brightness = 1.8
			glow.Color = Color3.fromRGB(255, 150, 70)
			glow.Parent = marker
		elseif name == "Spout" then
			particles(marker, {
				Color = ColorSequence.new(Color3.fromRGB(200, 230, 255)),
				Size = NumberSequence.new(0.25, 0.1),
				Transparency = NumberSequence.new(0.3, 1),
				Lifetime = NumberRange.new(0.8, 1.1),
				Rate = 40,
				Speed = NumberRange.new(4, 5),
				SpreadAngle = Vector2.new(20, 20),
				Acceleration = Vector3.new(0, -14, 0),
				EmissionDirection = Enum.NormalId.Top,
			})
		elseif name == "Seat" or string.match(name, "^Seat%d$") then
			local seat = Instance.new("Seat")
			seat.Name = name
			seat.Size = Vector3.new(1.6, 0.2, 1.6)
			seat.CFrame = marker.WorldCFrame * CFrame.new(0, -0.1, 0)
			seat.Transparency = 1
			seat.Anchored = true
			seat.CanCollide = false
			seat.Parent = model
		end
	end
end

-- Gloria's yard (GloriaService) dresses its decorations the same way.
DecorService.dress = dress

local function remove(owner: Player, key: number)
	local shown = models[owner]
	local model = shown and shown[key]
	if model then
		model:Destroy()
		shown[key] = nil
	end
end

-- Puts one placed decoration on the owner's plot.
local function render(owner: Player, entry)
	remove(owner, entry.key)
	local decoration = Decorations.get(entry.id)
	local frame = WorldService:GetDecorArea(owner)
	if not (decoration and frame) then
		return
	end
	local model = Assets.decoration(entry.id)
	Assets.anchor(model)
	Assets.placeDecoration(model, frame * CFrame.new(entry.x, 0, entry.z) * CFrame.Angles(0, entry.turn, 0))
	model.Name = entry.id .. "_" .. entry.key
	model:SetAttribute("Interact", "MoveDecor")
	model:SetAttribute("InteractText", "Move")
	model:SetAttribute("InteractName", decoration.name)
	model:SetAttribute("DecorId", entry.id)
	model:SetAttribute("DecorOwner", owner.UserId)
	model:SetAttribute("DecorKey", entry.key)
	-- Where it stands in plot space, so the client can keep new ones from overlapping it.
	model:SetAttribute("DecorX", entry.x)
	model:SetAttribute("DecorZ", entry.z)
	model:SetAttribute("DecorTurn", entry.turn)
	dress(model)
	if decoration.shrub then
		showOvergrowth(model, entry.overgrown == true)
	end
	models[owner] = models[owner] or {}
	models[owner][entry.key] = model
	model.Parent = ownerFolder(owner)
end

-- Where a placed decoration stands, as DecorPlacement sees it.
local function placedRect(entry)
	local offsetX, offsetZ, width, depth = Assets.decorFootprint(entry.id)
	return DecorPlacement.footprint(entry.x, entry.z, entry.turn, offsetX, offsetZ, width, depth)
end

local function isPlaced(entry): boolean
	return Decorations.get(entry.id) ~= nil
		and DecorPlacement.finite(entry.x)
		and DecorPlacement.finite(entry.z)
		and DecorPlacement.finite(entry.turn)
end

-- Whether a decoration can stand at (x, z, turn) on the owner's plot, among the others there
-- (all but `moving`, the one being moved).
local function fitsAt(
	owner: Player,
	id: string,
	x: number,
	z: number,
	turn: number,
	moving: number?
): (boolean, string?)
	local decoration = Decorations.get(id)
	local data = DataService:Get(owner)
	local _, area = WorldService:GetDecorArea(owner)
	if not (decoration and area and data) then
		return false, "You can't put that down right now."
	end
	local others = {}
	for _, entry in stateOf(data).placed do
		if entry.key ~= moving and isPlaced(entry) then
			table.insert(others, { rect = placedRect(entry), holds = Decorations.get(entry.id).holds })
		end
	end
	local offsetX, offsetZ, width, depth = Assets.decorFootprint(id)
	local rect = DecorPlacement.footprint(x, z, turn, offsetX, offsetZ, width, depth)
	return DecorPlacement.check(
		rect,
		area.width,
		area.depth,
		area.blocked,
		area.lawn,
		decoration.onLawn,
		others,
		decoration.holds
	)
end

-- [owner] = the DecorArea their decorations were last checked against
local shownArea = {}

-- Shows all the owner's decorations. Any that the plot no longer has room for (a bigger building
-- went up) go back in their boxes, keeping how trimmed they were. Ones the game doesn't know
-- (yet) are kept, just not shown.
local function renderAll(owner: Player)
	local data = DataService:Get(owner)
	local _, area = WorldService:GetDecorArea(owner)
	if not (data and area) then
		return
	end
	if models[owner] then
		for key in models[owner] do
			remove(owner, key)
		end
	end
	-- Anyone moving one of these puts it down where it was.
	for player, current in placing do
		if current.owner == owner and current.key then
			placing[player] = nil
			player:SetAttribute("PlacingDecor", nil)
			notify(player, "The yard changed, so you put the decoration back.")
		end
	end
	local decor = stateOf(data)
	local evicted = 0
	-- Each one checked against those already kept, so two that ended up overlapping don't both stay.
	local kept = {}
	for _, entry in decor.placed do
		if not Decorations.get(entry.id) then
			table.insert(kept, entry)
		end
	end
	for _, entry in decor.placed do
		if not Decorations.get(entry.id) then
			continue
		end
		local fits = false
		if isPlaced(entry) then
			decor.placed = kept
			fits = fitsAt(owner, entry.id, entry.x, entry.z, entry.turn)
		end
		if fits then
			table.insert(kept, entry)
		else
			table.insert(decor.boxes, {
				key = entry.key,
				id = entry.id,
				arrives = os.time(),
				overgrown = entry.overgrown,
				grown = entry.grown,
			})
			evicted += 1
		end
	end
	decor.placed = kept
	shownArea[owner] = WorldService:GetDecorAreaRaw(owner)
	for _, entry in kept do
		render(owner, entry)
	end
	if evicted > 0 then
		notify(owner, `Your shop needed the room: {evicted} decoration(s) went back in their boxes.`)
		DecorService.BoxesChanged:Fire(owner)
	end
end

-- Stops placing, leaving the decoration where it was (or back in its box).
local function stopPlacing(player: Player)
	local current = placing[player]
	if not current then
		return
	end
	placing[player] = nil
	player:SetAttribute("PlacingDecor", nil)
	local owner = current.owner
	if owner.Parent ~= Players then
		return
	end
	if current.box then
		DecorService.BoxesChanged:Fire(owner)
	elseif current.key then
		local model = models[owner] and models[owner][current.key]
		if model then
			model.Parent = ownerFolder(owner)
		end
	end
end

local function startPlacing(player: Player, owner: Player, id: string, box: number?, key: number?, turn: number?)
	placing[player] = { owner = owner, id = id, box = box, key = key }
	-- The ghost starts turned the way it stood.
	player:SetAttribute("PlacingTurn", turn or 0)
	player:SetAttribute("PlacingDecor", id)
	-- Only the business's owner can send one back.
	player:SetAttribute("PlacingOwn", owner == player)
end

-- [Model] = { value = NumberValue (0 shut, 1 open), tween = Tween? } for each mailbox swung
local mailboxSwing = setmetatable({}, { __mode = "k" })

-- Opens and closes a mailbox's door and flag on their hinges. A new swing carries on from
-- wherever the last one got to.
local function swingMailbox(model: Model, open: boolean)
	mailboxOpen[model] = open
	local swing = mailboxSwing[model]
	if not swing then
		local hinges = {}
		for _, part in model:GetDescendants() do
			local kind = part:IsA("BasePart") and string.match(part.Name, "__(%a+)$")
			local default = kind and MAILBOX_ANGLES[kind]
			if default then
				local closed = part:GetPivot()
				local angle = math.rad(tonumber(part:GetAttribute("OpenAngle")) or default)
				table.insert(hinges, { part = part, closed = closed, angle = angle })
			end
		end
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(amount)
			for _, hinge in hinges do
				if hinge.part.Parent then
					local at = hinge.closed.Position
					hinge.part:PivotTo(
						CFrame.new(at)
							* CFrame.fromAxisAngle(hinge.closed.RightVector, hinge.angle * amount)
							* CFrame.new(-at)
							* hinge.closed
					)
				end
			end
		end)
		value.Parent = model
		swing = { value = value, tween = nil }
		mailboxSwing[model] = swing
	end
	if swing.tween then
		swing.tween:Cancel()
	end
	local target = if open then 1 else 0
	local seconds = MAILBOX_TIME * math.abs(target - swing.value.Value)
	swing.tween = TweenService:Create(swing.value, TweenInfo.new(math.max(seconds, 0.05)), { Value = target })
	swing.tween:Play()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Public API ---------------------------------------------------------------------------------

-- Orders a decoration for the player's crew's shop. They pay; it's the crew leader's.
function DecorService:Buy(player: Player, id: string): (boolean, string)
	local decoration = Decorations.get(id)
	if not decoration then
		return false, "That item doesn't exist."
	end
	if decoration.won then
		return false, `The {decoration.name} can't be bought. It has to be won.`
	end
	if not WorldService:IsAtComputer(player) then
		return false, "Order it from the computer in your shop."
	end
	local owner = leaderOf(player)
	local data = DataService:Get(player)
	local ownerData = DataService:Get(owner)
	if not (data and ownerData) then
		return false, "Try again in a moment."
	end
	if owner ~= player and not DataService:CanSave(owner) then
		return false, `{owner.DisplayName}'s shop can't take orders right now.`
	end
	local decor = stateOf(ownerData)
	if #decor.placed + #decor.boxes >= MAX_DECORATIONS then
		return false, "That's as many decorations as the yard can take."
	end
	if owner ~= player then
		local waiting = 0
		for _, box in decor.boxes do
			if box.buyer == player.UserId then
				waiting += 1
			end
		end
		if waiting >= MAX_GIFT_BOXES then
			return false, `Put out what you've ordered for {owner.DisplayName}'s yard first.`
		end
	end
	if not DataService:TrySpend(player, decoration.price) then
		return false, `You need {Format.money(decoration.price - data.money)} more.`
	end
	table.insert(decor.boxes, {
		key = nextKey(decor),
		id = decoration.id,
		arrives = os.time() + GameConfig.DeliveryTime,
		buyer = player.UserId,
	})
	DecorService.BoxesChanged:Fire(owner)
	if owner ~= player then
		return true, `Ordered the {decoration.name} for {owner.DisplayName}'s shop!`
	end
	return true, `Ordered the {decoration.name}! It'll be delivered to your shop.`
end

-- Delivers a decoration the owner won (the Best Yard Trophy) in a box at their shop, like an
-- order, free. A full yard still takes it.
function DecorService:Gift(owner: Player, id: string): boolean
	local data = DataService:Get(owner)
	if not (data and Decorations.get(id)) then
		return false
	end
	local decor = stateOf(data)
	table.insert(decor.boxes, {
		key = nextKey(decor),
		id = id,
		arrives = os.time() + GameConfig.DeliveryTime,
		buyer = owner.UserId,
	})
	DecorService.BoxesChanged:Fire(owner)
	return true
end

-- What the Best Yard judges look at among the owner's decorations (Config/Contest.luau): how
-- many beds (`bedIds`), trimmed and shaggy shrubs and different kinds there are, and how well
-- decorated the yard is (0-1, as for curb appeal).
function DecorService:YardMeasures(owner: Player, bedIds: { string })
	local measures = { beds = 0, tidyShrubs = 0, shaggyShrubs = 0, kinds = 0, decorShare = self:DecorShare(owner) }
	local data = DataService:Get(owner)
	if not data then
		return measures
	end
	local kinds = {}
	for _, entry in stateOf(data).placed do
		local decoration = Decorations.get(entry.id)
		if not decoration then
			continue
		end
		kinds[decoration.id] = true
		if table.find(bedIds, decoration.id) then
			measures.beds += 1
		end
		if decoration.shrub and entry.overgrown then
			measures.shaggyShrubs += 1
		elseif decoration.shrub then
			measures.tidyShrubs += 1
		end
	end
	for _ in kinds do
		measures.kinds += 1
	end
	return measures
end

-- The owner's decoration boxes that have arrived and aren't being placed, for DeliveryService.
function DecorService:ArrivedBoxes(owner: Player): { { key: number, id: string, arrives: number } }
	local data = DataService:Get(owner)
	local arrived = {}
	if not data then
		return arrived
	end
	local now = os.time()
	for _, box in stateOf(data).boxes do
		local inUse = false
		for _, current in placing do
			if current.owner == owner and current.box == box.key then
				inUse = true
			end
		end
		if not inUse and Decorations.get(box.id) and typeof(box.arrives) == "number" and box.arrives <= now then
			table.insert(arrived, box)
		end
	end
	return arrived
end

-- Starts placing what's in one of the owner's boxes (DeliveryService has opened it). The box stays
-- saved until the decoration's down, so it comes back if they change their mind.
function DecorService:PlaceFromBox(player: Player, owner: Player, key: number): boolean
	local data = DataService:Get(owner)
	local box = data and findEntry(stateOf(data).boxes, key)
	if not box or placing[player] or leaderOf(player) ~= owner then
		return false
	end
	startPlacing(player, owner, box.id, key, nil)
	return true
end

function DecorService:IsPlacing(player: Player): boolean
	return placing[player] ~= nil
end

-- Puts down what the player is placing at (x, z) on their crew's plot, turned by `turn`.
function DecorService:Place(player: Player, x: number, z: number, turn: number): (boolean, string)
	local current = placing[player]
	if not current then
		return false, "You're not holding a decoration."
	end
	local owner = current.owner
	if leaderOf(player) ~= owner or owner.Parent ~= Players then
		stopPlacing(player)
		return false, "That belongs to another crew's shop."
	end
	local data = DataService:Get(owner)
	local frame, area = WorldService:GetDecorArea(owner)
	local root = rootOf(player)
	if not (data and frame and area and root) then
		return false, "You can't put that down right now."
	end
	turn = DecorPlacement.wrap(turn)
	local spot = frame:PointToWorldSpace(Vector3.new(x, 0, z))
	local offset = spot - root.Position
	if Vector2.new(offset.X, offset.Z).Magnitude > PLACE_REACH then
		return false, "Get closer to where you want it."
	end
	local decoration = Decorations.get(current.id)
	local fits, reason = fitsAt(owner, current.id, x, z, turn, current.key)
	if not fits then
		return false, reason or "It won't go there."
	end

	local decor = stateOf(data)
	local entry
	if current.box then
		local box, index = findEntry(decor.boxes, current.box)
		if not box then
			stopPlacing(player)
			return false, "That box is gone."
		end
		table.remove(decor.boxes, index)
		-- A new shrub arrives shaggy; one that went back in its box keeps how trimmed it was.
		local overgrown = if box.overgrown ~= nil then box.overgrown == true else decoration.shrub == true
		entry = {
			key = box.key,
			id = box.id,
			grown = tonumber(box.grown) or 0,
			overgrown = if decoration.shrub and overgrown then true else nil,
		}
		table.insert(decor.placed, entry)
	else
		entry = findEntry(decor.placed, current.key)
		if not entry then
			stopPlacing(player)
			return false, "That's not there anymore."
		end
	end
	entry.x, entry.z, entry.turn = x, z, turn
	placing[player] = nil
	player:SetAttribute("PlacingDecor", nil)
	render(owner, entry)
	local model = models[owner] and models[owner][entry.key]
	local soundAt = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	if soundAt then
		Sounds.play(soundAt, "Thunk")
	end
	if current.box then
		DecorService.BoxesChanged:Fire(owner)
	end
	DecorService.Changed:Fire(owner)
	if decoration.shrub and entry.overgrown then
		return true, `The {decoration.name} is in. Give it a trim with a hedge tool.`
	end
	return true, `Placed the {decoration.name}.`
end

-- Picks up one of the crew's placed decorations, to move it.
function DecorService:PickUp(player: Player, ownerId: number, key: number): (boolean, string)
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner or leaderOf(player) ~= owner then
		return false, "That's not your crew's."
	end
	if placing[player] or player:GetAttribute("Carrying") ~= nil or player:GetAttribute("Unboxing") then
		return false, "Your hands are full."
	end
	local data = DataService:Get(owner)
	local entry = data and findEntry(stateOf(data).placed, key)
	local model = models[owner] and models[owner][key]
	if not (entry and model and model.Parent) then
		return false, "That's not there anymore."
	end
	for _, current in placing do
		if current.owner == owner and current.key == key then
			return false, "Someone's already moving that."
		end
	end
	if not WorldService:IsNear(player, model, PICK_REACH) then
		return false, "Get closer to it."
	end
	model.Parent = nil
	startPlacing(player, owner, entry.id, nil, key, entry.turn)
	return true, "Look where you want it and put it down."
end

-- Puts back whatever the player is placing.
function DecorService:Cancel(player: Player)
	stopPlacing(player)
end

-- Sends back the decoration the owner is placing (out of its box, or picked up) for part of its
-- price. Only the business's owner can.
function DecorService:Return(player: Player): (boolean, string)
	local current = placing[player]
	if not current then
		return false, "You're not holding a decoration."
	end
	if current.owner ~= player then
		return false, `Only {current.owner.DisplayName} can send that back.`
	end
	local data = DataService:Get(player)
	local decoration = Decorations.get(current.id)
	if not (data and decoration) then
		return false, "You can't send that back right now."
	end
	if decoration.won then
		return false, `You won the {decoration.name}. It's not going anywhere.`
	end
	local decor = stateOf(data)
	local list = if current.box then decor.boxes else decor.placed
	local _, index = findEntry(list, current.box or current.key)
	if not index then
		stopPlacing(player)
		return false, "That's not there anymore."
	end
	table.remove(list, index)
	placing[player] = nil
	player:SetAttribute("PlacingDecor", nil)
	if current.key then
		remove(player, current.key)
	end
	local refund = math.floor(decoration.price * GameConfig.SellRefund)
	DataService:AddMoney(player, refund)
	if current.box then
		DecorService.BoxesChanged:Fire(player)
	end
	DecorService.Changed:Fire(player)
	return true, `Sent the {decoration.name} back for {Format.money(refund)}.`
end

-- Hedge work near the owner's overgrown shrubs (HomeLawnService passes it on). Says whether
-- anything got trimmed, and whether there was a shrub in reach this tool can't trim.
function DecorService:Trim(
	owner: Player,
	position: Vector3,
	radius: number,
	toolId: string,
	amount: number
): (boolean, boolean)
	local data = DataService:Get(owner)
	if not data then
		return false, false
	end
	local fit = TaskTypes.fit("ShearHedges", toolId)
	local changed, blocked = false, false
	for _, entry in stateOf(data).placed do
		local model = models[owner] and models[owner][entry.key]
		if not (entry.overgrown and model and model.Parent) then
			continue
		end
		local offset = model:GetPivot().Position - position
		if Vector2.new(offset.X, offset.Z).Magnitude > radius + SHRUB_REACH then
			continue
		end
		if not fit then
			blocked = true
			continue
		end
		trimWork[owner] = trimWork[owner] or {}
		local work = (trimWork[owner][entry.key] or 0) + amount * fit.speed
		changed = true
		if work >= SHRUB_WORK then
			trimWork[owner][entry.key] = nil
			entry.overgrown = nil
			entry.grown = 0
			showOvergrowth(model, false)
			DecorService.Changed:Fire(owner)
		else
			trimWork[owner][entry.key] = work
		end
	end
	return changed, blocked
end

-- Whether there's an overgrown shrub of the owner's near `position` (so a hedge tool has work).
function DecorService:HasWorkNear(owner: Player, position: Vector3, toolId: string): boolean
	local data = DataService:Get(owner)
	if not (data and TaskTypes.fit("ShearHedges", toolId)) then
		return false
	end
	for _, entry in stateOf(data).placed do
		local model = models[owner] and models[owner][entry.key]
		if entry.overgrown and model and model.Parent then
			local offset = model:GetPivot().Position - position
			if Vector2.new(offset.X, offset.Z).Magnitude <= SHRUB_REACH + 4 then
				return true
			end
		end
	end
	return false
end

-- How well decorated the owner's yard is, 0-1 (see HomeLawn.decorShare).
function DecorService:DecorShare(owner: Player): number
	local data = DataService:Get(owner)
	if not data then
		return 0
	end
	local placed = {}
	for _, entry in stateOf(data).placed do
		table.insert(placed, { id = entry.id, overgrown = entry.overgrown == true })
	end
	return HomeLawn.decorShare(placed)
end

-- Lifecycle ----------------------------------------------------------------------------------

function DecorService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Decorations"
	folder.Parent = workspace

	Net.func("PlaceDecor").OnServerInvoke = function(player, x, z, turn)
		if tooSoon(player) then
			return false, nil
		end
		if not (DecorPlacement.finite(x) and DecorPlacement.finite(z) and DecorPlacement.finite(turn)) then
			return false, "It won't go there."
		end
		return self:Place(player, x, z, turn)
	end
	Net.func("MoveDecor").OnServerInvoke = function(player, ownerId, key)
		if tooSoon(player) then
			return false, nil
		end
		if typeof(ownerId) ~= "number" or typeof(key) ~= "number" then
			return false, "That's not your crew's."
		end
		return self:PickUp(player, ownerId, key)
	end
	Net.func("CancelDecor").OnServerInvoke = function(player)
		self:Cancel(player)
		return true, nil
	end
	Net.func("ReturnDecor").OnServerInvoke = function(player)
		if tooSoon(player) then
			return false, nil
		end
		return self:Return(player)
	end
	Net.func("UseMailbox").OnServerInvoke = function(player, ownerId, key)
		if tooSoon(player) or typeof(ownerId) ~= "number" or typeof(key) ~= "number" then
			return false, nil
		end
		local owner = Players:GetPlayerByUserId(ownerId)
		local model = owner and models[owner] and models[owner][key]
		if not (owner and model and model.Parent and model:GetAttribute("DecorId") == "Mailbox") then
			return false, nil
		end
		if leaderOf(player) ~= owner then
			return false, "That's not your crew's mailbox."
		end
		if not WorldService:IsNear(player, model, PICK_REACH) then
			return false, "Get closer to it."
		end
		local open = not mailboxOpen[model]
		swingMailbox(model, open)
		return true, if open then "No mail today." else nil
	end
end

function DecorService:Start()
	-- Decorations stand on the owner's plot, which is (re)built when they join or upgrade.
	-- A truck or trailer swap rebuilds the plot without moving anything decorations care about,
	-- so they're only redrawn when the room for them changed.
	WorldService.PlotBuilt:Connect(function(owner)
		if shownArea[owner] == nil or shownArea[owner] ~= WorldService:GetDecorAreaRaw(owner) then
			renderAll(owner)
		end
		DecorService.Changed:Fire(owner)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(renderAll, player)
	end
	-- Placing for a crew you've left (or that's gone) stops.
	PartyService.Changed:Connect(function()
		for player, current in placing do
			if leaderOf(player) ~= current.owner or current.owner.Parent ~= Players then
				stopPlacing(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stopPlacing(player)
		for other, current in placing do
			if current.owner == player then
				stopPlacing(other)
			end
		end
		if models[player] then
			for key in models[player] do
				remove(player, key)
			end
			models[player] = nil
		end
		local leftover = folder:FindFirstChild("Decor_" .. player.UserId)
		if leftover then
			leftover:Destroy()
		end
		trimWork[player] = nil
		lastRequest[player] = nil
		shownArea[player] = nil
	end)

	-- Shrubs grow back while their owner plays, and placing stops if you wander off (or head out
	-- on a job).
	local regrow = GameConfig.ShrubRegrowMinutes * 60
	while true do
		task.wait(1)
		for _, owner in Players:GetPlayers() do
			local data = DataService:Get(owner)
			if not data then
				continue
			end
			for _, entry in stateOf(data).placed do
				local decoration = Decorations.get(entry.id)
				if decoration and decoration.shrub and not entry.overgrown then
					entry.grown = (tonumber(entry.grown) or 0) + 1
					if entry.grown >= regrow then
						entry.overgrown = true
						entry.grown = 0
						local model = models[owner] and models[owner][entry.key]
						if model then
							showOvergrowth(model, true)
						end
						DecorService.Changed:Fire(owner)
					end
				end
			end
		end
		for player, current in placing do
			local frame = WorldService:GetDecorArea(current.owner)
			local root = rootOf(player)
			local away = not (frame and root) or (root.Position - frame.Position).Magnitude > WANDER_DISTANCE
			if away then
				stopPlacing(player)
				notify(player, "You put the decoration back.")
			end
		end
	end
end

return DecorService
