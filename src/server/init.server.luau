local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local ApartmentGenerator = require(script.map.ApartmentGenerator)

ApartmentGenerator.generate(MapConfig)
