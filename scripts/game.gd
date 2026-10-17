extends Node3D

const Actor = preload("res://scripts/actor.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Data = preload("res://scripts/data.gd")
const Arena = preload("res://scripts/arena.gd")
const UI = preload("res://scripts/ui.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Fx = preload("res://scripts/fx.gd")
const Campaign = preload("res://scripts/campaign.gd")
const HazardScript = preload("res://scripts/hazard.gd")

var state := "menu"
var mode := 0
var selected := [0,3]
var arena_theme := "white"  # environment of the current run (Data.ARENAS key)
var survival_arena := "white"  # the environment picked for Survival (saved)
# Campaign (Operation Meridian, campaign.gd): five chapters of three waves and a boss.
var campaign := false
var chapter := 0            # current chapter (0-4)
var start_chapter := 0      # chapter a new campaign run starts from (picked in Run setup)
var unlocked := 1           # chapters available in Run setup (saved)
var wave_pool := {}         # enemy id -> weight for the wave being spawned
var boss_actor: SectorActor  # the boss on the field (HUD health bar), null otherwise
var upgrade_after := Callable()  # what follows the upgrade picks (next wave, or the next chapter)
var shutting_down := false  # a boss just fell: the remaining robots power down (no splitting)
var heroes: Array[SectorActor] = []
var enemies: Array[SectorActor] = []
var arena: Node3D
var camera: Camera3D
var ui: Control
var wave := 0
var score := 0
var team_xp := 0
var kills := 0
var best := 0
var spawn_left := 0
var spawn_timer := 0.0
var wave_wait := 0.0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var config := ConfigFile.new()
var settings := {"master":.75,"music":.35,"sfx":.7,"shake":.35,"effects":1.0,"sensitivity":1.0,"fullscreen":0.0,"vsync":1.0,"autoaim":0.0,"killcam":1.0,"coop":0.0}  # coop: local two-player mode offered in the squad picker (0 off, 1 couch, 2 two pads)
const SAVED_BINDINGS := ["move_left","move_right","move_up","move_down","dodge","interact","weapon_prev","weapon_next"]
var upgrade_queue: Array[int] = []
var offers: Array[Dictionary] = []
var sfx_pool: Array[AudioStreamPlayer] = []
var tones := {}
# Per-sound trims so rapid or very short clips do not dominate the mix.
const SFX_GAIN := {"minigun":.55,"smg":.45,"pistol":.7,"ui":.5,"switch":.6,"damage":.7,"windup":.9,"wave":1.2,"explosion":1.1,"shatter":.3,"disintegrate":.4,"plasma":.6,"destroyed_1":1.0,"destroyed_2":1.0,"destroyed_3":1.0,"blade_hit":.85,"sniper":1.1,"rack":.7}
var music: AudioStreamPlayer
# Perspective follow camera, pitched ~55 degrees like the reference shots.
const CAM_OFFSET := Vector3(0,27,19)
const CAM_FOV := 38.0
var camera_center := Vector3.ZERO
var camera_zoom := 1.0
var camera_kick := Vector3.ZERO
var hitstop_until := 0
var _next_hitstop := 0
var killcam: KillCam  # every 9th kill and the boss: cinematic kill cam (killcam.gd)
var cinematic := false  # accents (camera nudge, scoped zoom, slow-motion) run from the start of a run until the first kill
var shake_amount := 0.0
var fx: SectorFx
var projectile_meshes := {}

func _ready() -> void:
 rng.randomize()
 _input_actions()
 _load_save()
 apply_display()
 get_tree().auto_accept_quit=false  # quit_game() releases audio first
 ui=UI.new(); add_child(ui); ui.bind(self)
 fx=Fx.new(); fx.name="Fx"; fx.game=self; add_child(fx)
 _load_projectile_meshes()
 for i in range(16):
  var channel:=AudioStreamPlayer.new(); add_child(channel); sfx_pool.append(channel)
 # Procedural tones are the fallback; ElevenLabs-generated clips in assets/audio replace them (source_art/audio/generate_audio.py).
 tones={"minigun":_tone(175,.09),"sword":_tone(95,.22,true),"pistol":_tone(520,.12),"rail":_tone(870,.25),"bolt":_tone(390,.18),"rifle":_tone(210,.22),"windup":_tone(140,.28),"damage":_tone(100,.16,true),"death":_tone(75,.28,true),"pickup":_tone(760,.25),"wave":_tone(440,.42),"ui":_tone(630,.07),
  "smg":_tone(260,.06),"shotgun":_tone(90,.25,true),"rocket":_tone(120,.35,true),"grenade":_tone(180,.15),"plasma":_tone(560,.14),"explosion":_tone(60,.5,true),"switch":_tone(900,.05),"shatter":_tone(300,.2,true),"disintegrate":_tone(700,.35),
  "destroyed_1":_tone(140,.3,true),"destroyed_2":_tone(120,.3,true),"destroyed_3":_tone(160,.3,true),"blade_hit":_tone(500,.15,true),"sniper":_tone(180,.4,true),"rack":_tone(700,.2,true)}
 for kind in tones.keys():
  var clip_path:="res://assets/audio/%s.ogg" % kind
  if ResourceLoader.exists(clip_path): tones[kind]=load(clip_path)
 music=AudioStreamPlayer.new(); add_child(music)
 if ResourceLoader.exists("res://assets/audio/music.ogg"):
  var track: AudioStreamOggVorbis=load("res://assets/audio/music.ogg"); track.loop=true; music.stream=track
 else: music.stream=_music()
 music.play()
 ui.show_menu()

func _input_actions() -> void:
 for entry in [["move_left",KEY_A],["move_right",KEY_D],["move_up",KEY_W],["move_down",KEY_S],["dodge",KEY_SPACE],["interact",KEY_E],["pause",KEY_ESCAPE],
   ["weapon_prev",KEY_Q],["weapon_next",KEY_R],["weapon_1",KEY_1],["weapon_2",KEY_2],["weapon_3",KEY_3],["weapon_4",KEY_4],["weapon_5",KEY_5],["weapon_6",KEY_6],["weapon_7",KEY_7],["weapon_8",KEY_8]]:
  if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
  if InputMap.action_get_events(entry[0]).is_empty():
   var ev:=InputEventKey.new(); ev.physical_keycode=entry[1]; InputMap.action_add_event(entry[0],ev)

func _load_save() -> void:
 var err:=config.load("user://sector03.cfg")
 if err!=OK: return
 for k in settings: settings[k]=clampf(float(config.get_value("settings",k,settings[k])),0.0,2.0 if k in ["sensitivity","coop"] else 1.0)
 best=maxi(0,int(config.get_value("progress","best",0)))
 for i in range(2): selected[i]=clampi(int(config.get_value("selection","fighter"+str(i),selected[i])),0,5)
 var saved_arena:=str(config.get_value("selection","arena","white"))
 survival_arena=saved_arena if Data.ARENAS.has(saved_arena) else "white"
 arena_theme=survival_arena
 unlocked=clampi(int(config.get_value("progress","chapter_unlocked",1)),1,Campaign.CHAPTERS.size())
 for action in SAVED_BINDINGS:
  var key:=int(config.get_value("bindings",action,0))
  if key>0:
   InputMap.action_erase_events(action)
   var ev:=InputEventKey.new(); ev.physical_keycode=key; InputMap.action_add_event(action,ev)

# Fullscreen and V-sync come from settings (stored as 0/1); F11 or Alt+Enter toggles fullscreen.
func apply_display() -> void:
 var full: bool=settings.fullscreen>=.5
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync>=.5 else DisplayServer.VSYNC_DISABLED)

func toggle_fullscreen() -> void:
 settings.fullscreen=0.0 if settings.fullscreen>=.5 else 1.0
 apply_display(); save_preferences()

# Release audio before shutdown so the streaming music playback is freed (avoids leak warnings at exit).
func _stop_audio() -> void:
 if is_instance_valid(music): music.stop(); music.stream=null
 for c in sfx_pool: if is_instance_valid(c): c.stop(); c.stream=null
 tones.clear()

func quit_game() -> void:
 get_tree().auto_accept_quit=false
 _stop_audio()
 await get_tree().process_frame
 await get_tree().process_frame
 get_tree().quit()

func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func _exit_tree() -> void:
 _stop_audio()

func save_preferences() -> void:
 if get_tree().get_script()!=null: return  # headless test scripts (--script) tweak settings: never persist them
 for k in settings: config.set_value("settings",k,settings[k])
 config.set_value("progress","best",best)
 for i in range(2): config.set_value("selection","fighter"+str(i),selected[i])
 config.set_value("selection","arena",survival_arena)
 config.set_value("progress","chapter_unlocked",unlocked)
 for action in SAVED_BINDINGS:
  var events:=InputMap.action_get_events(action)
  if not events.is_empty() and events[0] is InputEventKey: config.set_value("bindings",action,events[0].physical_keycode)
 config.save("user://sector03.cfg")

func joy_for(owner: int) -> int:
 var pads:=Input.get_connected_joypads()
 if owner<=0 or owner>pads.size(): return -1
 return pads[owner-1]

func start_run() -> void:
 _clear_run()
 state="playing"; wave=0; score=0; team_xp=0; kills=0; elapsed=0
 cinematic=true  # one cinematic opening per run: ends with the first robot destroyed
 chapter=start_chapter if campaign else 0
 arena_theme=Campaign.CHAPTERS[chapter].arena if campaign else survival_arena
 _build_arena()
 camera=Camera3D.new(); camera.fov=CAM_FOV; camera.near=.5; camera.far=200
 camera_center=Vector3(-1,0,1); camera_zoom=1.0
 camera.position=camera_center+CAM_OFFSET; add_child(camera); camera.look_at(camera_center,Vector3.UP); camera.current=true
 if killcam==null: killcam=KillCam.new(); killcam.game=self; add_child(killcam)
 _spawn_hero(selected[0],0,Vector3(-2,0,1))
 if mode==1: _spawn_hero(selected[1],-1,Vector3(1,0,1))
 elif mode==2: _spawn_hero(selected[1],1,Vector3(1,0,1))
 elif mode==3:
  heroes[0].input_id=1
  _spawn_hero(selected[1],2,Vector3(1,0,1))
 if campaign:
  # starting further in: catch up on the upgrades the earlier chapters would have given (two per chapter)
  for h in heroes:
   for k in range(chapter*2): _auto_upgrade(h)
  state="briefing"; ui.show_briefing(chapter)
  return
 ui.show_hud()
 _next_wave()

func _build_arena() -> void:
 arena=Arena.new(); arena.name="Arena"; arena.theme=arena_theme; add_child(arena)

# Briefing -> fight.
func deploy() -> void:
 if state!="briefing": return
 state="playing"; ui.show_hud(); _next_wave()

# Next chapter: new environment, same squad (health, upgrades and ammo carry over; anyone down gets back up).
func _load_chapter(n: int) -> void:
 chapter=n; wave=0; boss_actor=null; spawn_left=0; wave_wait=0
 if is_instance_valid(killcam): killcam.stop()
 Engine.time_scale=1.0; hitstop_until=0
 for e in enemies: if is_instance_valid(e): e.queue_free()
 enemies.clear()
 for p in get_tree().get_nodes_in_group("transient"): p.queue_free()
 if is_instance_valid(fx): fx.clear()
 if is_instance_valid(arena): arena.name="ArenaOld"; arena.queue_free()
 arena_theme=Campaign.CHAPTERS[n].arena
 _build_arena()
 var spots:=[Vector3(-2,0,1),Vector3(1,0,1)]
 for i in range(heroes.size()):
  var h:=heroes[i]
  if not is_instance_valid(h): continue
  h.global_position=spots[mini(i,1)]; h.velocity=Vector3.ZERO; h.end_move()
  if h.dead or h.downed:
   h.dead=false; h.downed=false; h.visible=true; h.revive_progress=0; h._play_anim("revive")
  h.hp=maxf(h.hp,h.max_hp*.6); h.special_timer=0; h.buffs.clear(); h._update_bar()
 camera_center=Vector3(-1,0,1)
 state="briefing"; ui.show_briefing(chapter)

# Debrief -> upgrade picks -> next chapter (or the end of the campaign).
func continue_after_debrief() -> void:
 if state!="debrief": return
 if chapter>=Campaign.CHAPTERS.size()-1: _finish(true); return
 _begin_upgrades(func(): _load_chapter(chapter+1))

func _chapter_clear() -> void:
 state="debrief"
 unlocked=maxi(unlocked,mini(chapter+2,Campaign.CHAPTERS.size()))
 save_preferences()
 ui.show_debrief(chapter)

# HUD wave text: "2-3" (chapter 2, wave 3) or "2-B" (boss) in the campaign, the wave number in Survival.
func wave_label() -> String:
 if not campaign: return "%d" % wave
 return "%d-%s" % [chapter+1,"B" if wave>=4 else str(maxi(wave,1))]

# A line on the radio from the handler (or OVERSEER) for this moment of the chapter.
func radio(moment: String) -> void:
 if not campaign: return
 var line: String=Campaign.CHAPTERS[chapter].radio.get(moment,"")
 if line!="": ui.radio(Campaign.speaker(chapter,moment),line,5.5)

func _clear_run() -> void:
 if is_instance_valid(killcam): killcam.stop()
 Engine.time_scale=1.0; hitstop_until=0
 for h in heroes: if is_instance_valid(h): h.queue_free()
 for e in enemies: if is_instance_valid(e): e.queue_free()
 heroes.clear(); enemies.clear(); boss_actor=null; shutting_down=false
 for p in get_tree().get_nodes_in_group("transient"): p.queue_free()
 if is_instance_valid(fx): fx.clear()
 if is_instance_valid(arena): arena.queue_free()
 if is_instance_valid(camera): camera.queue_free()
 arena=null; camera=null

func _spawn_hero(id: int, owner: int, pos: Vector3) -> void:
 var a: SectorActor=Actor.new(); a.setup(self,true,id,owner); a.slot=heroes.size(); a.position=pos; add_child(a); heroes.append(a)

func _spawn_enemy(id: int) -> SectorActor:
 var p:=Vector3.ZERO
 for tries in range(60):
  var side:=rng.randi_range(0,3)
  if side==0: p=Vector3(rng.randf_range(-21,21),0,-16.5)
  elif side==1: p=Vector3(rng.randf_range(-21,21),0,16.5)
  elif side==2: p=Vector3(-21,0,rng.randf_range(-15,15))
  else: p=Vector3(21,0,rng.randf_range(-15,15))
  if arena.valid_spawn(p) and _min_hero_distance(p)>8: break
 return spawn_enemy_at(id,p)

# Puts a robot on the field: chapter health scaling, a chance to be elite, bosses tougher with two fighters.
func spawn_enemy_at(id: int, p: Vector3, allow_elite := true) -> SectorActor:
 var a: SectorActor=Actor.new(); a.setup(self,false,id,-2)
 var hp_mul: float=float(Campaign.CHAPTERS[chapter].hp) if campaign else 1.0
 if a.boss and heroes.size()>1: hp_mul*=1.35
 a.max_hp*=hp_mul; a.hp=a.max_hp; a.damage*=1.0+(hp_mul-1.0)*.5
 var elite_chance: float=float(Campaign.CHAPTERS[chapter].elite) if campaign else (.05 if wave>=6 else 0.0)
 if allow_elite and not a.boss and rng.randf()<elite_chance: a.make_elite()
 a.position=p; add_child(a); enemies.append(a)
 flash(p+Vector3.UP,Color("ff703e"),.55)
 if a.boss:
  boss_actor=a
  ui.boss_card(a)
 return a

func _min_hero_distance(p: Vector3) -> float:
 var d:=10000.0
 for h in heroes: if is_instance_valid(h) and not h.dead: d=minf(d,h.global_position.distance_to(p))
 return d

func _next_wave() -> void:
 wave+=1
 if campaign: _campaign_wave(); return
 if wave>10: _finish(true); return
 spawn_left=0 if wave==10 else [10,14,19,25,33,42,53,66,82][wave-1]
 wave_pool=Campaign.survival_pool(wave)
 spawn_timer=.5
 wave_wait=1.5
 _wave_heal()
 if wave==10: _spawn_enemy(Data.ARENAS[arena_theme].boss)  # each environment's own boss
 play_sfx("wave")
 ui.announce("WAVE %02d" % wave,2.0)

func _wave_heal() -> void:
 for h in heroes:
  if is_instance_valid(h) and not h.dead:
   h.hp=minf(h.max_hp,h.hp+8+Data.upgrade_value(h,"regen")*35); h._update_bar()

# Campaign waves 1-3 from the chapter's list, then wave 4: the boss with a trickle of escorts.
func _campaign_wave() -> void:
 var ch: Dictionary=Campaign.CHAPTERS[chapter]
 _wave_heal()
 play_sfx("wave")
 if wave<=3:
  spawn_left=int(ch.waves[wave-1][0]); wave_pool=ch.waves[wave-1][1]; spawn_timer=.5; wave_wait=1.5
  ui.announce("WAVE %d / 3" % wave,2.0)
  radio("wave%d" % wave)
 else:
  spawn_left=6; wave_pool=ch.escorts; spawn_timer=5.0; wave_wait=2.0
  _spawn_enemy(int(ch.boss))
  radio("boss")

func _process(delta: float) -> void:
 _end_hitstop_check()
 if is_instance_valid(music): music.volume_db=linear_to_db(maxf(.001,settings.master*settings.music*.7*(killcam.music_duck() if is_instance_valid(killcam) else 1.0)))
 if is_instance_valid(arena):
  arena.set_effects(settings.effects)
 if state!="playing": return
 elapsed+=delta
 if wave_wait>0: wave_wait-=delta
 elif spawn_left>0:
  spawn_timer-=delta
  if spawn_timer<=0 and enemies.size()<85:
   _spawn_enemy(Campaign.pick(wave_pool,rng)); spawn_left-=1
   spawn_timer=3.5 if is_instance_valid(boss_actor) else maxf(.15,.75-wave*.055)  # escorts trickle in during a boss
 elif enemies.is_empty() and wave_wait<=0:
  wave_wait=9999
  if campaign:
   if wave>=4: _chapter_clear()
   elif wave==2: _begin_upgrades()  # one pick mid-chapter, one after the boss
   else: _next_wave()
  elif wave<10 and wave%2==0: _begin_upgrades()
  else: _next_wave()
 _camera_update(delta)
 ui.update_hud()

func _camera_update(delta: float) -> void:
 if not is_instance_valid(camera): return
 var center:=Vector3.ZERO; var count:=0; var separation:=0.0
 for h in heroes:
  if is_instance_valid(h) and not h.dead:
   center+=h.global_position; count+=1
 if count==0: return
 center/=count
 if count>1: separation=heroes[0].global_position.distance_to(heroes[1].global_position)
 camera_zoom=lerpf(camera_zoom,clampf(1+separation*.02,1,1.35),delta*2)
 var focus:=Vector3(clampf(center.x,-12,12),0,clampf(center.z,-9,8))
 camera_center=camera_center.lerp(focus,clampf(delta*2.2,0,1))
 shake_amount=maxf(0,shake_amount-delta*1.6)
 camera_kick=camera_kick.lerp(Vector3.ZERO,clampf(delta*9.0,0,1))
 # scoped weapons pull the camera in slightly for a focused, cinematic framing
 var scoped: bool=heroes.size()>0 and is_instance_valid(heroes[0]) and not heroes[0].loadout.is_empty() and heroes[0].stance=="sniper"
 camera.fov=lerpf(camera.fov,CAM_FOV*(.97 if scoped and cinematic else 1.0),clampf(delta*3.0,0,1))
 camera.global_position=camera_kick+camera_center+CAM_OFFSET*camera_zoom+Vector3(randf_range(-1,1),randf_range(-1,1),0)*shake_amount*settings.shake

const GUN_HEIGHT := 1.4
var cursor_override := Vector2(-1,-1)  # tests drive a virtual cursor (viewport pixels) instead of the real mouse

func cursor_pos() -> Vector2:
 return cursor_override if cursor_override.x>=0 else get_viewport().get_mouse_position()
# Where the cursor ray meets a horizontal plane (gun height by default): shots aimed here pass through the cursor on screen.
func mouse_plane(height: float) -> Vector3:
 if not is_instance_valid(camera): return Vector3.ZERO
 var origin:=camera.project_ray_origin(cursor_pos())
 var dir:=camera.project_ray_normal(cursor_pos())
 if absf(dir.y)<.01: return Vector3.ZERO
 return origin+dir*((height-origin.y)/dir.y)

# Mouse aim point: if the cursor is over a robot on screen, aim at that robot's body (magnetism), otherwise at
# the point under the cursor at gun height.
func mouse_aim(height: float = GUN_HEIGHT) -> Vector3:
 var p:=mouse_plane(height)
 if not is_instance_valid(camera): return p
 var cursor:=cursor_pos()
 var best: SectorActor=null; var best_d:=INF
 for e in enemies:
  if not is_instance_valid(e) or e.dead: continue
  var h: float=maxf(1.0,e.body_scale())
  for k in range(3):  # feet, middle, head
   if camera.is_position_behind(e.global_position): continue
   var sp:=camera.unproject_position(e.global_position+Vector3.UP*h*(.15+.42*k))
   var d:=sp.distance_to(cursor)
   if d<best_d: best_d=d; best=e
 var radius:=34.0*get_viewport().get_visible_rect().size.y/720.0
 if best!=null and best_d<radius: return Vector3(best.global_position.x,height,best.global_position.z)
 return p

# Direction from the gun's muzzle to the shooter's aim point (flat), so the visible shot and its damage line
# both leave the barrel and cross the cursor, whatever way the fighter is moving.
func shot_dir(source: SectorActor, fallback: Vector3) -> Vector3:
 var v: Vector3=source.aim_point-source.muzzle_position(); v.y=0
 if v.length()>1.2 and v.normalized().dot(fallback)>.5: return v.normalized()
 # cursor too close to (or behind) the muzzle: fire the way the barrel points
 var barrel: Vector3=source.barrel_dir()
 return barrel if barrel!=Vector3.ZERO and barrel.dot(fallback)>.5 else fallback

func shot_origin(source: SectorActor) -> Vector3:
 var m:=source.muzzle_position()
 return Vector3(m.x,source.global_position.y+.88,m.z)

func mouse_floor() -> Vector3:
 if not is_instance_valid(camera): return Vector3.ZERO
 var origin:=camera.project_ray_origin(get_viewport().get_mouse_position())
 var dir:=camera.project_ray_normal(get_viewport().get_mouse_position())
 if absf(dir.y)<.01: return Vector3.ZERO
 return origin+dir*(-origin.y/dir.y)

func _input(event: InputEvent) -> void:
 if event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START):
  if state=="playing": state="paused"; ui.show_pause()
  elif state=="paused": state="playing"; ui.show_hud()
 if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_F11 or (event.physical_keycode==KEY_ENTER and event.alt_pressed)):
  toggle_fullscreen(); get_viewport().set_input_as_handled(); return
 if state=="playing" and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  for h in heroes:
   if is_instance_valid(h) and h.input_id==0 and not h.dead and not h.downed: h.set_weapon(h.weapon+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1))

