local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local WeaponService = {}

local playerStates = {}
local remotes = {}
local started = false

local function isFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector(vector: Vector3): boolean
	return isFiniteNumber(vector.X) and isFiniteNumber(vector.Y) and isFiniteNumber(vector.Z)
end

local function getOrCreateRemote(name: string): RemoteEvent
	local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "Remotes"
		remoteFolder.Parent = ReplicatedStorage
	end

	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local function sendState(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	remotes.State:FireClient(player, {
		Ammo = state.Ammo,
		MagazineSize = WeaponConfig.MagazineSize,
		Reloading = state.Reloading,
	})
end

local function createPrototypeTool(player: Player, character: Model)
	local backpack = player:WaitForChild("Backpack", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid then
		return
	end

	local oldBackpackTool = backpack:FindFirstChild(WeaponConfig.ToolName)
	if oldBackpackTool then
		oldBackpackTool:Destroy()
	end

	local oldCharacterTool = character:FindFirstChild(WeaponConfig.ToolName)
	if oldCharacterTool then
		oldCharacterTool:Destroy()
	end

	local tool = Instance.new("Tool")
	tool.Name = WeaponConfig.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Prototype sidearm — left click to fire, R to reload"
	tool.Grip = WeaponConfig.Tool.Grip

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = WeaponConfig.Tool.HandleSize
	handle.Color = WeaponConfig.Tool.HandleColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	tool.Parent = backpack

	task.defer(function()
		if tool.Parent == backpack and humanoid.Parent == character and humanoid.Health > 0 then
			humanoid:EquipTool(tool)
		end
	end)
end

local function configureCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	playerStates[player] = {
		Character = character,
		Ammo = WeaponConfig.MagazineSize,
		Reloading = false,
		LastShotAt = -math.huge,
		LastRequestAt = -math.huge,
	}

	createPrototypeTool(player, character)
	sendState(player)

	humanoid.Died:Connect(function()
		local state = playerStates[player]
		if state and state.Character == character then
			state.Reloading = false
			sendState(player)
		end
	end)
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		configureCharacter(player, character)
	end)

	if player.Character then
		task.spawn(configureCharacter, player, player.Character)
	end
end

local function getEquippedTool(character: Model): Tool?
	local tool = character:FindFirstChild(WeaponConfig.ToolName)
	return if tool and tool:IsA("Tool") then tool else nil
end

local function getTargetHumanoid(hitInstance: Instance, shooterCharacter: Model): (Humanoid?, Model?)
	local model = hitInstance:FindFirstAncestorOfClass("Model")
	if not model or model == shooterCharacter then
		return nil, nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if not targetPlayer and not model:GetAttribute("IsTestNpc") then
		return nil, nil
	end

	return humanoid, model
end

local function isAimDirectionAllowed(rootPart: BasePart, direction: Vector3): boolean
	local flatAim = Vector3.new(direction.X, 0, direction.Z)
	local flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if flatAim.Magnitude < 0.001 or flatLook.Magnitude < 0.001 then
		return true
	end

	local minimumDot = math.cos(math.rad(WeaponConfig.MaximumAimYawDegrees))
	return flatAim.Unit:Dot(flatLook.Unit) >= minimumDot
end

local function emitShotSound(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "PrototypeGunshot"
	sound.SoundId = WeaponConfig.Effects.ShotSoundId
	sound.Volume = WeaponConfig.Effects.ShotSoundVolume
	sound.PlaybackSpeed = WeaponConfig.Effects.ShotSoundPlaybackSpeed
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMinDistance = 7
	sound.RollOffMaxDistance = WeaponConfig.Effects.ShotSoundMaxDistance
	sound.Parent = head
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function handleFire(player: Player, claimedOrigin, claimedDirection)
	if typeof(claimedOrigin) ~= "Vector3" or typeof(claimedDirection) ~= "Vector3" then
		return
	end
	if not isFiniteVector(claimedOrigin) or not isFiniteVector(claimedDirection) then
		return
	end
	if claimedDirection.Magnitude < 0.9 then
		return
	end

	local state = playerStates[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not state or state.Character ~= character or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if not head or not head:IsA("BasePart") or not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	if not getEquippedTool(character) then
		return
	end

	local now = os.clock()
	if now - state.LastRequestAt < WeaponConfig.RequestCooldown then
		return
	end
	state.LastRequestAt = now

	if state.Reloading or state.Ammo <= 0 or now - state.LastShotAt < WeaponConfig.FireInterval then
		sendState(player)
		return
	end
	if (claimedOrigin - head.Position).Magnitude > WeaponConfig.OriginTolerance then
		return
	end

	local direction = claimedDirection.Unit
	if not isAimDirectionAllowed(rootPart, direction) then
		return
	end

	state.LastShotAt = now
	state.Ammo -= 1
	sendState(player)
	emitShotSound(character)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local origin = head.Position
	local result = Workspace:Raycast(origin, direction * WeaponConfig.MaximumRange, raycastParams)
	local hitPosition = origin + direction * WeaponConfig.MaximumRange
	local hitKind = "Miss"

	if result then
		hitPosition = result.Position
		local targetHumanoid = getTargetHumanoid(result.Instance, character)
		if targetHumanoid then
			local headshot = result.Instance.Name == "Head"
			local damage = WeaponConfig.BodyDamage
			if headshot then
				damage *= WeaponConfig.HeadshotMultiplier
			end

			local healthBefore = targetHumanoid.Health
			targetHumanoid:TakeDamage(damage)
			local eliminated = healthBefore > 0 and targetHumanoid.Health <= 0

			if eliminated then
				hitKind = "Elimination"
			elseif headshot then
				hitKind = "Head"
			else
				hitKind = "Body"
			end
		else
			hitKind = "Surface"
		end
	end

	remotes.Effect:FireAllClients(player, origin, hitPosition, hitKind)
end

local function handleReload(player: Player)
	local state = playerStates[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or state.Character ~= character or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if state.Reloading or state.Ammo >= WeaponConfig.MagazineSize then
		return
	end
	if not getEquippedTool(character) then
		return
	end

	state.Reloading = true
	sendState(player)

	local reloadCharacter = character
	task.delay(WeaponConfig.ReloadTime, function()
		local currentState = playerStates[player]
		local currentHumanoid = reloadCharacter:FindFirstChildOfClass("Humanoid")
		if not currentState or currentState ~= state or currentState.Character ~= reloadCharacter then
			return
		end

		currentState.Reloading = false
		if reloadCharacter.Parent and currentHumanoid and currentHumanoid.Health > 0 then
			currentState.Ammo = WeaponConfig.MagazineSize
		end
		sendState(player)
	end)
end

function WeaponService.start()
	if started then
		return
	end
	started = true

	remotes.Fire = getOrCreateRemote("WeaponFire")
	remotes.Reload = getOrCreateRemote("WeaponReload")
	remotes.State = getOrCreateRemote("WeaponState")
	remotes.Effect = getOrCreateRemote("WeaponEffect")

	remotes.Fire.OnServerEvent:Connect(handleFire)
	remotes.Reload.OnServerEvent:Connect(handleReload)

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return WeaponService