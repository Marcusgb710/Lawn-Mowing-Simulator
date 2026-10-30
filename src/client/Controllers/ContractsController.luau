-- The contracts panel: today's three contracts, the Bonus Day for doing all three, and the streak.
-- The chip under Grandma's goal opens it (HudController), and so will the mailbox at the curb: both
-- ask UI.open("Contracts"), so the window is made with UI.panel, the only way UI.open finds one by
-- name. It's still a window of its own like the Levels panel, not one of the menus: it has a place
-- and size of its own (UiLayout's ContractsPanel) and shrinks to fit the screen the way the Levels
-- panel does (__screen.scaling.ContractsPanel). UI.panel places a window as a menu's (UiLayout's
-- MenuWindow) whenever the screen turns short or tall and when the shop computer lets go of the
-- menus, so this one puts itself back after each.
--
-- Each contract is a row: its words and what it pays, how far along it is with a thin bar, and a
-- DONE stamp (words only, UI.stampText) once it's paid. The view is ClientState.contracts, which
-- init.client keeps from GetContracts and ContractsUpdated, and it's drawn again whenever that
-- changes while the panel is up. The streak line (ContractsController.streakLine) is the Levels
-- panel's too.
--
-- It closes with its Close button, the X in its corner and Escape, and, like the Levels panel, when
-- your job changes state (one accepted, the truck pulling out, the lawn done), when a scene, the
-- drive or the contest takes the screen, when you sit down at the shop computer, and when another
-- window opens, since only one is up at a time.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contracts = require(Shared.Config.Contracts)
local Format = require(Shared.Format)
local Streak = require(Shared.Config.Streak)

local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

-- What DailyService sends (its viewOf): the day's contracts with how far along each is, whether
-- the Bonus Day is paid, and the streak with what tomorrow pays.
export type Contract = {
	id: string,
	kind: string,
	text: string,
	need: number,
	have: number,
	reward: number,
	done: boolean,
}
export type View = {
	day: string,
	contracts: { Contract },
	bonus: boolean,
	streak: { days: number, last: string, next: number },
}

local ContractsController = {}

-- The name UI.open knows the window by.
local PANEL = "Contracts"
-- The panel is never drawn smaller than this, however short the screen is: past it, it couldn't be
-- read anyway.
local SMALLEST_SCALE = 0.25
-- A row's height, the gap between rows, and where its two lines sit (their middles): the words and
-- the reward on the top one, how far along it is and the bar below.
local ROW_HEIGHT = 58
local ROW_GAP = 8
local TOP_LINE = 17
local BOTTOM_LINE = 41
local BAR_HEIGHT = 6
-- Room for the reward on the right ("+$900"), and how tall the DONE stamp is.
local REWARD_WIDTH = 72
local DONE_STAMP_HEIGHT = 28

local panel: GuiObject
local scale: UIScale
local rows: Frame
local waiting: TextLabel
local bonusLabel: TextLabel
local streakCard: GuiObject
local streakLabel: TextLabel
-- Your job's id and state the last time either changed, to close the panel when they do.
local jobStep: string? = nil
-- The contracts the last draw showed done, by `day/id`, so a draw while the panel's up lands the
-- stamp only on the one that just got done.
local drawnDone: { [string]: boolean } = {}

-- The streak line without its label: "Day 3 of 7, next $300", and past the first week the real count
-- beside the week's: "Day 6 of 7 (20 days in a row), next $1,000". `next` is what tomorrow pays.
-- Nothing before there's a view or a streak to show. The Levels panel's line is this one too.
function ContractsController.streakLine(view: View?): string?
	if not view or view.streak.days < 1 then
		return nil
	end
	local line = Streak.text(view.streak.days)
	if view.streak.days > #Streak.Rewards then
		line ..= ` ({view.streak.days} days in a row)`
	end
	return `{line}, next {Format.money(view.streak.next)}`
end

-- "2/3", or in dollars for the Earn contract: "$120/$400".
local function progressText(contract: Contract): string
	if contract.kind == "Earn" then
		return `{Format.money(contract.have)}/{Format.money(contract.need)}`
	end
	return `{contract.have}/{contract.need}`
end