func closest_enemy(pos: Vector3) -> SectorActor:
 var chosen: SectorActor=null; var d:=INF
 for e in enemies:
  if not is_instance_valid(e) or e.dead: continue
  var v:=e.global_position.distance_squared_to(pos)
  if v<d: d=v; chosen=e
 return chosen

func enemy_separation(actor: SectorActor) -> Vector3:
 var push:=Vector3.ZERO
 for other in enemies:
  if other==actor or not is_instance_valid(other) or other.dead: continue
  var away:=actor.global_position-other.global_position; away.y=0
  var squared:=away.length_squared()
  if squared>.001 and squared<1.25: push+=away.normalized()*(1.25-squared)
 return push.limit_length(1.0)

func closest_active_hero(pos: Vector3) -> SectorActor:
 var chosen: SectorActor=null; var d:=INF
 for h in heroes:
  if not is_instance_valid(h) or h.dead or h.downed: continue
  var v:=h.global_position.distance_squared_to(pos)
  if v<d: d=v; chosen=h
 return chosen

func closest_human(pos: Vector3) -> SectorActor:
 for h in heroes: if is_instance_valid(h) and h.input_id>=0: return h
 return null

func closest_downed(pos: Vector3) -> SectorActor:
 var chosen: SectorActor=null; var d:=INF
 for h in heroes:
  if is_instance_valid(h) and h.downed and not h.dead:
   var v:=h.global_position.distance_squared_to(pos)
   if v<d: chosen=h; d=v
 return chosen

