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

--[[local function MakeBeam(Parent,Origin,Position,Color)
	if not Origin or not Position then return end
	if Position.Magnitude == 1 then Position += Origin end
	local Beam = Instance.new("Part")

	Beam.Name = "Cylinder"
	Beam.Anchored = true
	Beam.CanTouch = false
	Beam.CanQuery = false
	Beam.CanCollide = false

	Beam.BottomSurface = Enum.SurfaceType.Smooth
	Beam.TopSurface = Enum.SurfaceType.Smooth
	Beam.Material = Enum.Material.Neon
	Beam.Shape = Enum.PartType.Cylinder
	Beam.Color = Color3.new(1,0.5,0)
	Beam.Transparency = 0.75

	Beam.Size = Vector3.new((Origin - Position).Magnitude,0.1,0.1)

	Beam.CFrame = CFrame.new(Origin,Position)
	Beam.CFrame *= CFrame.new(0,0,-Beam.Size.X / 2)
	Beam.CFrame *= CFrame.Angles(0,math.rad(90),0)

	Beam.Parent = Parent

	return Beam
end]]

local function MakeBeam(StartWaypoint,EndWaypoint)
	if not StartWaypoint then return end
	if not EndWaypoint then return end

	local StartPoint = StartWaypoint.Point
	local EndPoint = EndWaypoint.Point
	local Beam = Instance.new("Beam")

	Beam.Name = "Beam"
	Beam.Color = ColorSequence.new(StartPoint.Color,EndPoint.Color)
	Beam.LightInfluence = 1
	Beam.TextureMode = Enum.TextureMode.Static
	Beam.TextureSpeed = 0

	Beam.Attachment0 = StartPoint.BeamAttachment
	Beam.Attachment1 = EndPoint.BeamAttachment
	Beam.FaceCamera = true
	Beam.Segments = 1
	Beam.Width0 = 0.1
	Beam.Width1 = 0.1

	Beam.Parent = StartPoint

	return Beam
end

local function MakePoint(Parent,Position,Color)
	if not Position then return end
	local Point = Instance.new("Part")
	local BeamAttachment = Instance.new("Attachment")

	Point.Name = "Point"
	Point.Anchored = true
	Point.CanTouch = false
	Point.CanQuery = false
	Point.CanCollide = false

	Point.BottomSurface = Enum.SurfaceType.Smooth
	Point.TopSurface = Enum.SurfaceType.Smooth
	Point.Material = Enum.Material.Neon
	Point.Shape = Enum.PartType.Ball
	Point.Transparency = 0.5
	Point.Color = Color or Color3.new(1,0.5,0)

	Point.Size = Vector3.new(0.5,0.5,0.5)
	Point.CFrame = CFrame.new(Position)
	
	BeamAttachment.Name = "BeamAttachment"
	BeamAttachment.Parent = Point

	Point.Parent = Parent

	return Point
end

function PMProto.AddWaypoint(Self,Position,Action,Label,Color)
	local PreviousWaypoint = Self.Waypoints[#Self.Waypoints]
	
	local Waypoint = {}
	Waypoint.Path = PathWaypoint.new(Position,Action,Label)

	Waypoint.Point = MakePoint(Self.WaypointsFolder,Position,Color)
	Waypoint.Beam = MakeBeam(PreviousWaypoint,Waypoint)


	table.insert(Self.Waypoints,Waypoint)
	return Waypoint
end

function PMProto.RemoveWaypoint(Self,Waypoint)
	if Waypoint.Point then Waypoint.Point:Destroy() end
	if Waypoint.Beam then Waypoint.Beam:Destroy() end

	Waypoint = table.find(Self.Waypoints,Waypoint)
	return table.remove(Self.Waypoints,Waypoint)
end

function PMProto.GetWaypoints(Self)
	local Waypoints = {}

	for Index,Waypoint in pairs(Self.Waypoints) do
		table.insert(Waypoints,Waypoint.Path)
	end

	return Waypoints
end

function PMProto.GetClosest(Self,Distance)
	local Waypoints = Self:GetWaypoints()
	Distance = Distance or math.huge
	local ClosestWaypoint = nil
	
	for Index,Waypoint in pairs(Waypoints) do
		local Magnitude = (Waypoint.Position - Self.OriginPart.Position).Magnitude
		if Magnitude <= Distance then Distance,ClosestWaypoint = Magnitude,Waypoint end
	end

	return ClosestWaypoint,Waypoints
end

function PMProto.FormatWaypoints(Self)
	local Waypoints = Self:GetWaypoints()
	local String = "return {\n"

	for Index,Waypoint in pairs(Waypoints) do
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

	return String .. "}",Waypoints
end

function PMProto.LoadWaypoints(Self,NewWaypoints)
	Self:Clear()

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

	Self:AddWaypoint(BasePart.Position,Enum.PathWaypointAction.Custom,CustomCommand,Color3.new(0,0,1))
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

	Self.WaypointsFolder:ClearAllChildren()
	table.clear(Self.Waypoints)
end

function PMProto.Destroy(Self)
	if Self.Working then
		Self:Stop()
	end

	Self.WaypointsFolder:Destroy()
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
	
	Self.WaypointsFolder = Instance.new("Folder")
	Self.WaypointsFolder.Name = "Waypoints"
	Self.WaypointsFolder.Parent = Workspace

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
