extends SceneTree
# Every operative holding their signature weapon, aimed in four directions, from the gameplay camera:
# evidence/poses_sheet.png (rows: heroes, columns: aim directions)

# [aim, move]: three standing holds, then running sideways and running toward the aim
const DIRS := [[Vector3(1,0,.6),Vector3.ZERO],[Vector3(-1,0,-.3),Vector3.ZERO],[Vector3(0,0,1),Vector3.ZERO],[Vector3(-1,0,.5),Vector3(0,0,-1)],[Vector3(1,0,0),Vector3(1,0,0)]]

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 var frames: Array[Image]=[]
 for i in range(6):
  game.selected=[i,(i+1)%6]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
  for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
  var h=game.heroes[0]; h.invulnerable=999; h.input_id=-1
  for o in game.heroes.slice(1): o.global_position=Vector3(30,0,30)
  h.global_position=Vector3(0,0,3); game.camera_center=Vector3(0,0,3); 
  for d in DIRS:
   h.global_position=Vector3(0,0,3)
   for f in range(40):
    h.aim=d[0].normalized(); h.target=null; h.last_move=d[1]; game.camera_center=h.global_position
    await physics_frame
   var cam:=Camera3D.new(); cam.fov=game.camera.fov; root.add_child(cam)
   cam.global_position=h.global_position+Vector3.UP+game.CAM_OFFSET*.22; cam.look_at(h.global_position+Vector3.UP,Vector3.UP); cam.current=true
   await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
   var img: Image=root.get_viewport().get_texture().get_image()
   var w: int=img.get_width(); var hh: int=img.get_height()
   var crop:=img.get_region(Rect2i(w/2-hh/2,0,hh,hh)); crop.resize(400,400); frames.append(crop)
   cam.queue_free(); game.camera.current=true
  game._clear_run(); await create_timer(.2).timeout
 var sheet:=Image.create(400*5,400*6,false,frames[0].get_format())
 for k in range(frames.size()): sheet.blit_rect(frames[k],Rect2i(0,0,400,400),Vector2i((k%5)*400,(k/5)*400))
 sheet.save_png("res://evidence/poses_sheet.png"); print("CAPTURE poses")
 game.queue_free(); await create_timer(.1).timeout
 quit()
