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

local MUFFLED_CHARACTERS = { "m", "h", "n", "s", ".", "?" }
local CLARITY_STEPS = 12

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

local function isLetter(character: string): boolean
	return character:match("[A-Za-z]") ~= nil
end

local function corruptText(originalText: string, clarity: number, seed: number): string
	if clarity >= 0.96 then
		return originalText
	end

	local bucket = math.floor(math.clamp(clarity, 0, 1) * CLARITY_STEPS + 0.5)
	local bucketClarity = bucket / CLARITY_STEPS
	local output = table.create(#originalText)

	for index = 1, #originalText do
		local character = originalText:sub(index, index)

		if not isLetter(character) then
			output[index] = character
			continue
		end

		-- The result is deterministic for a message and clarity level. Text does not
		-- flicker every frame while the listener remains at roughly the same range.
		local keepNoise = (math.noise(seed * 0.013, index * 0.173, bucket * 0.287) + 1) * 0.5
		local keepChance = bucketClarity ^ 0.72

		if keepNoise <= keepChance then
			output[index] = character
		else
			local replacementNoise = (math.noise(seed * 0.031, index * 0.419, bucket * 0.113) + 1) * 0.5
			local replacementIndex = math.clamp(
				math.floor(replacementNoise * #MUFFLED_CHARACTERS) + 1,
				1,
				#MUFFLED_CHARACTERS
			)
			output[index] = MUFFLED_CHARACTERS[replacementIndex]
		end
	end

	return table.concat(output)
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
	-- Keep the text drawable through geometry. The raycast system below controls
	-- how faint and unreadable it becomes when a wall blocks the speaker.
	gui.AlwaysOnTop = true
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
		OriginalText = text,
		CreatedAt = os.clock(),
		Destroyed = false,
		Visibility = 0,
		Clarity = 0,
		LastClarityBucket = -1,
		Seed = math.floor(os.clock() * 1000) % 100000 + #text * 97,
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
		local targetVisibility = 0
		local targetClarity = 0

		if listenerHead and speakerHead then
			local distance = (listenerHead.Position - speakerHead.Position).Magnitude
			local distanceClarity = 1 - math.clamp(
				(distance - ProximityChatConfig.FullClarityDistance)
					/ (ProximityChatConfig.MaximumDistance - ProximityChatConfig.FullClarityDistance),
				0,
				1
			)
			local visible = hasLineOfSight(listenerHead, speakerHead)
			local visibilityMultiplier = if visible then 1 else ProximityChatConfig.OccludedVisibility
			local clarityMultiplier = if visible then 1 else ProximityChatConfig.OccludedClarity

			targetVisibility = distanceClarity * visibilityMultiplier
			targetClarity = distanceClarity * clarityMultiplier
		end

		local blend = 1 - math.exp(-ProximityChatConfig.VisibilityResponsiveness * deltaTime)
		record.Visibility += (targetVisibility - record.Visibility) * blend
		record.Clarity += (targetClarity - record.Clarity) * blend

		local clarityBucket = math.floor(math.clamp(record.Clarity, 0, 1) * CLARITY_STEPS + 0.5)
		if clarityBucket ~= record.LastClarityBucket then
			record.LastClarityBucket = clarityBucket
			record.Label.Text = corruptText(record.OriginalText, clarityBucket / CLARITY_STEPS, record.Seed)
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
