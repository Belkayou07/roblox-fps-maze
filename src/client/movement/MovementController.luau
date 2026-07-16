local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.MovementConfig)

local MovementController = {}

local ACTION_PRIORITY = 3000
local player = Players.LocalPlayer
local movementRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MovementState")

local humanoid = nil
local currentState = nil
local sprintHeld = false
local crouching = false
local started = false

local SPEED_BY_STATE = {
	Walk = MovementConfig.WalkSpeed,
	Sprint = MovementConfig.SprintSpeed,
	Crouch = MovementConfig.CrouchSpeed,
}

local function setMovementState(nextState, force)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if not force and currentState == nextState then
		return
	end

	currentState = nextState
	humanoid.WalkSpeed = SPEED_BY_STATE[nextState]
	humanoid.CameraOffset = if nextState == "Crouch" then MovementConfig.CrouchCameraOffset else Vector3.zero
	movementRemote:FireServer(nextState)
end

local function refreshMovementState()
	if crouching then
		setMovementState("Crouch")
	elseif sprintHeld then
		setMovementState("Sprint")
	else
		setMovementState("Walk")
	end
end

local function handleSprint(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprintHeld = true
		if not crouching then
			refreshMovementState()
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprintHeld = false
		if not crouching then
			refreshMovementState()
		end
	end

	return Enum.ContextActionResult.Sink
end

local function handleCrouch(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end

	crouching = not crouching
	refreshMovementState()

	return Enum.ContextActionResult.Sink
end

local function blockJump()
	return Enum.ContextActionResult.Sink
end

local function configureCharacter(character)
	humanoid = character:WaitForChild("Humanoid")
	sprintHeld = false
	crouching = false
	currentState = nil

	player.CameraMode = Enum.CameraMode.LockFirstPerson
	humanoid.AutoJumpEnabled = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	setMovementState("Walk", true)

	humanoid.Died:Connect(function()
		if humanoid and humanoid.Parent == character then
			humanoid = nil
		end
	end)
end

function MovementController.start()
	if started then
		return
	end
	started = true

	ContextActionService:BindActionAtPriority(
		"TacticalSprint",
		handleSprint,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle("TacticalSprint", "Sprint")

	ContextActionService:BindActionAtPriority(
		"TacticalCrouch",
		handleCrouch,
		true,
		ACTION_PRIORITY,
		Enum.KeyCode.C,
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:SetTitle("TacticalCrouch", "Crouch")

	ContextActionService:BindActionAtPriority(
		"DisableJump",
		blockJump,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)

	player.CharacterAdded:Connect(configureCharacter)
	if player.Character then
		task.spawn(configureCharacter, player.Character)
	end
end

return MovementController
