# Verification record

## Environment

- Godot: 4.7.2.stable.official.ed1daf0bf
- Blender: 5.2.2 LTS
- Renderer: Vulkan Forward+ on Intel Iris Xe Graphics (ADL GT2)
- OS: Linux desktop
- Physics: Jolt, 60 physics ticks per second

## Checks run

- Godot project import and script parse: passed after excluding `.blend` sources from import.
- Gameplay check: hitscan damage, friendly-fire filtering, health upgrade, pause timers, enemy cleanup passed.
- Roster check: all six `.glb` models loaded; all six primary and special actions executed; two-controller ownership passed.
- Revive check: human and AI companion each revived the other.
- Archetype check: boss alternated charge and radial attack; shield reduced frontal damage.
- Progression check: ten waves, four upgrade breaks, boss death, victory results passed.
- Visual capture: `evidence/arena.png`, `evidence/crowd.png`, `evidence/menu.png`; fighter previews under `evidence/fighters/`.
- Desktop export: `exports/Sector03.x86_64` plus `exports/Sector03.pck` created and launched headlessly.

## Short crowd run

At 1920 × 1080 on Intel Iris Xe, a warmed four-second Forward+ run with 73 live common enemies and two rigged heroes averaged 59.75 FPS, 18.0 ms process time, and 6.1 ms physics time from Godot monitors. A four-second run with Effects set to zero had 68 live enemies and averaged 60.0 FPS, 20.0 ms process time, and 5.7 ms physics time. Returning to full effects with 65 enemies averaged 59.8 FPS and 19.5 ms process time. These samples are short and have changing enemy counts; sustained 60 FPS at 80–120 enemies is not established.

## Arena and camera restyle (2026-10-11)

- The arena and enemy visuals were rebuilt in Blender 5.2.2 through the Blender MCP add-on socket on port 9876 with `source_art/blender/build_arena.py`.
- The camera changed from a 37° orthographic view to a perspective follow camera. It uses a 38° FOV and pitches down about 55°. The sun is low, the sky fill is cool, and SSAO, glow and AgX tonemapping are on.
- After the change, the gameplay, roster, revive, archetype, progression and smoke checks all passed.
- In the 1920 × 1080 crowd benchmark on Intel Iris Xe with 74 enemies, full effects averaged 59.8 FPS and 17.7 ms process time. Effects at 0 averaged 59.4 FPS. An 8192 shadow map with MSAA 2× dropped full effects to 32 FPS, so the project uses the default shadow map size and FXAA.

## Fighter redesign and muzzle fix (2026-10-11)

- All six fighters were rebuilt through the Blender MCP add-on to match the "The Six" reference sheet. They have large rounded helmets with a low visor, cream ceramic plates over a black undersuit, accent shoulder pads and chunky boots. Magnus is bulkier, while Albert and Seren are leaner. Line-up: `evidence/fighters/lineup.png`.
- Bug fix: the fighter GLBs face +Z, but the game turned models so that -Z pointed at the aim, so every hero aimed its weapon behind itself. `actor.gd` now turns the imported model 180° inside a pivot.
- Each fighter has a `Muzzle_<Name>` marker on its weapon bone. Hitscan tracers, Seren's bolts and muzzle flashes start there. Damage rays still run at body height, so hit detection is unchanged. The roster test asserts that every muzzle sits in front of its fighter. Shot capture: `evidence/shot.png` (`tests/capture_shot.gd`).
- `tests/gameplay.gd` compared upgraded health against Magnus's base HP. It now uses the selected hero's base HP, because the test loads the saved fighter selection.
- With the screen locked, the desktop throttles windowed runs to 1 FPS, so these benchmarks used `--disable-vsync`. At 1920 × 1080 with about 73 enemies, full effects averaged 76–82 FPS and Effects 0 averaged 130 FPS.
- Running the fighter generator in the Blender GUI crashed Blender twice. The causes were mesh operators run under a context override, and a glTF or `.blend` write from a newly created scene. The script now builds meshes with bmesh and exports from the active scene. It runs cleanly both headless and over MCP.

## Menu restyle (2026-10-11)

- The main menu, run setup, settings, pause, upgrade and results screens follow the "Run setup" reference. They use a light plate background with a blue edge strip and an Orbitron display font with Share Tech Mono labels. Selected tiles are navy with lime text and have slanted edges, and the cards have clipped corners.
- Key rebinding moved into the settings screen. Squad modes and operatives are picked with tiles instead of drop-downs.
- Captures: `evidence/ui_*.png` (`tests/capture_ui.gd`). All gameplay tests still pass.

## Fighter carry poses (2026-10-11)

- Weapons and hands were held at crotch height in front of a white crotch plate with a coloured buckle, which read badly in the line-up. `build_fighters.py` now gives each fighter a carry pose, and a waist belt plate replaces the crotch plate:
  - Iris and Nadia shoulder their rifles at chest height, with the left hand under the fore-end.
  - Magnus carries the gatling on his gun side.
  - Theo raises his pistol at arm's length.
  - Albert holds his sword in a raised guard at his side.
  - Seren raises both gauntlets forward.
- The muzzle markers move with the weapons. Roster, gameplay, revive, archetype, progression and smoke checks pass.

## Weapons and effects (2026-10-11)

- There are seven swappable weapons: rifle, SMG, shotgun, railgun, rocket, grenade and plasma. Gun and projectile models were built through the Blender MCP add-on (`build_weapons.py`). All fighters now share a shouldered carry pose with a Grip socket, and the built-in per-hero weapons were removed. ElevenLabs generated the new sounds for each weapon, explosions, weapon switching, shattering and disintegration.
- The roster test mounts and fires all seven weapons on all six operatives, and checks that each muzzle sits in front of the fighter. Gameplay, revive, archetype, progression and smoke checks pass.
- Captures: `evidence/weapon_<id>.png` and `evidence/weapons_sheet.png` (`tests/capture_weapons.gd`).
- Crowd benchmark (vsync off, 1920 × 1080, about 68 enemies, with the AI partner firing): 63 FPS with full effects and 89 FPS with Effects 0. Projectile raycasts added a few milliseconds of physics time.

## HUD and ammo (2026-10-11)

- The HUD was rebuilt to the reference: a WAVE / TIME / KILLS strip at the top and one card per player in the bottom corners. Cards and ground rings follow the player colour, yellow for you and cyan for the partner. The partner's ring changed from pale green to cyan.
- Weapons have magazines that reload automatically. All checks pass after the change.

## Hit feel, explosions, railgun (2026-10-11)

- **Hits:** hitscan weapons used a thin ray from the body, so tracers could visibly cross a robot and miss. Shots now use `trace_shot`, which hits any robot whose body width overlaps the shot line (0.36–1.05 m depending on type). Enemies flash white and stagger briefly when hit. Common enemy HP dropped about 20%: Grunt 30, Runner 20, Brute 100, Shooter 28, Shield 60, Warden 1500. `tests/gameplay.gd` checks that an off-centre hit connects and a clear miss does not.
- **Shotgun sound:** regenerated as a single blast. The old clip was mostly the pump and reload.
- **Explosions:**
  - An orange fireball drawn over the smoke.
  - A dark rising smoke column, a dust ring, sparks and chunks.
  - Two shockwave rings and a fading scorch mark.
  - Rocket exhaust flame with a thick smoke trail.
  - Grenades blink, and show a danger ring at their blast radius until they detonate.
  - Fire and smoke vertex colours are treated as sRGB; before this, the orange rendered as beige.
- **Railgun:** charge time cut from 0.85 s to 0.3 s, magazine raised from 4 to 6, with a glowing orb that builds at the muzzle while charging.
- **Benchmark** (vsync off, 1920 × 1080, about 66 enemies): 65 FPS with full effects and 107 FPS with Effects 0.

## Natural movement (2026-10-11)

- **Cause of the freeze:** firing played a full-body "attack" clip that blocked the run cycle, so the legs froze mid-move.
- **New clips:** added in `build_fighters.py`: `aim` (breathing hold), a legs-only `run` with hip twist, `run_back`, `strafe_left`, `strafe_right`, `recoil` and `reload`.
- **Fighter AnimationTree** (`actor.gd`, `_setup_tree`):
  - **Legs:** a 2D blend space driven by velocity in the fighter's own frame, so they run, backpedal or strafe according to movement relative to where the fighter aims.
  - **Upper body:** filtered to the spine, arms, head and weapon, holding the aim and layering recoil, reload (timed to the reload length) and hit/special one-shots.
  - **Full body:** dodge, revive and victory play as full-body one-shots, and a life transition handles downed and dead.
- **Procedural extras:**
  - Stronger lean into movement.
  - A recoil kick that pushes the body back along the aim.
  - Footstep dust on each step.
  - Enemies rock back when hit.
