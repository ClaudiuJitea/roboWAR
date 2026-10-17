# Master prompt: Godot arena combat game with Blender MCP fighters

Copy the prompt below into your coding agent and attach all four reference images again. This brief chooses a complete playable scope where the still images do not establish the rules. Those choices are requirements for this build, not claims about the game pictured.

---

You are a senior Godot developer, technical artist, Blender character artist, animator, and game designer. Build a complete, polished, playable 3D top-down arena combat game using Godot and create its fighters in Blender through Blender MCP.

Do the implementation, asset creation, integration, testing, and packaging. Do not stop at a design document, a code sample, a graybox, or a mockup. Work in milestones, with a runnable project after each milestone. Prioritize strong reference matching, satisfying combat, and reliable integration.

## 1. Attached references and their authority

I am attaching four images. If filenames differ, identify them by their contents and attachment order:

- Reference A — image(2).png: elevated arena view with white rectangular structures, cobalt-blue floor sections, yellow hazard markings, dark enemy crowds, two light-colored fighters, and a cyan electrical beam effect.
- Reference B — image(3).png: another view of the same arena aesthetic, two fighters with colored ground indicators, purple energy, scattered debris, and approaching enemies.
- Reference C — image(4).png: the clearest arena composition reference, with two armed fighters firing at enemies, white modular industrial obstacles, blue floor panels, the large white “03” floor marking, yellow accents, and dark rails or conduits.
- Reference D — image(5).png, the LAST attachment: the fighter design reference. It shows six armored characters named MAGNUS, ALBERT, THEO, IRIS, SEREN, and NADIA, including smaller views that demonstrate their appearance from the gameplay camera.

Use A–C for environment, framing, scale relationships, enemy crowd appearance, lighting, and combat readability. Use D as the primary authority for all playable fighter models. The fighters must have the detailed armored design in D, rather than the simple cube-bodied player placeholders visible in A–C.

Do not reproduce browser controls, video timelines, cursors, fullscreen messages, or screenshot borders. Do not interpret the sheet heading as a required game logo. Use “Sector 03” as an editable working title.

The pictures establish visual direction but do not establish movement rules, multiplayer implementation, progression, or weapon statistics. Implement the concrete defaults below. If a visual detail is unclear, make a consistent choice and document it instead of claiming it was visible.

## 2. Game scope and core loop

Build a real-time 3D arena shooter/brawler with a fixed elevated camera. Characters move on the horizontal XZ plane. Movement, aiming, attacks, dodging, and crowd control should be immediate and readable.

Deliver these modes:

1. Solo: one human fighter against the enemy waves.
2. Solo plus AI companion: one human and one selectable AI fighter, reproducing the two-hero composition in the references.
3. Local two-player co-op: shared camera, one keyboard/mouse player and one controller player, with support for two controllers.

Do not add online networking for this build. Keep player ownership and input routing modular so it can be added later.

Core loop: main menu → mode and fighter selection → arena deployment → survive ten escalating waves → upgrade choices between waves → boss encounter in wave ten → victory or defeat → results → restart or menu.

Include all six selectable fighters, one finished handcrafted arena, five regular enemy archetypes, one boss, a functional upgrade system, menus, settings, audio, effects, and saved preferences. All fighters should be available initially. Target a roughly 10–15 minute run, tuned through playtesting. An endless mode is optional after the required game is complete.

## 3. Technical foundation

Use an installed, supported stable Godot 4.x version and typed GDScript. Inspect the actual environment first, record the exact Godot and Blender versions, and verify version-specific APIs against official documentation when necessary. Do not assume MCP tool names or available capabilities.

Use Godot for gameplay, physics, navigation, camera, rendering integration, UI, audio, saves, and exports. Use Blender MCP for fighter modeling, rigging, animation, materials, weapon modeling, and export. Do not replace Blender work with downloaded finished characters or flat sprites.

Prefer Forward+ on supported desktop hardware; provide lower quality settings for effects and shadows. Use a fixed physics tick, frame-rate-independent movement, meaningful collision layers, centralized damage processing, and data-driven fighter/weapon/enemy/upgrade resources. Avoid a single monolithic gameplay script.

Suggested project layout:

