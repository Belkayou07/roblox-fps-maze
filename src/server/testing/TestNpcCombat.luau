local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TestNpcConfig = require(ReplicatedStorage.Shared.TestNpcConfig)

local TestNpcCombat = {}

local function getEffectRemote(): RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	return remotes:WaitForChild("WeaponEffect")
end

local function getCharacterParts(character: Model): (Humanoid?, BasePart?, BasePart?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	return humanoid,
		if head and head:IsA("BasePart") then head else nil,
		if rootPart and rootPart:IsA("BasePart") then rootPart else nil
end

local function hasLineOfSight(npc: Model, origin: Vector3, character: Model, targetPosition: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, targetPosition - origin, params)
	return result == nil or result.Instance:IsDescendantOf(character)
end

local function findNearestVisibleTarget(npc: Model, npcHead: BasePart): (Model?, BasePart?, number?)
	local nearestCharacter = nil
	local nearestHead = nil
	local nearestDistance = math.huge

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end

		local humanoid, head = getCharacterParts(character)
		if not humanoid or humanoid.Health <= 0 or not head then
			continue
		end

		local distance = (head.Position - npcHead.Position).Magnitude
		if distance > TestNpcConfig.Combat.DetectionRange or distance >= nearestDistance then
			continue
		end

		if hasLineOfSight(npc, npcHead.Position, character, head.Position) then
			nearestCharacter = character
			nearestHead = head
			nearestDistance = distance
		end
	end

	return nearestCharacter, nearestHead, if nearestCharacter then nearestDistance else nil
end

local function createWeaponProp(npc: Model)
	local rightHand = npc:FindFirstChild("RightHand") or npc:WaitForChild("RightHand", 5)
	if not rightHand or not rightHand:IsA("BasePart") then
		return
	end

	local prop = Instance.new("Part")
	prop.Name = "TemporaryNpcSidearm"
	prop.Size = TestNpcConfig.Combat.WeaponPropSize
	prop.Color = TestNpcConfig.Combat.WeaponPropColor
	prop.Material = Enum.Material.Metal
	prop.CanCollide = false
	prop.CanTouch = false
	prop.CanQuery = false
	prop.Massless = true
	prop.CastShadow = false
	prop.CFrame = rightHand.CFrame * TestNpcConfig.Combat.WeaponGrip
	prop.Parent = npc

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = prop
	weld.Parent = prop
end

local function faceTarget(rootPart: BasePart, targetPosition: Vector3)
	local flatTarget = Vector3.new(targetPosition.X, rootPart.Position.Y, targetPosition.Z)
	if (flatTarget - rootPart.Position).Magnitude < 0.01 then
		return
	end

	rootPart.CFrame = CFrame.lookAt(rootPart.Position, flatTarget)
end

local function applySpread(origin: Vector3, targetPosition: Vector3, random: Random): Vector3
	local direct = targetPosition - origin
	if direct.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end

	local lookFrame = CFrame.lookAt(Vector3.zero, direct.Unit)
	local spread = math.tan(math.rad(TestNpcConfig.Combat.AimSpreadDegrees))
	local localDirection = Vector3.new(
		random:NextNumber(-spread, spread),
		random:NextNumber(-spread, spread),
		-1
	)

	return lookFrame:VectorToWorldSpace(localDirection).Unit
end

local function getPlayerHumanoidFromHit(instance: Instance): Humanoid?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model or not Players:GetPlayerFromCharacter(model) then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function fireAtTarget(
	npc: Model,
	npcHead: BasePart,
	targetPosition: Vector3,
	random: Random,
	effectRemote: RemoteEvent
)
	local origin = npcHead.Position
	local direction = applySpread(origin, targetPosition, random)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction * TestNpcConfig.Combat.FireRange, params)
	local hitPosition = origin + direction * TestNpcConfig.Combat.FireRange
	local hitKind = "Miss"

	if result then
		hitPosition = result.Position
		local targetHumanoid = getPlayerHumanoidFromHit(result.Instance)
		if targetHumanoid then
			local damage = TestNpcConfig.Combat.Damage
			local headshot = result.Instance.Name == "Head"
			if headshot then
				damage *= TestNpcConfig.Combat.HeadshotMultiplier
			end

			local healthBefore = targetHumanoid.Health
			targetHumanoid:TakeDamage(damage)
			if healthBefore > 0 and targetHumanoid.Health <= 0 then
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

	effectRemote:FireAllClients(npc, origin, hitPosition, hitKind)
end

function TestNpcCombat.start(npc: Model, humanoid: Humanoid, rootPart: BasePart)
	if not TestNpcConfig.Combat.Enabled then
		return
	end

	local npcHead = npc:FindFirstChild("Head") or npc:WaitForChild("Head", 5)
	if not npcHead or not npcHead:IsA("BasePart") then
		warn("Temporary NPC combat could not find Head")
		return
	end

	createWeaponProp(npc)

	local random = Random.new()
	local effectRemote = getEffectRemote()

	task.spawn(function()
		local currentTarget: Model? = nil
		local lastKnownPosition: Vector3? = nil
		local lastSeenAt = -math.huge
		local nextShotAt = math.huge

		while npc.Parent and humanoid.Health > 0 do
			local now = os.clock()
			local visibleTarget, visibleHead, distance = findNearestVisibleTarget(npc, npcHead)

			if visibleTarget and visibleHead and distance then
				if currentTarget ~= visibleTarget then
					currentTarget = visibleTarget
					nextShotAt = now + random:NextNumber(
						TestNpcConfig.Combat.MinimumReactionTime,
						TestNpcConfig.Combat.MaximumReactionTime
					)
				end

				lastKnownPosition = visibleHead.Position
				lastSeenAt = now
			elseif currentTarget then
				local targetHumanoid, targetHead = getCharacterParts(currentTarget)
				if not targetHumanoid or targetHumanoid.Health <= 0 or not targetHead then
					currentTarget = nil
					lastKnownPosition = nil
				elseif now - lastSeenAt > TestNpcConfig.Combat.LoseTargetAfter then
					currentTarget = nil
					lastKnownPosition = nil
				end
			end

			local engaged = currentTarget ~= nil and lastKnownPosition ~= nil
			npc:SetAttribute("CombatEngaged", engaged)

			if engaged and lastKnownPosition then
				humanoid:MoveTo(rootPart.Position)
				humanoid.WalkSpeed = 0
				faceTarget(rootPart, lastKnownPosition)

				local targetHumanoid, targetHead = getCharacterParts(currentTarget :: Model)
				local canFire = targetHumanoid
					and targetHumanoid.Health > 0
					and targetHead
					and (targetHead.Position - npcHead.Position).Magnitude <= TestNpcConfig.Combat.FireRange
					and hasLineOfSight(npc, npcHead.Position, currentTarget :: Model, targetHead.Position)

				if canFire and now >= nextShotAt then
					fireAtTarget(npc, npcHead, targetHead.Position, random, effectRemote)
					nextShotAt = now + random:NextNumber(
						TestNpcConfig.Combat.MinimumShotInterval,
						TestNpcConfig.Combat.MaximumShotInterval
					)
				end
			end

			task.wait(TestNpcConfig.Combat.ScanInterval)
		end

		npc:SetAttribute("CombatEngaged", false)
	end)
end

return TestNpcCombat
