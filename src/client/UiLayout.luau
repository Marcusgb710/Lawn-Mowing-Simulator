-- Where everything on the play screen goes, as plain data for the layout editor: the HUD, the
-- phone buttons, the prompts, the popups, the menus' windows, the dialogue and the drive cutscene,
-- one entry each, by a name that stays the same. The editor draws them on a phone, tablet or PC
-- screen and writes where they're dragged to back here. To give it what's here now:
--   lune run scripts/ui-layout-json      prints this whole file as JSON, the names as keys
-- So that Lune can read it, it's only numbers, strings, booleans and tables of them: no game, no
-- services, no requires.
--
-- In the game, UI.place(gui, name) puts an element where its entry says as it's made (UI.luau).
-- The few that move later still do it in their controllers, starting from the values here.
--
-- Each entry:
--   label     what the editor calls it
--   group     what it's listed under: HUD, Trackers, Prompts, Phone buttons, Popups, Menus, Aim,
--             Dialogue, Cutscene or Studio
--   screen    the ScreenGui it's on (one of __screen.screens), for anything placed on the screen
--   parent    the element it's inside, for anything placed in another one: its position and size
--             are then in its parent's box, as Roblox does it
--   order     where it comes in its parent's list (its LayoutOrder)
--   list      for an element that stacks what's in it (a UIListLayout): which way ("Vertical" or
--             "Horizontal"), the gap between them in pixels, and which side they line up on
--             ("Left", "Center" or "Right"). What's in a list has no position of its own: the list
--             decides it
--   anchor    its AnchorPoint, { x, y }
--   position  its Position, a UDim2 as { x scale, x pixels, y scale, y pixels }
--   size      its Size, the same way. With autoSize, it's the least it can be along that way
--   autoSize  "X", "Y" or "XY": which way it grows to fit what's in it (its AutomaticSize)
--   min, max  { width = , height = } in pixels: the smallest and biggest it can be (a
--             UISizeConstraint). A side that isn't there has no limit
--   typical   { width, height } in pixels: about how big it shows on a phone held sideways
--             (__screen.phone), before any UIScale, for anything whose size isn't all in `size`
--   touch     an anchor, position or size to use instead on a touch screen
--   compact   the same on a short screen (shorter than __screen.compactHeight)
--   device    "touch": it only ever shows on a touch screen; "keyboard": only with a keyboard
--   fixed     true for something drawn only so the rest can be placed around it: the game decides
--             where it goes (the dot is where the camera aims), so the editor shouldn't move it
--   note      when it shows, what decides its size, and anything else the editor should know
--
-- The screens. Each element is on one of these ScreenGuis (its `screen`, or its parent's), and
-- __screen.screens has each one's settings:
--   * LawnUI, the game's own screen (UI.getScreen): the HUD, the menus, the Snip button and most
--     popups. IgnoreGuiInset is off, so its top is just under Roblox's top bar (the strip with
--     Roblox's own buttons: GuiService:GetGuiInset() says how tall, 58 px on today's Roblox), and
--     its ScreenInsets are Roblox's default, CoreUISafeInsets, which also keeps it clear of a
--     phone's notch. Toasts, Computer and StudioTest are the same.
--   * Interact, Decorating, Crosshair, DialogueBars and Cutscene have IgnoreGuiInset on, so they
--     cover the whole screen, notch and all (Roblox keeps ScreenInsets in step: None). The dot
--     has to be in the very middle of the screen, where the camera aims, and the look-at prompt
--     and buttons are on screens like the dot's, so they line up with it.
--   * Dialogue and BestYard have IgnoreGuiInset on too, then ScreenInsets set to
--     DeviceSafeInsets: they can go under Roblox's top bar but keep clear of a phone's notch.
-- LawnUI is switched off while a scene, the drive or the contest results has the screen
-- (UI.hideGame), and Roblox's own hotbar (the Backpack) only shows on a job site (UI.setHotbar).
-- The hotbar's place is Roblox's, along the bottom in the middle, so it isn't in here: the tool
-- condition and the carry hint sit far enough up to clear it.
--
-- Scaling. Three things shrink with a UIScale to fit the screen; __screen.scaling has the exact
-- numbers and each rule, and the controllers read them from there:
--   * the two HUD columns (LeftColumn and RightColumn): full size on a screen at least 560 px
--     tall, smaller on shorter ones down to 0.7 (a phone held sideways), and smaller still, down
--     to 0.5, if a column wouldn't fit the screen's height otherwise. A UIScale shrinks toward
--     the element's AnchorPoint, so the left column stays in the top left corner and the right
--     one in the top right;
--   * the pay breakdown, to fit the screen;
--   * the contest results, laid out at 1100 x 640 and scaled to fit (a little bigger on a big
--     screen).
-- The big moments and act titles also have one, only to pop in.
--
-- Touch. A touch screen is one where UserInputService.TouchEnabled is true (UI.isTouch). That's
-- the check that shows the phone buttons, and `touch` places are used there; a laptop with a
-- touchscreen counts. The dialogue words its buttons for a phone ("Tap to continue") only when
-- there's no keyboard as well, but that changes words, not places.
--
-- Worked out while playing, from the values here (each one's note has the rule):
--   * the columns' scale (above), and curb appeal hiding on a short screen during a job;
--   * the toasts move down to stay just under the first-job coach while it shows;
--   * the dialogue box's width and height, for each line and the screen it's on, and the
--     dialogue's compact places when the screen turns;
--   * a menu's window fills the computer's screen while you're at the computer;
--   * inside the computer's screen, the taskbar hides the apps' names (and then your money) on
--     narrower screens;
--   * the min and max clamps, as `min` and `max`.
-- Not in here: what's inside the menus, panels and boxes (their own layout), full-screen layers
-- that are never placed (fades, the dialogue's click-anywhere button, the contest's dim
-- backdrop), the invisible button that frees the mouse, and the title card when you join
-- (src/first, which is shown before any of this loads).

return {
	-- How the screens work, for the editor to copy.
	__screen = {
		-- A touch screen is one where this is true (UI.isTouch).
		touch = "UserInputService.TouchEnabled",
		-- Screens shorter than this (pixels) are short ones, like a phone held sideways: `compact`
		-- places are used there. Only the dialogue has them; it checks again when the screen turns.
		compactHeight = 500,
		-- The phone the `typical` sizes are guessed for, held sideways (an iPhone 13's points).
		phone = { width = 844, height = 390 },
		-- Each ScreenGui by name, as its controller makes it. They're here to be copied: changing
		-- them here doesn't change the game.
		screens = {
			LawnUI = {
				ignoreGuiInset = false,
				screenInsets = "CoreUISafeInsets",
				displayOrder = 0,
				note = "The game's own screen (UI.getScreen). Switched off while a scene, the drive or the "
					.. "contest results has the screen.",
			},
			Toasts = {
				ignoreGuiInset = false,
				screenInsets = "CoreUISafeInsets",
				displayOrder = 5,
				note = "Toasts and big moments: over the shop computer, so its replies show, but under the drive.",
			},
			Interact = {
				ignoreGuiInset = true,
				screenInsets = "None",
				displayOrder = 0,
				note = "The look-at prompt and the phone buttons that go with it, around the dot.",
			},
			Decorating = {
				ignoreGuiInset = true,
				screenInsets = "None",
				displayOrder = 0,
				note = "The prompt and phone buttons for putting a decoration down.",
			},
			Crosshair = {
				ignoreGuiInset = true,
				screenInsets = "None",
				displayOrder = 0,
				note = "The dot in the very middle of the screen, and the hold ring round it.",
			},
			Computer = {
				ignoreGuiInset = false,
				screenInsets = "CoreUISafeInsets",
				displayOrder = 4,
				note = "The shop computer's monitor, while you're at it.",
			},
			DialogueBars = {
				ignoreGuiInset = true,
				screenInsets = "None",
				displayOrder = 8,
				note = "A scene's letterbox bars and fade, filling the whole screen, notch and all.",
			},
			Dialogue = {
				ignoreGuiInset = true,
				screenInsets = "DeviceSafeInsets",
				displayOrder = 9,
				note = "What you read and press in a scene, clear of a phone's notch.",
			},
			BestYard = {
				ignoreGuiInset = true,
				screenInsets = "DeviceSafeInsets",
				displayOrder = 9,
				note = "The Best Yard contest's results.",
			},
			Cutscene = {
				ignoreGuiInset = true,
				screenInsets = "None",
				displayOrder = 10,
				note = "The drive to a job: letterbox bars and where you're going.",
			},
			StudioTest = {
				ignoreGuiInset = false,
				screenInsets = "CoreUISafeInsets",
				displayOrder = 50,
				note = "Shortcuts for testing the story, only ever made in a Studio playtest.",
			},
			World = {
				billboard = true,
				note = "Not a screen: BillboardGuis over people in the world. Only their size is placed.",
			},
		},
		-- What scales to fit the screen (a UIScale on each of `elements`), with the rule for how much.
		scaling = {
			Columns = {
				elements = { "LeftColumn", "RightColumn" },
				fullHeight = 560,
				minScale = 0.7,
				tightScale = 0.5,
				margin = 24,
				note = "The screen's height over fullHeight, but at least minScale and at most 1. If the "
					.. "column at full size is taller than the screen's height less margin, then small enough to "
					.. "fit in that, but never below tightScale.",
			},
			PayBreakdown = {
				elements = { "PayBreakdown" },
				margin = 24,
				note = "The smallest of 1, (screen height - margin) / its height and (screen width - margin) / "
					.. "its width.",
			},
			ContestResults = {
				elements = { "ContestResults" },
				marginX = 32,
				marginY = 24,
				maxScale = 1.15,
				note = "The smallest of screen width / (its width + marginX), screen height / (its height + "
					.. "marginY) and maxScale.",
			},
		},
	},

	-- The HUD ------------------------------------------------------------------------------------

	LeftColumn = {
		label = "Left HUD column",
		group = "HUD",
		screen = "LawnUI",
		anchor = { 0, 0 },
		position = { 0, 12, 0, 12 },
		size = { 0, 220, 0, 0 },
		autoSize = "Y",
		list = { direction = "Vertical", padding = 10, align = "Left" },
		typical = { 220, 400 },
		note = "The money panel, the menu buttons and Grandma's goal stacked down the left, so they can't "
			.. "run into each other on a short screen. Its UIScale shrinks it to fit (__screen.scaling.Columns).",
	},
	MoneyPanel = {
		label = "Money and level panel",
		group = "HUD",
		parent = "LeftColumn",
		order = 1,
		size = { 0, 220, 0, 104 },
		note = "Always shown during play: your money, your level and jobs done, and the XP bar.",
	},
	MenuButtons = {
		label = "Menu buttons",
		group = "HUD",
		parent = "LeftColumn",
		order = 2,
		size = { 0, 150, 0, 0 },
		autoSize = "Y",
		list = { direction = "Vertical", padding = 8, align = "Left" },
		typical = { 150, 148 },
		note = "The Truck, Guide and Crew buttons. With a keyboard each one has its key (T, G, C) and the "
			.. "mouse hint goes under them, which makes it 172 px tall.",
	},
	TruckButton = {
		label = "Truck button",
		group = "HUD",
		parent = "MenuButtons",
		order = 1,
		size = { 0, 150, 0, 44 },
		note = "Opens the Truck menu (T).",
	},
	GuideButton = {
		label = "Guide button",
		group = "HUD",
		parent = "MenuButtons",
		order = 2,
		size = { 0, 150, 0, 44 },
		note = "Opens the Tool Guide (G).",
	},
	CrewButton = {
		label = "Crew button",
		group = "HUD",
		parent = "MenuButtons",
		order = 3,
		size = { 0, 150, 0, 44 },
		note = "Opens the Crew menu (C).",
	},
	MouseHint = {
		label = "Hold Alt hint",
		group = "HUD",
		parent = "MenuButtons",
		order = 4,
		size = { 0, 150, 0, 16 },
		device = "keyboard",
		note = "'Hold Alt for the mouse', with a keyboard only: in first person the mouse is locked to the "
			.. "middle of the screen.",
	},
	GrandmaGoal = {
		label = "Grandma's goal",
		group = "Trackers",
		parent = "LeftColumn",
		order = 3,
		size = { 0, 220, 0, 0 },
		autoSize = "Y",
		typical = { 220, 128 },
		note = "Grandma's sticky note with your story goal and how close you are, while you have one. As "
			.. "tall as its words.",
	},
	RightColumn = {
		label = "Right HUD column",
		group = "HUD",
		screen = "LawnUI",
		anchor = { 1, 0 },
		position = { 1, -12, 0, 12 },
		size = { 0, 280, 0, 0 },
		autoSize = "Y",
		list = { direction = "Vertical", padding = 10, align = "Right" },
		typical = { 280, 330 },
		note = "Curb appeal over the job tracker, down the right. Its UIScale shrinks it to fit like the left "
			.. "column's, toward its top right corner. Typical is during a job on a phone, where curb appeal "
			.. "hides.",
	},
	CurbAppeal = {
		label = "Curb appeal panel",
		group = "HUD",
		parent = "RightColumn",
		order = 1,
		size = { 0, 220, 0, 78 },
		note = "Your crew's curb appeal out of 100, once there is one. Hidden during a job on a screen "
			.. "shorter than __screen.scaling.Columns.fullHeight, where the job tracker needs the room.",
	},
	JobTracker = {
		label = "Job tracker",
		group = "Trackers",
		parent = "RightColumn",
		order = 2,
		size = { 0, 280, 0, 0 },
		autoSize = "Y",
		typical = { 280, 330 },
		note = "On the art's GoalTracker card, while you have a job: its name, a hint, its to-dos, the timer "
			.. "against par and damage while you work, and a button to call it off. As tall as what's in it.",
	},
	ToolCondition = {
		label = "Tool condition",
		group = "HUD",
		screen = "LawnUI",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -130 },
		size = { 0.9, 0, 0, 36 },
		autoSize = "Y",
		max = { width = 440 },
		typical = { 440, 36 },
		note = "What's wrong with the tool in your hands (a chip for each thing), or 'Working on it... 3s' "
			.. "while you work on one. The chips go onto a second line when they don't fit. Far enough up to "
			.. "clear Roblox's hotbar.",
	},

	-- Prompts ------------------------------------------------------------------------------------

	TutorialBanner = {
		label = "First-job coach",
		group = "Prompts",
		screen = "LawnUI",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, 12 },
		size = { 0.6, 0, 0, 0 },
		autoSize = "Y",
		max = { width = 520 },
		typical = { 506, 130 },
		note = "Coaches a new player through their first job, a step at a time, once the intro scene's over "
			.. "and until the job's paid. As tall as its words. The toasts keep below it.",
	},
	CarryHint = {
		label = "Carry hint",
		group = "Prompts",
		screen = "LawnUI",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -90 },
		size = { 0.9, 0, 0, 0 },
		autoSize = "Y",
		min = { width = 240 },
		max = { width = 460 },
		touch = { size = { 1, -540, 0, 0 } },
		typical = { 304, 78 },
		note = "What to do with the tool you're carrying or driving at your business. On a touch screen it's "
			.. "540 px narrower than the screen, to stay between the round buttons on the right and the HUD on "
			.. "the left. As tall as its words.",
	},
	InteractPrompt = {
		label = "Look-at prompt",
		group = "Prompts",
		screen = "Interact",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0.5, 22 },
		size = { 0, 440, 0, 0 },
		autoSize = "Y",
		typical = { 440, 46 },
		note = "Just under the dot while it's on something you can use: a 46 px pill for each thing you can "
			.. "do (6 px apart), red with the reason when it won't work. With a keyboard there's a second pill "
			.. "for R when there's a second thing to do. On a touch screen it only shows when the thing has a "
			.. "name, since the button says what it does.",
	},
	DecorPrompt = {
		label = "Decorating prompt",
		group = "Prompts",
		screen = "Decorating",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0.5, 22 },
		size = { 0, 440, 0, 0 },
		autoSize = "Y",
		typical = { 440, 46 },
		note = "Just under the dot while you're putting a decoration down: its name, red with why it can't "
			.. "go there, and with a keyboard or gamepad a second pill with the keys (98 px tall then).",
	},

	-- Phone buttons --------------------------------------------------------------------------------

	InteractButton = {
		label = "Look-at button",
		group = "Phone buttons",
		screen = "Interact",
		anchor = { 1, 0.5 },
		position = { 1, -24, 0.55, 0 },
		size = { 0, 110, 0, 110 },
		device = "touch",
		note = "The big round button that does what E does, while the dot's on something you can use, greyed "
			.. "out when it won't work. Its glyph is inside and its words go under it (28 px more, 20 px past "
			.. "each side).",
	},
	InteractSecondButton = {
		label = "Look-at second button",
		group = "Phone buttons",
		screen = "Interact",
		anchor = { 1, 1 },
		position = { 1, -24, 0.55, -66 },
		size = { 0, 110, 0, 44 },
		device = "touch",
		note = "What R does, when the thing you're looking at has a second thing to do (take one tool out of "
			.. "the bucket, the building's machines, the mailbox). Just over the round button.",
	},
	SnipButton = {
		label = "Snip button",
		group = "Phone buttons",
		screen = "LawnUI",
		anchor = { 1, 0.5 },
		position = { 1, -146, 0.55, 0 },
		size = { 0, 96, 0, 96 },
		device = "touch",
		note = "While you hold grass shears in first person: tap to snip, hold to keep snipping. Its words go "
			.. "under it (28 px more). Left of the look-at button, but on the game's own screen, so it sits a "
			.. "little lower than that one does at the same 0.55.",
	},
	DecorButtons = {
		label = "Decorating buttons",
		group = "Phone buttons",
		screen = "Decorating",
		anchor = { 1, 0.5 },
		position = { 1, -24, 0.4, 0 },
		size = { 0, 110, 0, 240 },
		list = { direction = "Vertical", padding = 8, align = "Left" },
		device = "touch",
		note = "While you're putting a decoration down, on the right where the look-at button usually is, "
			.. "clear of the jump button.",
	},
	DecorPlaceButton = {
		label = "Place button",
		group = "Phone buttons",
		parent = "DecorButtons",
		order = 1,
		size = { 0, 110, 0, 80 },
		note = "Puts the decoration down where it is (E).",
	},
	DecorTurnButton = {
		label = "Turn button",
		group = "Phone buttons",
		parent = "DecorButtons",
		order = 2,
		size = { 0, 110, 0, 44 },
		note = "Turns it 15 degrees (R).",
	},
	DecorPutBackButton = {
		label = "Put back button",
		group = "Phone buttons",
		parent = "DecorButtons",
		order = 3,
		size = { 0, 110, 0, 44 },
		note = "Stops placing it and puts it back (Q).",
	},
	DecorSendBackButton = {
		label = "Send back button",
		group = "Phone buttons",
		parent = "DecorButtons",
		order = 4,
		size = { 0, 110, 0, 44 },
		note = "Sends it back for part of its price (F). Only for the business's owner: hidden otherwise.",
	},

	-- Popups ---------------------------------------------------------------------------------------

	Toasts = {
		label = "Toasts",
		group = "Popups",
		screen = "Toasts",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, 60 },
		size = { 1, -32, 0, 200 },
		max = { width = 420, height = 200 },
		list = { direction = "Vertical", padding = 6, align = "Left" },
		note = "Where the little messages stack, each fading after a few seconds: a notice is 40 px tall or "
			.. "as tall as it wraps to, a new text 64 px. While the first-job coach shows, the stack moves down "
			.. "to start 8 px under it.",
	},
	Moment = {
		label = "Big moment",
		group = "Popups",
		screen = "Toasts",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.3, 0 },
		size = { 0.9, 0, 0, 140 },
		max = { width = 720, height = 140 },
		note = "Level Up!, New Tool! or Payday! for a couple of seconds: the wordmark with a line under it. "
			.. "It pops in with a UIScale from 0.6.",
	},
	PayBreakdown = {
		label = "Pay breakdown",
		group = "Popups",
		screen = "LawnUI",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0, 500, 0, 0 },
		autoSize = "Y",
		typical = { 500, 430 },
		note = "After a job until you close it: Job Complete!, what each part paid and the total. As tall as "
			.. "its lines; its UIScale shrinks it to fit the screen (__screen.scaling.PayBreakdown).",
	},
	CrewInvite = {
		label = "Crew invite",
		group = "Popups",
		screen = "LawnUI",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -110 },
		size = { 0, 360, 0, 90 },
		note = "When someone invites you to their crew, until you answer or it runs out: Join or No thanks.",
	},

	-- Menus ----------------------------------------------------------------------------------------

	MenuWindow = {
		label = "Menu window",
		group = "Menus",
		screen = "LawnUI",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0.9, 0, 0.75, 0 },
		max = { width = 720, height = 520 },
		note = "Every menu's window, one open at a time: Truck, Guide and Crew, and the computer's Jobs, "
			.. "Orders, Business and Messages apps. While you're at the computer they fill its screen instead "
			.. "(ComputerMonitor), however big that is.",
	},
	ComputerMonitor = {
		label = "Shop computer",
		group = "Menus",
		screen = "Computer",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0.98, 0, 0.96, 0 },
		max = { width = 1000, height = 640 },
		note = "The computer's monitor while you're at it. Inside: the desktop's app icons (a row at most "
			.. "680 x 130), and a 48 px taskbar along the bottom whose buttons show their app's name only "
			.. "when the monitor's display is at least 1100 px wide, and your money at its end from 760.",
	},
	ContestResults = {
		label = "Best Yard results",
		group = "Menus",
		screen = "BestYard",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0, 1100, 0, 640 },
		note = "The contest's results after judging day's scene, over a dim backdrop. Everything in it is laid "
			.. "out for exactly this size, which its UIScale then fits to the screen "
			.. "(__screen.scaling.ContestResults): move it, but leave its size.",
	},

	-- The dot --------------------------------------------------------------------------------------

	Reticle = {
		label = "Aiming dot",
		group = "Aim",
		screen = "Crosshair",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0, 26, 0, 26 },
		fixed = true,
		note = "The dot you aim with, where the camera looks. Hidden while a menu frees the mouse. 6 px "
			.. "across while its art isn't uploaded.",
	},
	HoldRing = {
		label = "Hold ring",
		group = "Aim",
		screen = "Crosshair",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0, 76, 0, 76 },
		fixed = true,
		note = "Fills round the dot while you hold E to work on a tool.",
	},

	-- The story's dialogue ---------------------------------------------------------------------------

	DialogueTopBar = {
		label = "Scene letterbox, top",
		group = "Dialogue",
		screen = "DialogueBars",
		anchor = { 0, 0 },
		position = { 0, 0, 0, 0 },
		size = { 1, 0, 0, 56 },
		compact = { size = { 1, 0, 0, 52 } },
		note = "While a scene plays.",
	},
	DialogueBottomBar = {
		label = "Scene letterbox, bottom",
		group = "Dialogue",
		screen = "DialogueBars",
		anchor = { 0, 1 },
		position = { 0, 0, 1, 0 },
		size = { 1, 0, 0, 56 },
		compact = { size = { 1, 0, 0, 36 } },
		note = "While a scene plays.",
	},
	DialogueCaption = {
		label = "Scene caption",
		group = "Dialogue",
		screen = "Dialogue",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, 6 },
		size = { 0.5, 0, 0, 44 },
		note = "Where and when the scene is ('Maple Grove · First day of summer'), up top in the middle, "
			.. "clear of Roblox's own buttons.",
	},
	DialogueSkip = {
		label = "Skip button",
		group = "Dialogue",
		screen = "Dialogue",
		anchor = { 1, 0 },
		position = { 1, -12, 0, 6 },
		size = { 0, 0, 0, 44 },
		autoSize = "X",
		typical = { 92, 44 },
		note = "Skips the scene. As wide as its words: 'Skip' on a phone, the scene's own on a computer "
			.. "('Skip to the results').",
	},
	DialogueBox = {
		label = "Dialogue box",
		group = "Dialogue",
		screen = "Dialogue",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -30 },
		size = { 0, 900, 0, 160 },
		compact = { position = { 0.5, 0, 1, -14 }, size = { 0, 812, 0, 160 } },
		typical = { 718, 130 },
		note = "The speaker's portrait (poking up out of its top), their name and the line. Laid out again for "
			.. "each line and when the screen turns: as wide as the screen less 32 px, but at least 200 and "
			.. "at most its size's width, and as tall as the line needs (160 is only where it starts).",
	},
	DialogueToolCard = {
		label = "New tool card",
		group = "Dialogue",
		screen = "Dialogue",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0, 70 },
		size = { 0, 300, 0, 64 },
		compact = { position = { 0.5, 0, 0, 66 } },
		note = "Pops up when a line hands you a new tool, 14 px under the top letterbox bar.",
	},
	ActTitle = {
		label = "Act title card",
		group = "Dialogue",
		screen = "Dialogue",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.34, 0 },
		size = { 0.86, 0, 0, 110 },
		max = { width = 760, height = 110 },
		note = "An act's title ('Act 2: TurfKing') over its opening scene for a few seconds. It pops in with "
			.. "a UIScale from 0.7.",
	},
	SpeechBubble = {
		label = "Speech bubble",
		group = "Dialogue",
		screen = "World",
		size = { 0, 320, 0, 200 },
		compact = { size = { 0, 240, 0, 200 } },
		note = "Over whoever's talking in the world (Gloria on her porch, June when you talk to her), not on "
			.. "the screen, so only its size is placed. The bubble grows up from the bottom of this box, as "
			.. "tall as its words, with its tail on the person.",
	},

	-- The drive to a job -----------------------------------------------------------------------------

	CutsceneTopBar = {
		label = "Drive letterbox, top",
		group = "Cutscene",
		screen = "Cutscene",
		anchor = { 0, 0 },
		position = { 0, 0, 0, 0 },
		size = { 1, 0, 0.12, 0 },
		note = "While the truck drives to a job.",
	},
	CutsceneBottomBar = {
		label = "Drive letterbox, bottom",
		group = "Cutscene",
		screen = "Cutscene",
		anchor = { 0, 1 },
		position = { 0, 0, 1, 0 },
		size = { 1, 0, 0.12, 0 },
		note = "While the truck drives to a job.",
	},
	CutsceneTitle = {
		label = "Drive title",
		group = "Cutscene",
		screen = "Cutscene",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 0.88, -36 },
		size = { 0.8, 0, 0, 40 },
		note = "Where the crew's going, just over the bottom bar.",
	},
	CutsceneSubtitle = {
		label = "Drive subtitle",
		group = "Cutscene",
		screen = "Cutscene",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 0.88, -8 },
		size = { 0.8, 0, 0, 26 },
		note = "The line under the title.",
	},

	-- Studio playtests -------------------------------------------------------------------------------

	StudioTestHint = {
		label = "Studio test hint",
		group = "Studio",
		screen = "StudioTest",
		anchor = { 1, 1 },
		position = { 1, -10, 1, -8 },
		size = { 0, 170, 0, 16 },
		note = "'Studio test panel: K' in the corner, so it's clear the panel's there. Studio playtests only.",
	},
	StudioTestPanel = {
		label = "Studio test panel",
		group = "Studio",
		screen = "StudioTest",
		anchor = { 1, 0.5 },
		position = { 1, -12, 0.5, 0 },
		size = { 0, 240, 0, 0 },
		autoSize = "Y",
		typical = { 240, 410 },
		note = "Shortcuts for testing the story, shown and hidden with K in Studio playtests only. Its buttons "
			.. "are laid out for its width.",
	},
}
