-- Shared values for the first server-validated combat prototype.
-- These numbers are intentionally simple and will need proper balancing later.

return {
	ToolName = "Prototype Sidearm",

	MagazineSize = 8,
	BodyDamage = 34,
	HeadshotMultiplier = 1.75,
	FireInterval = 0.32,
	ReloadTime = 1.65,
	MaximumRange = 250,

	-- The client supplies camera aim, but the server rejects impossible origins,
	-- backward shots, excessive fire rates, invalid ammo use, and wall penetration.
	OriginTolerance = 8,
	MaximumAimYawDegrees = 100,
	RequestCooldown = 0.03,

	Tool = {
		HandleSize = Vector3.new(0.45, 0.7, 1.6),
		HandleColor = Color3.fromRGB(48, 49, 52),
		Grip = CFrame.new(0, -0.15, -0.75) * CFrame.Angles(0, math.rad(180), 0),
	},

	Effects = {
		TracerLifetime = 0.07,
		ImpactLifetime = 0.12,

		-- The old built-in rocket sound was misleading and has been muted.
		-- A proper firearm recording will be added during the audio pass.
		ShotSoundId = "rbxasset://sounds/Rocket shot.wav",
		ShotSoundVolume = 0,
		ShotSoundPlaybackSpeed = 1,
		ShotSoundMaxDistance = 120,
	},
}