- `tests/capture_motion.gd` saves frame strips of strafing, backpedalling and running while firing to `evidence/motion_*.png`. The roster test now checks the new clips and that the tree is active.
- Benchmark (vsync off, 1920 × 1080, about 69 enemies): 59 FPS with full effects and 88 FPS with Effects 0.
- Fixed a HUD error when a player card's fighter had already been freed.

## Display settings and clean exit (2026-10-11)

- Settings has a Display section with Fullscreen and V-sync toggles, saved in `user://sector03.cfg`. F11 or Alt+Enter toggles fullscreen anywhere. The weapon-switch bindings are now saved too.
- Removed the operative-card tooltips; their popups produced "disconnect a nonexistent connection" errors on the root window.
- Closing the window or pressing QUIT now stops the music and effects before the engine shuts down, so the leaked-instance and resource-in-use messages no longer print. Runs started with `--quit-after` skip this path and can still print them.

## Sheet characters and signature weapons (2026-10-11)

- The fighters were rebuilt to follow "The Six" sheet more closely:
  - **Helmets:** boxier, with a dark lower faceplate. Magnus, Iris and Seren have a wide glowing visor; Albert, Theo and Nadia have a single side eye.
  - **Accents per character:** helmet side panels (Theo left only; Iris, Seren and Nadia both), Albert's orange shoulder tops and hip panels, Magnus's large blue shoulder and forearm blocks, and Nadia's red thigh panels.
  - **Shared armour:** a cream chest vest and belly plate, elbow pads, chunkier gloves, and boots with toe and heel caps.
- The weapon kit (`build_weapons.py`) adds the six signature weapons. Each is weapon 1 in that hero's loadout (`Data.SIGNATURES`, `Data.loadout`), ahead of the seven shared guns:
  - **Minigun:** spinning `Spin_minigun` node.
  - **Energy blade:** melee arc with a crescent slash effect.
  - **Sidearm.**
  - **Rail rifle:** charges in 0.4 s.
  - **Arc gauntlets:** plasma bolts.
  - **Sniper:** pierces 2 targets.
- The `aim_blade` stance (blade low at the side, off arm relaxed) is solved in Blender by fitting the arm and weapon bones to target hand and blade positions. Godot swaps to it whenever a melee weapon is equipped, and `slash` swings start and end in it.
- Roster test: every operative starts with its signature weapon, mounts all 8 weapons, and fires each. Captures: `evidence/signature_<id>.png`, `evidence/signatures_sheet.png`, `evidence/fighters/lineup.png`.
- Limit: these are hard-surface models built from bevelled primitives. Matching the painted sheet exactly (sculpted forms, wear, hand-painted texture detail) needs an artist modelling and texturing pass.

## Gun orientation fix (2026-10-11)

- **Bug:** guns pointed upward in game. The fighter's `Grip_<Name>` socket was placed from the evaluated pose, and after `aim_blade` and `slash` were added, the top NLA track left the weapon bone tilted at export. The Grip is now computed from the rest bone (`build_fighters.py`).
- Albert's blade stance is now a blend (`stance` Blend2: `aim` / `aim_blade`) applied once the tree exists, so it shows at spawn and switches back cleanly when he changes to a gun.
- The roster test checks that every gun on every operative is within about 25° of level, and that blade users start in the blade stance. Close-up capture: `evidence/holding_sheet.png`.

## Blade combo and destroy sounds (2026-10-11)

- **Longer blade:** Albert's blade is 1.6 m instead of 1.0 m. The blade stance was re-solved with a shallower angle so the tip clears the floor.
- **Three-hit combo** (`slash_1` forehand sweep, `slash_2` backhand, `slash_3` overhead chop): each hit has wind-up, strike, follow-through and recovery, and plays at 1.6× speed.
  - Hits chain within 0.9 s.
  - Damage lands at the strike frame (about 0.16 s), with a step-in lunge. Hit 3 does 1.6× damage, has +0.5 m reach, a bigger lunge and a longer recovery.
  - A tapered additive trail is drawn from the real hilt and tip, only through the strike window.
  - A blade-hit sizzle plays on contact.
  - An AI-controlled Albert now closes to melee range.
- **Enemy destroyed sounds:** three ElevenLabs variants (`destroyed_1` to `destroyed_3`) play at random on every kill, at most one per 45 ms. The bullet, explosion and energy death sounds remain as a quieter layer.
- Capture: `evidence/blade_combo.png` (`tests/capture_blade.gd`). All checks pass.

## Blade stance and combo rework (2026-10-11)

- **Solver:** every blade key pose is now solved in Blender (`solve_pose`) from a target sword-hand position, blade direction and off-hand position, plus a fixed torso twist. A grip-lock term keeps the hilt in the fist, and each key is seeded from the previous one so the motion stays continuous.
- **Ready stance:** a two-handed guard with the blade raised forward and up, replacing the low side hold.
- **Combo:**
  - Hit 1: a shoulder wind-up into a flat forehand sweep at chest height.
  - Hit 2: a backhand sweep.
  - Hit 3: a 360° spinning finisher. Godot spins the body with an eased turn, and the hit covers the full circle.
- **Blade twirl:** the blade twirls when drawn, and again after 4.5 s idle with the sword out.
- Capture: `evidence/blade_combo.png`. All checks pass.

## Weapon stances and sniper feel (2026-10-11)

- **Weapon-class stances:** solved in Blender (`gun_stance_clips`), one per class:
  - Sniper (sniper, rail rifle, railgun): cheek weld, scope at the visor, support hand forward.
  - Pistol: one-handed and extended.
  - Heavy (minigun, rocket): hip carry.
  - Cast (gauntlets).
  - Gun (other shared guns) and blade keep their existing holds.
- **In Godot:** `Data` gives every weapon a `stance`, and the AnimationTree cross-fades between stance holds through a Transition node. Recoil and reload play stance-specific clips (`recoil_<stance>`, `reload_<stance>`), so the arms never snap back to the generic hold.
- **Sniper:** a heavy kick, then a bolt-cycle re-chamber with a shell eject and rack sound (both 0.36 s after the shot), a red laser sight with a pulsing dot, muzzle smoke, and a slight camera zoom while it's equipped. New ElevenLabs `sniper` shot and `rack` bolt sounds.
- **All weapons:** a camera recoil push along the shot, and a short hit-stop on heavy kills (Brute, boss, or hits of 60+ damage). Hit-stop is off when Effects is below 50%.
- **Portraits:** each shows the operative's signature stance. Capture: `evidence/sniper_sequence.png` (`tests/capture_sniper.gd`). All checks pass.

## Aim line, subtler cinematics, sniper pointer (2026-10-11)

- **Shots looked sideways while moving:** aim was computed on the floor under the cursor, but shots fly at gun height from the right hand. From the 55° camera, that line missed the cursor on screen by up to 86 px.
  - The mouse now aims where the cursor ray meets the actual muzzle height (`mouse_plane`), with magnetism onto a robot under the cursor (`mouse_aim`).
  - Every shot leaves the muzzle toward that point (`shot_dir`, `shot_origin`), and the damage line follows the same path.
  - Tracers and the railgun beam ride with the shooter for their short life.
  - `tests/aim_line.gd` strafes in four directions with four weapons and asserts that the shot line passes within 12 px of the cursor on screen (measured: 7 px windowed, about 9–10 px headless at 648p); it uses a virtual cursor so it runs headless.
- **Subtler cinematics:**
  - The camera nudge only applies to heavy weapons, at about a quarter of the previous strength.
  - The scoped zoom is reduced to 3%, and explosion shake is lower.
  - Hit-stop always triggers on the boss; otherwise it's a 20% chance on heavy kills, with a 9 s cooldown.
- **Sniper pointer:** a beam from the barrel to a camera-facing reticle (ring, four spinning ticks, centre dot) drawn over the scene. The reticle sits on the cursor and snaps tighter and faster when it locks onto a robot. Capture: `evidence/pointer_and_strafe.png` (`tests/capture_pointer.gd`).

## Upper-body filter bug, sniper eye level, per-wave cinematics (2026-10-11)

- **Root-cause bug:** on glTF import, Godot renames bones that clash with mesh names (`R_upper_arm` becomes `R_upper_arm_2`). The upper-body filter used fixed names, so the upper arms always came from the legs layer and every authored stance was only partly applied. That is why the sniper sat low and the head looked down, and why heavy and pistol guns tilted. The filter is now built from the skeleton's real bone names, matched on the base name.
- **Gun stances:** the solver gained level-barrel and no-cant terms, and the trigger-hand target is weighted more strongly.
- **Sniper:** the scope sits on taller rings, so it lines up with the visor (scope 1.62 m, eye 1.63 m) with the head upright.
- **Cinematics** (camera nudge, scoped zoom, freeze-frame) run from the start of each wave until its first kill, which gets the freeze-frame. After that they're off for the rest of the wave; the boss kill always gets one.
- All checks pass.

