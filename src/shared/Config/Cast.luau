-- The story's nine people (docs/superpowers/specs/2026-10-28-model-overhaul-design.md, section 4),
-- each one a Roblox avatar dressed from the catalog. CastService (on the server) reads this when
-- it starts and builds every one as an R15 rig with Players:CreateHumanoidModelFromDescription,
-- named after its key here (NPC_Gloria and so on). Who each person is: alphainstructions/
-- instructions37.md. Their names and lines are in Config/Story.luau (Story.Cast).
--
-- Every id is a free catalog item that is not limited, so any player's server can use it.
-- scripts/cast-check.py asks the catalog about all of them (it needs the network, so it is
-- not part of the Lune checks) and scripts/check-story.luau checks the shape of this file.
-- Roblox's own items are preferred. Anything from another creator has to be free and not a
-- limited-quantity collectible, which is why June and Judge Marigold have no hat: every straw
-- hat and flower hat that is free is a collectible, and the ones by Roblox are caps and visors.
--
-- This file has no Roblox requires, so scripts/check-story.luau can test it with Lune. Lune has
-- no Color3 or Vector3, so colors are { r = 0-255, g = 0-255, b = 0-255 } tables and seats are
-- { x, y, z } tables here. CastService turns them into Color3.fromRGB and Vector3 when it builds
-- a rig.
--
-- A person:
--   name       what the Story calls them (Story.Cast[...].name)
--   body       skin color, and the HumanoidDescription scales: height and width and head between
--              0.9 and 1.1, `proportion` between 0 (Roblox's classic blocky build) and 1
--   hair       a hair accessory id, and `hairColor` recolours its mesh (the rig builder takes the
--              texture off and sets the color), since the free catalog has no grey hair
--   hat        a hat accessory id
--   face       a face id; nil keeps the default face
--   shirt      a classic shirt id (asset type 11), `pants` a classic pants id (type 12)
--   tshirt     a T-shirt graphic id (type 2) drawn over the shirt; 0 until the image is uploaded
--   layered    layered clothing (types 64 to 72), worn over the classic clothes, innermost
--              first by `order`. `type` is the Enum.AccessoryType name: TShirt, Shirt, Pants,
--              Jacket, Sweater, Shorts, DressSkirt, LeftShoe or RightShoe
--   pose       a key of Cast.Poses, played in a loop once the rig is placed
--   seat       only for someone sitting: where the rig's invisible Root part goes, in the chair's
--              frame (the chair's origin is on its floor and its seat is 1.83 up). Root sits 0.5
--              above the feet when standing. It is an estimate for a 0.9-scale rig, to be tuned in
--              Studio when June is placed on her rocker

export type Rgb = { r: number, g: number, b: number }
export type Seat = { x: number, y: number, z: number }
export type Person = {
	name: string,
	body: { skin: Rgb, heightScale: number, widthScale: number, headScale: number, proportion: number },
	hair: number?,
	hairColor: Rgb?,
	hat: number?,
	face: number?,
	shirt: number?,
	pants: number?,
	tshirt: number?,
	layered: { { id: number, type: string, order: number } },
	pose: string,
	seat: Seat?,
}

local Cast = {}

-- Roblox's own animations, so nothing has to be uploaded. They are all looping poses.
-- Inspect and Note have no animation of their own: Inspect points and Note stands at ease.
local IDLE = { id = "rbxassetid://507766666", looped = true }
local POINT = { id = "rbxassetid://507770453", looped = true }
Cast.Poses = {
	Idle = IDLE,
	Walk = { id = "rbxassetid://507777826", looped = true },
	Sit = { id = "rbxassetid://2506281703", looped = true },
	Wave = { id = "rbxassetid://507770239", looped = true },
	Point = POINT,
	Inspect = POINT,
	Note = IDLE,
}

local function rgb(r: number, g: number, b: number): Rgb
	return { r = r, g = g, b = b }
end

-- TurfKing's purple and gold is not in the free catalog: the only top with any purple is Purple
-- and Teal Top, which is mostly teal. So Chad and Sam wear it as a stand-in, with `tshirt = 0`
-- until the crown on purple is uploaded as a T-shirt graphic and its id goes there. Every id is
-- written out in full (not named in a local) because scripts/cast-check.py reads them as text.
Cast.People = {
	-- Gloria Pemberton: tall and immaculate, a lavender cardigan set, her hair done in silver.
	NPC_Gloria = {
		name = "Gloria Pemberton",
		body = { skin = rgb(234, 184, 150), heightScale = 1.05, widthScale = 1, headScale = 1, proportion = 0 },
		hair = 376526888, -- Straight Blonde Hair
		hairColor = rgb(205, 205, 205),
		shirt = 398634295, -- Pastel Starburst Top with Gray Jacket
		pants = 398634487, -- Beautiful You Jeans
		layered = {},
		pose = "Idle",
	},

	-- Chad, TurfKing's local boss: spiked blonde hair, a cap, TurfKing's top, shorts and white shoes.
	NPC_Chad = {
		name = "Chad",
		body = { skin = rgb(214, 164, 128), heightScale = 1.05, widthScale = 1, headScale = 1, proportion = 0 },
		hair = 376524487, -- Blonde Spiked Hair
		hat = 607702162, -- Roblox Baseball Cap
		shirt = 4047886060, -- Purple and Teal Top
		tshirt = 0, -- the TurfKing crown, once it is uploaded
		pants = 382537950, -- Jean Shorts with White Shoes
		layered = {},
		pose = "Idle",
	},

	-- Edna Alvarez: warm and round, short curly grey hair, a bright top and a white summer skirt,
	-- waving.
	NPC_Edna = {
		name = "Edna Alvarez",
		body = { skin = rgb(204, 142, 105), heightScale = 0.95, widthScale = 1.1, headScale = 1, proportion = 0 },
		hair = 9244137452, -- Short Curls - Cool Brown
		hairColor = rgb(178, 178, 184),
		shirt = 398635081, -- Blue Plaid Shirt
		layered = {
			{ id = 9240776381, type = "DressSkirt", order = 1 }, -- Long Ruffle Skirt - White
		},
		pose = "Wave",
	},

	-- Grandma June Hollis: small and sharp, silver hair in a knot, a white blouse under a beige
	-- cardigan and dark green gardening trousers. Sitting in her rocker, or standing with the shears.
	NPC_June_Sitting = {
		name = "Grandma June",
		body = { skin = rgb(232, 188, 160), heightScale = 0.9, widthScale = 0.9, headScale = 1, proportion = 0 },
		hair = 9244060144, -- Top Knot - Brown
		hairColor = rgb(200, 200, 205),
		pants = 144076760, -- Dark Green Jeans
		layered = {
			{ id = 9240752338, type = "Shirt", order = 1 }, -- Tie-Front Top - White
			{ id = 6984769289, type = "Sweater", order = 2 }, -- Knit Sweater - Beige
		},
		pose = "Sit",
		seat = { x = 0, y = 1, z = 0.1 },
	},
	NPC_June_Standing = {
		name = "Grandma June",
		body = { skin = rgb(232, 188, 160), heightScale = 0.9, widthScale = 0.9, headScale = 1, proportion = 0 },
		hair = 9244060144,
		hairColor = rgb(200, 200, 205),
		pants = 144076760,
		layered = {
			{ id = 9240752338, type = "Shirt", order = 1 },
			{ id = 6984769289, type = "Sweater", order = 2 },
		},
		pose = "Idle",
	},

	-- Sam Pemberton, about 17: messy short hair. Out in TurfKing's top and work shorts, then in a
	-- green jersey and jeans after quitting.
	NPC_Sam_TurfKing = {
		name = "Sam Pemberton",
		body = { skin = rgb(238, 194, 160), heightScale = 0.95, widthScale = 0.95, headScale = 1, proportion = 0 },
		hair = 9243976603, -- Short Fringe - Brown
		hat = 607700713, -- Roblox Logo Visor
		shirt = 4047886060, -- Purple and Teal Top
		tshirt = 0,
		layered = {
			{ id = 9174391966, type = "Shorts", order = 1 }, -- Bermuda Shorts - Black
		},
		pose = "Idle",
	},
	NPC_Sam_Casual = {
		name = "Sam Pemberton",
		body = { skin = rgb(238, 194, 160), heightScale = 0.95, widthScale = 0.95, headScale = 1, proportion = 0 },
		hair = 9243976603,
		shirt = 382538059, -- Green Jersey
		pants = 382538503, -- Black Jeans with Sneakers
		layered = {},
		pose = "Idle",
	},

	-- The Best Yard judges, with clipboards. Judge Pruitt is in a grey business coat over a grey
	-- tee, Judge Marigold in a salmon one over a white blouse and skirt.
	NPC_Judge1 = {
		name = "Judge Pruitt",
		body = { skin = rgb(196, 150, 112), heightScale = 1, widthScale = 1, headScale = 1, proportion = 0 },
		hair = 7193419595, -- Side Part - Brown
		hairColor = rgb(168, 168, 168),
		pants = 382537569, -- Black Jeans
		layered = {
			{ id = 9112474888, type = "TShirt", order = 1 }, -- Basic T-Shirt - Gray
			{ id = 8516638468, type = "Jacket", order = 2 }, -- Business Coat - Gray
		},
		pose = "Note",
	},
	NPC_Judge2 = {
		name = "Judge Marigold",
		body = { skin = rgb(222, 170, 136), heightScale = 1, widthScale = 1, headScale = 1, proportion = 0 },
		hair = 7193449810, -- Straight Bangs - Brown
		hairColor = rgb(96, 58, 38),
		layered = {
			{ id = 9240752338, type = "Shirt", order = 1 }, -- Tie-Front Top - White
			{ id = 8516655378, type = "Jacket", order = 2 }, -- Business Coat - Salmon
			{ id = 9240776381, type = "DressSkirt", order = 3 }, -- Long Ruffle Skirt - White
		},
		pose = "Inspect",
	},
}

-- An optional id as the description takes it: only an id above 0 is an item, so nil and 0 both
-- mean nothing (a number for the clothes and the face, a string for the hair and the hat).
local function idNumber(id: number?): number
	return if id and id > 0 then id else 0
end

local function idString(id: number?): string
	return if id and id > 0 then tostring(id) else ""
end

-- What to hand a HumanoidDescription for this person: its property names with strings and
-- numbers, so nothing in it needs Roblox (an id is "" or 0 for nothing). Colors and layered
-- clothing aren't here: CastService sets them from `person.body.skin`, `person.hairColor` and
-- `person.layered` once the description exists.
function Cast.describe(person: Person): { [string]: any }
	return {
		HairAccessory = idString(person.hair),
		HatAccessory = idString(person.hat),
		Face = idNumber(person.face),
		Shirt = idNumber(person.shirt),
		Pants = idNumber(person.pants),
		GraphicTShirt = idNumber(person.tshirt),
		HeightScale = person.body.heightScale,
		WidthScale = person.body.widthScale,
		HeadScale = person.body.headScale,
		ProportionScale = person.body.proportion,
	}
end

return Cast
