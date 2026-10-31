-- The lawn map: a small top-down picture of the job's lawn in the right column, under the boost pills,
-- while a job with mowing is Working, so the shape of what's left to cut is always in sight. One pixel
-- per grass cell (an EditableImage, drawn Pixelated): uncut grass dark, mown grass bright, torn grass its
-- own colour and bare ground brown, from the ledger GrassController keeps (jobLawn) and not from the
-- lawn's pictures, so it looks the same whether the lawn is painted flat or over the lawn art. On it, a
-- white dot where you are and a dark dot for each piece of junk still in the grass. It is dark glass like
-- the job card, with "Lawn" and the percent mowed over the picture.
--
-- It faces the house, the way you do when you arrive: the street (the lawn's Origin edge, row 0) is at the
-- bottom and walking toward the house moves your dot up. That is the lawn seen from above turned half a
-- turn from its world axes (lawn X runs right to left on the map, lawn Z bottom to top), not mirrored:
-- facing +Z, +X is on your left, and it is on the map's left too. toMap does it for the dots and paint for
-- the pixels.
--
-- It only shows where the column has room for it: never on a short screen (a phone held sideways, where
-- the right column is already at its floor without it), and on a touch screen only from TOUCH_MIN_HEIGHT
-- px of GUI, where Roblox's move stick and jump button leave the column less room (scripts/check-gui has
-- the arithmetic). HudController builds it (LawnMap.build); it then keeps itself up to date from
-- GrassController.LawnChanged, the job and the screen's size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LawnGrid = require(Shared.LawnGrid)
local Swath = require(Shared.Swath)

local ClientState = require(script.Parent.Parent.ClientState)
local GrassPaint = require(script.Parent.Parent.GrassPaint)
local Juicy = require(script.Parent.Parent.Juicy)
local UI = require(script.Parent.Parent.UI)
local GrassController = require(script.Parent.Parent.Controllers.GrassController)
local Columns = require(script.Parent.Columns)
local JobCard = require(script.Parent.JobCard)

local LawnMap = {}

-- The picture fits in a box this many pixels a side, kept to the lawn's shape, with every cell the same
-- whole number of pixels (see fitPicture).
local MAP_BOX = 150
-- The glass around it (UiLayout's LawnMap is MAP_BOX + 2 * PADDING wide): how round it is, its ink outline and
-- the lip under it, and the caption's row over the picture. As tall as what's in it, so at most
-- PADDING + CAPTION_HEIGHT + CAPTION_GAP + MAP_BOX + PADDING (188 px, UiLayout's typical).
local PADDING = 8
local PANEL_RADIUS = 14
local PANEL_STROKE = 3
local PANEL_LIP = 4
local CAPTION_HEIGHT = 18
local CAPTION_GAP = 4
local CAPTION_TEXT = 12
local PICTURE_STROKE = 2
-- A touch screen shows the map only from this many pixels of GUI height (the screen's less Roblox's top
-- bar): there the right column, with everything in it during a job and the map, still fits above the
-- move stick and jump button at the columns' minScale (scripts/check-gui works it out).
local TOUCH_MIN_HEIGHT = 650
-- The dots: you, white with an ink ring, and each piece of junk, ink with a pale ring so it reads on the
-- dark uncut grass too.
local PLAYER_DOT = 6
local JUNK_DOT = 5
local DOT_RING = 1
-- On the map uncut grass is GrassPaint's uncut turf darkened this much more, so mown grass stands out
-- further still.
local UNCUT_DARKEN = 0.25

local function bytesOf(color: Color3): { number }
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

-- Each state the ledger has, as the red, green and blue the map draws it in.
local COLORS: { [string]: { number } } = {
	[LawnGrid.TALL] = bytesOf(GrassPaint.UNCUT:Lerp(Color3.new(0, 0, 0), UNCUT_DARKEN)),
	[LawnGrid.MOWED] = Swath.Colors.Light,
	[LawnGrid.RAGGED] = Swath.Colors[Swath.RAGGED],
	[LawnGrid.EMPTY] = bytesOf(GrassPaint.GROUND),
}

local holder: Frame
local percentLabel: TextLabel
local mapBox: Frame
local picture: ImageLabel
local playerDot: Frame
-- The lawn the picture is of (GrassController.jobLawn, as it was when the picture was made), its image
-- and the pixels written into it, and the state each cell was drawn in, by cell index.
local shown: GrassController.JobLawn? = nil
local image: EditableImage? = nil
local pixels: buffer? = nil
local drawn: { string } = {}
-- Set for the rest of the session once the picture couldn't be made or drawn: the map stays hidden.
local broken = false
-- [junk model] = its dot, and what watches the job site's Debris folder.
local junkDots: { [Instance]: Frame } = {}
local junkWatch: { RBXScriptConnection } = {}
-- Moves your dot every frame, only while the map shows.
local following: RBXScriptConnection? = nil

-- Where a spot in the world is on the picture, as a share of it across and down: half a turn from the
-- lawn's own axes, so the street is at the bottom (see the header).
local function toMap(lawn: GrassController.JobLawn, spot: Vector3): UDim2
	return UDim2.fromScale(
		1 - math.clamp((spot.X - lawn.origin.X) / lawn.columns, 0, 1),
		1 - math.clamp((spot.Z - lawn.origin.Z) / lawn.rows, 0, 1)
	)
end

-- A dot on the picture at a spot in the world.
local function dotAt(spot: Vector3, size: number, color: Color3, ring: Color3, zIndex: number, name: string): Frame
	return UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(shown :: GrassController.JobLawn, spot),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = picture,
	}, {
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.new("UIStroke", { Color = ring, Thickness = DOT_RING }),
	})
