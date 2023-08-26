local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PathMaker = {}

local PMProto = {}
PMProto.__index = PMProto

local WaypointForm = "PathWaypoint.new(Vector3.new(%s, %s, %s), %s, \"%s\")"

local function Pointer(Value)
	return tonumber(string.format("%.3f",Value))
end

local function CheckOriginPart(Self)
	if Self.OriginPart.Parent == nil then
		Self:Clear()
		warn("OriginPart not found, please reassign")
	end
end

function PMProto.MakeBeam(Self,Origin,Position,Color)
	if not Origin or not Position then return end
	if Position.Magnitude == 1 then Position += Origin end
	local Cylinder = Instance.new("Part")

	Cylinder.Name = "Cylinder"
	Cylinder.Anchored = true
	Cylinder.CanTouch = false
	Cylinder.CanQuery = false
	Cylinder.CanCollide = false

	Cylinder.BottomSurface = Enum.SurfaceType.Smooth
	Cylinder.TopSurface = Enum.SurfaceType.Smooth
	Cylinder.Material = Enum.Material.Neon
	Cylinder.Shape = Enum.PartType.Cylinder
	Cylinder.Color = Color3.new(1,0.5,0)
	Cylinder.Transparency = 0.75

	Cylinder.Size = Vector3.new((Origin - Position).Magnitude,0.1,0.1)

	Cylinder.CFrame = CFrame.new(Origin,Position)
	Cylinder.CFrame *= CFrame.new(0,0,-Cylinder.Size.X / 2)
	Cylinder.CFrame *= CFrame.Angles(0,math.rad(90),0)

	Cylinder.Parent = Self.WaypointFolder

	return Cylinder
end

function PMProto.MakePoint(Self,Position,Color)
	if not Position then return end
	local Ball = Instance.new("Part")

	Ball.Name = "Ball"
	Ball.Anchored = true
	Ball.CanTouch = false
	Ball.CanQuery = false
	Ball.CanCollide = false

	Ball.BottomSurface = Enum.SurfaceType.Smooth
	Ball.TopSurface = Enum.SurfaceType.Smooth
	Ball.Material = Enum.Material.Neon
	Ball.Shape = Enum.PartType.Ball
	Ball.Color = Color or Color3.new(1,0.5,0)
	Ball.Transparency = 0.5

	Ball.Size = Vector3.new(0.5,0.5,0.5)
	Ball.CFrame = CFrame.new(Position)

	Ball.Parent = Self.WaypointFolder

	return Ball
end

