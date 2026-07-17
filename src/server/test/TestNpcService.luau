local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.MovementConfig)
local TestNpcConfig = require(ReplicatedStorage.Shared.TestNpcConfig)

local TestNpcService = {}

local random = Random.new()
local started = false

local SPEED_BY_STATE = {
	Walk = MovementConfig.WalkSpeed,
	Sprint = MovementConfig.SprintSpeed,
	Crouch = MovementConfig.CrouchSpeed,
}

local function getMessageRemote(): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("ProximityMessage")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ProximityMessage"
		remote.Parent = remotes
	end

	return remote :: RemoteEvent
end

local function collectNavigationPoints(map: Model): { BasePart }
	local folder = map:FindFirstChild("NavigationPoints")
	if not folder then
		return {}
	end

	local points = {}
	for _, instance in folder:GetChildren() do
		if instance:IsA("BasePart") then
			table.insert(points, instance)
		end
	end

	return points
end

local function chooseMovementState(): string
	local roll = random:NextNumber()
	local total = 0

	for _, stateName in { "Walk", "Sprint", "Crouch" } do
		total += TestNpcConfig.StateWeights[stateName]
		if roll <= total then
			return stateName
		end
	end

	return "Walk"
end

local function setMovementState(npc: Model, humanoid: Humanoid, baseHipHeight: number, stateName: string)
	npc:SetAttribute("MovementState", stateName)
	humanoid.WalkSpeed = SPEED_BY_STATE[stateName]
	humanoid.HipHeight = if stateName == "Crouch"
		then math.max(0, baseHipHeight - TestNpcConfig.CrouchHipOffset)
		else baseHipHeight
end

local function attachFootsteps(npc: Model, humanoid: Humanoid, rootPart: BasePart)
	local sound = Instance.new("Sound")
	sound.Name = "TacticalFootsteps"
	sound.SoundId = MovementConfig.Footsteps.SoundId
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMinDistance = MovementConfig.Footsteps.RollOffMinDistance
	sound.RollOffMaxDistance = MovementConfig.Footsteps.RollOffMaxDistance
	sound.Volume = 0
	sound.Parent = rootPart

	local heartbeatConnection
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not npc.Parent or humanoid.Health <= 0 then
			heartbeatConnection:Disconnect()
			if sound.Parent then
				sound:Destroy()
			end
			return
		end

		local velocity = rootPart.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local moving = horizontalSpeed >= MovementConfig.Footsteps.MinimumMovingSpeed

		if grounded and moving then
			local stateName = npc:GetAttribute("MovementState") or "Walk"
			local profile = MovementConfig.Footsteps.Profiles[stateName] or MovementConfig.Footsteps.Profiles.Walk
			sound.Volume = profile.Volume
			sound.PlaybackSpeed = profile.PlaybackSpeed

			if not sound.IsPlaying then
				sound:Play()
			end
		elseif sound.IsPlaying then
			sound:Stop()
		end
	end)
end

local function createNpc(startPoint: BasePart): (Model?, Humanoid?, BasePart?)
	local description = Instance.new("HumanoidDescription")
	local success, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()

	if not success then
		warn("Unable to create tactical test NPC:", result)
		return nil, nil, nil
	end

	local npc = result :: Model
	npc.Name = "TacticalTestNPC"
	npc:SetAttribute("IsTestNpc", true)

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		npc:Destroy()
		return nil, nil, nil
	end

	humanoid.DisplayName = TestNpcConfig.Name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.AutoJumpEnabled = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	for _, descendant in npc:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = descendant == rootPart
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
		end
	end

	local npcFolder = Workspace:FindFirstChild("TestNPCs")
	if not npcFolder then
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "TestNPCs"
		npcFolder.Parent = Workspace
	end

	npc.Parent = npcFolder
	npc:PivotTo(CFrame.new(startPoint.Position + Vector3.new(0, TestNpcConfig.SpawnHeight, 0)))
	attachFootsteps(npc, humanoid, rootPart)

	return npc, humanoid, rootPart
end

local function moveAlongPath(humanoid: Humanoid, rootPart: BasePart, destination: Vector3)
	local path = PathfindingService:CreatePath(TestNpcConfig.Pathfinding)
	local success = pcall(function()
		path:ComputeAsync(rootPart.Position, destination)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		humanoid:MoveTo(destination)
		humanoid.MoveToFinished:Wait()
		return
	end

	for _, waypoint in path:GetWaypoints() do
		if humanoid.Health <= 0 or not humanoid.Parent then
			return
		end

		humanoid:MoveTo(waypoint.Position)
		local reached = humanoid.MoveToFinished:Wait()
		if not reached then
			return
		end
	end
end

local function startSpeechLoop(npc: Model, remote: RemoteEvent)
	if not TestNpcConfig.Speech.Enabled then
		return
	end

	task.spawn(function()
		while npc.Parent do
			task.wait(random:NextNumber(TestNpcConfig.Speech.MinimumDelay, TestNpcConfig.Speech.MaximumDelay))
			if not npc.Parent then
				break
			end

			local lines = TestNpcConfig.Speech.Lines
			local line = lines[random:NextInteger(1, #lines)]
			remote:FireAllClients(npc, line)
		end
	end)
end

local function startMovementLoop(npc: Model, humanoid: Humanoid, rootPart: BasePart, navigationPoints: { BasePart })
	local baseHipHeight = humanoid.HipHeight
	local previousPoint: BasePart? = nil

	task.spawn(function()
		task.wait(1)

		while npc.Parent and humanoid.Health > 0 do
			local destinationPoint = navigationPoints[random:NextInteger(1, #navigationPoints)]
			if #navigationPoints > 1 and destinationPoint == previousPoint then
				destinationPoint = navigationPoints[(table.find(navigationPoints, destinationPoint) % #navigationPoints) + 1]
			end
			previousPoint = destinationPoint

			local stateName = chooseMovementState()
			setMovementState(npc, humanoid, baseHipHeight, stateName)
			moveAlongPath(humanoid, rootPart, destinationPoint.Position)

			setMovementState(npc, humanoid, baseHipHeight, "Walk")
			task.wait(random:NextNumber(TestNpcConfig.MinimumPause, TestNpcConfig.MaximumPause))
		end
	end)
end

function TestNpcService.start(map: Model)
	if started then
		return
	end
	started = true

	local navigationPoints = collectNavigationPoints(map)
	if #navigationPoints == 0 then
		warn("No navigation points exist for the tactical test NPC.")
		return
	end

	local npc, humanoid, rootPart = createNpc(navigationPoints[1])
	if not npc or not humanoid or not rootPart then
		return
	end

	local messageRemote = getMessageRemote()
	startMovementLoop(npc, humanoid, rootPart, navigationPoints)
	startSpeechLoop(npc, messageRemote)
end

return TestNpcService