# Auto aim (Settings > Feel): the best visible robot near the direction the player is aiming, within the
# weapon's reach. `wanted` is the player's own aim direction (flat); ZERO means "anything" (idle controller stick).
# The current lock is kept while it stays near the aim, so the target does not flicker between robots.
func auto_aim(source: SectorActor, wanted: Vector3, height: float) -> Vector3:
 if settings.autoaim<.5 or source.loadout.is_empty(): source.auto_target=null; return Vector3.ZERO
 var w: Dictionary=source.loadout[source.weapon]
 var reach: float=float(w.get("range",22.0)) if w.kind!="melee" else float(w.radius)+1.5
 var cone:=deg_to_rad(50.0)
 var best: SectorActor=null; var best_score:=INF
 for e in enemies:
  if not is_instance_valid(e) or e.dead: continue
  var v: Vector3=e.global_position-source.global_position; v.y=0
  var dist:=v.length()
  if dist>reach or dist<.3: continue
  var ang:=0.0 if wanted==Vector3.ZERO else v.normalized().angle_to(wanted)
  var sticky: bool=e==source.auto_target
  if ang>(cone*1.4 if sticky else cone): continue
  if not line_of_sight(source.global_position,e.global_position): continue
  var score:=ang*10.0+dist*(.35 if wanted!=Vector3.ZERO else 1.0)-(2.5 if sticky else 0.0)
  if score<best_score: best_score=score; best=e
 source.auto_target=best
 if best==null: return Vector3.ZERO
 return Vector3(best.global_position.x,height,best.global_position.z)

