-- Where everything on the play screen goes, as plain data for the layout editor: the HUD, the
-- phone buttons, the prompts, the popups, the menus' windows, the dialogue and the drive cutscene,
-- one entry each, by a name that stays the same. The editor draws them on a phone, tablet or PC
-- screen and writes where they're dragged to back here. To give it what's here now:
--   lune run scripts/ui-layout-json      prints this whole file as JSON, the names as keys
-- So that Lune can read it, it's only numbers, strings, booleans and tables of them: no game, no
-- services, no requires.
--
-- In the game, UI.place(gui, name) puts an element where its entry says as it's made (UI.luau),
-- and UI.keepPlaced does that and does it again when the screen turns short or tall. The few that
-- move later still do it in their controllers, starting from the values here.
--
-- Each entry:
--   label     what the editor calls it
--   group     what it's listed under: HUD, Trackers, Prompts, Phone buttons, Popups, Menus, Aim,
--             Dialogue, Cutscene or Studio
--   screen    the ScreenGui it's on (one of __screen.screens), for anything placed on the screen
--   parent    the element it's inside, for anything placed in another one: its position and size
--             are then in its parent's box, as Roblox does it
--   detach    for a piece of a HUD column that can be taken out of it: the column it belongs in,
--             and goes back into ("LeftColumn" or "RightColumn"). With that column as its `parent`
--             it's in the column, at its `order`. With no `parent` it's out on the game's own
--             screen (`screen` is "LawnUI", and it has an `anchor` and a `position` like anything
--             else there), it keeps its `order` for when it goes back, and a UIScale of its own
--             shrinks it by the columns' rule (__screen.scaling.Columns), so it's the size it was
--             in the column on a phone too
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
--   scale     how much bigger or smaller it's drawn, everything in it too: 1 when it isn't there,
--             and 0.5 to 2 is sensible. It's a UIScale, so it grows or shrinks about its
--             AnchorPoint, and in a list it takes up its scaled size. Its size, position and the
--             rest stay in its own pixels, before the scale. See Scaling for how it goes with the
--             UIScales that fit things to the screen. Not for World pieces: only their size is
--             placed
--   typical   { width, height } in pixels: about how big it shows on a phone held sideways
--             (__screen.phone), before any UIScale, for anything whose size isn't all in `size`
--   touch     an anchor, position, size or scale to use instead on a touch screen. For a piece of a
--             HUD column (one with a `detach`), it can have a `parent` too: false takes it out of its
--             column on a touch screen (with an anchor and position there), and the column's name
--             puts it back in
--   compact   the same on a short screen (shorter than __screen.compactHeight), over the touch ones
--             (see Touch and short screens), but not a `parent`. Touch and compact can also have a
--             `typical`, for the editor to draw the piece at on those screens; the game never reads
--             typical
--   hideWhile the pieces that take its spot: while any of them shows, it hides, and shows again when
--             they've gone (UI.givesWay). It can be in `touch` or `compact` instead, for a piece that
--             only gives way there
--   device    "touch": it only ever shows on a touch screen; "keyboard": only with a keyboard
--   fixed     true for something drawn only so the rest can be placed around it: the game decides
--             where it goes (the dot is where the camera aims), so the editor shouldn't move it
--   compactOnly  true for a piece that only shows on a short screen, the way the HUD counts one for
--             its columns: shorter than __screen.scaling.Columns.fullHeight, not compactHeight. Once
--             the editor learns it, it draws it on the phone screens and leaves it out of the tall ones
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
--     to 0.5, if a column wouldn't fit the screen's height less 24 px otherwise. On a touch screen
--     that's less 110 px (touchMargin), so the columns end above Roblox's move stick and jump
--     button. A UIScale shrinks toward the element's AnchorPoint, so the left column stays in the
--     top left corner and the right one in the top right. A piece taken out of its column (see
--     `detach`) shrinks by the same rule on its own;
--   * the pay breakdown, to fit the screen;
--   * the contest results, laid out at 1100 x 640 and scaled to fit (a little bigger on a big
--     screen).
-- The big moments and act titles also have one, only to pop in.
-- An entry's `scale` goes with these: the UIScale is what the rule works out times the scale (a
-- column the rule puts at 0.7 on a phone, with a scale of 1.2, is drawn at 0.84), and a pop-in
-- grows to its scale instead of to 1. Everything else with a `scale` that isn't 1 gets a UIScale
-- of its own for it, named LayoutScale. Roblox only honours one UIScale on an element, so nothing
-- gets two.
--
-- Touch and short screens. A touch screen is one where UserInputService.TouchEnabled is true
-- (UI.isTouch). That's the check that shows the phone buttons, and `touch` places are used there;
-- a laptop with a touchscreen counts. The dialogue words its buttons for a phone ("Tap to
-- continue") only when there's no keyboard as well, but that changes words, not places. A short
-- screen is one whose whole height (the camera's view) is less than __screen.compactHeight
-- (UI.isCompact), and `compact` places are used there. A piece's place is its own values, with its
-- touch ones over them on a touch screen and then its compact ones over those on a short screen,
-- one field at a time, the same way the editor does it. When the screen turns short or tall (a
-- window resized), what's placed with UI.keepPlaced is placed again, and the dialogue lays itself
-- out again; the rest is placed once, as it's made.
--
-- Worked out while playing, from the values here (each one's note has the rule):
--   * the columns' scale (above), and curb appeal hiding on a short screen while the job tracker
--     shows;
--   * the goals rail under Grandma's goal (its next two milestones, from Config/Milestones.luau), which
--     hides on a short screen, where NextChip shows the next one instead, through a job too;
--   * what gives way to what (each piece's hideWhile): on a touch screen Grandma's goal, the
--     first-job coach and a crew invite share the top of the screen, one at a time, and the job
--     tracker steps aside for the decorating buttons;
--   * the job tracker's smaller layout on a short screen, which leaves room for the phone
--     buttons under it;
--   * the toasts move down to stay just under what's showing at the top of the screen in their
--     way: the first-job coach, and on a touch screen Grandma's goal or a crew invite;
--   * the dialogue box's width and height, for each line and the screen it's on, and the
--     dialogue's compact places when the screen turns;
--   * the Levels panel and the contracts panel shrinking to fit the screen by the pay breakdown's rule
--     (centred, they're already clear of the move stick and jump button on a touch screen);
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
		-- Screens shorter than this (pixels, the whole screen) are short ones, like a phone held
		-- sideways: `compact` places are used there, for any piece that has them (UI.isCompact).
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
		-- Each element's own `scale` multiplies what the rule works out.
		scaling = {
			Columns = {
				elements = { "LeftColumn", "RightColumn" },
				fullHeight = 560,
				minScale = 0.7,
				tightScale = 0.5,
				margin = 24,
				touchMargin = 110,
				note = "The screen's height over fullHeight, but at least minScale and at most 1. If the "
					.. "column at full size is taller than the screen's height less margin, then small enough to "
					.. "fit in that, but never below tightScale. On a touch screen it's touchMargin instead of "
					.. "margin, so the columns end above Roblox's move stick and jump button. A piece taken out "
					.. "of its column (its detach, with no parent) has a UIScale of its own by the same rule, "
					.. "from its own height.",
			},
			PayBreakdown = {
				elements = { "PayBreakdown" },
				margin = 24,
				note = "The smallest of 1, (screen height - margin) / its height and (screen width - margin) / "
					.. "its width.",
			},
			LevelsPanel = {
				elements = { "LevelsPanel" },
				margin = 24,
				touchMargin = 24,
				scale = 1,
				note = "The smallest of `scale`, (screen height - margin) / its height and (screen width - "
					.. "margin) / its width, so it only ever shrinks. On a touch screen the height margin is "
					.. "touchMargin, the same 24 as margin: a panel in the middle of the screen is already clear "
					.. "of Roblox's move stick and jump button in the bottom corners, so it takes no more "
					.. "height than the pay breakdown does.",
			},
			ContractsPanel = {
				elements = { "ContractsPanel" },
				margin = 24,
				touchMargin = 24,
				scale = 1,
				note = "The same rule as the Levels panel's: the smallest of `scale`, (screen height - margin) / "
					.. "its height and (screen width - margin) / its width, so it only ever shrinks. On a touch "
					.. "screen the height margin is touchMargin, the same 24 as margin, for the same reason: it's "
					.. "in the middle of the screen, clear of Roblox's move stick and jump button.",
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
		size = { 0, 250, 0, 0 },
		autoSize = "Y",
		list = { direction = "Vertical", padding = 18, align = "Left" },
		typical = { 250, 416 },
		note = "The money panel, the menu buttons, Grandma's goal and the contracts chip stacked down the "
			.. "left, so they can't run into each other on a short screen, far enough apart that the panels "
			.. "are clear of the menu buttons on a phone. Its UIScale shrinks it to fit "
			.. "(__screen.scaling.Columns). Each of them can be taken out of it (their detach) and put "
			.. "anywhere on the screen: on a touch screen Grandma's goal is, away from your thumb on the move "
			.. "stick.",
	},
	MoneyPanel = {
		label = "Money and level panel",
		group = "HUD",
		parent = "LeftColumn",
		detach = "LeftColumn",
		order = 1,
		size = { 0, 250, 0, 72 },
		note = "Always shown during play: your money, then your level and jobs done, then the XP bar. The level "
			.. "line and the XP bar are the Levels button (key L). Low and wide, so it takes little of a short "
			.. "screen's height.",
	},
	MenuButtons = {
		label = "Menu buttons",
		group = "HUD",
		parent = "LeftColumn",
		detach = "LeftColumn",
		order = 2,
		size = { 0, 150, 0, 0 },
		autoSize = "Y",
		list = { direction = "Vertical", padding = 12, align = "Left" },
		typical = { 150, 156 },
		note = "The Truck, Guide and Crew buttons, far enough apart to tap one at a time on a phone. With a "
			.. "keyboard each one has its key (T, G, C) and the mouse hint goes under them, which makes it "
			.. "184 px tall.",
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
		detach = "LeftColumn",
		order = 3,
		size = { 0, 220, 0, 0 },
		autoSize = "Y",
		typical = { 220, 86 },
		touch = {
			parent = false,
			anchor = { 0.5, 0 },
			position = { 0.5, 0, 0, 12 },
			hideWhile = { "TutorialBanner", "CrewInvite" },
		},
		note = "Grandma's sticky note with your story goal and how close you are, while you have one. As "
			.. "tall as its words. Under the goal's bar is the goals rail: the next two milestones (the ones "
			.. "nearest to done), each a line of words over a thin bar, until the screen is shorter than "
			.. "__screen.scaling.Columns.fullHeight, where the rail is hidden and NextChip says the next one "
			.. "instead (typical is that short screen, so it has no rail). On a touch screen it's out of the "
			.. "column, at the top in the middle between the HUD's columns, away from your thumb on the move "
			.. "stick, and the toasts start under it. The first-job coach and a crew invite go there too, and "
			.. "it waits while either shows.",
	},
	ContractsChip = {
		label = "Contracts chip",
		group = "Trackers",
		parent = "LeftColumn",
		detach = "LeftColumn",
		order = 4,
		size = { 0, 220, 0, 28 },
		note = "Today's contracts on one line ('Contracts 1/3': how many of the day's three are done), under "
			.. "Grandma's goal, from the moment the server has sent the day's contracts. It shows on every "
			.. "screen, tall or short, and stays up during a job (nothing takes its spot); tapping it opens "
			.. "the contracts panel. Its words shrink to fit the line (to 10 px at the least). When a "
			.. "contract is done its cash lifts off it and a chime rings.",
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
		typical = { 280, 368 },
		note = "Curb appeal, then on a short screen the Next chip, over the job tracker, then the Show what I "
			.. "missed button late in the mowing, down the right. Its UIScale shrinks it to fit like the left "
			.. "column's, toward its top right corner. Typical is during a job on a phone, where curb appeal "
			.. "hides and the chip stays. Each of the four can be taken out of it (their detach) and put "
			.. "anywhere on the screen.",
	},
	CurbAppeal = {
		label = "Curb appeal panel",
		group = "HUD",
		parent = "RightColumn",
		detach = "RightColumn",
		order = 1,
		size = { 0, 220, 0, 78 },
		note = "Your crew's curb appeal out of 100, once there is one. Hidden during a job on a screen "
			.. "shorter than __screen.scaling.Columns.fullHeight, where the job tracker needs the room.",
	},
	NextChip = {
		label = "Next milestone chip",
		group = "Trackers",
		parent = "RightColumn",
		detach = "RightColumn",
		order = 2,
		size = { 0, 220, 0, 28 },
		compactOnly = true,
		note = "The goals rail's next milestone on one line ('Next: Finish 3 jobs 1/3'), under curb appeal, "
			.. "while there is one left. Only on a screen shorter than __screen.scaling.Columns.fullHeight (a "
			.. "phone held sideways), where Grandma's goal has no room for the rail's two rows. Nothing takes "
			.. "its spot, so it stays up during a job, when curb appeal hides. Its words shrink to fit the "
			.. "line (to 10 px at the least, so a line over 24 characters drops its 'Next: '), and it gets "
			.. "the DONE stamp and the sparkles when the milestone's reached.",
	},
	JobTracker = {
		label = "Job tracker",
		group = "Trackers",
		parent = "RightColumn",
		detach = "RightColumn",
		order = 3,
		size = { 0, 280, 0, 0 },
		autoSize = "Y",
		typical = { 280, 330 },
		compact = { typical = { 280, 144 } },
		hideWhile = { "DecorButtons" },
		note = "On the art's GoalTracker card, while you have a job: its name, a hint, its to-dos, the timer "
			.. "against par and damage while you work, and a button to call it off. As tall as what's in it. "
			.. "On a screen shorter than __screen.scaling.Columns.fullHeight (a phone) it's laid out small, "
			.. "so the look-at and Snip buttons fit under it: no hint, the timer beside the job's name, each "
			.. "to-do on one line without its bar, and the damage (once there is some) and a small call-off "
			.. "button sharing a row at the bottom. Typical is during a job with two to-dos and the junk; "
			.. "compact's is that on a short screen. It steps aside while you're putting a decoration down on a "
			.. "phone, for the decorating buttons (and curb appeal shows again).",
	},
	MissedButton = {
		label = "Show what I missed button",
		group = "HUD",
		parent = "RightColumn",
		detach = "RightColumn",
		order = 4,
		size = { 0, 280, 0, 44 },
		touch = { size = { 0, 280, 0, 52 } },
		note = "Under the job tracker, once the mowing's percent (how much of what the job requires is cut, "
			.. "not counting the optional grass beside flowers and trees) reaches GameConfig.MissedSpotsFrom "
			.. "(90%) and until the mowing counts as done: lights up all the grass that's left, red, for "
			.. "GameConfig.MissedSpotsSeconds. With a keyboard its key (M) is on it, as on the menu buttons. "
			.. "Taller on a touch screen, to be easy to tap. It's hidden whenever the job tracker is, and "
			.. "unless a job site's lawn near you is drawn as a surface (the simple renderer has nothing to "
			.. "light up, and a lawn far off isn't drawn). Nothing takes its spot.",
	},
	ToolCondition = {
		label = "Tool condition",
		group = "HUD",
		screen = "LawnUI",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -68 },
		size = { 0.9, 0, 0, 36 },
		autoSize = "Y",
		max = { width = 440 },
		typical = { 440, 36 },
		touch = { position = { 0.5, 0, 1, -78 } },
		compact = { position = { 0.5, 0, 1, -66 }, scale = 0.85 },
		note = "What's wrong with the tool in your hands (a chip for each thing), or 'Working on it... 3s' "
			.. "while you work on one. The chips go onto a second line when they don't fit. Above Roblox's "
			.. "hotbar (60 px slots, 48 on a phone), and on a touch screen far enough above it to keep clear of "
			.. "tapping a slot; under the look-at prompt, and a little smaller on a phone to fit between them.",
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
		typical = { 450, 130 },
		touch = { size = { 1, -400, 0, 0 }, scale = 0.85, typical = { 450, 96 }, hideWhile = { "CrewInvite" } },
		compact = { size = { 1, -320, 0, 0 }, scale = 0.7, hideWhile = { "CrewInvite", "HoldRing" } },
		note = "Coaches a new player through their first job, a step at a time, once the intro scene's over "
			.. "and until the job's paid: at the shop, on the way and on the lawn. As tall as its words. The "
			.. "toasts keep below it. On a touch screen its words are shorter and it's narrower, to fit between "
			.. "the HUD's columns (the job tracker's on the right), and smaller, so it stays above the dot. A "
			.. "crew invite goes there too on a touch screen, and it waits while that shows, and on a short "
			.. "screen while you hold to work on a tool (the hold ring would be under it).",
	},
	CarryHint = {
		label = "Carry hint",
		group = "Prompts",
		screen = "LawnUI",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -20 },
		size = { 0.9, 0, 0, 0 },
		autoSize = "Y",
		min = { width = 240 },
		max = { width = 460 },
		touch = { size = { 1, -360, 0, 0 } },
		compact = { size = { 1, -372, 0, 0 }, scale = 0.85 },
		typical = { 304, 78 },
		hideWhile = { "ToolCondition" },
		note = "What to do with the tool you're carrying or driving at your business, along the bottom under "
			.. "the look-at prompt. On a touch screen it's 360 px narrower than the screen, to stay between "
			.. "Roblox's move stick and jump button, and on a short screen a little smaller, under the look-at prompt "
			.. "and clear of the Snip button. As tall as its words. A tool you can use comes out of "
			.. "storage in your hands, for your own lawn, so it can have something wrong with it, or be worked "
			.. "on: the tool condition goes in the same spot then, and this waits while it shows.",
	},
	InteractPrompt = {
		label = "Look-at prompt",
		group = "Prompts",
		screen = "Interact",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0.5, 42 },
		size = { 0, 440, 0, 0 },
		autoSize = "Y",
		typical = { 440, 46 },
		touch = { scale = 0.85 },
		note = "Under the dot, clear of the hold ring, while it's on something you can use: a 46 px pill "
			.. "for each thing you can do (6 px apart), red with the reason when it won't work. With a "
			.. "keyboard there's a second pill for R when there's a second thing to do. On a touch screen it "
			.. "only shows when the thing has a name, since the button says what it does, and it's a little "
			.. "smaller, so the tool condition fits under it.",
	},
	DecorPrompt = {
		label = "Decorating prompt",
		group = "Prompts",
		screen = "Decorating",
		anchor = { 0.5, 0 },
		position = { 0.5, 0, 0.5, 42 },
		size = { 0, 440, 0, 0 },
		autoSize = "Y",
		typical = { 440, 46 },
		touch = { scale = 0.85 },
		note = "Under the dot, like the look-at prompt, while you're putting a decoration down: its name, "
			.. "red with why it can't go there, and with a keyboard or gamepad a second pill with the keys "
			.. "(98 px tall then). A little smaller on a touch screen, like the look-at prompt.",
	},

	-- Phone buttons --------------------------------------------------------------------------------

	InteractButton = {
		label = "Look-at button",
		group = "Phone buttons",
		screen = "Interact",
		anchor = { 1, 0.5 },
		position = { 1, -24, 0.55, 0 },
		size = { 0, 110, 0, 110 },
		touch = { anchor = { 1, 1 }, position = { 1, -75, 0.715, 0 }, scale = 0.7 },
		compact = { position = { 1, -75, 0.7, 0 }, scale = 0.6 },
		device = "touch",
		note = "The big round button that does what E does, while the dot's on something you can use, greyed "
			.. "out when it won't work. Its glyph is inside and its words go under it (28 px more, 20 px past "
			.. "each side). On a touch screen it's smaller and low on the right, its words just above Roblox's "
			.. "jump button, clear of a phone's notch, and far enough under the HUD's right column (the job "
			.. "tracker's call-off button) not to be tapped by mistake; smaller still on a short screen.",
	},
	InteractSecondButton = {
		label = "Look-at second button",
		group = "Phone buttons",
		screen = "Interact",
		anchor = { 1, 1 },
		position = { 1, -24, 0.55, -66 },
		size = { 0, 110, 0, 44 },
		touch = { anchor = { 1, 1 }, position = { 1, -170, 0.715, 0 }, scale = 0.6 },
		compact = { position = { 1, -160, 0.7, 0 }, scale = 0.55 },
		device = "touch",
		note = "What R does, when the thing you're looking at has a second thing to do (take one tool out of "
			.. "the bucket, the building's machines, the mailbox). Over the round button, or on a touch "
			.. "screen just left of it, where the Snip button goes (which waits while this shows).",
	},
	SnipButton = {
		label = "Snip button",
		group = "Phone buttons",
		screen = "LawnUI",
		anchor = { 1, 0.5 },
		position = { 1, -146, 0.55, 0 },
		size = { 0, 96, 0, 96 },
		touch = { anchor = { 1, 1 }, position = { 1, -170, 0.715, -17 }, scale = 0.7 },
		compact = { position = { 1, -155, 0.7, -17 }, scale = 0.6 },
		hideWhile = { "InteractSecondButton" },
		device = "touch",
		note = "While you hold grass shears in first person: tap to snip, hold to keep snipping. Its words go "
			.. "under it (28 px more). Left of the look-at button, level with it. It's on the game's own "
			.. "screen, which starts under Roblox's top bar, so its y is worked out to land where the look-at "
			.. "button's 0.715 (0.7 on a short screen) of the whole screen does. The look-at second button goes "
			.. "in the same spot: holding shears at your business (they work on your own lawn), the dot can be "
			.. "on something with a second thing to do, like your mailbox, and this waits while that shows.",
	},
	DecorButtons = {
		label = "Decorating buttons",
		group = "Phone buttons",
		screen = "Decorating",
		anchor = { 1, 1 },
		position = { 1, -75, 0.69, 0 },
		size = { 0, 232, 0, 116 },
		scale = 0.9,
		compact = { position = { 1, -75, 0.725, 0 }, scale = 0.7 },
		list = { direction = "Vertical", padding = 12, align = "Right" },
		device = "touch",
		note = "While you're putting a decoration down: two rows of two where the look-at button usually is "
			.. "(it's hidden then), above the jump button. The job tracker steps aside meanwhile, so they have "
			.. "the room (its hideWhile). Smaller and a little lower on a short screen, to stay clear of the "
			.. "decorating prompt and the toasts.",
	},
	DecorTopRow = {
		label = "Decorating buttons, top row",
		group = "Phone buttons",
		parent = "DecorButtons",
		order = 1,
		size = { 0, 232, 0, 52 },
		list = { direction = "Horizontal", padding = 12, align = "Right" },
		note = "Send back (for the business's owner) and Put back, over the bottom row.",
	},
	DecorBottomRow = {
		label = "Decorating buttons, bottom row",
		group = "Phone buttons",
		parent = "DecorButtons",
		order = 2,
		size = { 0, 232, 0, 52 },
		list = { direction = "Horizontal", padding = 12, align = "Right" },
		note = "Turn and Place, with Place nearest your thumb.",
	},
	DecorPlaceButton = {
		label = "Place button",
		group = "Phone buttons",
		parent = "DecorBottomRow",
		order = 2,
		size = { 0, 110, 0, 52 },
		note = "Puts the decoration down where it is (E).",
	},
	DecorTurnButton = {
		label = "Turn button",
		group = "Phone buttons",
		parent = "DecorBottomRow",
		order = 1,
		size = { 0, 110, 0, 52 },
		note = "Turns it 15 degrees (R).",
	},
	DecorPutBackButton = {
		label = "Put back button",
		group = "Phone buttons",
		parent = "DecorTopRow",
		order = 2,
		size = { 0, 110, 0, 52 },
		note = "Stops placing it and puts it back (Q).",
	},
	DecorSendBackButton = {
		label = "Send back button",
		group = "Phone buttons",
		parent = "DecorTopRow",
		order = 1,
		size = { 0, 110, 0, 52 },
		note = "Sends it back for part of its price (F). Only for the business's owner: hidden otherwise, "
			.. "and Put back moves over to the right.",
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
		touch = { size = { 0, 320, 0, 200 } },
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
		typical = { 500, 480 },
		note = "After a job until you close it: Job Complete!, what each part paid and the total, then the "
			.. "stars row (three slots, about 50 px, that go gold one by one). As tall as its lines; its "
			.. "UIScale shrinks it to fit the screen (__screen.scaling.PayBreakdown).",
	},
	CrewInvite = {
		label = "Crew invite",
		group = "Popups",
		screen = "LawnUI",
		anchor = { 0.5, 1 },
		position = { 0.5, 0, 1, -110 },
		size = { 0, 360, 0, 90 },
		touch = { anchor = { 0.5, 0 }, position = { 0.5, 0, 0, 12 }, size = { 0, 300, 0, 90 }, scale = 0.8 },
		note = "When someone invites you to their crew, until you answer or it runs out: Join or No thanks. "
			.. "It can come at any time, so it may pass over the HUD for a moment, but not over a button. On a "
			.. "touch screen it's at the top in the middle, clear of the hotbar and the carry hint along the "
			.. "bottom; Grandma's goal and the first-job coach wait while it shows there, and the toasts start "
			.. "under it.",
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
	LevelsPanel = {
		label = "Levels panel",
		group = "Menus",
		screen = "LawnUI",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0, 360, 0, 460 },
		note = "Opened from the XP bar (and L on a keyboard), closed by its Close button or Escape: your level "
			.. "and the XP to the next, the streak line under that ('Streak: Day 3 of 7, next $300'), then "
			.. "what the next five levels pay. Its own window, not one of the menus: it never opens inside "
			.. "the shop computer, and it closes when a job's state changes, a scene starts or you open a "
			.. "menu. Its UIScale shrinks it to fit the screen (__screen.scaling.LevelsPanel).",
	},
	ContractsPanel = {
		label = "Contracts panel",
		group = "Menus",
		screen = "LawnUI",
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0, 0.5, 0 },
		size = { 0, 360, 0, 400 },
		note = "Opened from the contracts chip (and the curb mailbox at the street end of the driveway), "
			.. "closed by its Close button or Escape: today's three contracts (each with how far along it "
			.. "is and what it pays, and a DONE stamp once it's paid), the Bonus Day for doing all three, "
			.. "and the streak line ('Day 3 of 7, next $300'). It's opened by name like the menus "
			.. "(UI.open), but it's a window of its own like the Levels panel: it never opens inside the "
			.. "shop computer, and it closes when a job's state changes, a scene starts or you open a "
			.. "menu. Its UIScale shrinks it to fit the screen (__screen.scaling.ContractsPanel).",
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
		size = { 0.4, 0, 0, 44 },
		compact = { size = { 0.36, 0, 0, 44 } },
		note = "Where and when the scene is ('Maple Grove · First day of summer'), up top in the middle, "
			.. "clear of Roblox's own buttons: a little narrower on a short screen, where they're closer.",
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
		typical = { 240, 634 },
		note = "Shortcuts for testing the story, shown and hidden with K in Studio playtests only. Its buttons "
			.. "are laid out for its width.",
	},
}
