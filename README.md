# Roblox FPS Maze

Early Roblox prototype for a slow tactical free-for-all FPS with controlled procedural map variation.

## Current state

Implemented prototype systems:

- Rojo project foundation
- generated apartment-floor test map
- randomized room access, obstacle placement, and player spawns
- forced first-person camera
- tactical walking, sprinting, and crouching
- jumping disabled
- basic spatial footstep audio
- temporary roaming NPC for solo testing
- proximity text affected by distance, walls, fading, and muffled gibberish
- automatically equipped prototype sidearm
- server raycast hit detection, ammo, reloads, damage, and headshots
- temporary NPC detection, aiming, line-of-sight checks, inaccurate firing, and player damage
- no respawns during the active round
- basic last-survivor result message

## Controls

- Move: standard Roblox movement controls
- Sprint: hold `Left Shift`
- Crouch: press `C` or `Left Control`
- Fire: left mouse button
- Reload: `R`
- Jump: disabled

Controller and temporary touch actions are also bound for prototype testing.

## Structure

- `src/client` — camera, input, HUD, proximity text, and client audio/effects
- `src/server` — map generation, movement validation, combat validation, test NPC, and round tracking
- `src/shared` — shared map, movement, chat, NPC, and weapon configuration
- `default.project.json` — Rojo project mapping

## Syncing

1. Clone the repository.
2. Install Rojo.
3. Run `rojo serve` from the repository folder, or start the project through the VS Code Rojo extension.
4. Connect using the Rojo plugin in Roblox Studio.

## Prototype limitations

- The sidearm and NPC weapon models are generated block placeholders.
- Gunshots are currently silent until a suitable firearm sound is added.
- The tracer, hit marker, and HUD are temporary testing effects.
- The NPC combat behavior is only for solo testing and does not use advanced searching, cover, hearing, or tactical decision-making.
- A finished round does not yet regenerate the map or start another round.
- Footsteps currently use one placeholder built-in sound for every surface.
- Crouching lowers the camera and movement speed but does not yet resize the character collision body.
- Client requests are validated by the server, but the prototype is not presented as exploit-proof.
- The apartment map uses plain blocks and is only intended for gameplay testing.
