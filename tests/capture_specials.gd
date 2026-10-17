extends SceneTree
# Each operative's special move, surrounded by robots, caught mid-move: evidence/special_<n>.png + evidence/specials_sheet.png

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 # [hero, crowd radius, move time to capture at, file name]
 var plan:=[[0,3.2,.9,"hurricane"],[1,5.5,.32,"hundred_cuts"],[1,2.4,.3,"kaiten"],[2,5.0,.45,"dead_eye"],[3,4.0,.42,"halo"],[4,4.0,1.4,"singularity"],[5,2.0,1.05,"orbital"]]
 var shots: Array[Image]=[]
 for step in plan:
  game.selected=[step[0],0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
  for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
  game.cinematic=false
  var h=game.heroes[0]; h.input_id=-1; h.global_position=Vector3(-2,0,2); h.aim=Vector3(0,0,-1); h.aim_point=Vector3(-2,1.4,-4)
  for k in range(8):
   game._spawn_enemy(k%3); var e=game.enemies[-1]
   var r: float=step[1]*(1.0 if k%2==0 else 1.25)
   e.global_position=h.global_position+Vector3(cos(k*TAU/8+.3),0,sin(k*TAU/8+.3))*r
   e.speed=0; e.attack_timer=99; e.max_hp=400; e.hp=400
  h.special_timer=99  # keep the AI from firing it on its own while the crowd settles
  await create_timer(.5).timeout
  h.special_timer=0; h._special()
  while h.move_t>=0 and h.move_t<step[2]: await physics_frame
  await process_frame
  var img: Image=root.get_viewport().get_texture().get_image()
  img.save_png("res://evidence/special_%s.png" % step[3]); shots.append(img)
  print("CAPTURE special ",step[3])
  while h.move_t>=0: await physics_frame
  game._clear_run(); await create_timer(.2).timeout
 # contact sheet: 4 x 2 at half size
 var w: int=shots[0].get_width()/2; var hh: int=shots[0].get_height()/2
 var sheet:=Image.create(w*4,hh*2,false,shots[0].get_format())
 for i in range(shots.size()):
  var s: Image=shots[i].duplicate(); s.resize(w,hh)
  sheet.blit_rect(s,Rect2i(0,0,w,hh),Vector2i((i%4)*w,(i/4)*hh))
 sheet.save_png("res://evidence/specials_sheet.png")
 game.queue_free(); await create_timer(.1).timeout
 quit()
