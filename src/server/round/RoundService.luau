local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoundService = {}

local combatants = {}
local roundActive = false
local roundFinished = false
local statusRemote = nil
local started = false

local function getOrCreateStatusRemote(): RemoteEvent
	local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "Remotes"
		remoteFolder.Parent = ReplicatedStorage
	end

	local existing = remoteFolder:FindFirstChild("RoundStatus")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = "RoundStatus"
	remote.Parent = remoteFolder
	return remote
end

local function isCombatantModel(model: Model): boolean
	return Players:GetPlayerFromCharacter(model) ~= nil or model:GetAttribute("IsTestNpc") == true
end

local function getCombatantName(model: Model): string
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return player.DisplayName
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.DisplayName ~= "" then
		return humanoid.DisplayName
	end

	return model.Name
end

local function getAliveCombatants()
	local alive = {}
	for model, record in combatants do
		if model.Parent and record.Humanoid.Parent == model and record.Humanoid.Health > 0 then
			table.insert(alive, model)
		end
	end
	return alive
end

local function broadcast(state: string, message: string)
	if statusRemote then
		statusRemote:FireAllClients(state, message)
	end
end

local function evaluateRound()
	if not roundActive or roundFinished then
		return
	end

	local alive = getAliveCombatants()
	if #alive > 1 then
		return
	end

	roundActive = false
	roundFinished = true

	if #alive == 1 then
		broadcast("Finished", `{getCombatantName(alive[1])} survived`)
	else
		broadcast("Finished", "No one survived")
	end
end

local function tryStartRound()
	if roundActive or roundFinished then
		return
	end

	local alive = getAliveCombatants()
	if #alive >= 2 then
		roundActive = true
		broadcast("Active", "Last survivor wins")
	else
		broadcast("Waiting", "Waiting for another combatant")
	end
end

local function registerCombatant(model: Model)
	if combatants[model] or not isCombatantModel(model) then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local diedConnection
	local ancestryConnection

	diedConnection = humanoid.Died:Connect(function()
		task.delay(0.15, evaluateRound)
	end)

	ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		local record = combatants[model]
		if record then
			record.DiedConnection:Disconnect()
			record.AncestryConnection:Disconnect()
			combatants[model] = nil
		end
		task.delay(0.05, evaluateRound)
	end)

	combatants[model] = {
		Humanoid = humanoid,
		DiedConnection = diedConnection,
		AncestryConnection = ancestryConnection,
	}

	tryStartRound()
end

local function loadAndRegisterPlayer(player: Player)
	player.CharacterAdded:Connect(registerCombatant)

	if player.Character then
		registerCombatant(player.Character)
		return
	end

	task.spawn(function()
		local ok, errorMessage = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok then
			warn(`Unable to load character for {player.Name}: {errorMessage}`)
		end
	end)
end

function RoundService.start()
	if started then
		return
	end
	started = true

	statusRemote = getOrCreateStatusRemote()
	broadcast("Waiting", "Preparing combatants")

	Players.PlayerAdded:Connect(loadAndRegisterPlayer)
	for _, player in Players:GetPlayers() do
		loadAndRegisterPlayer(player)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(registerCombatant, child)
		end
	end)

	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") then
			registerCombatant(child)
		end
	end
end

return RoundService