## Slow motion stuck on, once per run (2026-10-11)

- **Bug:** slow motion was ended by a timer callback that only reset the time scale if it fired at or after the exact millisecond target. When the timer fired a few milliseconds early, `Engine.time_scale` stayed slowed. It is now ended by a real-time clock check in `game._process`, so it can't stick.
- **Once per run:** the cinematic opening now runs from the start of a run until the first robot is destroyed. That kill gets a 0.35 s slow-motion beat at 0.25× speed, and there is no slow motion after it (the boss accent is removed).
- **Aim during slow motion:** mouse aim, fighter facing and the sniper pointer update on real time in `actor._process`, so the cursor target keeps moving while the game is slowed.
- `tests/cinematic.gd` plays into wave 2 and asserts: one short beat, none after the first kill, and aim tracking the cursor during the beat.

## New music and the Sector 07 arena (2026-10-11)

- **Music:** the old track was a 22 s sound-effect generation (the free plan returns 402 for the Music API). It's replaced by a composed 2-minute loop (`compose_music.py`) using ElevenLabs drum and FX one-shots, a sidechained bass, a delayed arpeggio, reverb pads and a lead in drop B. The spectrogram shows the intended arrangement. Nobody has listened to it yet; the levels are mastered to −16 LUFS.
- **Sector 07:** `build_arena.py` takes a palette theme. The black theme is built through the Blender MCP add-on as `arena_black.glb`, with emissive red accents, a painted "07", and the floor lifted to `#4a4d54` so the dark robots stay readable. `arena.gd` applies a matching dark environment (cool key light, red-tinted sky fill, five red work lights, stronger glow, light fog). The choice is on the run-setup screen and saved in `user://sector03.cfg`. Capture: `evidence/arena_black.png`.

## Compact, arena-themed HUD (2026-10-11)

- **Smaller HUD:** the top WAVE / TIME / KILLS strip and the player cards are about a third smaller. Values go from 24 to 16 px, cards from 300 to 220 px wide, and the HP bar from 11 to 6 px tall.
- **Theme:** the HUD, wave announcement and weapon tag follow the arena. Sector 03 uses light plates with a blue edge; Sector 07 uses dark smoked glass with a red edge and light text. Captures: `evidence/hud_white.png`, `evidence/hud_black.png`.

## Curved plasma sabre (2026-10-11)

- **New blade:** Albert's straight 1.6 m bar is replaced by a curved plasma sabre in `build_weapons.py`. It has a scimitar arc (1.55 m radius, 0.66 rad sweep) built as flat prisms from a 2D outline: a translucent orange-red aura, an orange-red plasma blade, and a slim white-hot core along the spine. The hilt is an emitter with ridged rings and a forked guard. The muzzle marker sits at the blade tip, so the swing trail follows the new tip.
- **Visibility:** a flat curved blade vanishes when seen edge-on from the overhead camera.
  - The pose solver gained a `flat` term that keeps the blade's face toward the sky in the guard and every swing key.
  - The guard now holds the sabre raised diagonally out to the side, not straight forward along the line of sight.
  - Albert's portrait is rendered from a higher camera so the curve shows.
- Rebuilt through the Blender MCP add-on. Portraits, line-up, signature captures and the run-setup screen are refreshed. All checks pass.

## Samurai katana (2026-10-11)

- **Plasma katana** (`build_weapons.py`, renamed PLASMA KATANA in game):
  - About 1.5 m with a gentle curve (sori), the edge on the convex side and an angled kissaki tip.
  - Wider layered plasma: aura, blade and a white-hot shinogi line.
  - A round tsuba guard and a 33 cm two-hand tsuka with wrap bands and a kashira pommel.
- **Kenjutsu clips** (`blade_clips`): each key is solved for a two-handed grip (left glove placed down the hilt) and an edge-direction term, so the cutting edge faces the cut, or faces down in the guard.
  - Chudan-no-kamae guard with breathing.
  - Kesa-giri: over the right shoulder, cutting diagonally down-left.
  - Gyaku-kesa: rising cut back up to the right.
  - Shomen-uchi: jodan raise, vertical cut with a fumikomi step-in, held zanshin. This replaces the 360° spin.
  - Chiburi: the blade flick, played on draw and after 5 s idle.
- Damage timing matches the strike keys. Captures: `evidence/blade_combo.png`, `evidence/holding_sheet.png`, `evidence/fighters/lineup.png`. All checks pass.

## Two-handed grips (2026-10-11)

- **Problem:** the pose solver treated the support hand as one soft target, so it ended up off the weapon. Measured gaps were 37 cm in the katana guard, 30 cm in the sniper hold and 23 cm in the heavy hip-carry. Between keys, the arms interpolated independently, so the hand drifted up to 44 cm mid-swing.
- **Fix in `build_fighters.py`:**
  - A second solving pass (`support`) pins the left glove onto a point on the weapon after it is aimed: the katana tsuka, the sniper fore-end or the heavy receiver.
  - Two-handed clips (katana guard, cuts and chiburi; sniper and heavy holds, recoil and reload) are baked on every frame (`bake_two_handed`), with eased interpolation and the support hand re-pinned each frame.
- **Result:** the worst gap is 0.03 m on all six fighters. `source_art/blender/check_hands.py` re-measures every frame and fails above 5 cm.
- The baked build takes about 43 minutes headless. It was run headless with the same script the MCP add-on executes.

## Arms reattached, both hands on every weapon (2026-10-11)

- **Root cause:** the arm armour pieces (upper arm, elbow, forearm, wrist, glove) had been moved in the model into the old rifle-hold position, away from the bones that carry them. Posing a bone then swung its piece around a far pivot, so forearms and gloves flew off or sank into the torso (the "missing hand"). The Grip socket also sat 70 cm from the right hand's real bone.
- **Fix in `build_fighters.py`:**
  - The pieces stay on their bones at rest (arms down), and the bones scale with each fighter's bulk.
  - The Grip and weapon bone sit in the right fist (`grip_point`), and elbow caps sit on the elbow pivot.
  - Every hold is a solved pose, including the shared-gun hold (`aim` / `recoil` / `reload`).
  - Two-handed poses are solved jointly: the support hand on the weapon is required, the shooting-hand position is a preference (held firm for guns), and a small chest twist is allowed.
  - Per-frame baking seeds from the previous frame and lets the weapon arm give slightly when the support hand is out of reach.
  - Support points sit within the robots' roughly 0.8 m arm reach: rifle magwell, sniper receiver.
- **In Godot:** hit, special and cast reactions go through a torso-only `flinch` layer, so they no longer drop the arms.
- **Checks:** `check_hands.py` now also checks that the right hand stays on the grip (0.000 m on all six) and that arm pieces stay connected (at most 1.9 cm). Left-hand gaps are at most 3 cm (the katana check is Albert only). The sniper scope sits at 1.64 m, against a visor at 1.74 m.
- Close-ups: `evidence/hands_closeup.png`.

## Clean holds: analytic arms, shoulder pads, gauntlets (2026-10-12)

- **Problem:** in play every fighter looked tangled. The numeric pose solver could twist each upper arm freely, bend elbows on three axes and turn the weapon in the wrist, starting from big steps. It met its hand targets with broken-looking poses: elbows up, pauldrons flipped up beside the helmet, weapons crossing the body. Seren's gauntlet model also floated 10 to 60 cm in front of her fist.
- **Fix in `build_fighters.py`:**
  - The solver is replaced by analytic two-bone IK (`Poser`). Elbows are hinges, and each elbow bends toward a pole direction, so there is no free upper-arm twist. The right elbow aims where the forearm runs straight into the wrist.
  - A fixed wrist offset gives a natural grip: the forearm runs behind the grip instead of hanging 90 degrees from it, and the weapon bone counter-turns about the grip point.
  - The chest blades (turns) only as much as needed for both hands to reach, and the head turns back to keep the visor on the target.
  - Pauldrons ride on new `L_shoulder` / `R_shoulder` bones that follow the upper arm 45% of the way. They are also added to the upper-body filter in `actor.gd`.
  - Every hold and motion is described as a weapon placement (grip, barrel or blade direction, up or edge, support point) and solved on every frame. A full six-fighter build now takes about 5 minutes, instead of about 50.
  - The katana guard (chudan) is raised and angled out to the right, so from the top-down camera the blade never reads through the body.