function PMProto.AddWaypoint(Self,Position,Action,Label,Color)
	local PreviousWaypoint = Self.Waypoints[#Self.Waypoints] and Self.Waypoints[#Self.Waypoints].Path
	local PreviousWaypointPosition = PreviousWaypoint and PreviousWaypoint.Position

	local Waypoint = {
		Path = PathWaypoint.new(Position,Action,Label),
		Beam = Self:MakeBeam(PreviousWaypointPosition,Position,Color),
		Point = Self:MakePoint(Position,Color)
	}

	table.insert(Self.Waypoints,Waypoint)
	return Waypoint
end

function PMProto.RemoveWaypoint(Self,Waypoint)
	if Waypoint.Point then Waypoint.Point:Destroy() end
	if Waypoint.Beam then Waypoint.Beam:Destroy() end

	Waypoint = table.find(Self.Waypoints,Waypoint)
	return table.remove(Self.Waypoints,Waypoint)
end

function PMProto.FormatWaypoints(Self)
	local String = "return {\n"

	for Index,Waypoint in pairs(Self.Waypoints) do
		Waypoint = Waypoint.Path
		local X = Pointer(Waypoint.Position.X)
		local Y = Pointer(Waypoint.Position.Y)
		local Z = Pointer(Waypoint.Position.Z)
		local Action = tostring(Waypoint.Action)
		local Label = tostring(Waypoint.Label)

		if Index == #Self.Waypoints then
			String ..= ("\t[%s] = %s\n"):format(Index,WaypointForm:format(X,Y,Z,Action,Label))
			continue
		end
		String ..= ("\t[%s] = %s,\n"):format(Index,WaypointForm:format(X,Y,Z,Action,Label))
	end

	return String .. "}"
end

function PMProto.LoadWaypoints(Self,NewWaypoints)
	if Self.Working then return end

	Self.WaypointFolder:ClearAllChildren()
	table.clear(Self.Waypoints)

	for Index,Waypoint in pairs(NewWaypoints) do
		local Command = string.split(Waypoint.Label,"/")
		local Color = (Command[1] == "Start" and Color3.new(1,0,0))
			or (Command[1] == "Stop" and Color3.new(0,1,0))
			or (Command[1] == "Action" and Color3.new(0,0,1))
		Self:AddWaypoint(Waypoint.Position,Waypoint.Action,Waypoint.Label,Color)
	end
end

function PMProto.AddAction(Self,BasePart,CustomCommand)
	if not Self.Working then return end

	Self.AddingAction = true
	if not Self.AddingAction then return end

	local CurrentWaypoint = Self.Waypoints[#Self.Waypoints]
	if not CurrentWaypoint then return end

	if not BasePart then return end
	print("Action on",BasePart.Name)

	local Distance = (CurrentWaypoint.Path.Position - Self.OriginPart.Position).Magnitude
	if Distance > Self.WaypointDistance * Self.CheckDistance then
		Self:AddWaypoint(Self.OriginPart.Position,Enum.PathWaypointAction.Walk)
	end

	Self:AddWaypoint(BasePart.Position,Enum.PathWaypointAction.Custom,"Action/"..CustomCommand,Color3.new(0,0,1))
	Self.AddingAction = false
end

function PMProto.Start(Self)
	CheckOriginPart(Self)
	Self.Working = true

	--if not Self.Working then return end
	local CurrentWaypoint = Self.Waypoints[#Self.Waypoints]

	if CurrentWaypoint then
		local Distance = (CurrentWaypoint.Path.Position - Self.OriginPart.Position).Magnitude
		if Distance < Self.WaypointDistance * Self.CheckDistance then
			Self:RemoveWaypoint(CurrentWaypoint)
			Self:AddWaypoint(CurrentWaypoint.Path.Position,Enum.PathWaypointAction.Walk,"Start",Color3.new(1,0,0))
			return
		end
	end
	
	Self:AddWaypoint(Self.OriginPart.Position,Enum.PathWaypointAction.Walk,"Start",Color3.new(1,0,0))
end

function PMProto.Stop(Self)
	CheckOriginPart(Self)
	Self.Working = false
	
	--if Self.Working then return end
	local CurrentWaypoint = Self.Waypoints[#Self.Waypoints]
	if not CurrentWaypoint then return end
	
	local Distance = (CurrentWaypoint.Path.Position - Self.OriginPart.Position).Magnitude
	if Distance < Self.WaypointDistance * Self.CheckDistance then
		Self:RemoveWaypoint(CurrentWaypoint)
		Self:AddWaypoint(CurrentWaypoint.Path.Position,Enum.PathWaypointAction.Walk,"Stop",Color3.new(0,1,0))
		return
	end

	Self:AddWaypoint(Self.OriginPart.Position,Enum.PathWaypointAction.Walk,"Stop",Color3.new(0,1,0))
end

function PMProto.Toggle(Self)
	local Toggle = not Self.Working and Self.Start or Self.Stop

	Toggle(Self)
end

function PMProto.Clear(Self)
	if Self.Working then
		Self:Stop()
	end

	Self.WaypointFolder:ClearAllChildren()
	table.clear(Self.Waypoints)
end

function PMProto.Destroy(Self)
	if Self.Working then
		Self:Stop()
	end

	Self.WaypointFolder:Destroy()
	Self.Connection:Disconnect()
	table.clear(Self.Waypoints)
end

function PathMaker.new(OriginPart)
	local Self = setmetatable({},PMProto)
	
	Self.Waypoints = {}
	Self.Working = false
	Self.AddingAction = false
	Self.OriginPart = OriginPart

	Self.WaypointDistance = 4
	Self.CheckDistance = 0.75
	
	Self.WaypointFolder = Instance.new("Folder")
	Self.WaypointFolder.Name = "Waypoints"
	Self.WaypointFolder.Parent = Workspace

	Self.Connection = RunService.Heartbeat:Connect(function()
		if not Self.Working or Self.AddingAction then return end
		
		CheckOriginPart(Self)
		local CurrentWaypoint = Self.Waypoints[#Self.Waypoints]
		if not CurrentWaypoint then return end

		if CurrentWaypoint.Path.Action == Enum.PathWaypointAction.Custom then
			CurrentWaypoint = Self.Waypoints[#Self.Waypoints - 1]
		end

		local Distance = (CurrentWaypoint.Path.Position - Self.OriginPart.Position).Magnitude
		if Distance < Self.WaypointDistance then return end

		Self:AddWaypoint(Self.OriginPart.Position,Enum.PathWaypointAction.Walk)
	end)

	return Self
end

return PathMaker