-- Draws one contract's row, the `index`th down: its words on the left and what it pays on the
-- right, how far along it is under them with a bar. A paid one has a tick in front of it, its words
-- muted and a full bar, and `stamp` lands the DONE stamp on it (`sparkles` of them round it, if
-- that's how many).
local function addRow(index: number, contract: Contract, stamp: boolean, sparkles: number?)
	local done = contract.done
	local row = UI.card({
		Name = `Contract{contract.id}`,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = index,
		Parent = rows,
	})
	local x = 12
	if done then
		local tick = UI.icon("Check", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(x, TOP_LINE),
			Size = UDim2.fromOffset(18, 18),
			Parent = row,
		}, UI.Colors.Money)
		if not tick then
			UI.label("✓", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(x, TOP_LINE),
				Size = UDim2.fromOffset(18, 18),
				TextSize = 16,
				TextColor3 = UI.Colors.Money,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = row,
			})
		end
		x += 24
	end
	UI.label(`+{Format.money(contract.reward)}`, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, TOP_LINE),
		Size = UDim2.fromOffset(REWARD_WIDTH, 22),
		TextSize = 17,
		FontFace = UI.Fonts.Heavy,
		TextColor3 = UI.Colors.Money,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	-- The longest ("Pick up 8 pieces of junk") shrinks a little to stay on its line.
	local words = UI.label(contract.text, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(x, TOP_LINE),
		Size = UDim2.new(1, -(x + 12 + REWARD_WIDTH + 6), 0, 22),
		TextScaled = true,
		TextSize = 16,
		FontFace = UI.Fonts.Heavy,
		TextColor3 = if done then UI.Colors.SubText else UI.Colors.Text,
		Parent = row,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11, Parent = words })
	local progress = progressText(contract)
	local progressWidth = math.ceil(UI.textWidth(progress, 14)) + 6
	UI.label(progress, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(x, BOTTOM_LINE),
		Size = UDim2.fromOffset(progressWidth, 16),
		TextSize = 14,
		FontFace = UI.Fonts.Bold,
		TextColor3 = if done then UI.Colors.Money else UI.Colors.SubText,
		Parent = row,
	})
	local bar = UI.bar({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(x + progressWidth + 6, BOTTOM_LINE),
		Size = UDim2.new(1, -(x + progressWidth + 6 + 12), 0, BAR_HEIGHT),
		Parent = row,
	}, if done then "Money" else "Grass")
	bar.set(if contract.need > 0 then contract.have / contract.need else 1)
	if stamp then
		UI.stampText(row, "DONE", DONE_STAMP_HEIGHT).flash("Text", Vector2.new(0.5, 0.5), sparkles)
	end
end

-- Draws the three contracts, the Bonus Day line and the streak card from the view. `reopened` is
-- true as the panel opens, when every paid contract gets its stamp; after that only one that has
-- just been paid does, with sparkles. Until the server has sent the day's contracts (the save is
-- still loading) it says they're on their way.
local function render(reopened: boolean)
	local view: View? = ClientState.contracts
	local ready = view ~= nil and #view.contracts > 0
	waiting.Visible = not ready
	rows.Visible = ready
	bonusLabel.Visible = ready
	UI.clearList(rows)
	if not view or not ready then
		streakCard.Visible = false
		drawnDone = {}
		return
	end
	local now: { [string]: boolean } = {}
	for index, contract in view.contracts do
		local key = `{view.day}/{contract.id}`
		local fresh = contract.done and not drawnDone[key]
		addRow(index, contract, contract.done and (reopened or fresh), if fresh and not reopened then 5 else nil)
		if contract.done then
			now[key] = true
		end
	end
	drawnDone = now
	if view.bonus then
		bonusLabel.Text = "Bonus Day collected"
		bonusLabel.TextColor3 = UI.Colors.Money
	else
		bonusLabel.Text = `Bonus Day: {Format.money(Contracts.BonusCash)} for all three`
		bonusLabel.TextColor3 = UI.Colors.Gold
	end
	local line = ContractsController.streakLine(view)
	streakCard.Visible = line ~= nil
	if line then
		streakLabel.Text = `Streak: {line}`
	end
end

-- Sizes the panel to the screen (__screen.scaling.ContractsPanel): the smallest of its biggest scale
-- and what fits the screen's height and width less their margins (the touch height margin is the
-- same as the other), times its own scale in UiLayout.
local function fit()
	local screen = UI.getScreen().AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	local rule = UI.Layout.__screen.scaling.ContractsPanel
	local place = UI.layout("ContractsPanel")
	local size = place.size :: UDim2
	local margin = if UI.isTouch() then rule.touchMargin else rule.margin
	local wanted = math.min(rule.scale, (screen.Y - margin) / size.Y.Offset, (screen.X - rule.margin) / size.X.Offset)
	scale.Scale = math.max(wanted, SMALLEST_SCALE) * place.scale
