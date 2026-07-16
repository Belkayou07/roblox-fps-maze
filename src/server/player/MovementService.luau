local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.MovementConfig)

local MovementService = {}

local SPEED_BY_STATE = {
	Walk = MovementConfig.WalkSpeed,
	Sprint = MovementConfig.SprintSpeed,
	Crouch = MovementConfig.CrouchSpeed,
}

local lastRequestAt = {}
local initialized = false

local function getMovementRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("MovementState")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "MovementState"
		remote.Parent = remotes
	end

	return remote
end

local function configureCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	humanoid.AutoJumpEnabled = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.WalkSpeed = MovementConfig.WalkSpeed
	character:SetAttribute("MovementState", "Walk")
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(configureCharacter)

	if player.Character then
		task.spawn(configureCharacter, player.Character)
	end
end

function MovementService.start()
	if initialized then
		return
	end
	initialized = true

	local movementRemote = getMovementRemote()

	movementRemote.OnServerEvent:Connect(function(player, requestedState)
		if typeof(requestedState) ~= "string" then
			return
		end

		local requestedSpeed = SPEED_BY_STATE[requestedState]
		if not requestedSpeed then
			return
		end

		local now = os.clock()
		local previousRequest = lastRequestAt[player] or 0
		if now - previousRequest < MovementConfig.RequestCooldown then
			return
		end
		lastRequestAt[player] = now

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end

		humanoid.WalkSpeed = requestedSpeed
		character:SetAttribute("MovementState", requestedState)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return MovementService