func line_of_sight(a: Vector3,b: Vector3) -> bool:
 var q:=PhysicsRayQueryParameters3D.create(a+Vector3.UP*.8,b+Vector3.UP*.8,1)
 return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func hurt(victim: SectorActor, amount: float, source: SectorActor, at: Vector3, damage_type := "kinetic", knockback := 0.0, critical := false) -> void:
 if is_instance_valid(victim):
  # Critical optics upgrade: a chance for any hit from that fighter to land as a critical
  if is_instance_valid(source) and source.hero and not critical and rng.randf()<Data.upgrade_value(source,"crit")*.10: critical=true
  var before: float=victim.hp
  victim.take_damage(amount,source,at,damage_type,knockback,critical)
  if victim.hero: shake_amount=maxf(shake_amount,.45)
  elif before-victim.hp>0: fx.number(victim.global_position+Vector3.UP*maxf(1.6,victim.body_scale()*1.05),before-victim.hp,Color("ff9a2a") if critical else (Color("ffe28a") if amount>=40 else Color.WHITE))

func hitscan(source: SectorActor, dir: Vector3, amount: float, length: float, pierce: int, color: Color) -> void:
 # Damage ray runs at body height; the visible tracer starts at the weapon's muzzle.
 var start:=source.global_position+Vector3.UP*.88+dir*.58
 var end:=start+dir*length
 var excludes: Array[RID]=[source.get_rid()]
 for i in range(pierce):
  var q:=PhysicsRayQueryParameters3D.create(start,end,1|2|4)
  q.exclude=excludes
  var hit:=get_world_3d().direct_space_state.intersect_ray(q)
  if hit.is_empty(): break
  end=hit.position if hit.collider is StaticBody3D else end
  if hit.collider is SectorActor:
   var a: SectorActor=hit.collider
   if a.team!=source.team: hurt(a,amount,source,hit.position,"energy" if source.hero_id in [3,4] else "kinetic",.7)
   excludes.append(a.get_rid())
  else: break
 var muzzle:=source.muzzle_position()
 if end.distance_to(start)>=length-.01: end.y=muzzle.y
 _beam(muzzle,end,color,.045,.13)

