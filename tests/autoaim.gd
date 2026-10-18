extends SceneTree
# Auto aim: off -> the shot follows the cursor; on -> it locks onto a visible robot near the aim direction,
# ignores robots far outside the aim cone, and stays off when the setting is off again.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[2,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999  # Marshal: pistol, range 20
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999; h.input_id=0
 for o in game.heroes.slice(1): o.global_position=Vector3(30,0,30)
 h.global_position=Vector3(0,0,4); game.camera_center=h.global_position
 game._spawn_enemy(0); var near=game.enemies[-1]; near.global_position=Vector3(2.6,0,-2.5); near.speed=0; near.attack_timer=99
 game._spawn_enemy(0); var behind=game.enemies[-1]; behind.global_position=Vector3(0,0,9); behind.speed=0; behind.attack_timer=99
 await create_timer(.5).timeout
 var ahead:=Vector3(0,1.4,-6)
 var result:={}
 for mode in [0.0,1.0,0.0]:
  game.settings.autoaim=mode
  for f in range(20):
   game.cursor_override=game.camera.unproject_position(ahead)
   await physics_frame
  var to_near: Vector3=(near.global_position-h.global_position); to_near.y=0
  var locked: bool=h.aim.angle_to(to_near.normalized())<.12
  var straight: bool=h.aim.angle_to(Vector3(0,0,-1))<.15
  print("AUTOAIM mode=",mode," aim=",h.aim," locked=",locked," straight=",straight," target=",h.auto_target)
  result[mode]=[locked,straight]
  assert(locked if mode>.5 else straight,"auto aim %s: wrong aim %s" % ["on" if mode>.5 else "off",h.aim])
  if mode>.5: assert(h.auto_target==near,"locked onto the robot near the aim, never the one behind")
  else: assert(h.auto_target==null,"no lock while auto aim is off")
 print("AUTOAIM PASS")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