end

-- Junk ---------------------------------------------------------------------------------------------
-- The pieces of junk are the models in the job site's Debris folder (LawnService's _placeDebris) that
-- say Interact = "PickUpDebris". They don't move, so each gets its dot once, as it turns up, and loses
-- it as it goes (picked up or chewed up): no looking for them every frame.

local function addJunk(thing: Instance)
	if junkDots[thing] or not shown or not thing:IsA("Model") or thing:GetAttribute("Interact") ~= "PickUpDebris" then
		return
	end
	junkDots[thing] =
		dotAt(thing:GetPivot().Position, JUNK_DOT, Juicy.Palette.Ink, Juicy.Palette.Cream.bottom, 6, "Junk")
end

local function removeJunk(thing: Instance)
	local dot = junkDots[thing]
	if dot then
		dot:Destroy()
		junkDots[thing] = nil
	end
end

local function forgetJunk()
	for _, connection in junkWatch do
		connection:Disconnect()
	end
	table.clear(junkWatch)
	for _, dot in junkDots do
		dot:Destroy()
	end
	table.clear(junkDots)
end

-- Follows the Debris folder of the lawn's job site (the Grass folder's parent), or waits for one: it's
-- only made when the lawn hides junk.
local function watchJunk(lawn: GrassController.JobLawn)
	local site = lawn.folder.Parent
	if not site then
		return
	end
	local function watch(folder: Instance)
		table.insert(junkWatch, folder.ChildAdded:Connect(addJunk))
		table.insert(junkWatch, folder.ChildRemoved:Connect(removeJunk))
		for _, child in folder:GetChildren() do
			addJunk(child)
		end
	end
	local debris = site:FindFirstChild("Debris")
	if debris then
		watch(debris)
		return
	end
	local waiting: RBXScriptConnection
	waiting = site.ChildAdded:Connect(function(child)
		if child.Name == "Debris" then
			waiting:Disconnect()
			watch(child)
		end
	end)
	table.insert(junkWatch, waiting)
end

-- The picture -------------------------------------------------------------------------------------

