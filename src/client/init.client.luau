local MovementController = require(script.movement.MovementController)
local FootstepController = require(script.audio.FootstepController)
local ProximityChatController = require(script.chat.ProximityChatController)
local WeaponController = require(script.combat.WeaponController)

MovementController.start()
FootstepController.start()
ProximityChatController.start()
WeaponController.start()