func melee(source: SectorActor, radius: float, amount: float, arc: float, color: Color) -> void:
 var hits:={}
 var pool: Array= enemies if source.hero else heroes
 for target: SectorActor in pool:
  if not is_instance_valid(target) or target.dead or target.downed: continue
  var v:=target.global_position-source.global_position; v.y=0
  if v.length()<=radius and source.aim.dot(v.normalized())>cos(arc):
   if not hits.has(target.get_instance_id()) and line_of_sight(source.global_position,target.global_position):
    hits[target.get_instance_id()]=true; hurt(target,amount,source,source.global_position,"melee",3.0)
 _beam(source.global_position+Vector3.UP*.75,source.global_position+source.aim*radius+Vector3.UP*.75,color,.11,.20)

func spawn_projectile(source: SectorActor, dir: Vector3, amount: float, color: Color, v: float) -> void:
 var p: SectorProjectile=Projectile.new(); p.setup(self,source,dir,amount,color,v)
 p.position=source.muzzle_position()
 p.cruise_y=.85
 add_child(p); p.add_to_group("transient")

func boss_burst(source: SectorActor) -> void:
 for h in heroes:
  if is_instance_valid(h) and not h.dead and not h.downed and h.global_position.distance_to(source.global_position)<4: hurt(h,source.damage,source,source.global_position,"shock",5.0)
 for i in range(12):
  var d:=Vector3(sin(i*TAU/12),0,cos(i*TAU/12))
  spawn_projectile(source,d,source.damage*.55,Color("ff513c"),7)
 if source.enemy_id==5 and source.hp<source.max_hp*.5 and enemies.size()<20:
  for i in range(2): _spawn_enemy(1)

# Short slow-motion beat (real-time duration); aiming keeps running in real time meanwhile (actor._process).
func hitstop(seconds: float) -> void:
 if settings.effects<.5: return
 hitstop_until=maxi(hitstop_until,Time.get_ticks_msec()+int(seconds*1000))
 Engine.time_scale=.25

# Ends slow motion on the real-time clock (checked every rendered frame), so it can never get stuck on.
func _end_hitstop_check() -> void:
 if is_instance_valid(killcam) and killcam.active: return  # the kill cam drives time itself
 if Engine.time_scale<1.0 and Time.get_ticks_msec()>=hitstop_until: Engine.time_scale=1.0

func enemy_killed(e: SectorActor) -> void:
 var spec: Dictionary=Data.ENEMIES[e.enemy_id]
 score+=int(spec.score)*(3 if e.elite else 1)
 kills+=1
 team_xp+=int(spec.xp)
 enemies.erase(e)
 _drops(e)
 _kill_effects(e)
 if e.boss: _boss_down(e)
 var mode: String={"explosive":"explosive","energy":"energy"}.get(e.last_damage_type,"kinetic")
 # freeze-frames are rare accents: always on the boss, otherwise an occasional heavy kill with a long cooldown
 # the first robot destroyed in a run gets a short slow-motion beat, then cinematics are off for the run
 if cinematic: hitstop(.35)
 cinematic=false
 var away: Vector3=e.global_position-e.last_hit_from; away.y=0
 var boom:=func():
  if not is_instance_valid(e): return
  fx.disintegrate(e.global_position,e.model.scale.x if is_instance_valid(e.model) else 1.25,mode,away.normalized() if away.length_squared()>.01 else Vector3.ZERO,e.last_hit_color)
  play_sfx("destroyed")  # ElevenLabs robot-destroyed variants
  play_sfx("disintegrate" if mode=="energy" else ("death" if mode=="explosive" else "shatter"))  # quieter type layer
  e.queue_free()
 # every 9th kill: the kill cam may hold the robot intact until its shot lands on screen, then call boom
 # (not for kills made by a special move in progress: those already have their own staging)
 var by_special: bool=is_instance_valid(e.last_attacker) and e.last_attacker.move_t>=0
 if is_instance_valid(killcam) and not by_special and killcam.on_kill(e,kills,boom): return
 boom.call()

func _pickup(pos: Vector3, kind := "health") -> void:
 var p=Pickup.new(); p.game=self; p.kind=kind; p.position=Vector3(pos.x,0,pos.z); add_child(p); p.add_to_group("transient")

func _random_powerup() -> String:
 var kinds:=["overcharge","rapid","barrier","surge","haste"]
 return kinds[rng.randi_range(0,kinds.size()-1)]

# Repair kits and power-ups: bosses drop a spread, elites always one, others now and then (Scavenger raises it).
func _drops(e: SectorActor) -> void:
 if shutting_down: return
 var scav:=0.0
 for h in heroes: if is_instance_valid(h): scav=maxf(scav,Data.upgrade_value(h,"scavenger"))
 var at: Vector3=e.global_position
 if e.boss:
  for k in range(4): _pickup(at+Vector3(cos(k*TAU/4),0,sin(k*TAU/4))*1.8,"health" if k==0 else _random_powerup())
  return
 if e.elite: _pickup(at,_random_powerup()); return
 var r:=rng.randf()
 if r<.055: _pickup(at)
 elif r<.055+.04*(1.0+scav*.4): _pickup(at,_random_powerup())

