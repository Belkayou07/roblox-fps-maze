local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local ApartmentGenerator = require(script.map.ApartmentGenerator)
local MovementService = require(script.player.MovementService)

MovementService.start()
ApartmentGenerator.generate(MapConfig)
