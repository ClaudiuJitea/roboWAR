extends SceneTree
# One operative cycling through every weapon in the loadout, low side-view camera:
# evidence/loadout_<hero>.png (one tile per weapon). HERO env picks the operative index (default 0).

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 var idx:=int(OS.get_environment("HERO")) if OS.get_environment("HERO")!="" else 0
 game.selected=[idx,(idx+1)%6]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999; h.input_id=-1
 for o in game.heroes.slice(1): o.global_position=Vector3(30,0,30)
 h.global_position=Vector3(0,0,3)
 var frames: Array[Image]=[]
 for w in range(h.loadout.size()):
  h.set_weapon(w)
  for f in range(45):
   h.aim=Vector3(1,0,0); h.target=null; h.last_move=Vector3.ZERO
   await physics_frame
  var cam:=Camera3D.new(); cam.fov=40.0; root.add_child(cam)
  # low side view: the hold reads in profile
  cam.global_position=h.global_position+Vector3(0,1.6,5.5); cam.look_at(h.global_position+Vector3.UP,Vector3.UP); cam.current=true
  await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
  var img: Image=root.get_viewport().get_texture().get_image()
  var hh: int=img.get_height(); var crop:=img.get_region(Rect2i(img.get_width()/2-hh/2,0,hh,hh)); crop.resize(400,400); frames.append(crop)
  print("CAPTURE weapon ",h.loadout[w].id," stance=",h.stance)
  game.camera.current=true; cam.queue_free(); await process_frame
 var sheet:=Image.create(400*4,400*2,false,frames[0].get_format())
 for k in range(frames.size()): sheet.blit_rect(frames[k],Rect2i(0,0,400,400),Vector2i((k%4)*400,(k/4)*400))
 sheet.save_png("res://evidence/loadout_%d.png" % idx)
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