# What a robot does as it dies (bombers blow up, splitters split) and the fighter's on-kill upgrades.
func _kill_effects(e: SectorActor) -> void:
 var by: SectorActor=e.last_attacker if is_instance_valid(e.last_attacker) else null
 if e.enemy_id==6 and not e.ai.get("self_destruct",false):  # a bomber shot down takes its neighbours with it
  blast(e.global_position,2.6,40.0,by,Color("ffb000"),1)
 if e.enemy_id==10 and not shutting_down:  # splitter: two runners climb out
  for side in [-1.0,1.0]:
   var p: Vector3=e.global_position+Vector3(side*.7,0,0)
   spawn_enemy_at(1,p if arena.valid_spawn(p) else e.global_position,false)
 if by!=null and by.hero:
  var vamp:=Data.upgrade_value(by,"vampiric")
  if vamp>0 and not by.downed and not by.dead: by.hp=minf(by.max_hp,by.hp+2.0*vamp); by._update_bar()
  var vol:=Data.upgrade_value(by,"volatile")
  if vol>0 and e.last_damage_type!="salvage":
   fx.sparks(e.global_position+Vector3.UP*.6,Color("ffb35a"),10,5.0); fx._ring(e.global_position,Color("ffb35a"),2.0,.2)
   for o in enemies.duplicate():
    if is_instance_valid(o) and not o.dead and o.global_position.distance_to(e.global_position)<1.8:
     hurt(o,18.0*vol,by,e.global_position,"salvage",1.5)

# A boss falls: its robots power down and the radio closes the chapter.
func _boss_down(e: SectorActor) -> void:
 if boss_actor==e: boss_actor=null
 ui.announce("%s DESTROYED" % Data.enemy_name(e.enemy_id).to_upper(),3.0)
 radio("down")
 shake_amount=maxf(shake_amount,.8)
 call_deferred("_shutdown_robots")

func _shutdown_robots() -> void:
 shutting_down=true
 for o in enemies.duplicate():
  if is_instance_valid(o) and not o.dead: hurt(o,99999.0,null,o.global_position,"energy")
 spawn_left=0
 shutting_down=false

# A boss enters a new phase (robots.gd): banner, radio line, a jolt.
func boss_phase(e: SectorActor, phase: int) -> void:
 ui.announce("%s  -  PHASE %d" % [Data.enemy_name(e.enemy_id).to_upper(),phase],2.5)
 radio("phase%d" % phase)
 fx._flash_mesh(e.global_position+Vector3.UP*1.5,e.eye_color(),3.5,.4)
 shake_amount=maxf(shake_amount,.5); play_sfx("windup")

# ---------------------------------------------------------------- robot attacks (robots.gd)
# Area damage on one side: hit_team 0 hurts the fighters, 1 the robots.
func blast(pos: Vector3, radius: float, amount: float, source: SectorActor, c: Color, hit_team: int) -> void:
 fx.explosion(pos,radius,c)
 play_sfx("explosion")
 shake_amount=maxf(shake_amount,.3)
 for t in (heroes if hit_team==0 else enemies).duplicate():
  if not is_instance_valid(t) or t.dead or t.downed: continue
  var dist: float=t.global_position.distance_to(Vector3(pos.x,t.global_position.y,pos.z))
  if dist<radius: hurt(t,amount*lerpf(1.0,.45,dist/radius),source,pos,"explosive",4.0)

# Mortar shell lobbed from a robot onto a point (a warning ring marks the landing spot).
func lob_shell(source: SectorActor, target: Vector3, amount: float, radius: float, c: Color) -> void:
 var p: SectorProjectile=Projectile.new(); p.setup(self,source,Vector3.FORWARD,amount,c,0.0)
 p.kind="shell"; p.radius_damage=radius
 var from: Vector3=source.global_position+Vector3.UP*1.6*source.body_scale()
 var land:=Vector3(target.x,0,target.z)
 p.lob(from,land); p.landing=land; p.position=from
 add_child(p); p.add_to_group("transient")

# The red line a lancer paints before it fires (stops at walls).
func telegraph_line(source: SectorActor, dir: Vector3, length: float, duration: float) -> void:
 var a: Vector3=source.global_position+Vector3.UP*.9
 var b: Vector3=a+dir*length
 var q:=PhysicsRayQueryParameters3D.create(a,b,1); q.exclude=[source.get_rid()]
 var wall:=get_world_3d().direct_space_state.intersect_ray(q)
 if not wall.is_empty(): b=wall.position
 _beam(a+Vector3.UP*.02,b,Color(1,.15,.18),.035,duration)
 if randf()<.5: play_sfx("windup")

# A robot's piercing beam: hits every fighter on the line up to a wall.
func enemy_beam(source: SectorActor, dir: Vector3, amount: float, c: Color) -> void:
 var start: Vector3=source.global_position+Vector3.UP*.88
 var r: Array=trace_shot(source,start,dir,26.0,4,.1)
 for h in r[0]: hurt(h[0],amount,source,h[1]-dir,"energy",2.5)
 var end: Vector3=r[1]
 fx.rail_beam(source.global_position+Vector3.UP*1.0*source.body_scale(),Vector3(end.x,1.0,end.z),c)
 fx.sparks(end,c,8,4.0)
 play_sfx("rail")

# Pulsing ring on the floor for an attack about to land on that area.
func warn_ring(pos: Vector3, radius: float, duration: float, c: Color) -> void:
 var m:=MeshInstance3D.new(); var t:=TorusMesh.new(); t.inner_radius=.94; t.outer_radius=1.0; t.rings=48; t.ring_segments=3; m.mesh=t
 var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.albedo_color=Color(c.r*2,c.g*2,c.b*2,.75); m.material_override=mat; m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 m.position=Vector3(pos.x,.07,pos.z); m.scale=Vector3(radius,.02,radius); add_child(m); m.add_to_group("transient")
 var fill:=MeshInstance3D.new(); var disc:=CylinderMesh.new(); disc.top_radius=1.0; disc.bottom_radius=1.0; disc.height=.01; disc.radial_segments=32; fill.mesh=disc
 var fmat:=mat.duplicate() as StandardMaterial3D; fmat.albedo_color=Color(c.r*1.5,c.g*1.5,c.b*1.5,.22); fill.material_override=fmat
 fill.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; fill.position=m.position; fill.scale=Vector3(.05,1,.05); add_child(fill); fill.add_to_group("transient")
 var tw:=fill.create_tween(); tw.tween_property(fill,"scale",Vector3(radius,1,radius),duration); tw.tween_callback(fill.queue_free)
 var tw2:=m.create_tween(); tw2.tween_interval(duration); tw2.tween_callback(m.queue_free)

func hazard(pos: Vector3, radius: float, life: float, dps: float, c: Color) -> void:
 var h=HazardScript.new(); h.game=self; h.radius=radius; h.life=life; h.dps=dps; h.color=c
 h.position=Vector3(pos.x,0,pos.z); add_child(h); h.add_to_group("transient")

func check_defeat() -> void:
 for h in heroes: if is_instance_valid(h) and not h.dead and not h.downed: return
 _finish(false)

