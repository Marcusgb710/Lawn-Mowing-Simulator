-- Run in Studio's Command Bar with ONLY the newly imported library selected.
-- Prepares asset models; does not add runtime scripts or publish anything.
local Selection = game:GetService("Selection")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local manifest = HttpService:JSONDecode(
	[==[{"meters_per_stud":0.28,"assets":[{"name":"House","folder":"Props","triangles":3216,"size_studs":[30.29872689928327,17.779999119894843,18.440001351492743],"grip_studs":null,"bounds_blender_m":{"min":[-4.241821765899658,-2.503200054168701,0.0],"max":[4.241821765899658,2.6600000858306885,4.978399753570557]}},{"name":"Shed","folder":"Buildings","triangles":1872,"size_studs":[12.30003067425319,12.879999194826397,10.430000509534562],"grip_studs":null,"bounds_blender_m":{"min":[-1.7220042943954468,-1.4531999826431274,0.0],"max":[1.7220042943954468,1.4672000408172607,3.6063997745513916]}},{"name":"Garage","folder":"Buildings","triangles":1784,"size_studs":[26.299999441419327,14.199999400547572,20.379999705723353],"grip_studs":null,"bounds_blender_m":{"min":[-3.681999921798706,-2.8420000076293945,0.0],"max":[3.681999921798706,2.8643999099731445,3.9759998321533203]}},{"name":"SmallOffice","folder":"Buildings","triangles":2748,"size_studs":[36.29999841962542,16.000000068119594,24.50479779924665],"grip_studs":null,"bounds_blender_m":{"min":[-5.081999778747559,-3.4019999504089355,-7.450580596923828e-09],"max":[5.081999778747559,3.459343671798706,4.480000019073486]}},{"name":"FlowerPatch","folder":"Props","triangles":1260,"size_studs":[3.4500000732285634,0.8702915694032396,3.4500000732285634],"grip_studs":null,"bounds_blender_m":{"min":[-0.4830000102519989,-0.4830000102519989,0.0],"max":[0.4830000102519989,0.4830000102519989,0.2436816394329071]}},{"name":"GardenGnome","folder":"Props","triangles":852,"size_studs":[0.8559520755495343,2.3999999676431925,0.8350000317607607],"grip_studs":null,"bounds_blender_m":{"min":[-0.11983329057693481,-0.11060000211000443,3.725290298461914e-09],"max":[0.11983329057693481,0.12320000678300858,0.671999990940094]}},{"name":"RustyPickup","folder":"Trucks","triangles":9032,"size_studs":[7.095000147819518,6.635000024523054,16.177827971322195],"grip_studs":null,"bounds_blender_m":{"min":[-0.9933000206947327,-2.2897918224334717,-0.0098000168800354],"max":[0.9933000206947327,2.240000009536743,1.8480000495910645]},"bed_area":{"position_studs":[0,2.73,3.75],"size_studs":[6,0.2,7.6],"slots":3}},{"name":"WorkPickup","folder":"Trucks","triangles":9056,"size_studs":[7.095000147819518,6.835000004087175,16.650000640324183],"grip_studs":null,"bounds_blender_m":{"min":[-0.9933000206947327,-2.3520002365112305,-0.0098000168800354],"max":[0.9933000206947327,2.309999942779541,1.903999924659729]},"bed_area":{"position_studs":[0,2.73,4.0],"size_studs":[6,0.2,7.6],"slots":3}},{"name":"HeavyDutyPickup","folder":"Trucks","triangles":8924,"size_studs":[8.094999619892665,7.534999506814138,18.150000912802557],"grip_studs":null,"bounds_blender_m":{"min":[-1.1332999467849731,-2.562000274658203,-0.0098000168800354],"max":[1.1332999467849731,2.5199999809265137,2.0999999046325684]},"bed_area":{"position_studs":[0,2.73,4.75],"size_studs":[6,0.2,7.6],"slots":3}},{"name":"LandscapingTruck","folder":"Trucks","triangles":8696,"size_studs":[7.494999681200299,9.034999779292514,18.150000912802557],"grip_studs":null,"bounds_blender_m":{"min":[-1.049299955368042,-2.562000274658203,-0.0098000168800354],"max":[1.049299955368042,2.5199999809265137,2.5199999809265137]},"bed_area":{"position_studs":[0,2.73,4.75],"size_studs":[6,0.2,7.6],"slots":3}},{"name":"UtilityTrailer","folder":"Trailers","triangles":2124,"size_studs":[7.099999700273786,3.0150000538144788,12.410000392368861],"grip_studs":null,"bounds_blender_m":{"min":[-0.9939999580383301,-1.5848000049591064,0.0],"max":[0.9939999580383301,1.8900001049041748,0.8442000150680542]},"bed_area":{"position_studs":[0,1.775,1],"size_studs":[6,0.2,8],"slots":1}},{"name":"LandscapeTrailer","folder":"Trailers","triangles":2436,"size_studs":[7.300000531332833,7.499999659402029,15.140942164829797],"grip_studs":null,"bounds_blender_m":{"min":[-1.0220000743865967,-2.209463596343994,0.0],"max":[1.0220000743865967,2.0299999713897705,2.0999999046325684]},"bed_area":{"position_studs":[0,1.775,1],"size_studs":[6,0.2,10],"slots":2}},{"name":"ReelMower","folder":"Tools","triangles":1396,"size_studs":[2.5499999523162837,4.309999942779541,4.609999912125724],"grip_studs":[0,4.2,0],"bounds_blender_m":{"min":[-0.3569999933242798,-0.03080001473426819,0.0],"max":[0.3569999933242798,1.2599999904632568,1.2067999839782715]}},{"name":"SelfPropelledMower","folder":"Tools","triangles":7312,"size_studs":[2.835285663604736,4.285000051770891,5.242250221116202],"grip_studs":[0,4.2,0],"bounds_blender_m":{"min":[-0.3932499885559082,-0.058713220059871674,0.0],"max":[0.40062999725341797,1.4091168642044067,1.1998000144958496]}},{"name":"WideRake","folder":"Tools","triangles":272,"size_studs":[2.628571433680398,4.822509629385811,0.6797875676836286],"grip_studs":[0,3.6,0],"bounds_blender_m":{"min":[-0.36800000071525574,-0.09517024457454681,0.0],"max":[0.36800000071525574,0.0951702743768692,1.3503026962280273]}},{"name":"HalfMoonEdger","folder":"Tools","triangles":604,"size_studs":[1.1899999209812708,4.400000401905604,0.29999999595539906],"grip_studs":[0,4.3,0],"bounds_blender_m":{"min":[-0.16659998893737793,-0.041999999433755875,0.0],"max":[0.16659998893737793,0.041999999433755875,1.2320001125335693]}},{"name":"GardenShears","folder":"Tools","triangles":320,"size_studs":[0.4941005259752273,1.2988750423703874,1.6515220914568218],"grip_studs":[0,0,0],"bounds_blender_m":{"min":[-0.06917407363653183,-0.12334734946489334,-0.29642626643180847],"max":[0.06917407363653183,0.3390788435935974,0.06725874543190002]}},{"name":"Brushcutter","folder":"Tools","triangles":2112,"size_studs":[2.479242214134761,3.919501389775957,6.428571684019905],"grip_studs":[1.15,4,-0.1],"bounds_blender_m":{"min":[-0.3470939099788666,-0.33500003814697266,0.04809999838471413],"max":[0.3470939099788666,1.465000033378601,1.145560383796692]}},{"name":"ElectricEdger","folder":"Tools","triangles":2084,"size_studs":[1.1700000081743511,4.735000218663896,5.220632893698555],"grip_studs":[0,4.2,0],"bounds_blender_m":{"min":[-0.24359998106956482,-0.3697771728038788,0.07420000433921814],"max":[0.08400001376867294,1.0920000076293945,1.4000000953674316]}},{"name":"GasStickEdger","folder":"Tools","triangles":2024,"size_studs":[1.1700000081743511,4.735000218663896,5.050000122615269],"grip_studs":[0,4.2,0],"bounds_blender_m":{"min":[-0.24359998106956482,-0.32199999690055847,0.07420000433921814],"max":[0.08400001376867294,1.0920000076293945,1.4000000953674316]}},{"name":"WalkBehindEdger","folder":"Tools","triangles":6096,"size_studs":[2.210000157356262,4.34499979019165,4.109999963215419],"grip_studs":[0,4.2,0],"bounds_blender_m":{"min":[-0.2757999897003174,-0.03080001473426819,-0.009800001978874207],"max":[0.34300002455711365,1.1200000047683716,1.2067999839782715]}},{"name":"LeafBlower","folder":"Tools","triangles":608,"size_studs":[1.2180817978722707,3.1821291361536295,4.03837263584137],"grip_studs":[0,4.3,0],"bounds_blender_m":{"min":[-0.14646290242671967,-0.21000000834465027,0.41520386934280396],"max":[0.19460000097751617,0.9207443594932556,1.3062000274658203]}},{"name":"BackpackBlower","folder":"Tools","triangles":840,"size_studs":[2.506348064967564,2.9171290142195563,6.188373054776872],"grip_studs":[0,4.3,0],"bounds_blender_m":{"min":[-0.5180000066757202,-0.8119999766349792,0.41520386934280396],"max":[0.18377748131752014,0.9207444787025452,1.2319999933242798]}},{"name":"HandHedgeShears","folder":"Tools","triangles":416,"size_studs":[0.7580701261758803,0.42266026139259333,2.845793110983712],"grip_studs":[0.26,0.3,0],"bounds_blender_m":{"min":[-0.10612981766462326,-0.08831163495779037,0.053234249353408813],"max":[0.10612981766462326,0.7085104584693909,0.17157912254333496]}},{"name":"ElectricHedgeTrimmer","folder":"Tools","triangles":684,"size_studs":[1.0999999940395355,1.0030969977378845,3.7228933402470177],"grip_studs":[0,0.4,0],"bounds_blender_m":{"min":[-0.15399999916553497,-0.1604101061820984,0.03413282334804535],"max":[0.15399999916553497,0.8819999694824219,0.3149999976158142]}},{"name":"CordlessHedgeTrimmer","folder":"Tools","triangles":756,"size_studs":[1.0999999940395355,1.0999999940395355,4.424999867166791],"grip_studs":[0,0.4,0],"bounds_blender_m":{"min":[-0.15399999916553497,-0.16099998354911804,0.006999999284744263],"max":[0.15399999916553497,1.0779999494552612,0.3149999976158142]}},{"name":"GasHedgeTrimmer","folder":"Tools","triangles":792,"size_studs":[1.0999999940395355,1.0000000042574746,4.699999945504325],"grip_studs":[0,0.4,0],"bounds_blender_m":{"min":[-0.15399999916553497,-0.06999999284744263,0.03500000387430191],"max":[0.15399999916553497,1.246000051498413,0.3149999976158142]}}]}]==]
)
local candidates = {}
for _, selected in Selection:Get() do
	if selected:IsA("Model") then
		candidates[selected.Name] = selected
	end
	for _, child in selected:GetDescendants() do
		if child:IsA("Model") then
			candidates[child.Name] = child
		end
	end
