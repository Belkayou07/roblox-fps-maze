local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Competitive rounds have finite lives. RoundService loads the initial character
-- after the generated map exists, and eliminated players do not auto-respawn.
Players.CharacterAutoLoads = false

local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local ApartmentGenerator = require(script.map.ApartmentGenerator)
local MovementService = require(script.player.MovementService)
local WeaponService = require(script.combat.WeaponService)
local RoundService = require(script.round.RoundService)
local TestNpcService = require(script.testing.TestNpcService)

MovementService.start()
WeaponService.start()
ApartmentGenerator.generate(MapConfig)
RoundService.start()
TestNpcService.start()