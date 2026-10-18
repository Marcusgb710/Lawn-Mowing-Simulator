-- The "Workbench" menu, opened at your business's workbench or at the truck's tailgate on a job.
-- Pick one of your tools, then a supply to use on it. Nothing says which supply fits which tool:
-- the conditions read like a mechanic would say them ("Tire looks soft"), and the supplies say
-- what they're for in the shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maintenance = require(Shared.Config.Maintenance)
local Net = require(Shared.Net)
local Tools = require(Shared.Config.Tools)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local WorkbenchController = {}

local window: Frame
local header: TextLabel
local list: ScrollingFrame
local selectedTool: string? = nil

local function card(order: number): Frame
	return UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Card,
		LayoutOrder = order,
		Parent = list,
	}, { UI.corner(8) })
end

local function text(parent: Instance, value: string, order: number, props)
	local label = UI.label(value, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = UI.Colors.SubText,
		LayoutOrder = order,
		Parent = parent,
	})
	for key, prop in props or {} do
		(label :: any)[key] = prop
	end
	return label
end

local function render()
	local info = Net.func("GetWorkbench"):InvokeServer()
	local profile = ClientState.profile
	UI.clearList(list)
	if not window.Visible then
		return
	end
	if not (info and info.kind and profile) then
		header.Text = "Stand at your business's workbench, or by your truck on a job."
		return
	end
	header.Text = if info.kind == "Bench"
		then "At the workbench: everything you own is here."
		else "At the tailgate: only what you brought in the truck."

	if selectedTool and not table.find(info.tools, selectedTool) then
		selectedTool = nil
	end

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	UI.label(if selectedTool then "Use a supply on it:" else "Pick a tool to work on:", {
		TextSize = 17,
		TextColor3 = UI.Colors.Money,
		LayoutOrder = nextOrder(),
		Parent = list,
	})

	if selectedTool then
		local tool = Tools.get(selectedTool)
		local selected = card(nextOrder())
		local details = UI.new("Frame", {
			Size = UDim2.new(1, -130, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = selected,
		}, { UI.list(2), UI.padding(8) })
		UI.label(tool.name, { TextSize = 19, LayoutOrder = 1, Parent = details })
		local warnings = Maintenance.warnings(tool, profile.condition[selectedTool] or {})
		text(details, if #warnings > 0 then table.concat(warnings, "  ·  ") else "In good shape", 2, {
			TextColor3 = if #warnings > 0 then UI.Colors.Money else UI.Colors.Accent,
		})
		UI.button("Back", function()
			selectedTool = nil
			render()
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(100, 34),
			BackgroundColor3 = UI.Colors.Disabled,
			Parent = selected,
		})

		if #info.supplies == 0 then
			text(list, "You don't have any supplies here.", nextOrder())
		end
		for _, supply in info.supplies do
			local supplyTool = Tools.get(supply.id)
			local row = card(nextOrder())
			local rowText = UI.new("Frame", {
				Size = UDim2.new(1, -130, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = row,
			}, { UI.list(2), UI.padding(8) })
			local name = supplyTool.name .. (if supply.owned then "" else " (the shop's)")
			UI.label(name, { TextSize = 17, LayoutOrder = 1, Parent = rowText })
			text(rowText, supplyTool.description, 2)
			if supply.uses then
				text(rowText, `{supply.uses} left`, 3, { TextColor3 = UI.Colors.Text })
			end
			local usable = supply.uses == nil or supply.uses > 0
			UI.button(if usable then "Use" else "Empty", function()
				if not usable then
					return
				end
				local _, message = Net.func("Maintain"):InvokeServer(selectedTool, supply.id)
				UI.notify(message)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(100, 34),
				BackgroundColor3 = if usable then UI.Colors.Accent else UI.Colors.Disabled,
				Parent = row,
			})
		end
		return
	end

	for _, id in info.tools do
		local tool = Tools.get(id)
		local row = card(nextOrder())
		local details = UI.new("Frame", {
			Size = UDim2.new(1, -130, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = row,
		}, { UI.list(2), UI.padding(8) })
		UI.label(tool.name, { TextSize = 17, LayoutOrder = 1, Parent = details })
		local warnings = Maintenance.warnings(tool, profile.condition[id] or {})
		text(details, if #warnings > 0 then table.concat(warnings, "  ·  ") else "In good shape", 2, {
			TextColor3 = if #warnings > 0 then UI.Colors.Money else UI.Colors.Accent,
		})
		UI.button("Work on it", function()
			selectedTool = id
			render()
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 34),
			Parent = row,
		})
	end
end

function WorkbenchController:Start()
	local content
	window, content = UI.panel("Workbench", "Workbench")
	header = UI.label("", {
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.Colors.SubText,
		Parent = content,
	})
	list = UI.scrollingList(content, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
	})

	-- Asking the server takes a moment, so changes that come in meanwhile redraw once more after.
	local rendering, again = false, false
	local function refresh()
		if not window.Visible then
			return
		elseif rendering then
			again = true
			return
		end
		rendering = true
		repeat
			again = false
			render()
		until not again
		rendering = false
	end
	ClientState.Changed:Connect(function(key)
		if key == "profile" or key == "job" then
			task.spawn(refresh)
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Visible then
			selectedTool = nil
			task.spawn(refresh)
		end
	end)
	player:GetAttributeChangedSignal("MaintainingUntil"):Connect(function()
		task.spawn(refresh)
	end)
end

return WorkbenchController
