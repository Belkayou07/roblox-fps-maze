local Workspace = game:GetService("Workspace")

local ApartmentGenerator = {}

local GENERATED_MAP_NAME = "GeneratedMap"

local function createPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createWallWithOpening(
	parent: Instance,
	name: string,
	center: Vector3,
	length: number,
	wallHeight: number,
	wallThickness: number,
	doorWidth: number,
	doorHeight: number,
	alongX: boolean,
	color: Color3
)
	local sideLength = (length - doorWidth) / 2
	local horizontalOffset = doorWidth / 2 + sideLength / 2
	local wallY = center.Y + wallHeight / 2

	if alongX then
		createPart(parent, name .. "Left", Vector3.new(sideLength, wallHeight, wallThickness), Vector3.new(center.X - horizontalOffset, wallY, center.Z), color)
		createPart(parent, name .. "Right", Vector3.new(sideLength, wallHeight, wallThickness), Vector3.new(center.X + horizontalOffset, wallY, center.Z), color)
		createPart(parent, name .. "Header", Vector3.new(doorWidth, wallHeight - doorHeight, wallThickness), Vector3.new(center.X, center.Y + doorHeight + (wallHeight - doorHeight) / 2, center.Z), color)
	else
		createPart(parent, name .. "Left", Vector3.new(wallThickness, wallHeight, sideLength), Vector3.new(center.X, wallY, center.Z - horizontalOffset), color)
		createPart(parent, name .. "Right", Vector3.new(wallThickness, wallHeight, sideLength), Vector3.new(center.X, wallY, center.Z + horizontalOffset), color)
		createPart(parent, name .. "Header", Vector3.new(wallThickness, wallHeight - doorHeight, doorWidth), Vector3.new(center.X, center.Y + doorHeight + (wallHeight - doorHeight) / 2, center.Z), color)
	end
end

local function chooseOpenRooms(random: Random, roomCount: number, minimumOpen: number, openChance: number): { boolean }
	local states = table.create(roomCount, false)
	local openCount = 0

	for index = 1, roomCount do
		states[index] = random:NextNumber() <= openChance
		if states[index] then
			openCount += 1
		end
	end

	while openCount < minimumOpen do
		local index = random:NextInteger(1, roomCount)
		if not states[index] then
			states[index] = true
			openCount += 1
		end
	end

	return states
end

local function createSpawn(parent: Instance, name: string, position: Vector3)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = position
	spawn.Transparency = 0.45
	spawn.Material = Enum.Material.ForceField
	spawn.Parent = parent
end

