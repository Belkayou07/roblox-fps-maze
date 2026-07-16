local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.MovementConfig)

local FootstepController = {}

local activeCharacters = {}
local started = false

local function getProfile(character, speed)
	local state = character:GetAttribute("MovementState")
	local profiles = MovementConfig.Footsteps.Profiles

	if state and profiles[state] then
		return profiles[state]
	end

	if speed >= (MovementConfig.WalkSpeed + MovementConfig.SprintSpeed) * 0.5 then
		return profiles.Sprint
	elseif speed <= (MovementConfig.CrouchSpeed + MovementConfig.WalkSpeed) * 0.5 then
		return profiles.Crouch
	else
		return profiles.Walk
	end
end

local function removeCharacter(character)
	local controller = activeCharacters[character]
	if not controller then
		return
	end

	controller.HeartbeatConnection:Disconnect()
	controller.ChildAddedConnection:Disconnect()
	controller.Sound:Destroy()
	activeCharacters[character] = nil
end

local function muteDefaultRunningSound(instance)
	if instance:IsA("Sound") and instance.Name == "Running" then
		instance.Volume = 0
	end
end

local function addCharacter(character)
	if activeCharacters[character] then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not rootPart or not character.Parent then
		return
	end

	for _, child in rootPart:GetChildren() do
		muteDefaultRunningSound(child)
	end
	local childAddedConnection = rootPart.ChildAdded:Connect(muteDefaultRunningSound)

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
		if not character.Parent or humanoid.Health <= 0 then
			removeCharacter(character)
			return
		end

		local velocity = rootPart.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local moving = horizontalSpeed >= MovementConfig.Footsteps.MinimumMovingSpeed

		if grounded and moving then
			local profile = getProfile(character, horizontalSpeed)
			sound.Volume = profile.Volume
			sound.PlaybackSpeed = profile.PlaybackSpeed

			if not sound.IsPlaying then
				sound:Play()
			end
		elseif sound.IsPlaying then
			sound:Stop()
		end
	end)

	activeCharacters[character] = {
		HeartbeatConnection = heartbeatConnection,
		ChildAddedConnection = childAddedConnection,
		Sound = sound,
	}
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(addCharacter, character)
	end)

	player.CharacterRemoving:Connect(removeCharacter)

	if player.Character then
		task.spawn(addCharacter, player.Character)
	end
end

function FootstepController.start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return FootstepController