```text
project.godot
scenes/{menus,arena,characters,enemies,weapons,effects,ui}/
scripts/{core,combat,characters,ai,input,camera,ui}/
resources/{fighters,weapons,enemies,waves,upgrades}/
assets/{models,materials,textures,audio,fonts}/
source_art/blender/
tools/blender/
tests/
docs/
```

Use reusable scenes for fighters, enemies, weapons, and effects. Suitable Godot building blocks include CharacterBody3D, Camera3D, NavigationRegion3D, NavigationAgent3D where appropriate, AnimationPlayer, AnimationTree, Area3D, and Godot Resource definitions. Choose crowd navigation based on profiling, rather than placing a costly full navigation update on every enemy every frame.

Separate gameplay state from visual state. Store balance values in editable resources. Combat must remain functional if visual effects are disabled.

## 4. Camera, arena, and lighting

Match the elevated three-quarter, near-orthographic appearance in A–C. Use an orthographic camera initially, approximately 50–60 degrees above the ground, then adjust yaw, elevation, and size through reference comparison. Treat these angles as starting points, not measurements of the source images.

Keep both fighters and nearby threats visible. Track the midpoint of active teammates with damped movement and a bounded zoom range. Prevent unbounded separation with an arena-aware soft tether and a readable warning. Do not yank fighters through walls. Fade tall geometry that obscures a fighter while keeping collisions intact. Add subtle, configurable camera shake.

Create a clean industrial test facility with:

- Light gray tiled ground and large cobalt-blue painted floor zones.
- White modular walls, rectangular barriers, pillars, and low cover blocks with subtle bevels.
- Blue lower wall panels and inset door-like accents.
- Yellow door trim, thin safety lines, hazard stripes, arrows, and an oversized “03” marking.
- Sparse dark conduits or rails crossing selected areas.
- Open fighting spaces linked by several navigable corridors, with no unavoidable one-way traps.

Build a modular kit on a consistent grid. Compose a finished arena approximately 45 × 35 meters as a starting point, adjusting scale for fighter readability and traversal. Use a one-meter asset convention and fighters approximately 1.6 meters tall.

The apparent rails in the images are decorative unless clearly represented as obstacles in the final design. Never add invisible collisions where the player sees an open route. Bake and validate navigation against the actual traversable spaces.

Lighting: one directional key light with strong diagonal shadows, soft ambient fill, neutral-to-slightly-warm white surfaces, rich blue floors, and subtle contact depth. Avoid washed-out whites, excessive bloom, heavy fog, or visual noise. Weapon and visor emission should be readable without dominating the environment.

## 5. Fighter art direction: mandatory match to the last image

Create all six fighters as stylized hard-surface armored humanoids. Preserve the shared design language:

- Oversized rounded-cube helmet with beveled edges and a narrow dark visor slit.
- Compact torso, wide shoulders, short sturdy limbs, large gloves, and chunky boots.
- Off-white armor plates over dark charcoal mechanical undersuits and joints.
- Separate chest, shoulder, forearm, thigh, knee, shin, and boot armor forms.
- Small colored panels, restrained emissive visor details, and readable weapon silhouettes.
- Slight edge wear and panel separation without photorealistic grime.

Aim for premium stylized game miniatures: dimensional, expressive, and coherent from the elevated gameplay view. Do not make featureless cubes, realistic adult proportions, anime faces, heavily weathered military soldiers, or ultra-dense sculpted characters.

Create a shared humanoid base, skeleton, and material system; then give each fighter distinctive armor parts, proportions where needed, accent colors, weapon, stance, and effects:

| Fighter | Required appearance | Primary attack | Special ability |
| --- | --- | --- | --- |
| Magnus | Blue armor accents, heavier stance, bulky rotary minigun | Rapid sustained fire with spin-up and heat management | Temporary overdrive with improved firing and cooling |
| Albert | Orange accents, glowing orange energy sword | Three-hit melee combo with clear arcs | Short forward dash slash with piercing damage |
| Theo | Yellow/gold accents, compact sci-fi pistol | Fast, accurate pistol fire | Timed deployable shield that blocks enemy projectiles, with visible health |
| Iris | Cyan/teal accents, long twin-rail weapon | Charged piercing rail shot and bright cyan trail | Chain-lightning pulse linking nearby enemies |
| Seren | Purple accents, glowing gauntlets, energy rings and holographic forms | Traveling purple energy bolts | Temporary gravity field that slows and pulls enemies |
| Nadia | Red accents, long scoped rifle | Slower high-damage precision shots | Charged penetrating shot with a targeting line |

