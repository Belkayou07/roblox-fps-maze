-- Shared movement values for the tactical first-person prototype.

return {
	WalkSpeed = 8,
	SprintSpeed = 13,
	CrouchSpeed = 4,
	CrouchCameraOffset = Vector3.new(0, -1.4, 0),
	RequestCooldown = 0.05,

	Footsteps = {
		SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		MinimumMovingSpeed = 1,
		RollOffMinDistance = 4,
		RollOffMaxDistance = 45,

		Profiles = {
			Walk = {
				Volume = 0.32,
				PlaybackSpeed = 0.9,
			},
			Sprint = {
				Volume = 0.7,
				PlaybackSpeed = 1.25,
			},
			Crouch = {
				Volume = 0.1,
				PlaybackSpeed = 0.65,
			},
		},
	},
}