function ApartmentGenerator.generate(config)
	local existing = Workspace:FindFirstChild(GENERATED_MAP_NAME)
	if existing then
		existing:Destroy()
	end

	local random = Random.new()
	local map = Instance.new("Model")
	map.Name = GENERATED_MAP_NAME
	map.Parent = Workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = map

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = map

	local origin = config.Origin
	local floorLength = config.FloorLength
	local floorDepth = config.FloorDepth
	local floorY = origin.Y
	local roomCount = config.RoomCountPerSide
	local roomLength = floorLength / roomCount
	local roomDepth = (floorDepth - config.CorridorWidth) / 2
	local northRoomCenterZ = origin.Z - (config.CorridorWidth / 2 + roomDepth / 2)
	local southRoomCenterZ = origin.Z + (config.CorridorWidth / 2 + roomDepth / 2)

	createPart(geometry, "Floor", Vector3.new(floorLength, config.FloorThickness, floorDepth), origin, config.Colors.Floor, Enum.Material.Concrete)

	if config.AddCeiling then
		createPart(geometry, "Ceiling", Vector3.new(floorLength, config.FloorThickness, floorDepth), origin + Vector3.new(0, config.WallHeight, 0), config.Colors.Ceiling, Enum.Material.Concrete)
	end

	local wallY = floorY + config.WallHeight / 2
	createPart(geometry, "OuterNorth", Vector3.new(floorLength, config.WallHeight, config.WallThickness), Vector3.new(origin.X, wallY, origin.Z - floorDepth / 2), config.Colors.Wall)
	createPart(geometry, "OuterSouth", Vector3.new(floorLength, config.WallHeight, config.WallThickness), Vector3.new(origin.X, wallY, origin.Z + floorDepth / 2), config.Colors.Wall)
	createPart(geometry, "OuterWest", Vector3.new(config.WallThickness, config.WallHeight, floorDepth), Vector3.new(origin.X - floorLength / 2, wallY, origin.Z), config.Colors.Wall)
	createPart(geometry, "OuterEast", Vector3.new(config.WallThickness, config.WallHeight, floorDepth), Vector3.new(origin.X + floorLength / 2, wallY, origin.Z), config.Colors.Wall)

	local northOpen = chooseOpenRooms(random, roomCount, config.MinimumOpenRoomsPerSide, config.OpenRoomChance)
	local southOpen = chooseOpenRooms(random, roomCount, config.MinimumOpenRoomsPerSide, config.OpenRoomChance)

	for roomIndex = 1, roomCount do
		local roomCenterX = origin.X - floorLength / 2 + roomLength * (roomIndex - 0.5)

		createWallWithOpening(geometry, `NorthRoom{roomIndex}Front`, Vector3.new(roomCenterX, floorY, origin.Z - config.CorridorWidth / 2), roomLength, config.WallHeight, config.WallThickness, config.DoorWidth, config.DoorHeight, true, config.Colors.Wall)
		createWallWithOpening(geometry, `SouthRoom{roomIndex}Front`, Vector3.new(roomCenterX, floorY, origin.Z + config.CorridorWidth / 2), roomLength, config.WallHeight, config.WallThickness, config.DoorWidth, config.DoorHeight, true, config.Colors.Wall)

		if not northOpen[roomIndex] then
			createPart(geometry, `NorthRoom{roomIndex}LockedDoor`, Vector3.new(config.DoorWidth, config.DoorHeight, 0.5), Vector3.new(roomCenterX, floorY + config.DoorHeight / 2, origin.Z - config.CorridorWidth / 2), config.Colors.Door, Enum.Material.Wood)
		end

		if not southOpen[roomIndex] then
			createPart(geometry, `SouthRoom{roomIndex}LockedDoor`, Vector3.new(config.DoorWidth, config.DoorHeight, 0.5), Vector3.new(roomCenterX, floorY + config.DoorHeight / 2, origin.Z + config.CorridorWidth / 2), config.Colors.Door, Enum.Material.Wood)
		end

		if roomIndex < roomCount then
			local dividerX = origin.X - floorLength / 2 + roomLength * roomIndex
			createPart(geometry, `NorthDivider{roomIndex}`, Vector3.new(config.WallThickness, config.WallHeight, roomDepth), Vector3.new(dividerX, wallY, northRoomCenterZ), config.Colors.Wall)
			createPart(geometry, `SouthDivider{roomIndex}`, Vector3.new(config.WallThickness, config.WallHeight, roomDepth), Vector3.new(dividerX, wallY, southRoomCenterZ), config.Colors.Wall)
		end
	end

	local obstacleX = random:NextNumber(-floorLength * 0.25, floorLength * 0.25)
	createPart(geometry, "CorridorObstacle", Vector3.new(8, 5, 4), Vector3.new(origin.X + obstacleX, floorY + 2.5, origin.Z), config.Colors.Obstacle, Enum.Material.WoodPlanks)

	local spawnPositions = {
		Vector3.new(origin.X - floorLength * 0.38, floorY + 1, origin.Z),
		Vector3.new(origin.X + floorLength * 0.38, floorY + 1, origin.Z),
		Vector3.new(origin.X - floorLength * 0.16, floorY + 1, northRoomCenterZ),
		Vector3.new(origin.X + floorLength * 0.16, floorY + 1, southRoomCenterZ),
	}

	for index = 1, math.min(config.SpawnCount, #spawnPositions) do
		createSpawn(spawns, `Spawn{index}`, spawnPositions[index])
	end

	map:SetAttribute("GeneratedAt", os.time())
	return map
end

return ApartmentGenerator