- **Seren:** `W_gauntlet` is now an armoured gauntlet worn over the right fist (knuckle guard, cuff, emitter), with its twin built onto her left glove.
- **Fix in `actor.gd`:** a sword cut still pending when the weapon is swapped mid-swing is dropped, instead of reading the gun's stats (script error found by the roster test).
- **Checks:** `check_hands.py` now also covers recoil clips, the pauldron tilt (upright in every stance) and elbows staying below the shoulders in gun stances.
  - All six fighters: left hand 0.00 m on every two-handed clip, right hand 0.000 m on the grip.
  - Arm pieces stay within 2.4 cm (4.8 cm in one fast katana frame).
  - All eight Godot tests pass.
- **Evidence:**
  - In-game, every fighter aiming four ways and running: `evidence/poses_sheet.png` (`tests/capture_poses.gd`).
  - Blender front and side holds: `evidence/fighters/holds_sheet.png`.

## Holds matched to "The Six" sheet (2026-10-12)

- **Feedback:**
  - Magnus looked exaggerated, and his other guns seemed to share the minigun pose.
  - Albert's centre two-handed guard read as holding his groin, with his hands stuck to his body.
  - Theo held a small pistol in one hand.
  - Iris kept her left hand tight to her body.
  - Seren's right hand did not show a hologram.
- **Causes:**
  - Every rifle-class hold sat at roughly the same height.
  - Magnus's left arm rose 82 degrees to reach the minigun's top handle.
  - Albert's free elbow stuck out at shoulder height.
  - The chest turn was uncapped.
- **Changes in `build_fighters.py`:**
  - Magnus: minigun low at the hip, off hand braced on the side of the receiver, elbows down. The shared rifles are now shouldered at chest height, so swapping weapons visibly changes the pose: hip carry, shoulder, or eye-level scope.
  - Albert: the sheet's ready guard. The katana is low in his right hand, the blade sweeps forward and down past the right foot, and the left fist hangs free. Both hands join the hilt for each cut, and the glove travels smoothly between the one-handed guard and the two-handed grip.
  - Theo: two-handed pro grip (arms extended, support glove wrapped on the grip, pistol just under the eye line). `W_pistol` is 1.5x larger.
  - Iris: new `rail` stance for the rail rifle (`data.gd` / `actor.gd`). The rifle sits at the hip, with the support hand out along the barrel and the elbow out.
  - Seren: right hand forward under a translucent holo panel (frame, scan lines) with a glowing palm ring. The left hand hangs low with its ring. The gauntlet's muzzle is in front of the palm.
  - The automatic chest turn is capped at 0.36 rad (about 20 degrees), and pauldrons follow the arm 30% of the way.
- **Checks:**
  - `check_hands.py` adds an arm-lift limit (upper arm under 75 degrees in held stances; the worst is the extended pistol, at 64 to 74 degrees). It covers the pistol, rail and recoil clips, and measures katana cuts only while both hands are on the hilt.
  - All six fighters pass: left hand at most 0.03 m, right hand 0.000 m.
  - All eight Godot tests pass.
- **Evidence:**
  - `evidence/poses_sheet.png`: gameplay camera.
  - `evidence/loadout_<n>.png`: side view of every weapon in a fighter's loadout (`tests/capture_loadout.gd`, `HERO=n`).
  - `evidence/fighters/holds_sheet.png`: Blender front and side views.

## Menu portraits regenerated (2026-10-12)

- The start-menu, squad-select and results portraits (`assets/ui/<name>.png`) were stale renders of the old holds, and nothing in the repo produced them.
- `render_fighters.py` now also renders a `portrait` view, three-quarter from the fighter's left like "The Six" sheet, so each weapon reads in profile.
- `source_art/blender/make_portraits.py` crops, scales and writes the 256 px transparent portraits. All six share one scale (Magnus stays bigger), with the feet on a common baseline.
- Evidence: `evidence/menu.png`.
- **Hero shots (later the same day):** the cards now use dedicated action poses. Each fighter has a one-frame `showcase` clip (`showcase_clip` in `build_fighters.py`, arms solved by the same IK so hands stay on the weapons). `render_showcase.py` grounds the pose and renders it with key, fill and two rim lights from a per-fighter low perspective camera.
  - Magnus: braced wide and low behind the minigun.
  - Albert: lunging, with the katana thrust up and out.
  - Theo: two-handed pistol from a staggered stance.
  - Iris: deep lunge, rail rifle shouldered.
  - Seren: holo panel raised beside her head, left palm thrust out.
  - Nadia: kneeling with the sniper.
  - `make_portraits.py` fills each card with its shot. Albert is framed on his body, with the blade running off the top edge. The game never plays the `showcase` clip.

## Auto aim option (2026-10-12)

- **Setting:** Settings > Feel > **AUTO AIM** (off by default), saved with the other preferences (`settings.autoaim`).
- **How it chooses (`game.auto_aim`):** with it on, the aim locks onto the best robot that meets all three conditions:
  - within 50 degrees of where the player aims (cursor or right stick);
  - within the current weapon's range (for the katana, its reach);
  - in line of sight.
- **Choosing between robots:** robots closer to the aim line win, then closer ones. The current lock is kept while it stays within 70 degrees, so the aim does not flicker between robots.
- **Controller:** an idle right stick aims at the nearest visible robot.
- **Test:** `tests/autoaim.gd` checks that with the setting off the shot follows the cursor, with it on the aim locks onto the robot near the cursor (not the one behind the player), and switching it off releases the lock. All nine tests pass.
- **Evidence:** `evidence/settings.png`.

## Kill cam every 9th kill (2026-10-12)

- `scripts/killcam.gd` (child of `game`) runs a 4 to 5 second cinematic on every 9th robot destroyed, and on the boss. It eases in over 1.1 s: the camera glides from the gameplay view while time slows gradually. It eases out over 1.2 s: the camera glides back while time recovers to full speed. Everything is blended by one smootherstep weight, so there are no hard cuts; this was changed after feedback that the shots were too fast and started and ended abruptly. The shot depends on how the robot died:
  - **Bullet cam (guns):** time nearly freezes, and a glowing round with a streak flies from the muzzle to the robot with the camera riding behind it. The robot stays intact until the round lands, then bursts, and the camera swings round the suspended wreck as time ramps back.
  - **Impact zoom (guns, alternating with the bullet cam):** a push-in from the shooter's shoulder onto the frozen robot, which bursts with a small camera kick.
  - **Blast crane (rockets, grenades, explosive kills):** starts low inside the blast and cranes up and away.
  - **Blade orbit (katana):** a low orbit around the swordsman and the robot.
- **Framing and timing:** letterbox bars and a "KILL #N // style" caption; the music dips to 35%. Everything runs on the real-time clock (the kill cam drives `Engine.time_scale`; `hitstop` defers to it). Heroes are protected for the shot, and it then blends back to the gameplay camera.
- **Robustness:** a robot held for the bullet cam or impact zoom is always released, even if the shot is cut short (run end, results screen).
- **Setting:** Settings > Feel > **KILL CAM** (on by default). `enemy_killed` passes the destruction as a callable, so the kill cam can time it to the on-screen impact.
- **Tests:**
  - `tests/killcam.gd` kills nine robots per style (pistol, pistol again for the alternate gun shot, rocket, katana). It checks the style, the camera takeover, gradual easing (time still above 0.6x just after the start and above 0.85x just before the end), no camera jump cuts (largest per-frame move 0.4 to 1.3 m, against an average of 0.12 to 0.17 m), that the shot ends, time back at 1.0 and the gameplay camera restored, and that nothing triggers with the setting off.
  - `tests/cinematic.gd` (the once-per-run first-kill slow motion) now runs with the kill cam off.
  - All ten tests pass.
- **Evidence:** `evidence/killcam_bullet.png`, `killcam_zoom.png`, `killcam_crane.png`, `killcam_orbit.png` (five frames across each shot).

## Blade kill cam: the cut replayed and sliced

