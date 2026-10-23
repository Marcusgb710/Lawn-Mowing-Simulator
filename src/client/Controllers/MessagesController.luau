-- The Messages app on the shop computer (docs/STORY.md, "How the story is told in game"): texts
-- from Grandma June, the Bridge Club, Chad from TurfKing, Sam and your customers, a thread for
-- each, with an unread badge on every thread (and on the app's buttons, see ComputerController)
-- and a goal card for the act you're in. Most of the story arrives as texts so it never stops
-- play: away from the computer, a new text pops up as a small toast with the game's others.
-- On a narrow screen (a phone) the list of threads and the open thread take turns.
-- The inbox, what's been read and the goal all come from the server (StoryService); opening a
-- thread tells it that thread's been read. The art is in StoryArt, the colors and font in UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)

local ClientState = require(script.Parent.Parent.ClientState)
local StoryArt = require(script.Parent.Parent.StoryArt)
local UI = require(script.Parent.Parent.UI)
local DialogueController = require(script.Parent.DialogueController)

local player = Players.LocalPlayer

-- The app is laid out for a phone below this width (pixels): one pane at a time.
local NARROW = 560
local GAP = 12
-- How long a toast stays up, and how long a new text waits first (a scene may be about to start).
local TOAST_TIME = 5
local TOAST_DELAY = 0.75
-- At most this many toasts wait to show; older ones are dropped (they're still in the inbox).
local TOAST_QUEUE = 3

local MessagesController = {}

local window: Frame
local content: Frame
local listPane: ScrollingFrame
local threadPane: Frame
local backButton: TextButton
local threadName: TextLabel
local threadStatus: TextLabel
local messages: ScrollingFrame
local goalCard: Frame
local goalLabel: TextLabel
local goalText: TextLabel
local goalTrack: Frame
local goalFill: Frame
local goalValue: TextLabel

-- The thread shown, and on a narrow screen whether it's the thread showing (not the list).
local selected: string? = nil
local showingThread = false
-- The goal card's width and height when it was last laid out.
local goalWidth, goalHeight = 0, 0
-- The newest text seen so far (nil until the inbox first arrives: what's already there isn't new).
local lastSeen: number? = nil
local toastQueue: { { text: any, after: number } } = {}

-- The threads in the inbox, newest first: { id, texts, last, unread }.
local function threads()
	local story = ClientState.story
	if not story then
		return {}
	end
	local _, unread = Story.unread(story.texts, story.read)
	local byId, list = {}, {}
	for _, text in story.texts do
		local thread = byId[text.thread]
		if not thread then
			thread = { id = text.thread, texts = {}, unread = unread[text.thread] or 0 }
			byId[text.thread] = thread
			table.insert(list, thread)
		end
		table.insert(thread.texts, text)
		thread.last = text
	end
	table.sort(list, function(a, b)
		return a.last.n > b.last.n
	end)
	return list
end

-- A text's one-line preview: who sent it in a group thread, or "You".
local function preview(text): string
	local body = Story.plain(text.text)
	if text.mine then
		return "You: " .. body
	end
	return if text.from then `{text.from}: {body}` else body
end

-- What the goal's progress is right now: your money toward a price, or your curb appeal.
local function goalProgress(goal): (number, string)
	if goal.kind == "Money" then
		local money = if ClientState.profile then ClientState.profile.money else 0
		return money, `{Format.money(money)} / {Format.money(goal.need)}`
	end
	local appeal = player:GetAttribute("CurbAppeal")
	local have = if typeof(appeal) == "number" then appeal else 0
	return have, `{have} / {goal.need}`
end

local function textWidth(text: string, size: number): number
	return TextService:GetTextSize(text, size, UI.Font, Vector2.new(4000, 100)).X
end

-- Drawing the app ----------------------------------------------------------------------------

-- The goal card: on one row (the mock-up) where it fits, the bar under the goal where it doesn't.
local function renderGoal(width: number): number
	local story = ClientState.story
	local goal = story and story.goal
	goalCard.Visible = goal ~= nil
	if not goal then
		return 0
	end
	local have, value = goalProgress(goal)
	goalText.Text = goal.text
	goalValue.Text = value
	goalFill.Size = UDim2.fromScale(if goal.need > 0 then math.clamp(have / goal.need, 0, 1) else 1, 1)
	local labelWidth, valueWidth = textWidth("GOAL", 14) + 14, textWidth(value, 18) + 4
	local textX = 16 + labelWidth
	local oneRow = width - textX - textWidth(goal.text, 18) - valueWidth - 16 * 3 >= 80
	local height = if oneRow then 48 else 76
	goalLabel.Position = UDim2.fromOffset(16, 0)
	goalLabel.Size = UDim2.fromOffset(labelWidth, 48)
	goalValue.Position = UDim2.new(1, -16 - valueWidth, 0, if oneRow then 0 else 36)
	goalValue.Size = UDim2.fromOffset(valueWidth, if oneRow then 48 else 32)
	if oneRow then
		local barX = textX + textWidth(goal.text, 18) + 16
		goalText.Size = UDim2.fromOffset(textWidth(goal.text, 18) + 4, 48)
		goalTrack.Position = UDim2.fromOffset(barX, 17)
		goalTrack.Size = UDim2.new(1, -barX - valueWidth - 30, 0, 14)
	else
		goalText.Size = UDim2.new(1, -textX - 16, 0, 48)
		goalTrack.Position = UDim2.fromOffset(16, 45)
		goalTrack.Size = UDim2.new(1, -valueWidth - 46, 0, 14)
	end
	goalText.Position = UDim2.fromOffset(textX, 0)
	return height
end

local function markRead(thread)
	local story = ClientState.story
	if thread and story and thread.unread > 0 then
		Net.event("ReadThread"):FireServer(thread.id)
		-- Read here too, until the server's update comes back.
		story.read[thread.id] = thread.last.n
		thread.unread = 0
		ClientState.Changed:Fire("story")
	end
end

local function openThread(threadId: string)
	selected = threadId
	showingThread = true
	MessagesController.render()
end

local function threadCard(thread, index: number)
	local info = Story.thread(thread.id)
	local isSelected = thread.id == selected
	local card = UI.new("TextButton", {
		Name = "Thread",
		Size = UDim2.new(1, -8, 0, 72),
		BackgroundColor3 = if isSelected then UI.Colors.Card else UI.Colors.Panel,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = index,
		Parent = listPane,
	}, {
		UI.corner(16),
		UI.new("UIStroke", {
			Color = UI.Colors.Accent,
			Thickness = 3,
			Transparency = if isSelected then 0 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	local face = DialogueController.face(info.cast, 46)
	face.Position = UDim2.fromOffset(12, 13)
	face.Parent = card
	local right = if thread.unread > 0 then 50 else 14
	UI.label(info.name, {
		Position = UDim2.fromOffset(70, 12),
		Size = UDim2.new(1, -70 - right, 0, 24),
		TextSize = 19,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	UI.label(preview(thread.last), {
		Position = UDim2.fromOffset(70, 38),
		Size = UDim2.new(1, -70 - right, 0, 20),
		TextSize = 15,
		TextColor3 = UI.Colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	if thread.unread > 0 then
		local badge = UI.label(tostring(thread.unread), {
			Name = "Unread",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.Colors.Money,
			TextColor3 = UI.Colors.BubbleText,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		UI.corner(13).Parent = badge
	end
	card.Activated:Connect(function()
		openThread(thread.id)
	end)
end

-- One text: theirs in grey on the left (with who sent it, in a group), yours in green on the right.
local function bubble(text, index: number, maxWidth: number)
	local mine = text.mine == true
	local row = UI.new("Frame", {
		Name = "Text",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = messages,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = if mine then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
		}),
	})
	if text.from and not mine then
		UI.label(text.from, {
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 14,
			TextColor3 = UI.Colors.SubText,
			LayoutOrder = 1,
			Parent = row,
		})
	end
	local art = if mine then StoryArt.MyText else StoryArt.TheirText
	local color = if mine then UI.Colors.Accent else UI.Colors.Card
	local holder = UI.new(if art.image ~= "" then "ImageLabel" else "Frame", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = color,
		BackgroundTransparency = if art.image ~= "" then 1 else 0,
		LayoutOrder = 2,
		Parent = row,
	}, {
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
	})
	if art.image ~= "" then
		local image = holder :: ImageLabel
		image.Image = art.image
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = art.slice
	else
		UI.corner(18).Parent = holder
	end
	local label = UI.label(UI.highlight(text.text, if mine then UI.Colors.Background else UI.Colors.Money), {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		RichText = true,
		TextWrapped = true,
		TextSize = 18,
		TextColor3 = if mine then UI.Colors.BubbleText else UI.Colors.Text,
		Parent = holder,
	})
	-- As wide as the text, up to most of the thread's width, then it wraps.
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(maxWidth - 32, math.huge), Parent = label })
end

local function renderThread(thread, paneWidth: number)
	UI.clearList(messages)
	local narrow = content.AbsoluteSize.X < NARROW
	backButton.Visible = narrow
	local nameX = if narrow then 56 else 0
	threadName.Position = UDim2.fromOffset(nameX, 0)
	if not thread then
		threadName.Text = "Messages"
		threadStatus.Text = ""
		UI.label("No texts yet. Grandma June will be in touch.", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 16,
			TextColor3 = UI.Colors.SubText,
			Parent = messages,
		})
		return
	end
	local info = Story.thread(thread.id)
	threadName.Text = info.name
	threadName.Size = UDim2.fromOffset(textWidth(info.name, 21) + 4, 36)
	threadStatus.Position = UDim2.fromOffset(nameX + textWidth(info.name, 21) + 12, 0)
	threadStatus.Text = if info.status ~= "" then "· " .. info.status else ""
	local maxWidth = math.floor(math.max(160, (paneWidth - 28) * 0.78))
	for index, text in thread.texts do
		bubble(text, index, maxWidth)
	end
	-- Newest at the bottom, in view.
	task.defer(function()
		messages.CanvasPosition =
			Vector2.new(0, math.max(0, messages.AbsoluteCanvasSize.Y - messages.AbsoluteWindowSize.Y))
	end)
end

-- Draws the whole app, laid out for its width: side by side, or one pane at a time when narrow.
function MessagesController.render()
	if not (window and window.Visible) then
		return
	end
	local list = threads()
	local found = nil
	for _, thread in list do
		if thread.id == selected then
			found = thread
		end
	end
	if not found then
		found = list[1]
		selected = if found then found.id else nil
	end

	local size = content.AbsoluteSize
	local narrow = size.X < NARROW
	local listWidth = if narrow then size.X else math.clamp(math.floor(size.X * 0.34), 220, 330)
	local showList = not narrow or not showingThread or found == nil
	local showThread = not narrow or (showingThread and found ~= nil)

	-- The goal card sits at the bottom of the open thread, or under everything on a phone.
	goalWidth = if narrow then size.X else size.X - listWidth - GAP - 28
	goalHeight = renderGoal(goalWidth)
	local paneHeight = if narrow and goalHeight > 0 then size.Y - goalHeight - GAP else size.Y
	if narrow then
		goalCard.Parent = content
		goalCard.Position = UDim2.new(0, 0, 1, -goalHeight)
	else
		goalCard.Parent = threadPane
		goalCard.Position = UDim2.new(0, 14, 1, -14 - goalHeight)
	end
	goalCard.Size = UDim2.new(1, if narrow then 0 else -28, 0, goalHeight)

	listPane.Visible = showList
	listPane.Size = UDim2.fromOffset(listWidth, paneHeight)
	threadPane.Visible = showThread
	threadPane.Position = UDim2.fromOffset(if narrow then 0 else listWidth + GAP, 0)
	local threadWidth = if narrow then size.X else size.X - listWidth - GAP
	threadPane.Size = UDim2.fromOffset(threadWidth, paneHeight)
	local below = if narrow or goalHeight == 0 then 14 else goalHeight + 28
	messages.Size = UDim2.new(1, -28, 1, -(64 + below))

	-- Showing a thread reads it.
	if showThread and found then
		markRead(found)
	end
	UI.clearList(listPane)
	if #list == 0 then
		UI.label("No texts yet.", {
			Size = UDim2.new(1, -8, 0, 30),
			TextSize = 16,
			TextColor3 = UI.Colors.SubText,
			Parent = listPane,
		})
	end
	for index, thread in list do
		threadCard(thread, index)
	end
	if showThread then
		renderThread(found, threadWidth)
	end
end

-- Your money or curb appeal changed: only the goal card needs drawing again (so the thread you're
-- reading doesn't jump), unless it no longer fits the same way.
local function refreshGoal()
	if window and window.Visible and renderGoal(goalWidth) ~= goalHeight then
		MessagesController.render()
	end
end

-- Toasts --------------------------------------------------------------------------------------

local function showToast(text)
	local info = Story.thread(text.thread)
	local art = StoryArt.TextToast
	local toast = UI.new("CanvasGroup", {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = if art.image ~= "" then 1 else 0,
	}, { UI.corner(12) })
	if art.image ~= "" then
		UI.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			Image = art.image,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = art.slice,
			BackgroundTransparency = 1,
			Parent = toast,
		})
	end
	local face = DialogueController.face(info.cast, 42)
	face.Position = UDim2.fromOffset(10, 10)
	face.Parent = toast
	UI.label(info.name, {
		Position = UDim2.fromOffset(62, 8),
		Size = UDim2.new(1, -72, 0, 22),
		TextSize = 16,
		TextColor3 = UI.Colors.Accent,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = toast,
	})
	UI.label(preview(text), {
		Position = UDim2.fromOffset(62, 31),
		Size = UDim2.new(1, -72, 0, 22),
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = toast,
	})
	UI.toast(toast, TOAST_TIME)
end

-- New texts: a toast for each when you're away from the computer (not while a scene's playing).
local function onStoryChanged()
	local story = ClientState.story
	if not story then
		return
	end
	local newest = 0
	for _, text in story.texts do
		newest = math.max(newest, text.n)
	end
	if lastSeen == nil then
		lastSeen = newest
	elseif newest > lastSeen then
		for _, text in story.texts do
			if text.n > (lastSeen :: number) and not text.mine and not UI.hosted() then
				table.insert(toastQueue, { text = text, after = os.clock() + TOAST_DELAY })
			end
		end
		while #toastQueue > TOAST_QUEUE do
			table.remove(toastQueue, 1)
		end
		lastSeen = newest
	end
	MessagesController.render()
end

function MessagesController:Start()
	window, content = UI.panel("Messages", "Messages")

	listPane = UI.scrollingList(content, { Name = "Threads" })
	threadPane = UI.new("Frame", {
		Name = "Thread",
		BackgroundColor3 = UI.Colors.Panel,
		Parent = content,
	}, { UI.corner(18) })
	backButton = UI.button("<", function()
		showingThread = false
		MessagesController.render()
	end, {
		Name = "Back",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(44, 44),
		TextSize = 22,
		BackgroundColor3 = UI.Colors.Card,
		Visible = false,
		Parent = threadPane,
	})
	local header = UI.new("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 36),
		BackgroundTransparency = 1,
		Parent = threadPane,
	})
	threadName = UI.label("", { Size = UDim2.fromOffset(200, 36), TextSize = 21, Parent = header })
	threadStatus = UI.label("", {
		Size = UDim2.new(1, -220, 0, 36),
		TextSize = 15,
		TextColor3 = UI.Colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	UI.new("Frame", {
		Name = "Rule",
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 2),
		BackgroundColor3 = UI.Colors.Card,
		BorderSizePixel = 0,
		Parent = threadPane,
	})
	messages = UI.scrollingList(threadPane, {
		Name = "Texts",
		Position = UDim2.fromOffset(14, 66),
	})
	local layout = messages:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 10)
	end

	goalCard = UI.new("Frame", {
		Name = "Goal",
		BackgroundColor3 = UI.Colors.Background,
		ZIndex = 2,
		Parent = threadPane,
	}, { UI.corner(14) })
	goalLabel = UI.label("GOAL", {
		TextSize = 14,
		TextColor3 = UI.Colors.Accent,
		ZIndex = 2,
		Parent = goalCard,
	})
	goalText = UI.label("", { TextSize = 18, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = goalCard })
	goalTrack = UI.new("Frame", {
		BackgroundColor3 = UI.Colors.Card,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = goalCard,
	}, { UI.corner(7) })
	goalFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Money,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = goalTrack,
	}, { UI.corner(7) })
	goalValue = UI.label("", {
		TextSize = 18,
		TextColor3 = UI.Colors.Money,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = goalCard,
	})

	window:GetPropertyChangedSignal("Visible"):Connect(function()
		-- It opens on the list of threads.
		if not window.Visible then
			showingThread = false
		end
		MessagesController.render()
	end)
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(MessagesController.render)
	ClientState.Changed:Connect(function(key)
		if key == "story" then
			onStoryChanged()
		elseif key == "profile" then
			refreshGoal()
		end
	end)
	player:GetAttributeChangedSignal("CurbAppeal"):Connect(refreshGoal)
	onStoryChanged()

	-- Waiting toasts show once no scene is playing (and you haven't walked up to the computer).
	task.spawn(function()
		while true do
			task.wait(0.25)
			local waiting = toastQueue[1]
			if waiting and UI.hosted() then
				table.clear(toastQueue)
			elseif waiting and os.clock() >= waiting.after and not DialogueController.isOpen() then
				table.remove(toastQueue, 1)
				showToast(waiting.text)
			end
		end
	end)
end

return MessagesController