func _finish(win: bool) -> void:
 if is_instance_valid(killcam): killcam.stop()
 if campaign:
  if win: unlocked=Campaign.CHAPTERS.size()
  else: start_chapter=chapter  # a retry starts at the chapter you fell in
 state="results"
 if win:
  for h in heroes:
   if is_instance_valid(h) and not h.dead: h._play_anim("victory")
 best=maxi(best,score); save_preferences()
 ui.show_results(win)

func _begin_upgrades(after := Callable()) -> void:
 upgrade_after=after
 state="upgrade"; upgrade_queue.clear()
 for i in range(heroes.size()):
  if is_instance_valid(heroes[i]) and not heroes[i].dead:
   if heroes[i].input_id==-1: _auto_upgrade(heroes[i])
   else: upgrade_queue.append(i)
 _show_next_upgrade()

func _auto_upgrade(h: SectorActor) -> void:
 h.apply_upgrade(Data.UPGRADES[rng.randi_range(0,Data.UPGRADES.size()-1)])

func _show_next_upgrade() -> void:
 if upgrade_queue.is_empty():
  state="playing"
  if upgrade_after.is_valid():
   var then:=upgrade_after; upgrade_after=Callable(); then.call()
  else: _next_wave(); ui.show_hud()
  return
 var h:=heroes[upgrade_queue[0]]
 var available: Array[Dictionary]=[]
 for u in Data.UPGRADES:
  if u.key=="revive" and heroes.size()<2: continue
  if u.key=="pierce" and h.hero_id in [1,4]: continue
  if u.key=="heat" and h.hero_id not in [0,3,5]: continue
  if int(h.upgrades.get(u.key,0))<int(u.cap): available.append(u)
 available.shuffle()
 offers=available.slice(0,3)
 ui.show_upgrades(h,offers)

func pick_upgrade(index: int) -> void:
 if state!="upgrade" or upgrade_queue.is_empty() or index<0 or index>=offers.size(): return
 heroes[upgrade_queue.pop_front()].apply_upgrade(offers[index])
 _show_next_upgrade()

func _beam(a: Vector3,b: Vector3,color: Color,radius: float,duration: float,carrier: Node3D=null) -> void:
 var v:=b-a
 if v.length()<.01: return
 var line:=MeshInstance3D.new(); var cyl:=CylinderMesh.new(); cyl.top_radius=radius; cyl.bottom_radius=radius; cyl.height=v.length(); cyl.radial_segments=6; cyl.rings=1; line.mesh=cyl
 var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.albedo_color=Color(color.r*2.6,color.g*2.6,color.b*2.6,.95); line.material_override=mat; line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 line.position=(a+b)*.5; line.quaternion=Quaternion(Vector3.UP,v.normalized())
 if is_instance_valid(carrier):
  # parent to the shooter so the tracer stays attached to the moving gun for its short life
  carrier.add_child(line); line.global_position=(a+b)*.5; line.global_basis=Basis(Quaternion(Vector3.UP,v.normalized()))
 else: add_child(line)
 line.add_to_group("transient")
 var tw:=line.create_tween(); tw.tween_property(mat,"albedo_color:a",0.0,duration); tw.tween_callback(line.queue_free)

func flash(pos: Vector3,color: Color,duration: float) -> void:
 if randf()>settings.effects: return
 var mesh:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.20; sphere.height=.40; mesh.mesh=sphere
 var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.emission_enabled=true; mat.emission=color; mat.emission_energy_multiplier=2; mesh.material_override=mat
 mesh.position=pos; add_child(mesh); mesh.add_to_group("transient")
 get_tree().create_timer(duration).timeout.connect(mesh.queue_free)

func telegraph(source: SectorActor, duration: float) -> void:
 flash(source.global_position+Vector3.UP*1.4,Color("ff3434"),duration)
 if randf()<.22 or source.boss: play_sfx("windup")

func shot_fx(source: SectorActor, w: Dictionary) -> void:
 if w.kind=="melee":
  shake_amount=maxf(shake_amount,w.shake); play_sfx(w.sfx); return
 var tip:=source.muzzle_position()
 fx.muzzle(tip,source.aim,w.color,2.0 if w.kind in ["rail","rocket"] or w.id=="shotgun" else 1.0)
 if w.get("shells",false): fx.shell(tip-source.aim*.5,source.aim)
 shake_amount=maxf(shake_amount,w.shake)
 # camera recoil: a short push back along the shot, scaled by the weapon's punch
 if cinematic and w.shake>=.15: camera_kick-=source.aim*w.shake*.6*settings.shake/.35  # only heavy weapons, opening of a wave
 if w.get("bolt",false): fx.trail(tip,Color(.85,.86,.9,.6),1.2); fx.trail(tip+source.aim*.2,Color(.85,.86,.9,.5),1.0)
 play_sfx(w.sfx)

func _load_projectile_meshes() -> void:
 if not ResourceLoader.exists("res://assets/models/weapons.glb"): return
 var kit: Node=load("res://assets/models/weapons.glb").instantiate()
 for id in ["rocket","grenade"]:
  var node:=kit.find_child("P_"+id,true,false) as MeshInstance3D
  if node: projectile_meshes[id]=node.mesh
 kit.free()

func _spread(dir: Vector3, amount: float) -> Vector3:
 return dir.rotated(Vector3.UP,randf_range(-amount,amount)*.5).normalized()

# Shot line test used by every hitscan weapon: stops at walls, then hits targets whose body width
# overlaps the line (so a tracer that visibly crosses a robot always connects). Returns [hits, end].
func trace_shot(source: SectorActor, start: Vector3, d: Vector3, length: float, max_hits: int, width := 0.0) -> Array:
 var end: Vector3=start+d*length
 var q:=PhysicsRayQueryParameters3D.create(start,end,1); q.exclude=[source.get_rid()]
 var wall:=get_world_3d().direct_space_state.intersect_ray(q)
 if not wall.is_empty(): end=wall.position
 var reach: float=start.distance_to(end)
 var found: Array=[]
 for t in (enemies if source.team==0 else heroes):
  if not is_instance_valid(t) or t.dead or t.downed: continue
  var c: Vector3=t.global_position; c.y=start.y
  var along: float=(c-start).dot(d)
  if along<-.3 or along>reach: continue
  var r: float=width+t.hit_radius
  if c.distance_to(start+d*maxf(along,0.0))<r: found.append([along,t])
 found.sort_custom(func(x,y): return x[0]<y[0])
 var hits: Array=[]
 for f in found.slice(0,max_hits): hits.append([f[1],start+d*maxf(f[0],0.0)])
 if found.size()>=max_hits and max_hits>0 and hits.size()>0: end=hits[-1][1]
 return [hits,end,not wall.is_empty() and hits.size()<max_hits]

