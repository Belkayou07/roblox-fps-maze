local MovementController = require(script.movement.MovementController)
local FootstepController = require(script.audio.FootstepController)
local ProximityChatController = require(script.chat.ProximityChatController)

MovementController.start()
FootstepController.start()
ProximityChatController.start()