-- Lets the last lawn's picture go (it's another lawn now, or none).
local function release()
	forgetJunk()
	picture.ImageContent = Content.none
	if image then
		image:Destroy()
	end
	image, pixels, shown = nil, nil, nil
	table.clear(drawn)
end

-- Sizes the picture to the lawn's shape inside its MAP_BOX box: each cell the same whole number of
-- pixels, as many as fit, so Pixelated cells are all one size. A lawn of more than MAP_BOX cells along a
-- side is stretched to fit instead (its cells are then a pixel or less, and uneven).
local function fitPicture(columns: number, rows: number)
	local perCell = math.floor(MAP_BOX / math.max(columns, rows))
	local width, height
	if perCell >= 1 then
		width, height = columns * perCell, rows * perCell
	elseif columns >= rows then
		width, height = MAP_BOX, math.max(1, math.floor(MAP_BOX * rows / columns + 0.5))
	else
		width, height = math.max(1, math.floor(MAP_BOX * columns / rows + 0.5)), MAP_BOX
	end
	mapBox.Size = UDim2.fromOffset(MAP_BOX, height)
	picture.Size = UDim2.fromOffset(width, height)
end

-- Brings the picture up to the lawn's ledger, making it first for a lawn it hasn't drawn. Only the cells
-- whose state differs from what was drawn are written into the pixels, and the image then takes the
-- whole buffer in one WritePixelsBuffer: the biggest lawn (the Mansion Estate, 112 x 88 cells) is under
-- ten thousand pixels, so one call beats a DrawRectangle per cell, and a full redraw (GetSwaths) costs the
-- same as a mower's few cells. Cell (column, row) goes to pixel (columns - 1 - column, rows - 1 - row), half
-- a turn, so the street is at the bottom (see the header). False when the image can't be made (no
-- EditableImage to spare), which leaves the map hidden.
local function paint(lawn: GrassController.JobLawn): boolean
	if not image then
		local made = GrassPaint.newImage(Vector2.new(lawn.columns, lawn.rows))
		if not made then
			return false
		end
		image, pixels, shown = made, buffer.create(lawn.columns * lawn.rows * 4), lawn
		table.clear(drawn)
		fitPicture(lawn.columns, lawn.rows)
		picture.ImageContent = Content.fromObject(made)
		watchJunk(lawn)
	end
	local canvas, bytes = image :: EditableImage, pixels :: buffer
	local cells, columns, rows = lawn.cells, lawn.columns, lawn.rows
	local changed = false
	for index = 1, columns * rows do
		local state = cells[index]
		if state ~= drawn[index] then
			drawn[index] = state
			changed = true
			local column, row = LawnGrid.cell(index, rows)
			local rgb = COLORS[state] or COLORS[LawnGrid.TALL]
			local offset = ((rows - 1 - row) * columns + (columns - 1 - column)) * 4
			buffer.writeu8(bytes, offset, rgb[1])
			buffer.writeu8(bytes, offset + 1, rgb[2])
			buffer.writeu8(bytes, offset + 2, rgb[3])
			buffer.writeu8(bytes, offset + 3, 255)
		end
	end
	if changed then
		canvas:WritePixelsBuffer(Vector2.zero, canvas.Size, bytes)
	end
	return true
end

-- Your dot: where your character is on the lawn, every frame while the map shows.
local function placePlayer()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local lawn = shown
	if not (lawn and root and root:IsA("BasePart")) then
		playerDot.Visible = false
		return
	end
	playerDot.Position = toMap(lawn, root.Position)
	playerDot.Visible = true
end

local function follow(on: boolean)
	if on and not following then
		following = RunService.RenderStepped:Connect(placePlayer)
		placePlayer()
	elseif not on and following then
		following:Disconnect()
		following = nil
	end
end

-- Whether the right column has room for the map on this screen (see TOUCH_MIN_HEIGHT).
local function roomy(): boolean
	if Columns.shortScreen() then
		return false
	end
	return not UI.isTouch() or UI.getScreen().AbsoluteSize.Y >= TOUCH_MIN_HEIGHT
