# Lantern Keep — Wisp Rush

[![roblox-game-01](https://make.fun/bounty/roblox-game-01)](https://make.fun/bounty/roblox-game-01)

A 3D arena collector for Roblox, built for the
[make.fun roblox-game-01 bounty](https://make.fun/bounty/roblox-game-01)
("Make the best Roblox game").

You are the keeper of a night lantern keep. Collect glowing teal wisps to
light the three lantern zones, dodge the red shadow wisps that steal your
hearts, and survive all 5 waves — in the last wave the giant Wisp King
hunts you while you gather the final 15 wisps.

## How to play

- **Move:** WASD (default Roblox camera and controls).
- **Collect:** touch a teal wisp. Chained collects within 4 seconds build a
  combo multiplier up to x5.
- **Dodge:** red shadow wisps chase you. Touching one costs 1 heart and
  briefly makes you invulnerable (red screen flash + camera shake).
- **Dash:** Space — a quick burst with a short invulnerability window
  (3 second cooldown).
- **Win:** finish wave 5 by collecting 15 wisps while the Wisp King chases
  you. **Lose:** all 3 hearts gone, or a wave timer runs out too often.
- Each wave lights one more lantern zone; wave 5 lights the whole keep.

## How to run

Requires [Rojo 7.7.1](https://rojo.space/) and Node 22+.

```sh
rojo build default.project.json --output game.rbxl
```

Open `game.rbxl` in Roblox Studio and press Play. To hand the entry in:

```sh
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to
the output directory and writes `dossier.json` with the vendored
`vendor/makefun-roblox.ts` library. Running it twice produces a
byte-for-byte identical `dossier.json` (verified in a scratch copy).

## Structure

| File | Job |
| --- | --- |
| `src/shared/Config.luau` | All tuning: wave table, points, speeds, palette |
| `src/shared/StateStore.luau` | The one place game state lives (server writes, client mirrors) |
| `src/server/GameServer.server.luau` | Server entry: Lobby → Playing → Won/Lost state machine |
| `src/server/WaveDirector.luau` | Spawns wisps / shadow wisps / Wisp King, wave progress |
| `src/server/ScoreKeeper.luau` | Points, combo, hearts |
| `src/client/GameClient.client.luau` | Client entry: wires HUD, input, effects to the remotes |
| `src/client/HudController.luau` | HUD, start screen, end screen (built in code) |
| `src/client/InputController.luau` | Dash via ContextActionService (Space) |
| `src/client/EffectsController.luau` | Camera shake, red flash, particle bursts, tweens |

The arena (baseplate, walls with neon trim, central keep, 3 lantern
zones, crystals, trees) is declared in `default.project.json`. Lighting
is a dark indigo night with warm gold lanterns.

## Notes

- **No external assets.** No asset IDs, no uploaded sounds or images;
  all feedback is visual (TweenService, flashes, camera shake,
  particles) using only built-in Roblox textures.
- **Screenshots & PLAY.json are pending publish.** `screenshots/` is
  intentionally empty and `PLAY.json` still holds the placeholder
  (`place_id` 0). Real screenshots can only be taken from Roblox Studio,
  and the place IDs only exist after the experience is published as
  Public from Studio — both are the account owner's steps, not part of
  this build.

## License

MIT — see [LICENSE](LICENSE).
