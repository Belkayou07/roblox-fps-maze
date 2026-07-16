-- Shared configuration for the first apartment-floor prototype.
-- These values can be changed without rewriting the generator.

return {
	MapName = "ApartmentPrototype",
	Origin = Vector3.new(0, 2, 0),

	FloorLength = 150,
	FloorDepth = 80,
	FloorThickness = 1,
	CorridorWidth = 14,

	WallHeight = 16,
	WallThickness = 1,
	DoorWidth = 6,
	DoorHeight = 10,

	RoomCountPerSide = 3,
	OpenRoomChance = 0.65,
	MinimumOpenRoomsPerSide = 2,

	SpawnCount = 4,
	AddCeiling = true,

	Colors = {
		Floor = Color3.fromRGB(79, 78, 74),
		Wall = Color3.fromRGB(154, 151, 142),
		Ceiling = Color3.fromRGB(110, 108, 103),
		Door = Color3.fromRGB(63, 48, 39),
		Obstacle = Color3.fromRGB(92, 82, 68),
	},
}