local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local WeaponController = {}

local ACTION_PRIORITY = 3100
local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local fireRemote = remotesFolder:WaitForChild("WeaponFire")
local reloadRemote = remotesFolder:WaitForChild("WeaponReload")
local stateRemote = remotesFolder:WaitForChild("WeaponState")
local effectRemote = remotesFolder:WaitForChild("WeaponEffect")
local roundStatusRemote = remotesFolder:WaitForChild("RoundStatus")

local ammo = WeaponConfig.MagazineSize
local magazineSize = WeaponConfig.MagazineSize
local reloading = false
local lastLocalShotAt = -math.huge
local started = false
local roundMessageToken = 0

local ammoLabel = nil
local hitMarker = nil
local roundLabel = nil

local function isWeaponEquipped(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild(WeaponConfig.ToolName)
	return tool ~= nil and tool:IsA("Tool")
end

local function createCrosshairLine(parent: Instance, name: string, size: UDim2, position: UDim2)
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = size
	line.Position = position
	line.BackgroundColor3 = Color3.fromRGB(238, 238, 232)
	line.BackgroundTransparency = 0.15
	line.BorderSizePixel = 0
	line.Parent = parent
end

local function createHud()
	local playerGui = player:WaitForChild("PlayerGui")
	local oldGui = playerGui:FindFirstChild("CombatHud")
	if oldGui then
		oldGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(28, 28)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = gui

	createCrosshairLine(crosshair, "Top", UDim2.fromOffset(2, 7), UDim2.fromScale(0.5, 0.08))
	createCrosshairLine(crosshair, "Bottom", UDim2.fromOffset(2, 7), UDim2.fromScale(0.5, 0.92))
	createCrosshairLine(crosshair, "Left", UDim2.fromOffset(7, 2), UDim2.fromScale(0.08, 0.5))
	createCrosshairLine(crosshair, "Right", UDim2.fromOffset(7, 2), UDim2.fromScale(0.92, 0.5))

	hitMarker = Instance.new("TextLabel")
	hitMarker.Name = "HitMarker"
	hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarker.Position = UDim2.fromScale(0.5, 0.5)
	hitMarker.Size = UDim2.fromOffset(42, 42)
	hitMarker.BackgroundTransparency = 1
	hitMarker.Font = Enum.Font.GothamBold
	hitMarker.Text = "×"
	hitMarker.TextColor3 = Color3.fromRGB(245, 245, 240)
	hitMarker.TextSize = 34
	hitMarker.TextStrokeTransparency = 0.35
	hitMarker.TextTransparency = 1
	hitMarker.Parent = gui

	ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "Ammo"
	ammoLabel.AnchorPoint = Vector2.new(1, 1)
	ammoLabel.Position = UDim2.new(1, -34, 1, -28)
	ammoLabel.Size = UDim2.fromOffset(210, 46)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Font = Enum.Font.GothamMedium
	ammoLabel.TextColor3 = Color3.fromRGB(232, 232, 225)
	ammoLabel.TextStrokeTransparency = 0.5
	ammoLabel.TextSize = 22
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
	ammoLabel.Parent = gui

	roundLabel = Instance.new("TextLabel")
	roundLabel.Name = "RoundStatus"
	roundLabel.AnchorPoint = Vector2.new(0.5, 0)
	roundLabel.Position = UDim2.new(0.5, 0, 0, 54)
	roundLabel.Size = UDim2.new(0.7, 0, 0, 50)
	roundLabel.BackgroundTransparency = 1
	roundLabel.Font = Enum.Font.GothamMedium
	roundLabel.TextColor3 = Color3.fromRGB(235, 235, 228)
	roundLabel.TextStrokeTransparency = 0.4
	roundLabel.TextSize = 24
	roundLabel.TextTransparency = 1
	roundLabel.Parent = gui
end

local function updateAmmoHud()
	if not ammoLabel then
		return
	end

	if reloading then
		ammoLabel.Text = "RELOADING"
	else
		ammoLabel.Text = `{ammo} / {magazineSize}`
	end
end

local function showHitMarker(hitKind: string)
	if not hitMarker or hitKind == "Miss" or hitKind == "Surface" then
		return
	end

	local marker = hitMarker
	marker.TextColor3 = if hitKind == "Elimination"
		then Color3.fromRGB(220, 104, 104)
		else Color3.fromRGB(245, 245, 240)
	marker.TextTransparency = 0

	task.spawn(function()
		local start = os.clock()
		while marker.Parent and os.clock() - start < 0.22 do
			marker.TextTransparency = math.clamp((os.clock() - start) / 0.22, 0, 1)
			RunService.RenderStepped:Wait()
		end
		if marker.Parent then
			marker.TextTransparency = 1
		end
	end)
end

local function createShotEffect(origin: Vector3, hitPosition: Vector3)
	local distance = (hitPosition - origin).Magnitude
	if distance <= 0.01 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "PrototypeTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(226, 218, 187)
	tracer.Transparency = 0.25
	tracer.Size = Vector3.new(0.035, 0.035, distance)
	tracer.CFrame = CFrame.lookAt((origin + hitPosition) * 0.5, hitPosition)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, WeaponConfig.Effects.TracerLifetime)

	local impact = Instance.new("Part")
	impact.Name = "PrototypeImpact"
	impact.Shape = Enum.PartType.Ball
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanTouch = false
	impact.CanQuery = false
	impact.CastShadow = false
	impact.Material = Enum.Material.Neon
	impact.Color = Color3.fromRGB(210, 205, 190)
	impact.Transparency = 0.15
	impact.Size = Vector3.new(0.12, 0.12, 0.12)
	impact.Position = hitPosition
	impact.Parent = Workspace
	Debris:AddItem(impact, WeaponConfig.Effects.ImpactLifetime)