Names, colors, and main weapon silhouettes come from D. The ability behavior above is this project's design specification. Preserve color identity in visor emission, weapon accents, selection UI, and effects. Ground markers distinguish players independently of fighter colors: player one yellow, player two cyan, companion dashed or otherwise clearly distinct.

## 6. Blender MCP production pipeline

First discover the connected Blender MCP tools and inspect the active Blender scene. Work in a dedicated project collection. Preserve unrelated existing work. If MCP is unavailable, explicitly report the blocker, prepare reproducible Blender scripts, and continue Godot work with clearly labeled temporary assets. Do not claim characters were created through MCP until they actually were.

Use MCP to execute reproducible, idempotent Blender operations in manageable stages. Save source .blend files and the Python scripts used to generate or modify them. Use meaningful object and collection names. Avoid one uninspectable all-in-one modeling operation.

Production sequence:

1. Block out one base fighter and compare its silhouette against D from front, side, and the intended Godot camera angle.
2. Create a polished Magnus first as the style benchmark, including minigun and materials.
3. Create armor plates with modeled thickness, controlled bevels, correct normals, and clean shading.
4. Build the other five variants and weapons while preserving the established quality.
5. Rig with a shared bone hierarchy and consistent rest pose. Include pelvis, spine, chest, neck/head, arms, hands, legs, and feet, plus weapon sockets.
6. Use rigid bone weighting where appropriate for hard armor and smooth deformation for flexible joints. Keep armor from collapsing or clipping during movement.
7. Author and export animations, then validate them inside Godot.

Use material slots such as armor_white, undersuit_dark, accent, visor_emissive, weapon_metal, and energy_emissive. Use portable PBR materials; bake procedural detail if it cannot export reliably. Keep tiny surface detail secondary to shapes visible at gameplay scale.

Provisional budgets: roughly 8,000–18,000 triangles per hero including typical gear; up to 25,000 for Magnus and his minigun if profiling permits; roughly 500–2,000 per common enemy. Limit hero material count where practical, reuse materials, and generate lower-detail meshes if required. Adjust budgets using measured frame time.

Required animation coverage: idle, forward/backward/side movement or an appropriate reusable locomotion set, primary attack, special cast/attack, dodge, hit reaction, death, and victory. Add melee combo clips for Albert, minigun spin for Magnus, charge poses for Iris/Nadia, and casting for Seren. Rifle and minigun grips need believable two-hand placement. For local co-op, add downed and revive visuals.

Use in-place locomotion controlled by Godot. Keep gameplay timing independent of cosmetic animation playback; synchronize fire, melee windows, and cast moments through explicit events. Layer upper-body aiming over movement where practical. Use consistent clip names and a documented animation manifest.

Export selected meshes, skeletons, materials, and clips to .glb with no unintended cameras, lights, or hidden reference objects. Validate Blender-to-Godot axis conversion, scale, facing direction, pivots, rest poses, skinning, material appearance, and animation names. Apply transformations safely before rigging; do not apply arbitrary transforms to completed rigs without checking their animations. Prefer explicit .glb delivery so opening the game does not require Blender for import.

Deliver the .blend sources, exported .glb assets, production scripts, and front/side/gameplay-angle renders of each fighter. Inspect actual renders; a successful script execution alone is insufficient visual validation.

## 7. Controls and movement

Keyboard/mouse defaults: WASD move; mouse aim projected onto the gameplay plane; left mouse primary attack; right mouse special ability; Space dodge; E interact/revive; Escape pause. Normalize diagonal input. Handle ray intersections and obstructions robustly so aim does not jump when the mouse passes over walls.

Controller defaults: left stick movement; right stick aim; right trigger primary attack; left trigger special ability; south face button dodge; west face button interact/revive; menu button pause. Preserve last valid aim when the stick returns to its dead zone. Provide remapping and sensitivity settings.

