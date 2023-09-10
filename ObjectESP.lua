local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera

local DrawingLibrary = {ObjectESP = {}}
local FrameRate = 1/30

if not RESPContainer then
	getgenv().RESPContainer = InsertService:LoadLocalAsset("rbxassetid://11313408229")
	RESPContainer.Parent = CoreGui
end

local function NewThreadLoop(Wait,Function)
	task.spawn(function()
		while true do
			local Delta = task.wait(Wait)
			local Success,Error = pcall(Function,Delta)
			if not Success then warn(Error) end
		end
	end)
end

local function GetFlag(F,F1,F2)
	return F[F1..F2]
end
local function GetDistance(Position)
	return (Position - Camera.CFrame.Position).Magnitude
end
local function CheckDistance(Enabled,P1,P2)
	if not Enabled then return true end
	return P1 >= P2
end
local function WorldToScreen(WorldPosition)
	local Screen,OnScreen = Camera:WorldToViewportPoint(WorldPosition)
	return UDim2.fromOffset(Screen.X,Screen.Y),OnScreen,Screen.Z
end

function DrawingLibrary.AddObject(Self,Object,ObjectName,ObjectPosition,GlobalFlag,Flag,Flags)
	if Self.ObjectESP[Object] then return end

	Self.ObjectESP[Object] = {
		Target = {Name = ObjectName,Position = ObjectPosition},
		Flag = Flag,GlobalFlag = GlobalFlag,Flags = Flags,
		IsBasePart = typeof(ObjectPosition) ~= "Vector3",

		Name = RESPContainer.Storage.ObjectName:Clone()
	}

	Self.ObjectESP[Object].Name.Parent = RESPContainer
	if Self.ObjectESP[Object].IsBasePart then
		Self.ObjectESP[Object].Target.RootPart = ObjectPosition
		Self.ObjectESP[Object].Target.Position = ObjectPosition.Position
	end
end
function DrawingLibrary.RemoveObject(Self,Target)
	local ESP = Self.ObjectESP[Target]
	if not ESP then return end
	ESP.Name:Destroy()

	Self.ObjectESP[Target] = nil
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera
end)

NewThreadLoop(FrameRate,function()
	for Object,ESP in pairs(DrawingLibrary.ObjectESP) do
		if not GetFlag(ESP.Flags,ESP.GlobalFlag,"/Enabled")
		or not GetFlag(ESP.Flags,ESP.Flag,"/Enabled") then
			ESP.Name.Visible = false
			continue
		end

		ESP.Target.Position = ESP.IsBasePart and ESP.Target.RootPart.Position or ESP.Target.Position
		ESP.Target.ScreenPosition,ESP.Target.OnScreen = WorldToScreen(ESP.Target.Position)
		ESP.Target.Distance = GetDistance(ESP.Target.Position)

		ESP.Target.InTheRange = CheckDistance(
			GetFlag(ESP.Flags,ESP.GlobalFlag,"/DistanceCheck"),
			GetFlag(ESP.Flags,ESP.GlobalFlag,"/Distance"),
			ESP.Target.Distance
		)

		ESP.Name.Visible = ESP.Target.OnScreen and ESP.Target.InTheRange or false

		if ESP.Name.Visible then
			local Color = GetFlag(ESP.Flags,ESP.Flag,"/Color")
			ESP.Name.TextStrokeTransparency = math.max(Color[4],0.5)
			ESP.Name.TextTransparency = Color[4]
			ESP.Name.TextColor3 = Color[6]

			ESP.Name.Position = ESP.Target.ScreenPosition
			ESP.Name.Text = string.format("%s\n%i stud(s)",ESP.Target.Name,ESP.Target.Distance)
		end
	end
end)

return DrawingLibrary