end

-- The job's mowing to-do (the one with a percent), if it has one.
local function mowingTask(job): any?
	for _, info in job.tasks or {} do
		if info.percent then
			return info
		end
	end
	return nil
end

-- Shows the map, up to date, or hides it: while the job card shows a Working job with mowing, its lawn
-- is drawn as a surface near you, and the screen has room.
local function refresh()
	local job = ClientState.job
	local mowing = if job and job.state == "Working" then mowingTask(job) else nil
	local lawn = if mowing then GrassController.jobLawn() else nil
	-- While you respawn there's no character to find the job lawn from (jobLawnFolder needs it): the map
	-- hides, but keeps its picture, so it doesn't build it all again when you're back on the same lawn.
	local character = Players.LocalPlayer.Character
	local respawning = mowing ~= nil and not (character and character:FindFirstChild("HumanoidRootPart"))
	if shown and not respawning and not (lawn and lawn.folder == shown.folder) then
		release()
	end
	local show = false
	if mowing and lawn and not broken and JobCard.isShown() and roomy() then
		local ok, result = pcall(paint, lawn)
		if ok and result then
			show = true
		else
			broken = true
			release()
			warn(`[LawnMap] Couldn't draw the lawn map{if ok then " (no EditableImage to spare)" else `: {result}`}`)
		end
	end
	if show then
		percentLabel.Text = `{math.floor(mowing.percent * 100 + 1e-6)}% mowed`
	end
	holder.Visible = show
	follow(show)
end

-- Builds the map (hidden) in its spot in the right column, and keeps it up to date from then on. The
-- job card has to be built first.
function LawnMap.build()
	holder = JobCard.glassPanel({ Name = "LawnMap", Visible = false }, PANEL_RADIUS, PANEL_STROKE, PANEL_LIP)
	Columns.placeInColumn(holder, "LawnMap")
	local body = UI.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = holder,
	}, {
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, PADDING),
			PaddingBottom = UDim.new(0, PADDING),
			PaddingLeft = UDim.new(0, PADDING),
			PaddingRight = UDim.new(0, PADDING),
		}),
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, CAPTION_GAP),
		}),
	})
	local caption = UI.new("Frame", {
		Name = "Caption",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
		LayoutOrder = 1,
		Parent = body,
	})
	Juicy.text("Lawn", {
		Name = "Title",
		Size = UDim2.fromScale(0.5, 1),
		TextSize = CAPTION_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = caption,
	})
	percentLabel = Juicy.text("", {
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.5, 1),
		TextSize = CAPTION_TEXT,
		TextColor3 = Juicy.Palette.Gold.top,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = caption,
	})
	mapBox = UI.new("Frame", {
		Name = "Map",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(MAP_BOX, MAP_BOX),
		LayoutOrder = 2,
		Parent = body,
	})
	picture = UI.new("ImageLabel", {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(MAP_BOX, MAP_BOX),
		BackgroundColor3 = Juicy.Palette.Ink,
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Stretch,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ZIndex = 5,
		Parent = mapBox,
	}, {
		UI.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Juicy.Palette.Ink,
			Thickness = PICTURE_STROKE,
		}),
	})
	playerDot = UI.new("Frame", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(PLAYER_DOT, PLAYER_DOT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
		Parent = picture,
	}, {
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.new("UIStroke", { Color = Juicy.Palette.Ink, Thickness = DOT_RING }),
	})

	-- Deferred, so the job card has taken the same change first (JobCard.isShown).
	local function later()
		task.defer(refresh)
	end
	GrassController.LawnChanged:Connect(refresh)
	ClientState.Changed:Connect(function(key)
		if key == "job" then
			later()
		end
	end)
	UI.onGiveWay("JobTracker", later)
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	refresh()
end

return LawnMap