end

-- Puts the window where UiLayout's ContractsPanel says, if UI.panel's menu place (the same window
-- every menu has) has been put back over it, and fits it to the screen.
local function replace()
	local place = UI.layout("ContractsPanel")
	if panel.Size ~= place.size or panel.Position ~= place.position or panel.AnchorPoint ~= place.anchor then
		UI.place(panel, "ContractsPanel")
	end
	fit()
end

local function close()
	UI.close(PANEL)
end

-- The window: its title and X like every menu's (UI.panel), then, in a column, the three rows, the
-- Bonus Day line, the streak card and a Close button.
local function build()
	local content: Frame
	panel, content = UI.panel(PANEL, "Today's contracts")
	-- Over the pay breakdown (5) should the two ever be up together, like the Levels panel.
	panel.ZIndex = 6
	UI.keepPlaced(panel, "ContractsPanel")
	scale = UI.scaler(panel)
	UI.getScreen():GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	UI.list(8).Parent = content
	waiting = UI.label("Today's contracts are on their way.", {
		Name = "Waiting",
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = UI.Colors.SubText,
		TextWrapped = true,
		LayoutOrder = 1,
		Parent = content,
	})
	rows = UI.new("Frame", {
		Name = "Rows",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 1,
		Parent = content,
	}, { UI.list(ROW_GAP) })
	bonusLabel = UI.label("", {
		Name = "Bonus",
		Size = UDim2.new(1, 0, 0, 22),
		TextScaled = true,
		TextSize = 17,
		FontFace = UI.Fonts.Heavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = content,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 12, Parent = bonusLabel })
	streakCard = UI.card({
		Name = "StreakCard",
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		LayoutOrder = 3,
		Parent = content,
	})
	streakLabel = UI.label("", {
		Name = "Streak",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextScaled = true,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = streakCard,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = streakLabel })
	UI.button("Close", close, {
		Name = "CloseButton",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 20,
		LayoutOrder = 4,
		Parent = content,
	})
end

-- It's been opened (by name, with UI.open, or from the chip): drawn fresh and fitted, unless it
-- has no room, inside the shop computer's screen or while a scene has the game's.
local function onVisible()
	if not panel.Visible then
		return
	end
	if UI.hosted() or not UI.getScreen().Enabled then
		close()
		return
	end
	replace()
	render(true)
end

-- The job's id and state as one string, or nil without a job: it changes when a job is accepted,
-- starts the drive, gets going, finishes or is gone.
local function stepOf(job): string?
	return if job then `{job.id}/{job.state}` else nil
end

local function onChanged(key: string)
	if key == "contracts" then
		if panel.Visible then
			render(false)
		end
	elseif key == "job" then
		local step = stepOf(ClientState.job)
		if step ~= jobStep then
			jobStep = step
			close()
		end
	end
end

-- A menu opening is UI.open hiding this window, so only the shop computer starting to host the
-- menus needs closing for. When the menus' windows have been put back on the screen (the computer
-- letting go of them), this one goes back to its own place.
local function onCursorChanged()
	if UI.hosted() then
		close()
	else
		replace()
	end
end

local function onKey(input: InputObject)
	-- Roblox's own menu usually takes Escape (and marks it processed), so it closes either way.
	if input.KeyCode == Enum.KeyCode.Escape then
		close()
	end
end

function ContractsController:Start()
	build()
	jobStep = stepOf(ClientState.job)
	ClientState.Changed:Connect(onChanged)
	panel:GetPropertyChangedSignal("Visible"):Connect(onVisible)
	UI.CursorChanged:Connect(onCursorChanged)
	UI.CompactChanged:Connect(replace)
	-- A scene, the drive and the contest results switch the game's screen off (UI.hideGame).
	UI.getScreen():GetPropertyChangedSignal("Enabled"):Connect(function()
		if not UI.getScreen().Enabled then
			close()
		end
	end)
	-- Escape opens Roblox's own menu; the panel gives way to it.
	GuiService.MenuOpened:Connect(close)
	UserInputService.InputBegan:Connect(onKey)
end

return ContractsController
