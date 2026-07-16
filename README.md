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

Weapons, rounds, elimination logic, polished maps, and final audio are not implemented yet.

## Controls

- Move: standard Roblox movement controls
- Sprint: hold `Left Shift`
- Crouch: press `C` or `Left Control`
- Jump: disabled

Controller and temporary touch actions are also bound for prototype testing.

## Structure

- `src/client` — camera, input, and client audio
- `src/server` — map generation and server movement validation
- `src/shared` — shared map and movement configuration
- `default.project.json` — Rojo project mapping

## Syncing

1. Clone the repository.
2. Install Rojo.
3. Run `rojo serve` from the repository folder, or start the project through the VS Code Rojo extension.
4. Connect using the Rojo plugin in Roblox Studio.

## Prototype limitations

- Footsteps currently use one placeholder built-in sound for every surface.
- Crouching lowers the camera and movement speed but does not yet resize the character collision body.
- Movement speed requests are validated by the server, but the prototype is not presented as exploit-proof.
- The apartment map uses plain blocks and is only intended for gameplay testing.
