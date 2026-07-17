local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local ProximityChatConfig = require(ReplicatedStorage.Shared.ProximityChatConfig)

local ProximityChatController = {}
local player = Players.LocalPlayer
local activeMessages = {}
local started = false

local function getListenerHead(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function getSpeakerHead(speaker): BasePart?
	if typeof(speaker) ~= "Instance" then
		return nil
	end

	if speaker:IsA("Player") then
		local character = speaker.Character
		local head = character and character:FindFirstChild("Head")
		return if head and head:IsA("BasePart") then head else nil
	end

	if speaker:IsA("Model") then
		local head = speaker:FindFirstChild("Head")
		return if head and head:IsA("BasePart") then head else nil
	end

	return nil
end

local function hasLineOfSight(listenerHead: BasePart, speakerHead: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { listenerHead.Parent, speakerHead.Parent }
	params.IgnoreWater = true

	local result = Workspace:Raycast(listenerHead.Position, speakerHead.Position - listenerHead.Position, params)
	return result == nil
end

local function createBillboard(speaker, text: string)
	local speakerHead = getSpeakerHead(speaker)
	if not speakerHead then
		return
	end

	local previous = activeMessages[speaker]
	if previous then
		previous.Destroyed = true
		previous.Gui:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "ProximityMessage"
	gui.Adornee = speakerHead
	gui.Size = UDim2.fromOffset(ProximityChatConfig.BillboardWidth, ProximityChatConfig.BillboardHeight)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ProximityChatConfig.VerticalOffset, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = ProximityChatConfig.MaximumDistance
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 235, 230)
	label.TextSize = ProximityChatConfig.TextSize
	label.TextStrokeColor3 = Color3.fromRGB(10, 10, 10)
	label.TextStrokeTransparency = 0.35
	label.TextWrapped = true
	label.TextTransparency = 1
	label.Parent = gui

	local record = {
		Gui = gui,
		Label = label,
		Speaker = speaker,
		CreatedAt = os.clock(),
		Destroyed = false,
		Visibility = 0,
	}
	activeMessages[speaker] = record

	local holdTime = math.clamp(
		ProximityChatConfig.MinimumHoldTime + #text * ProximityChatConfig.SecondsPerCharacter,
		ProximityChatConfig.MinimumHoldTime,
		ProximityChatConfig.MaximumHoldTime
	)

	task.delay(holdTime, function()
		if record.Destroyed then
			return
		end

		local start = os.clock()
		while not record.Destroyed and os.clock() - start < ProximityChatConfig.FadeOutTime do
			local alpha = (os.clock() - start) / ProximityChatConfig.FadeOutTime
			record.Label.TextTransparency = math.max(record.Label.TextTransparency, alpha)
			record.Label.TextStrokeTransparency = math.max(record.Label.TextStrokeTransparency, 0.35 + alpha * 0.65)
			RunService.RenderStepped:Wait()
		end

		if activeMessages[speaker] == record then
			activeMessages[speaker] = nil
		end
		record.Destroyed = true
		record.Gui:Destroy()
	end)
end

local function updateMessages(deltaTime: number)
	local listenerHead = getListenerHead()
	for speaker, record in activeMessages do
		if record.Destroyed then
			continue
		end

		local speakerHead = getSpeakerHead(speaker)
		if not listenerHead or not speakerHead then
			record.Visibility = 0
		else
			local distance = (listenerHead.Position - speakerHead.Position).Magnitude
			local distanceVisibility = 1 - math.clamp(
				(distance - ProximityChatConfig.FullClarityDistance)
					/ (ProximityChatConfig.MaximumDistance - ProximityChatConfig.FullClarityDistance),
				0,
				1
			)
			local visible = hasLineOfSight(listenerHead, speakerHead)
			local obstructionMultiplier = if visible then 1 else ProximityChatConfig.OccludedVisibility
			local targetVisibility = distanceVisibility * obstructionMultiplier
			local blend = 1 - math.exp(-ProximityChatConfig.VisibilityResponsiveness * deltaTime)
			record.Visibility += (targetVisibility - record.Visibility) * blend
		end

		local age = os.clock() - record.CreatedAt
		local fadeIn = math.clamp(age / ProximityChatConfig.FadeInTime, 0, 1)
		local finalVisibility = record.Visibility * fadeIn
		record.Label.TextTransparency = 1 - finalVisibility
		record.Label.TextStrokeTransparency = 1 - finalVisibility * 0.65
	end
end

local function connectPlayerChat()
	pcall(function()
		local bubbleConfig = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbleConfig then
			bubbleConfig.Enabled = false
		end
	end)

	TextChatService.MessageReceived:Connect(function(message)
		local source = message.TextSource
		if not source then
			return
		end

		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker then
			createBillboard(speaker, message.Text)
		end
	end)
end

function ProximityChatController.start()
	if started then
		return
	end
	started = true

	connectPlayerChat()

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ProximitySpeech")
	remote.OnClientEvent:Connect(function(speaker, text)
		if typeof(text) == "string" then
			createBillboard(speaker, text)
		end
	end)

	RunService.RenderStepped:Connect(updateMessages)
end

return ProximityChatController