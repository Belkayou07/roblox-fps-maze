-- Temporary solo-testing NPC settings.

return {
	Name = "Test Subject",
	SpawnHeight = 3,
	MinimumPause = 1.25,
	MaximumPause = 3.75,
	CrouchHipOffset = 1.15,

	StateWeights = {
		Walk = 0.55,
		Sprint = 0.25,
		Crouch = 0.20,
	},

	Pathfinding = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	},

	Combat = {
		Enabled = true,
		DetectionRange = 78,
		FireRange = 68,
		ScanInterval = 0.12,
		LoseTargetAfter = 2.25,

		MinimumReactionTime = 0.55,
		MaximumReactionTime = 1.0,
		MinimumShotInterval = 0.85,
		MaximumShotInterval = 1.25,

		Damage = 18,
		HeadshotMultiplier = 1.4,
		AimSpreadDegrees = 5.5,

		WeaponPropSize = Vector3.new(0.35, 0.55, 1.25),
		WeaponPropColor = Color3.fromRGB(52, 53, 56),
		WeaponGrip = CFrame.new(0, -0.2, -0.7) * CFrame.Angles(0, math.rad(180), 0),
	},

	Speech = {
		Enabled = true,
		MinimumDelay = 8,
		MaximumDelay = 17,
		Lines = {
			"...",
			"Did you hear that?",
			"Who's there?",
			"I know someone is nearby.",
			"This place keeps changing.",
			"Stay quiet.",
		},
	},
}