Separate per-player input sources so controller two cannot accidentally steer player one. Support disconnect/reconnect gracefully.

Use responsive acceleration and stopping, consistent collision sliding, a short dodge with cooldown and a limited invulnerability window, and clearly signaled incoming damage. Do not allow dodging through solid geometry. Make movement camera-relative and keep weapon facing independent of locomotion direction.

## 8. Combat rules and feedback

Implement a common damage contract: source, team, damage, hit position, knockback, damage type, and critical state. Friendly fire is disabled. A hit must not apply duplicate damage from multiple callbacks. Piercing attacks maintain a per-attack hit set and stop at solid walls unless an explicit ability says otherwise.

Use validated ray queries for instant-hit weapons, swept collision for fast traveling projectiles, and explicit attack-window hit volumes for melee. Albert can hit each target once per combo swing. Enemy attacks require visible windups and enforceable hit windows.

Every weapon needs distinct attack cadence, audiovisual identity, impacts, cooldown or heat behavior, and balance. Include muzzle flashes, tracers, sword trails, electrical arcs, energy rings, small debris bursts, restrained hit flashes, knockback, and subtle recoil. Render cyan lightning inspired by A and purple effects inspired by B. Keep attack telegraphs visible through effect-heavy moments.

Use health pickups and shared team XP. Avoid ammunition pickups in this initial design; balance weapons with rate of fire, cooldowns, heat, charge time, range, and movement tradeoffs. Put all values in resources and tune after testing.

In co-op, defeated fighters enter a timed downed state. The teammate can revive by holding interact nearby. Downed players cannot attack; the run ends if both are downed or eliminated. Solo defeat triggers the results screen. The AI companion follows the same damage and revive rules.

## 9. Enemies, navigation, and waves

Common enemies should retain the dark chunky appearance in A–C: black or charcoal bodies, cubic helmets, simple limbs, and orange-red glowing eyes. Keep them simpler than the heroes so large crowds remain visually and computationally manageable.

Implement five readable archetypes:

- Grunt: normal pursuing melee enemy.
- Runner: smaller, faster, lower health, with a lunging attack.
- Brute: broader silhouette, higher health, slower heavy attack and knockback.
- Shooter: maintains distance, checks line of sight, fires visible dodgeable projectiles.
- Shield unit: frontal damage reduction, exposed rear, and a clearly readable facing direction.

Boss: a large industrial security automaton with a telegraphed charge, radial attack, and limited reinforcement summons. Use at least two behavior phases. Give each attack a recovery window. Boss size and health should create a challenge without filling every corridor or preventing navigation.

Enemies must navigate around walls, avoid indefinite jams, separate locally, and retarget when a fighter is downed. Use a spatial query or grid for nearby targets and separation. Stagger path recalculation and decision ticks. Implement stuck detection and a safe recovery strategy; never teleport enemies into the player or through visible solid walls.

Wave resources control spawn counts, archetype mix, pacing, spawn budget, and active population limits. Start small and escalate toward an initial target of 80–120 simultaneous common enemies if the test hardware sustains it. Spawn at valid boundary points with advance cues; never inside obstacles, directly on fighters, or in unavoidable attack range.

Companion AI should maintain a useful distance, aim and attack, avoid nearby threats, navigate around obstacles, prioritize reviving when safe, and never require the player to micromanage it.

## 10. Upgrades, UI, and audio

After designated waves, pause combat and offer three distinct upgrade choices. Give each human a clear sequential choice step; resume only after required choices are complete. The AI companion receives an appropriate automatic choice. Avoid offering an upgrade incompatible with the selected fighter.

Include at least twelve functioning upgrade definitions across health, movement, dodge recovery, attack damage, attack cadence, special cooldown, piercing, heat/charge behavior, and fighter-specific mechanics. Document stacking rules and caps. Every offered upgrade must modify actual gameplay.

UI visual language: clean industrial sci-fi panels, navy text, white/off-white surfaces, blue framing, yellow highlights, and restrained fighter colors. Required screens: title/main menu, mode and fighter selection, in-game HUD, pause, settings, upgrade choice, victory/defeat, and run results.

