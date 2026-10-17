extends SceneTree

# warp_mouse takes window pixels; unproject_position returns viewport pixels (they differ on HiDPI displays)
func warp(game, world: Vector3) -> void:
 Input.warp_mouse(game.camera.unproject_position(world)*Vector2(DisplayServer.window_get_size())/game.get_viewport().get_visible_rect().size)
# Sniper pointer on the cursor and on a robot (lock), then a rocket fired while strafing: evidence/pointer_and_strafe.png
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[5,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999
 game._spawn_enemy(0); var e=game.enemies[-1]; e.global_position=Vector3(-5,0,-1); e.speed=0; e.attack_timer=99
 h.global_position=Vector3(0,0,3)
 await create_timer(1.5).timeout
 var shots: Array[Image]=[]
 for target in [Vector3(3,0,-3),Vector3(-5,0,-1)]:
  for f in range(20):
   warp(game,target); await physics_frame
  var img: Image=root.get_viewport().get_texture().get_image()
  var sc: float=float(img.get_width())/root.get_visible_rect().size.x
  var c: Vector2=game.camera.unproject_position(Vector3(-1,0,0))*sc
  shots.append(img.get_region(Rect2i(int(c.x)-420,int(c.y)-300,840,560)))
 # rocket while strafing
 h.set_weapon(5); await create_timer(.5).timeout
 h.global_position=Vector3(6,0,3)
 Input.action_press("move_left")
 for f in range(30):
  warp(game,h.global_position+Vector3(0,0,-8))
  if f==8: h.attack_timer=0; h._primary(.016)
  await physics_frame
 Input.action_release("move_left")
 var img2: Image=root.get_viewport().get_texture().get_image()
 var sc2: float=float(img2.get_width())/root.get_visible_rect().size.x
 var c2: Vector2=game.camera.unproject_position(h.global_position)*sc2
 shots.append(img2.get_region(Rect2i(int(c2.x)-420,int(c2.y)-500,840,560)))
 var sheet:=Image.create(840,560*3,false,shots[0].get_format())
 for k in range(3): sheet.blit_rect(shots[k],Rect2i(0,0,840,560),Vector2i(0,560*k))
 sheet.save_png("res://evidence/pointer_and_strafe.png"); print("PTR")
 quit()