end
local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
	error("Open the Lawn Mowing game with its Assets folder first.")
end
local function parts(model)
	local result = {}
	for _, child in model:GetDescendants() do
		if child:IsA("LuaSourceContainer") then
			error("Unexpected script in imported model: " .. model.Name)
		end
		if child:IsA("BasePart") then
			table.insert(result, child)
		end
	end
	return result
end
local function bounds(list)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in list do
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local point = part.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z)
					low = low:Min(point)
					high = high:Max(point)
				end
			end
		end
	end
	return low, high
end
local function vector(values)
	return Vector3.new(values[1], values[2], values[3])
end
local function marker(name, size, position)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end
ChangeHistoryService:SetWaypoint("Before revised model preparation")
local prepared = 0
for _, entry in manifest.assets do
	local folder = assets:FindFirstChild(entry.folder)
	local model = candidates[entry.name]
	if folder and folder:FindFirstChild(entry.name) then
		warn("Left existing asset untouched:", entry.folder .. "/" .. entry.name)
		continue
	end
	if not folder or not model then
		warn("Missing folder or selected import:", entry.name)
		continue
	end
	local list = parts(model)
	if #list == 0 then
		warn("No imported mesh parts:", entry.name)
		continue
	end
	local low, high = bounds(list)
	local size, target = high - low, vector(entry.size_studs)
	local ratio = math.max(target.X, target.Y, target.Z) / math.max(size.X, size.Y, size.Z)
	if (size * ratio - target).Magnitude > 0.35 then
		warn("Check import orientation before preparing:", entry.name, "actual", size * ratio, "expected", target)
		continue
	end
	model:ScaleTo(model:GetScale() * ratio)
	low, high = bounds(list)
	local source = entry.bounds_blender_m
	local targetLow = Vector3.new(source.min[1], source.min[3], -source.max[2]) / manifest.meters_per_stud
	model:PivotTo(model:GetPivot() + targetLow - low)
	for _, part in list do
		part.Anchored = true
		part.CanTouch = false
		part.CanQuery = false
		part.CanCollide = entry.grip_studs == nil and entry.folder ~= "Props"
		if part:IsA("MeshPart") then
			part.RenderFidelity = Enum.RenderFidelity.Automatic
		end
		if entry.name == "House" then
			part.CanCollide = true
		end
		if entry.name == "FlowerPatch" and (part.Name == "Flower" or part.Name:match("^Flower%.%d+$")) then
			part.Name = "Flower"
		end
	end
	local primary
	if entry.grip_studs then
		primary = marker("Handle", Vector3.one * 0.4, vector(entry.grip_studs))
	else
		primary = marker("Root", Vector3.one, Vector3.new(0, 0.5, 0))
		primary.PivotOffset = CFrame.new(0, -0.5, 0)
	end
	-- Root/Handle is first, so the game's fallback can find it if Rojo loses PrimaryPart.
	local children = model:GetChildren()
	for _, child in children do
		child.Parent = nil
	end
	primary.Parent = model
	for _, child in children do
		child.Parent = model
	end
	model.PrimaryPart = primary
	if entry.bed_area then
		local bed = entry.bed_area
		local area = marker("BedArea", vector(bed.size_studs), vector(bed.position_studs))
		area:SetAttribute("Slots", bed.slots)
		area.Parent = model
	end
	model.Parent = folder
	prepared += 1
	print("Prepared", entry.folder .. "/" .. entry.name, "triangles", entry.triangles)
end
ChangeHistoryService:SetWaypoint("After revised model preparation")
print(
	"Prepared",
	prepared,
	"new models. Existing assets were left untouched. Save/export after visual and gameplay checks."
)