HUD: fighter identity, health, weapon heat or charge when relevant, dodge/special readiness, wave number, enemies remaining, and revive information. Preserve arena visibility. Include optional enemy health bars, readable tooltips, color-independent status icons, reduced camera shake, and adjustable effects intensity.

Audio: distinct weapon loops/shots, sword swishes, energy casts, enemy windups, damage, death, pickups, wave transitions, UI clicks, and a restrained combat music loop. Provide master/music/SFX sliders. Use only generated or appropriately licensed audio and document provenance. Prevent a large enemy crowd from spawning unlimited simultaneous sounds.

Save settings, key bindings, best score, and selected fighters with robust defaults and graceful recovery from missing or invalid save data. Do not require an account or external service.

## 11. Performance and verification

Target 60 FPS at 1920 × 1080 on the available test machine with two fighters, the finished arena, representative effects, and the target crowd. Record the machine, renderer, population, and measured frame times. Report unmet targets honestly. Do not label performance as verified without a real run.

Profile before optimization. Reuse shared meshes/materials, pool high-frequency effects and projectiles where useful, cap persistent debris, limit shadow-casting lights, stagger AI work, and provide effect/shadow quality settings. Do not sacrifice the defining fighter silhouettes to meet an arbitrary polygon count.

Run meaningful checks for damage application, attack cooldowns, upgrade effects, wave progression, team filtering, pause behavior, and save recovery. Playtest navigation, keyboard/mouse aiming, controller ownership, disconnects, both co-op revive paths, all six fighters, victory/defeat, and repeated restart cycles. Verify no orphan projectiles, leaked enemies, accumulating signal connections, or stale state after restarting.

Compare in-engine screenshots with the references at an equivalent elevated angle. Check arena color balance, wall placement rhythm, shadow direction, hero silhouettes, weapon scale, enemy contrast, and the legibility of both players. Inspect fighters at both close range and normal gameplay scale. Capture evidence; do not substitute descriptions for screenshots.

## 12. Implementation milestones

1. Environment audit and reference breakdown: inspect installed tools, confirm Blender MCP capabilities, establish project structure, and record assumptions.
2. Playable graybox: arena collision/navigation, camera, one controllable fighter, one weapon, enemies, damage, pause, and restart.
3. Visual benchmark: finished Magnus made through Blender MCP, one polished arena section, real lighting/materials, export/import validation, and reference comparison.
4. Full combat roster: remaining fighters, weapons, animations, enemy archetypes, boss, companion, and local co-op.
5. Complete game loop: ten waves, upgrades, menus, HUD, audio, settings, saves, victory/defeat, and results.
6. Polish and delivery: performance profiling, visual corrections, gameplay testing, reproducible asset pipeline, and runnable export.

At every milestone, run the project, correct blocking errors, and provide a short factual progress update. Keep the initial graybox temporary. Finish the required scope before optional modes or additional arenas.

## 13. Required delivery and completion criteria

Deliver the complete Godot source project; Blender source files; exported models and animations; Blender MCP production scripts; editable gameplay resources; README with exact versions, controls, setup and run instructions; asset/animation manifests; license notes; verification results; and representative in-engine screenshots.

Provide a desktop export for the platform supported by the environment. If export templates or platform tools are unavailable, deliver the runnable Godot project and clearly identify the export blocker. Never call a missing build “delivered.”

The work is complete when:

- The project opens and runs without script, import, or missing-resource errors.
- All six fighters match the last reference's armor language and have distinct functional weapons and abilities.
- The arena clearly matches the white/blue/yellow industrial direction of the first three references.
- Solo, companion, and local co-op modes function through a full run.
- Enemies navigate, attack, take damage, die, and progress through waves correctly.
- Boss victory, player defeat, upgrades, revives, settings, and restarts work.
- Required assets are finished rather than unmarked placeholders.
- Performance and visual quality have been checked with recorded evidence.
- Source assets and production scripts allow the project to be edited and reproduced.

Start by inspecting the attached images and available Godot/Blender MCP environment. Then build the game. Make routine implementation decisions independently, document material assumptions, and ask only when missing information or access blocks necessary work.