- **Predicted:** when Albert starts a swing, the kill cam checks the blade arc (`game.melee_targets`, the same test the damage uses) against each robot's health. If the cut will make the 9th kill or kill the boss, the shot starts right then, while the robot is still alive. Time drops to 0.12x within 0.12 s and the camera is in by about 0.5 s, so the real blade connects (about 1.3 s real) inside the slowed shot. The kill is held for the slice and then plays out as below. The camera films from the side of the fight with more open floor.
- A blade kill that was not predicted (a robot that walked into the arc, say) falls back to the replay described next.
- The katana kill cam no longer cuts to the aftermath. The robot is held intact. Albert lunges in and replays his finishing cut (the same kesa / gyaku-kesa / shomen he killed with) in slow motion, with no damage. The camera sits side-on to the arc, and the blade trail is drawn across the whole swing.
- When the blade connects, time nearly freezes and the camera pushes in to a close-up on the cut (0.3 s), held for 1.3 s. The robot is sliced in two along the plane the blade actually travelled: each half is a copy of the robot with a clip shader, and the cut face glows. The top half starts sliding off at once, so the separation plays out inside the close-up. The camera then pulls out and swings round behind the robot as both halves burn up, kept clear of walls by a ray check. The swing trail fades on real time during the replay, so it does not hide the cut.
- The kill cam clock now runs on the wall clock, and the slice shader is compiled at the start of the shot. Before this, a frame stall on the first compile left the shot behind real time.
- **Evidence:** `evidence/killcam_blade_cut.png` (12 frames across the predicted, live blade shot, from `tests/blade_cut.gd`) and `evidence/killcam_orbit.png` (the replay fallback). `tests/blade_cut.gd`, `killcam.gd`, `gameplay.gd`, `cinematic.gd` and `capture_blade.gd` pass.

## Side-on menu portraits, Seren's caster hands (2026-10-15)

- **Problem:** the Magnus, Albert and Seren portraits were shot from the front or from the right, while Theo, Iris and Nadia face the right of the card side-on. Seren's gauntlets (a 16 cm drum cuff around a mitten glove with a flat plate or disc on the end) read as a hammer, not a hand.
- **Poses:** new `showcase` holds in `build_fighters.py`. Magnus is braced low in profile with the minigun barrels level. Albert is in a deep lunge, driving the katana forward and up (tsuki). Seren reaches out with her right palm up under the holo panel and draws her left hand back. `render_showcase.py` films all three from the fighter's left, like the other three.
- **Hands:** `source_art/blender/caster_hand.py` builds an armoured open hand: four jointed fingers with knuckle caps and glowing tips, a thumb, a back-of-hand plate, a glowing palm emitter and a slim bracer. `W_gauntlet` (right) and Seren's left glove (mirrored) share it. The cast stance is rolled palm up (`up=(1,0,0)`), and the holo panel floats over the palm.
- **Evidence:** `evidence/fighters/{magnus,albert,seren}_showcase.png`, `assets/ui/*.png`, `seren_gameplay.png`. `check_hands.py` passes. `roster.gd`, `archetypes.gd` and `gameplay.gd` pass.

## Known limits

- The Blender MCP add-on was reachable in the running Blender GUI on port 9876. All six fighter sources and GLB exports were regenerated through its command transport after correcting armature parenting.
- Fighters have a shared Blender armature and 16 exported clips, imported and played by Godot. The hard-surface rig is rigid weighted; holds are solved analytically (see above). Close-up animation polish (finger detail, cloth-like secondary motion) is not attempted.
- No manual controller playtest was performed on physical controllers. Input ownership and revive logic were exercised by scripts.
- Enemy navigation uses an A* grid plus local steering. A full long-run navigation playtest across all wave configurations has not been completed.
- Sound effects and the music loop come from the ElevenLabs sound-effects API. The plan returned 402 for the Music API, so the music is composed by `source_art/audio/compose_music.py` from ElevenLabs one-shots. Clips are trimmed and loudness-normalised with ffmpeg; the in-game mix (`SFX_GAIN` in `game.gd`) has not had a listening pass.

## Rifle and SMG redesign (2026-10-17)

