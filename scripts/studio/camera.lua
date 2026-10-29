local HttpService = game:GetService("HttpService")
local LOG = {}
local lineup = workspace:FindFirstChild("Lineup")
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Fixed
cam.FieldOfView = 60
local Lighting = game:GetService("Lighting")
for _, e in Lighting:GetChildren() do
	if e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") or e:IsA("SunRaysEffect") then e.Enabled = false end
end
local stops = HttpService:JSONDecode(lineup:GetAttribute("Stops"))
task.wait(2)
for i, s in stops do
	cam.CFrame = CFrame.lookAt(Vector3.new(s[2], s[3], s[4]), Vector3.new(s[5], s[6], s[7]))
	cam.Focus = CFrame.new(s[5], s[6], s[7])
	table.insert(LOG, ("stop %d %s"):format(i, s[1]))
	task.wait(6)
end
pcall(function()
	HttpService:PostAsync("http://127.0.0.1:8765/log", table.concat(LOG, "\n"), Enum.HttpContentType.TextPlain)
end)