end

local function showRoundMessage(state: string, message: string)
	if not roundLabel then
		return
	end

	roundMessageToken += 1
	local token = roundMessageToken
	roundLabel.Text = message
	roundLabel.TextTransparency = 0

	if state == "Finished" then
		return
	end

	task.delay(2.5, function()
		if token ~= roundMessageToken or not roundLabel then
			return
		end

		local start = os.clock()
		while token == roundMessageToken and roundLabel.Parent and os.clock() - start < 1 do
			roundLabel.TextTransparency = math.clamp(os.clock() - start, 0, 1)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function attemptReload()
	if reloading or ammo >= magazineSize or not isWeaponEquipped() then
		return
	end

	reloading = true
	updateAmmoHud()
	reloadRemote:FireServer()
end

local function attemptFire()
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if not isWeaponEquipped() or reloading then
		return
	end
	if ammo <= 0 then
		attemptReload()
		return
	end

	local now = os.clock()
	if now - lastLocalShotAt < WeaponConfig.FireInterval then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	lastLocalShotAt = now
	ammo = math.max(0, ammo - 1)
	updateAmmoHud()
	fireRemote:FireServer(camera.CFrame.Position, camera.CFrame.LookVector)
end

local function handleFireAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		attemptFire()
	end
	return if isWeaponEquipped() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

local function handleReloadAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		attemptReload()
	end
	return if isWeaponEquipped() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

function WeaponController.start()
	if started then
		return
	end
	started = true

	createHud()
	updateAmmoHud()

	ContextActionService:BindActionAtPriority(
		"PrototypeFire",
		handleFireAction,
		true,
		ACTION_PRIORITY,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle("PrototypeFire", "Fire")
	ContextActionService:SetPosition("PrototypeFire", UDim2.new(1, -110, 1, -170))

	ContextActionService:BindActionAtPriority(
		"PrototypeReload",
		handleReloadAction,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:SetTitle("PrototypeReload", "Reload")
	ContextActionService:SetPosition("PrototypeReload", UDim2.new(1, -210, 1, -110))

	stateRemote.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end

		if typeof(state.Ammo) == "number" then
			ammo = state.Ammo
		end
		if typeof(state.MagazineSize) == "number" then
			magazineSize = state.MagazineSize
		end
		if typeof(state.Reloading) == "boolean" then
			reloading = state.Reloading
		end
		updateAmmoHud()
	end)

	effectRemote.OnClientEvent:Connect(function(shooter, origin, hitPosition, hitKind)
		if typeof(origin) ~= "Vector3" or typeof(hitPosition) ~= "Vector3" or typeof(hitKind) ~= "string" then
			return
		end

		createShotEffect(origin, hitPosition)
		if shooter == player then
			showHitMarker(hitKind)
		end
	end)

	roundStatusRemote.OnClientEvent:Connect(function(state, message)
		if typeof(state) == "string" and typeof(message) == "string" then
			showRoundMessage(state, message)
		end
	end)
end

return WeaponController