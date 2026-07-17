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
