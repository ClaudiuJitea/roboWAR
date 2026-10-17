extends SceneTree
# Albert runs a 3-hit blade combo into a group: frames saved to evidence/blade_combo.png

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[1,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999; h.input_id=-1; h.set_physics_process(true)
 h.global_position=Vector3(0,0,3); game.camera_center=Vector3(0,0,2)
 for k in range(5):
  game._spawn_enemy(k%2); var e=game.enemies[-1]; e.global_position=Vector3(-1.2+k*.6,0,1.2-(k%2)*.5); e.speed=0; e.attack_timer=99
 await create_timer(1.2).timeout
 var frames: Array[Image]=[]
 for f in range(70):
  h.aim=Vector3(0,0,-1); h.target=null; h.last_move=Vector3.ZERO
  if f in [0,24,48]: h.attack_timer=0; h._primary(.016)
  await physics_frame
  if f in [6,9,13,30,33,37,55,59,63]:
   var img: Image=root.get_viewport().get_texture().get_image()
   var sc: float=float(img.get_width())/root.get_visible_rect().size.x
   var c: Vector2=game.camera.unproject_position(h.global_position+Vector3.UP)*sc
   frames.append(img.get_region(Rect2i(int(c.x)-260,int(c.y)-260,520,520)))
 var sheet:=Image.create(520*3,520*3,false,frames[0].get_format())
 for k in range(frames.size()): sheet.blit_rect(frames[k],Rect2i(0,0,520,520),Vector2i((k%3)*520,(k/3)*520))
 sheet.resize(1020,1020)
 sheet.save_png("res://evidence/blade_combo.png"); print("CAPTURE blade enemies_left=",game.enemies.size())
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
