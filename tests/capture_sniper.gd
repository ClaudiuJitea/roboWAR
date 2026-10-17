extends SceneTree
# Nadia aims, fires and cycles the bolt: evidence/sniper_sequence.png

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[5,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999; h.input_id=-1
 h.global_position=Vector3(0,0,3); game.camera_center=Vector3(0,0,2); game.camera.fov=18
 for k in range(3):
  game._spawn_enemy(0); var e=game.enemies[-1]; e.global_position=Vector3(-6+k*.5,0,1.5-k*.4); e.speed=0; e.attack_timer=99
 await create_timer(1.2).timeout
 var frames: Array[Image]=[]
 for f in range(40):
  h.aim=Vector3(-1,0,-.2).normalized(); h.target=null; h.last_move=Vector3.ZERO
  if f==4: h.attack_timer=0; h._primary(.016)
  await physics_frame
  if f in [2,5,8,14,20,30]:
   var img: Image=root.get_viewport().get_texture().get_image()
   var sc: float=float(img.get_width())/root.get_visible_rect().size.x
   var c: Vector2=game.camera.unproject_position(h.global_position+Vector3.UP)*sc
   frames.append(img.get_region(Rect2i(int(c.x)-300,int(c.y)-220,480,400)))
 var sheet:=Image.create(480*3,400*2,false,frames[0].get_format())
 for k in range(frames.size()): sheet.blit_rect(frames[k],Rect2i(0,0,480,400),Vector2i((k%3)*480,(k/3)*400))
 sheet.save_png("res://evidence/sniper_sequence.png"); print("CAPTURE sniper")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