# Hitscan guns (rifle, SMG, shotgun): fired from the body along the aim, tracers drawn from the muzzle.
func fire_hitscan(source: SectorActor, dir: Vector3, w: Dictionary, amount: float, extra_pierce: int) -> void:
 var muzzle:=source.muzzle_position()
 var base_dir:=shot_dir(source,dir)
 for i in range(w.pellets):
  var d:=_spread(base_dir,w.spread)
  var start:=shot_origin(source)
  var result: Array=trace_shot(source,start,d,w.range,1+w.pierce+extra_pierce)
  var end: Vector3=result[1]
  for h in result[0]:
   hurt(h[0],amount,source,h[1]-d,"kinetic",w.knock)
   fx.sparks(h[1],Color("ffcf7a"),4,3.5)
  if result[2]: fx.sparks(end-d*.05,w.color,4,3.0)
  end.y=lerpf(muzzle.y,end.y,.5) if result[0].is_empty() else end.y
  _beam(muzzle,end,w.color,w.tracer,.05 if w.id=="smg" else .07,source)

func fire_rail(source: SectorActor, dir: Vector3, w: Dictionary, amount: float) -> void:
 dir=shot_dir(source,dir)
 var start:=shot_origin(source)
 var result: Array=trace_shot(source,start,dir,w.range,999,.25)
 var end: Vector3=start+dir*w.range
 var q:=PhysicsRayQueryParameters3D.create(start,end,1); q.exclude=[source.get_rid()]
 var wall:=get_world_3d().direct_space_state.intersect_ray(q)
 if not wall.is_empty(): end=wall.position
 for h in result[0]: hurt(h[0],amount,source,h[1]-dir,"energy",w.knock)
 var muzzle:=source.muzzle_position()
 end.y=muzzle.y
 fx.rail_beam(muzzle,end,w.color,source)
 fx.sparks(end,w.color,10,5.0)

# Energy blade: a wide arc in front of the fighter, with a glowing slash trail.
func fire_melee(source: SectorActor, dir: Vector3, w: Dictionary, amount: float) -> void:
 var hits:=melee_targets(source,dir,w)
 for target in hits:
  hurt(target,amount,source,source.global_position,"energy",w.knock)
  fx.sparks(target.global_position+Vector3.UP*.8,w.color,8,4.5)
 if not hits.is_empty():
  play_sfx("blade_hit"); shake_amount=maxf(shake_amount,.18)

# Robots inside a blade arc, in the order the cut hits them (the kill cam uses this to predict a kill).
func melee_targets(source: SectorActor, dir: Vector3, w: Dictionary) -> Array[SectorActor]:
 var hits: Array[SectorActor]=[]
 for target in enemies.duplicate():
  if not is_instance_valid(target) or target.dead: continue
  var v: Vector3=target.global_position-source.global_position; v.y=0
  var reach: float=w.radius+maxf(0.0,(target.hit_radius-.46)*1.4)
  if v.length()<=reach and (v.length()<.6 or dir.dot(v.normalized())>cos(w.arc)): hits.append(target)
 return hits

func fire_projectile(source: SectorActor, dir: Vector3, w: Dictionary, amount: float) -> void:
 var p: SectorProjectile=Projectile.new()
 if w.kind!="grenade": dir=shot_dir(source,dir)
 if w.kind=="rocket":
  # shoulder-fired: dive from the launcher onto the aim point (body height there), then fly level
  var tip:=source.muzzle_position(); var to:Vector3=source.aim_point-tip; to.y=0
  var reach:=maxf(to.length(),3.0) if source.aim_point!=Vector3.ZERO else 8.0
  dir=(dir*reach+Vector3.UP*(.85-tip.y)).normalized()
 p.setup(self,source,dir,amount,w.color,w.get("speed",14.0))
 p.kind=w.kind; p.radius_damage=w.get("radius",0.0); p.knock=w.knock
 if w.kind=="grenade":
  var goal: Vector3=source.global_position+dir*w.range
  if source.input_id==0: goal=mouse_floor()
  elif is_instance_valid(source.target): goal=source.target.global_position
  var flat: Vector3=goal-source.global_position; flat.y=0
  if flat.length()>w.range: flat=flat.normalized()*w.range
  p.lob(source.muzzle_position(),source.global_position+flat)
 p.mesh_override=projectile_meshes.get(w.kind)
 p.position=source.muzzle_position()
 if w.kind!="grenade": p.cruise_y=.85
 add_child(p); p.add_to_group("transient")

# Area damage for rockets and grenades; enemies caught in it are blown apart.
func explode(pos: Vector3, radius: float, amount: float, source: SectorActor, c: Color, knock: float) -> void:
 fx.explosion(pos,radius,c)
 play_sfx("explosion")
 shake_amount=maxf(shake_amount,.3)
 for e in enemies.duplicate():
  if not is_instance_valid(e) or e.dead: continue
  var dist: float=e.global_position.distance_to(Vector3(pos.x,e.global_position.y,pos.z))
  if dist<radius: hurt(e,amount*lerpf(1.0,.45,dist/radius),source,pos,"explosive",knock)

var _last_destroyed := 0
func play_sfx(kind: String) -> void:
 if kind=="destroyed":
  # random variant, rate-limited so mass kills do not stack into noise
  var now:=Time.get_ticks_msec()
  if now-_last_destroyed<45: return
  _last_destroyed=now; kind="destroyed_%d" % rng.randi_range(1,3)
 if not tones.has(kind) or settings.master*settings.sfx<=0: return
 for channel in sfx_pool:
  if channel.playing: continue
  channel.stream=tones[kind]
  channel.volume_db=linear_to_db(maxf(.001,settings.master*settings.sfx*.55*SFX_GAIN.get(kind,1.0)))
  channel.pitch_scale=randf_range(.95,1.05)
  channel.play()
  return

func _tone(freq: float, duration: float, noise := false) -> AudioStreamWAV:
 var wav:=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=22050; wav.stereo=false
 var bytes:=PackedByteArray()
 for i in range(int(22050*duration)):
  var t:=float(i)/22050.0
  var amp:=(randf_range(-1,1)*.5 if noise else sin(t*TAU*(freq+freq*t*.35)))*exp(-t*(5.0/duration))*.28
  var sample:=int(clampf(amp,-1,1)*32767)
  bytes.append(sample&255); bytes.append((sample>>8)&255)
 wav.data=bytes
 return wav

func _music() -> AudioStreamWAV:
 var wav:=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=22050; wav.stereo=false; wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
 var bytes:=PackedByteArray(); var hz:=[55.0,65.4,73.4,49.0]
 for i in range(22050*4):
  var t:=float(i)/22050.0
  var beat:=int(t*2.0)%4
  var pulse:=exp(-fmod(t,0.5)*12.0)
  var v:=(sin(t*TAU*hz[beat])+sin(t*TAU*hz[beat]*2)*.28)*.09*pulse
  var sample:=int(clampf(v,-1,1)*32767)
  bytes.append(sample&255); bytes.append((sample>>8)&255)
 wav.data=bytes; wav.loop_end=22050*4
 return wav
