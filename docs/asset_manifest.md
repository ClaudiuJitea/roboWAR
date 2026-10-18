# Asset manifest

| Asset | Source | Status |
| --- | --- | --- |
| Bastion, Ronin, Marshal, Nova, Hex, Kestrel `.glb` | `source_art/blender/build_fighters.py` and matching `.blend` | Rigged armored models; six distinct weapons/colors, 16 clips each |
| Fighter previews | `source_art/blender/render_fighters.py` | Front, side, gameplay angle for all six |
| Arena geometry and materials | `scripts/arena.gd` | Procedural modular industrial arena |
| Enemy and boss visuals | `scripts/actor.gd` | Procedural low-detail dark automata |
| Weapon and impact effects | `scripts/game.gd`, `scripts/projectile.gd` | Procedural beams, projectiles, flashes |
| Audio | `scripts/game.gd` | Runtime synthesized SFX and music; no external samples |
| Reference images 1–4 | User supplied | Reference only; excluded from export |

Animation manifest: `idle`, `run`, `attack`, `special`, `dodge`, `hit`, `death`, `downed`, `revive`, `victory`, `combo_1`, `combo_2`, `combo_3`, `spin`, `charge`, and `cast` are exported from Blender for each fighter. Godot plays them in `scripts/actor.gd`; combat timing runs independently from visual playback. Weapon grips and pose polish remain.