- **Problem:** the shared rifle and SMG were a few rounded cream blocks on a pipe and read as toys.
- **Models** (`build_weapons.py`): a first pass built detailed military guns from side-profile solids (`Part.side`). The user then supplied reference sheets, and both guns were rebuilt in that blocky game style with slate, dark-inset, silver and orange materials.
  - Rifle (second pass, from the user's reference sheet): a chunky AK-style rifle traced at 3 mm per pixel. It has a slate box receiver and handguard with a gas-tube cover, a front sight block, a silver barrel, a two-tier red-dot sight, orange accents (handguard squares, top tab, charging handle, rear block, selector), a curved orange magazine with a dark base, a raked grip and a solid wedge stock. The accent is now orange `f2a01e`, the same as the SMG. It is scaled 1.15×, so it stays longer than the SMG; the muzzle is at `(0, -.83, .093)`. Renders: `evidence/rifle_redesign.png`, `evidence/rifle_ingame.png`.
  - SMG (second pass, from the user's reference sheet): a chunky game-style SMG like a UMP, traced from the reference side view at 2.3 mm per pixel. It has a slate-grey box receiver with a front block and dark side panels, a silver barrel stub, a two-tier red-dot sight, orange accents (top plate, charging handle, rear block, selector), a straight orange magazine, a raked-back grip and a skeleton triangle stock. The accent is now orange `f2a01e`. It is scaled 1.3× (like the pistol's 1.5×) so it shows past the gloves in the top-down view; the muzzle is at `(0, -.598, .107)`. Renders: `evidence/smg_redesign.png`, `evidence/smg_ingame.png`.
  - The grip origin and the 'gun' support point are unchanged, so the fighters did not need a rebuild.
- **Shotgun** (same day, from the user's third reference sheet): a chunky pump shotgun traced at 3 mm per pixel. It has a slate receiver with a stepped rear sight, a silver ejection port, a silver barrel over a silver magazine tube, a front barrel block with an orange bead, an orange ribbed pump (six ribs over a darker groove core), a raked grip with an orange trigger and a wedge stock. The accent is orange `f2a01e`. The user found it too small, so it is now scaled 1.3× and built wider (receiver 11.5 cm, pump 12.4 cm, barrel radius 3.6 cm before scaling), so it reads from the top-down camera. To keep the shared 'gun' support glove (y = -.25) on the pump after scaling, the receiver is 2 cm shorter and the pump sits racked back against it; no fighter rebuild was needed. The muzzle is at `(0, -.854, .144)`. Renders: `evidence/shotgun_redesign.png`, `evidence/shotgun_ingame.png`.
- **Rocket launcher** (same day, from the user's reference sheet): a chunky RPG-style launcher traced at 3.7 mm per pixel. It has a faceted octagonal slate tube with orange bands, a flared rear venturi, a front collar, a loaded orange warhead with a dark charge band, a side plate, an orange optic, a rear trigger grip and a forward grip on silver brackets. The faceted parts use flat shading (`Part.cyl(..., spin, flat)`). `P_rocket` (the rocket in flight) now matches the warhead. The accent is orange `f2a01e`. The loaded warhead is its own node, `Load_rocket`, built from the same `warhead()` mesh as `P_rocket`, and the muzzle marker sits at its origin `(0, -.645, .124)`.
  - **Firing the loaded rocket** (user request): the rocket that flies is the one on the launcher. `actor.gd` hides the weapon's `Load_*` node when the round is fired and shows it again halfway through the reload (`reload_total`). The projectile starts at the warhead's position at the same size (rocket mesh scale 1.0, not 1.25). `game.gd` pitches the shot so it dives from the shoulder onto the aim point at body height (0.85 m, at least 3 m out), and `projectile.gd` levels it off there. In a scripted shot at three robots 9 m away, the warhead hid on the shot, the rocket dropped from 2.18 m to 0.90 m, all three robots died, and the warhead was back after half the reload. Frames: `evidence/rocket_fire_sequence.png`.
  - **Fast reload:** the launcher is now single-shot. Magazine 3 → 1, reload 2.2 s → 0.95 s, rate 1.05 s → 1.0 s, so the launcher reloads after every rocket. The firing cycle is now about 1.0 s per rocket instead of 3 rockets per 4.3 s, about 40% more sustained damage; damage per rocket is unchanged.
  - **New `shoulder` stance** (the user asked for shoulder and eye level): `build_fighters.py` adds the `aim/recoil/reload_shoulder` clips, `actor.gd` registers the stance and `data.gd` moves the rocket from `heavy` to `shoulder`. The tube rests on the right pauldron (tube centre 1.74 m, beside the visor at 1.65 m and clear of the ±0.29 m helmet). The right hand is on the rear grip and the left hand on the forward grip. The chest turns 0.30 rad side-on, the solver adds its maximum 0.36 rad so the left arm can reach, and the head turns back to the target. Reload lowers the tube to chest height and shoulders it again. The optic sits on the tube's left side at visor height instead of on top, where it would be above the head. All six fighters were rebuilt (about 6 minutes).
  - Because the tube is about 0.57 m to the side, `tests/capture_weapons.gd` now sets `aim_point` on the target, as mouse and auto aim do; otherwise its rocket flew parallel to the aim line and missed. With that, the rocket clears all 7 robots. All seven Godot checks pass. Renders: `evidence/rocket_redesign.png`, `evidence/rocket_shoulder_ingame.png`.
- **Sniper** (Nadia's signature, from the user's reference sheet): a chunky bolt-action rifle traced at 3.84 mm per pixel. It has a skeleton stock with an orange cheek pad, a slate receiver with a silver bolt slot, a bolt handle and a top rail, a raked grip with an orange trigger, an orange box magazine, a fore-end with orange dashes, a long thin silver barrel, a deployed bipod with orange sleeves, and a faceted scope (eyepiece, turrets, large objective with orange rings and a glowing lens) on a mount base with two ring towers. The accent is now orange `f2a01e` (was red). The existing `sniper` cheek-weld stance (shoulder and eye level) is kept, so no fighter rebuild was needed: the scope centre is 0.31 m over the grip, at the visor; the stock is shortened from the sheet to end at the shoulder (y = .335); and the left glove's point under the receiver front, (-.30, -.07), is unchanged. The user then asked for it bigger: it is now scaled 1.3× (2.1 m long, wider and thicker, so it reads from the top-down camera). The parts that must line up with the body are placed so they land on the stance after scaling: the scope at z .238 (0.31 m after scaling), the stock end at .258 (.335) and the magazine moved back behind the left glove. The barrel then looked too thin from the top-down camera, so it was thickened 1.7× (radius .034 before scaling, 4.4 cm in game), with a collar where it leaves the fore-end and a ported muzzle brake. The muzzle is at `(0, -1.668, .157)`. Hero shots and menu portraits were re-rendered (`render_showcase.py`, `make_portraits.py`). Renders: `evidence/sniper_redesign.png`, `evidence/sniper_ingame.png`.
- **Sounds:** three ElevenLabs takes per gun were scored on transient count, attack, decay and low-end share. The rifle take has one transient, a 5 ms attack, 52% of its energy below 200 Hz and a 209 ms decay; the old take had 17%. The first SMG take (a "suppressed" prompt) did not sound like an SMG. Prompts for a single SMG shot came back near silent, while full-auto burst prompts sounded right, with shots about 65 ms apart. `generate_audio.py` now asks for a burst and keeps only its last shot (`LAST_SHOT`, `last_shot_start`): it starts 8 ms before the final rise and keeps the shot's natural ~75 ms tail. The winning prompts are in `generate_audio.py`.
- The gameplay, roster and aim-line checks passed. The export and `Sector03-linux.zip` were rebuilt.

## Cleanup, Windows build and release (2026-10-17)

- **Cleanup:** 70 evidence screenshots that nothing referenced were removed. The `fighters/*_showcase.png` renders were kept, because `make_portraits.py` builds the menu portraits from them. The reference image `4.png`, six `.blend1` Blender backups, `__pycache__` folders and stale `.import` files were also removed. `source_art/` and `docs/` now carry a `.gdignore`, so Godot no longer imports raw MP3s or README media. The project went from 76 MB to 51 MB, not counting `.godot/` and `exports/`.
- **Builds:** `export_presets.cfg` has a **Windows** preset (x86_64, separate `.pck`, no code signing, no rcedit resource edits) beside **Linux**. Output goes to `exports/windows/` and `exports/linux/`. The Linux build was launched headless; the Windows `.exe` is a valid PE32+ x86-64 file, but Wine is not installed here, so it was not launched. Both are published as GitHub release assets rather than committed (the Windows executable is 109 MB, over GitHub's 100 MB file limit).
- **README:** rewritten, with gameplay footage recorded by `tests/record_gameplay.gd` through Godot's movie maker: 24 s of Magnus and Nadia (both AI) against a mixed crowd, Magnus cycling minigun, rocket, shotgun, rifle and SMG. `docs/media/gameplay.webp` (960 px, 15 fps, 9 MB) plays inline; `docs/media/gameplay.mp4` holds the full-quality clip. `docs/media/roster.png` and `weapons.png` come from the menu portraits and Blender renders.

## Machine gun redesign (2026-10-17)

- Magnus's minigun is replaced by a chunky belt-fed machine gun from the user's reference sheet (`W_minigun`, traced at 4 mm per pixel, scaled 1.3× for Magnus). It has a slanted stock with an orange cheek block and butt plate, a slate receiver with a feed-cover seam, an orange carry handle on two posts, a belt of orange and silver rounds feeding from an orange ammo box into the receiver, a raked grip with an orange trigger, a handguard with two rows of orange vents and an underside rail, a silver barrel and gas tube, a front sight and a folded-down bipod. The game shows it as MACHINE GUN; the internal id stays `minigun`, so sounds, the Bullet Hurricane special and the saved data are unchanged. The spin flag and the `Spin_minigun` barrel cluster are gone.
- **Hold:** the old 'heavy' stance braced the left glove on the side of the minigun's 30 cm receiver, which would float beside the slim machine gun. `build_fighters.py` now puts the left glove on the carry handle (`MG_HANDLE`, (0, -.221, .39) in weapon space after scaling), in both the hip carry and Magnus's showcase pose. Reload reaches down to the ammo box. The solver turns the chest 0.34 rad, within its 0.36 limit. All six fighters, the hero shots and the menu portraits were rebuilt.
- All seven Godot checks pass. The first gameplay run after the reimport hung until its 400 s timeout; it then passed three times in a row in about 2.5 s. Renders: `evidence/machinegun_redesign.png`, `evidence/machinegun_ingame.png`.

## Real machine gun and rifle sounds (2026-10-17)

- Eight new ElevenLabs takes were generated: four machine-gun bursts, two single rifle shots and two rifle bursts. As with the SMG, burst prompts gave realistic gunfire; one single-shot prompt came back near silent.
- **Machine gun** (`minigun.ogg`): the last shot of a 12-round burst with shots about 75 ms apart, a real belt-fed rhythm. It has a single transient, 19% of its energy below 200 Hz and a 42 ms decay, so shots stay distinct at 18 rounds per second. It replaces the old sci-fi minigun burst sample.
- **Rifle** (`rifle.ogg`): one heavy AK-style shot with its natural outdoor echo, kept at 0.47 s. It has a single transient, a 15 ms attack and a 108 ms decay.
- `generate_audio.py`: both use the new realistic prompts and `LAST_SHOT`. **Bug fixed** in `last_shot_start`: an echo hump inside one shot (its envelope dipping to 43% and rising again) was taken as a new shot, which cut the rifle's crack off. A new shot must now follow a gap below 30% of the peak and reach 80% of it. The SMG and machine-gun cuts came out unchanged.

## Hand cannon redesign (2026-10-17)

- Theo's pistol (`W_pistol`) is now a chunky revolver hand cannon from the user's reference sheet, traced at 1.9 mm per pixel and scaled 1.16×. It has a raked orange grip with a dark panel and screws, a hammer spur, a slate frame, a flat-shaded fluted silver cylinder bulging out of the frame with orange chamber marks, a heavy silver barrel slab with a dark top rib and front and rear sights, an under-lug with orange dashes, a silver ejector rod with a rail under it, and a trigger guard with an orange trigger. The accent is orange `f2a01e`. The game now calls it HAND CANNON (was SIDEARM); the id stays `pistol`. The 'pistol' stance wraps the left glove around the right fist, so the hold needed no fighter rebuild. The muzzle is at `(0, -.641, .05)`. Theo's hero shot and menu portrait were re-rendered. Renders: `evidence/handcannon_redesign.png`, `evidence/handcannon_ingame.png`.
- **Test fix:** `tests/gameplay.gd` hung on its "clear miss" check. A failed `assert` stops a headless script in the debugger, so it looks like a hang. The game and the tests share `user://sector03.cfg`, and Auto aim had been switched on there (`autoaim=1.0`), so the deliberate miss snapped onto the robot. The test now turns Auto aim off for its own run; the saved settings are left alone. It then passed three times in a row. This also explains the earlier one-off hang after the machine-gun rebuild.

### Hand cannon sound
- `pistol` SFX replaced: ElevenLabs magnum-revolver prompt, six takes compared by envelope and spectrum; take with one sharp crack, 74% energy below 200 Hz and a tail gone by ~250 ms kept (`source_art/audio/raw/pistol.mp3`), trimmed to .45 s. `SFX_GAIN` pistol .7 → .95.
- All seven tests pass; Linux and Windows exports and zips rebuilt.
- Replaced again on request ("choose something realistic"): the magnum take measured as a dull thump (1% energy above 2.5 kHz). Eight new takes scored against the accepted rifle/machine gun/sniper takes (5-14% crack, 50-70% body); the handgun range take g1 fits (11-15% crack, 56% body). Its last shot is sliced (`LAST_SHOT`), .45 s, -13.7 LUFS. Tests pass, exports and zips rebuilt.

### Plasma katana redesign
- `W_sword` rebuilt from the reference sheet: dark faceted blade (9 straight chunks along the sori curve) with a raised spine ridge and a glowing orange cutting edge that runs round the kissaki; gold habaki with a glowing gem on the spine side, tall dark tsuba, gold fuchi, square dark tsuka with diagonal gold wraps and a gold kashira. A faint plasma haze (alpha .07) keeps the blade readable from the top-down camera, where Albert's edge-down guard shows mostly the spine.
- Fittings sit ~.17 m ahead of the grip origin so they clear Albert's .29 m deep glove; the tsuka runs back to .40 m, so `BLADE_SUPPORT` (left glove at .22) is still on it. No fighter rebuild needed.
- `Part.prism` gained a `smooth` flag (flat-shaded blade facets).
- Checks: `blade_cut` kill cam (LIVE CUT PASS, `evidence/killcam_blade_cut.png`), all seven headless tests pass. Albert's showcase, `assets/ui/albert.png` and `docs/media/roster.png` re-rendered. Renders: `evidence/katana_redesign.png`, `evidence/katana_ingame.png`.

### Rail rifle redesign
- `W_railrifle` rebuilt from the reference sheet, traced from its side view at 4.4 mm per pixel and scaled 1.15x: slate receiver with a dark vented panel and orange strip, scope with orange rings and a big objective box, twin rails (slate caps over glowing cyan cores, a cyan field between them) with four orange clamp rings and dark tips, toothed under-rail, orange magazine with a dark window and glowing cyan base, raked dark pistol grip with an orange heel, skeleton stock with an orange cheek riser and a tall buttplate.
- The stock is squeezed to ~.39 m so it clears the hip-level 'rail' hold; the magazine sits under the stance's left glove (support -.34), a magwell grip, so no fighter rebuild was needed. Muzzle at the rail tips.
- Checks: in-game captures with Iris (`evidence/railrifle_ingame.png`), all seven headless tests pass; Iris's showcase, `assets/ui/iris.png` and `docs/media/roster.png` re-rendered; render `evidence/railrifle_redesign.png`.

### Arc gauntlets redesign
- `caster_hand.py` (shared by `W_gauntlet` and Seren's mirrored left glove) rebuilt from the reference sheet: chunky slate forearm bracer with rear and wrist cuffs, a hazard-striped orange/dark band, orange top panel with a slot and glowing vents on the palm side; slate back-of-hand plate with three glowing studs, palm emitter ring; four fingers with orange knuckle plates, slate and dark segments and glowing purple tips; slate thumb with a glowing tip. The holo panel is unchanged. Material keys are now slate / inset / orange / glow (weapons: SLATE, INSET, A['rifle'], G['gauntlet']; fighters: matching caster_* materials).
- Seren rebuilt alone with `FIGHTERS=seren` (~1 min); hand frame and grip unchanged, so the 'cast' stance is untouched.
- Checks: in-game captures (`evidence/gauntlet_ingame.png`), render `evidence/gauntlet_redesign.png`, all seven headless tests pass; Seren's showcase, `assets/ui/seren.png` and `docs/media/roster.png` re-rendered.

### Shared railgun = rail rifle
- `W_railgun` (the railgun every operative carries, 'sniper' stance) is now built from the same code as `W_railrifle` (loop over both ids in `build_weapons.py`); the old ceramic railgun is gone. The model's stock end (~.40 m) and scope height (~.35 m) sit close to the sniper stance anchors (.335 / .31), so it shoulders with the scope at the visor; the left glove lands on the magazine.
- Checks: all six operatives captured holding it (`evidence/railgun_ingame.png`), all seven headless tests pass.

### Grenade launcher redesign
- `W_grenade` rebuilt from the reference sheet as a revolver-drum launcher, traced from its side view at 2.3 mm per pixel and scaled 1.3x: silver barrel with a green glowing muzzle ring, dark clamp with a ribbed vertical foregrip, faceted slate drum with orange end bands, six chambers on its face and an orange cradle, stepped receiver with a hazard stripe and a red-dot sight, orange vents, orange trigger and raked pistol grip, skeleton stock with an orange cheek riser and buttplate stripe.
- New 'launcher' stance (build_fighters.py, actor.gd STANCES, data.gd grenade): shouldered like the rifles with the right hand 8 cm closer to the body and the left glove out on the foregrip (support -.55), so the drum stays in view. All six fighters rebuilt (aim/recoil/reload_launcher).
- Checks: all six operatives captured holding it (`evidence/grenade_ingame.png`), `capture_weapons` grenades still launch from the muzzle and blast the group (`evidence/weapon_grenade.png`), all seven headless tests pass; render `evidence/grenade_redesign.png`.

### Plasma caster redesign
- `W_plasma` rebuilt from the reference sheet, traced from its side view at 3.2 mm per pixel: twin emitter prongs with glowing purple tips and dark sleeves, light grey shell over the front half with a long glowing plasma cell window (purple bars), dark lower body with a slotted rail, dark receiver with a light top band, hazard stripe, sight, orange tabs and vents, grey magazine, orange trigger and raked orange pistol grip, skeleton stock with an orange top block and dark buttplate. Muzzle between the prong tips.
- Sized so the shared 'gun' stance's left glove (support -.25) sits on the lower fore-end just ahead of the magazine, under the cell window: no fighter rebuild.
- Checks: in-game captures (`evidence/plasma_ingame.png`), `capture_weapons` plasma orbs leave the prongs and hit the group (`evidence/weapon_plasma.png`), all seven headless tests pass; render `evidence/plasma_redesign.png`.

### Operative callsigns
- The Six renamed to callsigns that fit their roles: Magnus -> Bastion (heavy gunner), Albert -> Ronin (blade master), Theo -> Marshal (gunslinger), Iris -> Nova (rail specialist, Halo Array star volleys), Seren -> Hex (arc caster), Nadia -> Kestrel (marksman). Changed in `Data.HEROES`, code comments, tests, every Blender/Python generator (HEROES, BULK, per-name poses and stances), the models (`assets/models/<callsign>.glb`), portraits (`assets/ui/<callsign>.png`), the fighter .blend files, showcase renders, README and `docs/asset_manifest.md`. Earlier entries in this log keep the old names.
- All six fighters rebuilt so the rig nodes carry the new names (`Grip_<Name>`; Godot finds them by prefix). Portraits, `docs/media/roster.png` and `evidence/menu.png` re-rendered.

### Rifle sound (realistic)
- Eight new ElevenLabs takes (M4, AK field recording, soldier in a field, 7.62 battle rifle) scored against the accepted gun takes; the battle-rifle take's last shot has a 6 ms attack, 12% crack (the old one 5%) and a natural ~220 ms tail, and is kept (`LAST_SHOT`, .45 s, -14.3 LUFS).

### Cleanup and release
- Removed stray captures nothing references (`evidence/weapon_{railgun,rifle,rocket,shotgun,smg}.png`, `evidence/fighters/seren_gameplay.png`, `evidence/loadout_0.png`).
- README gameplay clip re-recorded (machine gun, rocket, grenade, shotgun, rifle, plasma, railgun, SMG) and `docs/media/weapons.png` rebuilt from the seven redesigned shared guns.
- All eight headless tests pass (gameplay, roster, revive, archetypes, progression, aim_line, cinematic, specials).

### App icon
- New icon from the supplied art (`source_art/icon/icon.jpeg`, 2048 px): white outer corners flood-filled to transparency, saved as `icon.png` (1024 px, project `config/icon`, the game window icon) and `icon.ico` (16-256 px, `config/windows_native_icon` and the Windows preset's `application/icon` with `modify_resources=true`). The default `icon.svg` was removed.
- Verified: the exported `Sector03.exe` carries six PNG icon resources and the largest is the new icon (extracted with pefile). The Linux zip ships `Sector03.png` for desktop shortcuts. README header shows `docs/media/icon.png`.

## Complete cinematic action (2026-10-18)

- The camera transition used the same clock as the action, while game time initially ran at full speed. Replayed cuts could land before the camera arrived, blast destruction started immediately, and clearing the last enemy could open upgrades/debrief/results before the cinematic finished.
- Kill cams now hold game time from the triggering frame and establish the camera for 1.1 real seconds before starting a separate action clock. The full bullet flight, blade wind-up and contact, and blast destruction play with the camera in place. Each scene keeps its full action duration, then eases back to gameplay; total duration is approximately 5–7 seconds.
- Impact zoom now also shows a round flying from the muzzle before the target bursts. Gun and blast cameras use the same wall clearance as the blade camera. Replayed cuts discard the original swing's remaining timers before starting the complete replay.
- Wave completion waits while the kill cam is active. Bomber chain explosions and other on-kill effects run with the filmed destruction, and the pending destruction callback is consumed before it runs so interruption cannot fire it twice.
- Added `tests/killcam_timing.gd`: all four styles hold the target through setup; both gun styles show flight before impact; all three real katana combo strikes preserve their wind-up and slice inside the established shot; upgrades and campaign debrief wait; stopping early runs a bomber chain explosion exactly once and restores time/control. The progression check now enables kill cams explicitly and waits for them before expecting victory.
- Validation: headless gameplay, roster, revive, archetypes, progression, aim_line, cinematic, specials, campaign and killcam_timing; rendered killcam and blade_cut checks. Refreshed `evidence/killcam_{bullet,zoom,crane,orbit,blade_cut}.png`. Largest camera movement in the rendered four-style check was 0.58 m/frame (limit 1.5), with time and the gameplay camera restored after each scene.
- Linux and Windows exports and ZIPs rebuilt; both ZIPs passed CRC checks. Linux exported menu smoke check passed. Its forced-exit resource warnings also occur in the previous packaged build.

### Blade cuts follow the animated edge

- Removed the fixed torso-height cut origin, the 1 cm motion cutoff that substituted a generic diagonal in slow motion, and the forced tilt applied to level cuts. The slice plane now contains the contacted blade segment and its measured sweep, anchored at the point where that edge crosses the robot's torso bounds.
- Added ordered cutting-edge markers to the katana generator and rebuilt `weapons.glb` / `weapons.blend`. Both contact detection and the visible trail use the actual curved edge. The trail's segments share one mesh and tween.
- Sample after animation evaluation and explicitly update skeleton attachments, so the weapon samples match the displayed pose. Swept-edge substeps prevent missed contact on slower frames. The gameplay strike key can request a slice, but the body splits only on visible blade contact; a missed or interrupted strike finishes without inventing a cut plane.
- The longer katana also needed corrected footwork: sample the real rig's three strike animations once and cache them, then choose each cinematic's stance from the blade position at the victim's body height. Hold the victim during this staging. This keeps diagonal and overhead strikes aligned for ordinary robots and bosses, while preserving their actual blade paths.
- Added `tests/blade_path.gd`: all three combos live, replayed after a rotated approach, and against a boss near the edge of melee range (nine cases). Checks verify that the plane contains the animated edge and sweep, that contact lies on the torso, that overhead splits stay vertical, and that lethal damage happens once. Passed headless and with rendering capped at 30 FPS; contact sheet: `evidence/killcam_blade_path.png`.
- Re-ran the timing, rendered blade/kill-cam, roster, gameplay, revive, archetypes, progression, aim-line, opening cinematic, specials and full campaign checks. Rebuilt both desktop packages for publication.
- Published the refreshed Linux and Windows ZIPs to release `v1.1.1`; verified both remote asset sizes and GitHub SHA-256 digests against the local packages.

## Kestrel Ghostline and shared gunship support (2026-10-18)

- Replaced Kestrel's Orbital Lance with **Ghostline**. Acquire up to three visible weak points, prioritizing the aim direction, then fire a charged sniper salvo with recoil, bolt cycling, scope reticles, piercing tracers and a short slow-motion finish. Shots pierce robots and frontal shields, stop at world cover, and retarget destroyed marks. End early on a clearing shot instead of firing empty follow-ups. The special uses its own 16-second cooldown and preserves magazine ammunition. Boss damage uses the existing special scaling; AI Kestrel now uses this ability from sniper range.
- Every operative can call a **gunship strafe** with both mouse buttons or both controller triggers. The visible aircraft crosses a marked area, fires twin guns, launches two rockets, casts a moving shadow, and exits. Damage and upgrades belong to the caller; allies are safe. Each player has a separate 35-second support cooldown shown in the HUD. The player keeps moving and can call support during an operative special; call-ins are blocked during weapon kill cams.
- Chord input takes priority over primary/special. Right-click has a short grace period so either press order works; a quick right-click release still casts the ordinary special. Holding both cannot repeat a call, a cooling-down call cannot fall back to the special, and primary fire resumes when right is released. Keyboard/mouse and controller use the same chord logic.
- Aircraft, ordnance and cooldowns follow game time and pause. Wave transitions wait for committed special moves and aircraft passes. Aerial kills preserve their own staging rather than starting a blade/gun kill cam. Reset cancels outgoing special timelines before disposing of the camera and removes aircraft/ordnance, preventing callbacks against a restarted run.
- Added `tests/kestrel.gd` (piercing, shield bypass, cover, boss damage, destroyed/empty targets, early finish, AI range) and `tests/air_support.gd` (all six operatives, mouse projection, both press orders, held/cooling-down chords, special independence, actual mouse input during a special, pause, friendly-fire filtering, phase handoff and reset). Updated the specials/progression checks and isolated the opening-cinematic check from deliberate special slow-motion beats.
- Rendered `evidence/ghostline.png` and `evidence/air_support.png`; refreshed the seven-special contact sheet with Ghostline. Updated the README, selection controls, HUD and master prompt with the new ability and bindings.
- Validation: all 13 gameplay/ability checks passed, including the full campaign and the previous cinematic/blade regressions; both capture runs completed without script errors. Linux and Windows release packages rebuilt and ZIP CRC checked; Linux launch smoke check passed. Uploaded both packages to `v1.1.1` and verified the remote SHA-256 digests against the local files.

## Shared ray-gun / kamikaze drone swarm (2026-10-18)

- Middle mouse deploys exactly three quad-rotor drones for every operative; controller players use right-stick click. The shared production mesh follows the supplied reference: graphite cabin, amber panels, cyan optic, four cross rotors and twin underslung guns. Rotors animate, the formation bobs above/follows its caller, and terminal dives leave orange trails.
- Ray guns cycle through the whole visible crowd for five game seconds, respecting world cover. The drones then select separate survivors where possible, rise and home into them, and explode once each. Destroyed targets are retargeted; when no enemies remain, unused drones hover indefinitely and immediately dive on new arrivals without restarting the ray phase.
- Each player owns a 40-second cooldown and one active swarm. Deployment consumes no ammo, character special or gunship cooldown and works during character specials. Damage scales with ability upgrades/overcharge, boss damage is reduced, and splash never hurts teammates. Drone kills keep their staging rather than interrupting with weapon kill cams.
- Pause freezes drones and cooldowns. Waiting drones persist through upgrade screens and allow the next wave; committed terminal dives finish before phase changes. New chapters, restart, defeat and caller removal clean up transient swarms.
- Added `tests/drone_swarm.gd`: all six operatives, whole-crowd ray targeting, five-second phase boundary, distinct dive targets, single-use cleanup, hover/follow, arrivals and lost targets, cover, boss balance, friendly fire, cooldown/stacking limits, actual middle-mouse input during a special, pause, upgrade handoff and reset. Rendered the actual mesh, ray sweep, terminal dives and explosions in `evidence/drone_swarm.png` using `tests/capture_drones.gd`. README, in-game control cards, per-player HUD and master prompt document the ability.
- Validation: all 14 gameplay/ability suites passed, including the full campaign and cinematic/blade regressions; the rendered drone capture completed without errors. Linux and Windows release exports include compiled `drone_swarm.gdc`. Re-ran the full swarm suite against each exported PCK using the Godot engine: both passed. Both ZIPs passed CRC checks and the Linux executable launch smoke check passed.

## Heavy five-second gunship bombardment (2026-10-18)

- Extended the shared aircraft pass from 3.5 to five game seconds, with a slower, closer flight and targeting brackets held across the full attack. The aircraft now has heavier cannon barrels and visible underwing rocket racks.
- Twin cannons fire 20 bursts / 40 visible explosive shells across the target strip, replacing small bullet hits with 52-damage, 2.6 m splash blasts. Four paired salvos launch eight larger rockets with 130 damage, 4.2 m splash and stronger knockback. All impacts use the same fireballs, rolling smoke, sparks, chunks, flash lights, shockwave rings and scorch marks as grenade/rocket weapons.
- Preserved the independent 35-second cooldown, input chord, ability/overcharge scaling, reduced boss damage, friendly-fire protection and aerial kill staging. Scheduled launch times let late frames catch up without discarding the final ordnance at cleanup.
- Extended `tests/air_support.gd` to verify all six operatives, the full fifth second, exactly 40 shell and eight rocket impacts, expanded splash, upgrade/overcharge and boss scaling, pause, allies, phase handoff, reset, and complete delivery at two frames per second. Updated README/master prompt and refreshed the rendered four-frame `evidence/air_support.png` capture at 0.9, 2.0, 3.1 and 4.45 seconds.
- Validation: updated air-support suite and six related regressions (gameplay, drone swarm, specials, Kestrel, kill-cam timing, progression) passed. Rendered support captures completed without errors. Both desktop release exports compiled cleanly; the full support suite passed against both exported resource packs. ZIP CRC checks and Linux executable launch passed.
