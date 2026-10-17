extends SceneTree
# Drives a fighter (strafe / backpedal / run) while firing and saves frame strips to evidence/motion_<move>.png.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[5,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999; h.set_weapon(1)
 await create_timer(1.0).timeout
 for move in [["strafe","move_left"],["backpedal","move_down"],["run","move_up"]]:
  h.global_position=Vector3(2,0,4) if move[0]!="run" else Vector3(2,0,8)
  var frames: Array[Image]=[]
  Input.action_press(move[1])
  for f in range(48):
   Input.warp_mouse(game.camera.unproject_position(h.global_position+Vector3(0,0,-6)))
   if f%2==0: h.attack_timer=0; h._primary(.05); h.ammo[h.weapon]=40
   await physics_frame
   if f>=24 and f%4==0:
    var img: Image=root.get_viewport().get_texture().get_image()
    var c: Vector2=game.camera.unproject_position(h.global_position+Vector3.UP)
    frames.append(img.get_region(Rect2i(int(c.x)-110,int(c.y)-130,220,230)))
  Input.action_release(move[1])
  var strip:=Image.create(220*frames.size(),230,false,frames[0].get_format())
  for i in range(frames.size()): strip.blit_rect(frames[i],Rect2i(0,0,220,230),Vector2i(220*i,0))
  strip.save_png("res://evidence/motion_%s.png" % move[0])
  print("CAPTURE ",move[0]," blend=",h.loco_blend)
  await create_timer(.4).timeout
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
