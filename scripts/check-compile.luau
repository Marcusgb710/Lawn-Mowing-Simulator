-- Checks that every script the game runs compiles, outside Roblox:
--   lune run scripts/check-compile
-- The other checks lint (selene), format (stylua) or bundle (rojo) the code, and none of those
-- compile it, so a script that Roblox can't load at all would pass them. This compiles every .luau
-- and .lua file under src with Luau's own compiler and prints each one that fails, with why.
-- Luau gives one function at most 200 locals that need a register (LIMIT; a local the compiler folds
-- to a constant, like `local GAP = 12`, takes none), and a module's top level is one function, so a
-- big controller stops loading the day it gets one local too many. So this also measures how many
-- locals each file's top level could still take, and says how close the fullest file is, so the wall
-- shows before it is hit. Exits with an error if any file fails to compile.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = "src"
local LIMIT = 200

local function compiles(source: string): (boolean, string?)
	local ok, err = pcall(luau.compile, source)
	if ok then
		return true, nil
	end
	-- The compiler's message is the error's first line; the rest is Lune's stack.
	return false, string.match(tostring(err), "syntax error: ([^\n]*)") or tostring(err)
end

-- How many more locals the file's top level could take: `extra` locals that each need a register (a
-- new table each, so none folds away) are put in at the top level, after everything else and before
-- the module's closing `return` when it has one, and the most that still compiles is the room left.
local function room(source: string): number
	local lines = string.split(source, "\n")
	local at = #lines + 1
	for index = #lines, 1, -1 do
		if string.match(lines[index], "^return[%s%(]") or lines[index] == "return" then
			at = index
			break
		end
	end
	local before = table.concat(lines, "\n", 1, at - 1)
	local after = table.concat(lines, "\n", at)
	local function fits(extra: number): boolean
		local probe = {}
		for index = 1, extra do
			probe[index] = `local __compileProbe{index} = \{}`
		end
		return (compiles(before .. "\n" .. table.concat(probe, "\n") .. "\n" .. after))
	end
	-- The most that fits, between 0 (it compiles as it is) and LIMIT.
	local low, high = 0, LIMIT
	while low < high do
		local middle = math.ceil((low + high) / 2)
		if fits(middle) then
			low = middle
		else
			high = middle - 1
		end
	end
	return low
end

local failures = 0
local files = 0
local fullest: string? = nil
local fullestRoom = math.huge

local function walk(dir: string)
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") or string.match(name, "%.lua$") then
			files += 1
			local source = fs.readFile(path)
			local ok, message = compiles(source)
			if ok then
				local left = room(source)
				if left < fullestRoom then
					fullest, fullestRoom = path, left
				end
			else
				failures += 1
				print(`FAIL {path}: {message}`)
			end
		end
	end
end

walk(ROOT)

if fullest then
	print(
		`The fullest top level that compiles is {fullest}: {LIMIT - fullestRoom} of Luau's {LIMIT} locals, room for {fullestRoom} more.`
	)
end
if failures > 0 then
	print(`{failures} of {files} files under {ROOT} don't compile.`)
	process.exit(1)
end
print(`All {files} files under {ROOT} compile.`)
