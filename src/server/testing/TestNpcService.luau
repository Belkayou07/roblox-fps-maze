local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.MovementConfig)
local TestNpcConfig = require(ReplicatedStorage.Shared.TestNpcConfig)

local TestNpcService = {}
local started = false

local function getRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("ProximitySpeech")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "ProximitySpeech"
		remote.Parent = remotes
	end

	return remote
end

local function createNpc(): Model?
	local description = Instance.new("HumanoidDescription")
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()

	if not ok or not npc then
		warn("Unable to create temporary test NPC")
		return nil
	end

	npc.Name = TestNpcConfig.Name
	npc:SetAttribute("IsTestNpc", true)
	npc:SetAttribute("MovementState", "Walk")

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = TestNpcConfig.Name
		humanoid.AutoJumpEnabled = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end

	return npc
end

local function getDestinationParts(): { BasePart }
	local results = {}
	local generatedMap = Workspace:FindFirstChild("GeneratedMap")
	if not generatedMap then
		return results
	end

	for _, descendant in generatedMap:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			table.insert(results, descendant)
		end
	end

	return results
end

local function chooseState(random: Random): string
	local roll = random:NextNumber()
	local walkEnd = TestNpcConfig.StateWeights.Walk
	local sprintEnd = walkEnd + TestNpcConfig.StateWeights.Sprint

	if roll <= walkEnd then
		return "Walk"
	elseif roll <= sprintEnd then
		return "Sprint"
	end

	return "Crouch"
end

local function applyState(npc: Model, humanoid: Humanoid, state: string, baseHipHeight: number)
	npc:SetAttribute("MovementState", state)

	if state == "Sprint" then
		humanoid.WalkSpeed = MovementConfig.SprintSpeed
		humanoid.HipHeight = baseHipHeight
	elseif state == "Crouch" then
		humanoid.WalkSpeed = MovementConfig.CrouchSpeed
		humanoid.HipHeight = math.max(0, baseHipHeight - TestNpcConfig.CrouchHipOffset)
	else
		humanoid.WalkSpeed = MovementConfig.WalkSpeed
		humanoid.HipHeight = baseHipHeight
	end
end

local function addFootsteps(npc: Model, humanoid: Humanoid, rootPart: BasePart)
	local sound = Instance.new("Sound")
	sound.Name = "TacticalFootsteps"
	sound.SoundId = MovementConfig.Footsteps.SoundId
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMinDistance = MovementConfig.Footsteps.RollOffMinDistance
	sound.RollOffMaxDistance = MovementConfig.Footsteps.RollOffMaxDistance
	sound.Volume = 0
	sound.Parent = rootPart

	task.spawn(function()
		while npc.Parent and humanoid.Health > 0 do
			local velocity = rootPart.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local moving = speed >= MovementConfig.Footsteps.MinimumMovingSpeed
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			local state = npc:GetAttribute("MovementState") or "Walk"
			local profile = MovementConfig.Footsteps.Profiles[state] or MovementConfig.Footsteps.Profiles.Walk

			if moving and grounded then
				sound.Volume = profile.Volume
				sound.PlaybackSpeed = profile.PlaybackSpeed
				if not sound.IsPlaying then
					sound:Play()
				end
			elseif sound.IsPlaying then
				sound:Stop()
			end

			task.wait(0.08)
		end
	end)
end

local function followPath(npc: Model, humanoid: Humanoid, destination: Vector3): boolean
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local path = PathfindingService:CreatePath(TestNpcConfig.Pathfinding)
	local ok = pcall(function()
		path:ComputeAsync(rootPart.Position, destination)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return false
	end

	for _, waypoint in path:GetWaypoints() do
		if not npc.Parent or humanoid.Health <= 0 then
			return false
		end

		humanoid:MoveTo(waypoint.Position)
		if not humanoid.MoveToFinished:Wait() then
			return false
		end
	end

	return true
end

local function runSpeech(npc: Model, remote: RemoteEvent, random: Random)
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

function TestNpcService.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local generatedMap = Workspace:WaitForChild("GeneratedMap", 15)
		if not generatedMap then
			warn("Test NPC could not find GeneratedMap")
			return
		end

		local destinations = getDestinationParts()
		if #destinations == 0 then
			warn("Test NPC could not find navigation points")
			return
		end

		local npc = createNpc()
		if not npc then
			return
		end

		local firstDestination = destinations[1]
		npc:PivotTo(firstDestination.CFrame + Vector3.new(0, TestNpcConfig.SpawnHeight, 0))
		npc.Parent = Workspace

		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
			npc:Destroy()
			return
		end

		pcall(function()
			rootPart:SetNetworkOwner(nil)
		end)

		local random = Random.new()
		local baseHipHeight = humanoid.HipHeight
		local remote = getRemote()
		addFootsteps(npc, humanoid, rootPart)
		runSpeech(npc, remote, random)

		while npc.Parent and humanoid.Health > 0 do
			destinations = getDestinationParts()
			if #destinations == 0 then
				break
			end

			local state = chooseState(random)
			applyState(npc, humanoid, state, baseHipHeight)
			local destination = destinations[random:NextInteger(1, #destinations)]
			followPath(npc, humanoid, destination.Position)
			applyState(npc, humanoid, "Walk", baseHipHeight)
			task.wait(random:NextNumber(TestNpcConfig.MinimumPause, TestNpcConfig.MaximumPause))
		end
	end)
end

return TestNpcService