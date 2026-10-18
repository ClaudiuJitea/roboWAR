extends SceneTree
# Temporal regression checks without rendering: setup must finish before any flight, cut or destruction;
# a final kill must finish its cinematic before an upgrade screen or campaign debrief can interrupt it.

var game

func _initialize() -> void:
 call_deferred("run")

func setup(hero: int, weapon := 0) -> void:
 game._clear_run()
 await process_frame
 game.selected=[hero,(hero+1)%6]; game.mode=0; game.campaign=false; game.start_run()
 game.settings.killcam=1.0; game.settings.autoaim=0.0; game.cinematic=false
 game.spawn_left=0; game.wave_wait=9999; game.kills=8
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]
 h.input_id=0; h.invulnerable=999; h.global_position=Vector3(0,0,4); h.set_weapon(weapon)
 h.set_physics_process(false); h.set_process(false)
 for o in game.heroes.slice(1): o.set_physics_process(false)
 game.killcam.set_process(false)  # advance the real-time camera clock deterministically below
 await physics_frame
 await create_timer(.35).timeout  # let the AnimationTree settle into the selected weapon stance

func enemy(index := 0):
 game._spawn_enemy(index)
 var e=game.enemies[-1]
 e.global_position=Vector3(0,0,2); e.speed=0; e.attack_timer=999; e.hp=1
 return e

func advance(until: float) -> void:
 while game.killcam.active and game.killcam.t<until:
  game.killcam._last_us=Time.get_ticks_usec()-100000
  game.killcam._process(0.0)

func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 for style in ["bullet","zoom","crane","orbit"]:
  await setup(1 if style=="orbit" else 2,5 if style=="crane" else 0)
  game.killcam._gun_alt=1 if style=="zoom" else 0
  var h=game.heroes[0]; var e=enemy()
  if style=="orbit": h.swing_time=.4; h.swing_impact=.2  # a cut that prediction missed
  game.hurt(e,9999.0,h,h.global_position,"explosive" if style=="crane" else "kinetic")
  var kc=game.killcam
  assert(kc.active and kc.style==style,"expected %s cinematic" % style)
  assert(Engine.time_scale<=kc.SETUP_SCALE,"action is held in the triggering frame")
  advance(kc.EASE_IN-.15)
  assert(kc.shot_time==0 and not kc._impacted,"no action during camera setup")
  assert(is_instance_valid(e) and not e.is_queued_for_deletion(),"victim survives camera setup")
  if style in ["bullet","zoom"]: assert(kc.slug.global_position.is_equal_approx(kc.muzzle),"round waits at muzzle")
  if style=="orbit": assert(not kc.has_meta("replayed"),"cut replay waits for camera setup")
  advance(kc.EASE_IN+.8)
  if style=="bullet":
   assert(kc.slug.global_position.distance_to(kc.muzzle)>.1,"flight plays after setup")
   assert(not kc._impacted and not e.is_queued_for_deletion(),"victim remains intact during flight")
  elif style=="zoom":
   assert(kc.slug.global_position.distance_to(kc.muzzle)>.1,"impact zoom also shows the round in flight")
   assert(not kc._impacted,"impact waits for the full push-in")
  elif style=="crane": assert(kc._impacted and e.is_queued_for_deletion(),"blast lands once camera is ready")
  else:
   assert(kc.has_meta("replayed") and h.swing_impact>0,"whole blade swing replays after setup")
   kc.blade_connects(h)
   assert(kc.cut_at<0 and kc.halves.is_empty(),"a timer alone cannot invent a blade plane without visible contact")
  # Wave two normally opens upgrades immediately when the final enemy is removed.
  game.wave=2; game.wave_wait=0
  game._process(.016)
  assert(game.state=="playing" and kc.active,"final kill must finish before upgrades")
  advance(kc.EASE_IN+kc.DURATION[style]-.1)
  assert(Engine.time_scale>.85,"time recovers before returning to gameplay")
  advance(kc.EASE_IN+kc.DURATION[style]+.2)
  assert(not kc.active and game.camera.current and is_equal_approx(Engine.time_scale,1.0),"clean handoff")
  assert(e.is_queued_for_deletion(),"destruction always completes")
  game._process(.016)
  assert(game.state=="upgrade","upgrades proceed after the complete cinematic")
  print("KILLCAM TIMING ",style," PASS")
 # A live cut must retain its wind-up until the camera has arrived, with every combo's actual strike timer.
 for combo in range(3):
  await setup(1)
  var h=game.heroes[0]; var v=enemy()
  v.global_position=h.global_position+Vector3.FORWARD*1.6
  h.aim=Vector3.FORWARD; h.attack_timer=0; h.combo=(combo+2)%3; h.last_swing=Time.get_ticks_msec()/1000.0
  h._primary(.016)
  var kc=game.killcam
  assert(kc.active and kc.live and game.kills==8,"live cut begins before lethal damage")
  h.set_physics_process(true)
  advance(kc.EASE_IN-.15)
  for i in range(4): await physics_frame
  assert(game.kills==8 and kc.cut_at<0 and h.swing_impact>.15,"wind-up survives camera setup")
  advance(kc.EASE_IN+.6)  # establish the filmed footwork before advancing the real animation below
  var deadline:=Time.get_ticks_msec()+4000
  while (game.kills==8 or kc.halves.is_empty()) and Time.get_ticks_msec()<deadline:
   await process_frame
   kc._sample_blade()
  assert(game.kills==9 and kc.halves.size()==2,"real combo strike kills and slices inside the shot")
  assert(kc._boom.is_valid(),"destruction waits while the sliced halves are shown")
  kc.stop()
  assert(not h.cutscene and is_equal_approx(Engine.time_scale,1.0),"stop restores live fighter control")
  print("KILLCAM LIVE COMBO ",combo," PASS")
 # A filmed bomber's chain explosion belongs to the impact, and must run only once even if stopped early.
 await setup(2)
 var bomber=enemy(6); var nearby=enemy()
 nearby.global_position=bomber.global_position+Vector3(.6,0,0)
 game.hurt(bomber,9999.0,game.heroes[0],Vector3.ZERO)
 assert(game.kills==9 and not nearby.dead,"chain explosion waits for the filmed impact")
 advance(game.killcam.EASE_IN-.15)
 assert(not nearby.dead,"camera setup cannot trigger chain destruction")
 game.killcam.stop(); game.killcam.stop()
 assert(game.kills==10 and nearby.dead,"early stop flushes the pending explosion exactly once")
 assert(is_equal_approx(Engine.time_scale,1.0),"early stop restores time")
 # A campaign boss can die at any kill count; debrief must wait, even after all escorts power down.
 await setup(2)
 var boss=enemy(5); game.kills=2; game.campaign=true; game.wave=4; game.wave_wait=0
 game.hurt(boss,99999.0,game.heroes[0],Vector3.ZERO)
 assert(game.killcam.active,"boss cinematic starts away from the ninth kill")
 await process_frame
 game._process(.016)
 assert(game.state=="playing" and game.killcam.active,"boss cinematic survives the empty arena")
 game.killcam.stop(); game._process(.016)
 assert(game.state=="debrief","campaign debrief follows the complete boss cinematic")
 game._clear_run(); game.queue_free(); await create_timer(.35,true,false,true).timeout
 print("KILLCAM TIMING PASS")
 quit()
