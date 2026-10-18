extends SceneTree
# Blade kill cam, predicted: Ronin kills 8 robots, then starts a cut that will finish the 9th. The kill cam must
# start on the swing while the robot is still alive, the real blade must connect (and kill) inside the slowed shot,
# and the robot is sliced. Saves evidence/killcam_blade_cut.png (12 frames).

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.settings.killcam=1.0
 game.selected=[1,2]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 game.cinematic=false
 var h=game.heroes[0]; h.invulnerable=999; h.input_id=-1; h.global_position=Vector3(0,0,4)
 for o in game.heroes.slice(1): o.global_position=Vector3(30,0,30)
 h.set_weapon(0)
 for k in range(8):
  game._spawn_enemy(0); var e=game.enemies[-1]; e.global_position=Vector3(-6+k,0,-6); e.speed=0; e.attack_timer=99
  await physics_frame
  game.hurt(e,9999.0,h,h.global_position,"energy"); await physics_frame
 assert(game.kills==8)
 game._spawn_enemy(0); var v=game.enemies[-1]; v.global_position=Vector3(0,0,2.6); v.speed=0; v.attack_timer=99; v.hp=12.0
 h.attack_timer=99; await create_timer(1.0).timeout
 h.global_position=Vector3(0,0,4.2); h.velocity=Vector3.ZERO; h.aim=Vector3(0,0,-1); h.attack_timer=0; h.last_swing=-10.0
 h._primary(.016)
 assert(game.killcam.active and game.killcam.live,"kill cam starts on the swing, before the blade connects")
 assert(game.kills==8,"robot still alive when the shot starts")
 var frames: Array[Image]=[]
 var start:=Time.get_ticks_msec()
 for m in [.1,.3,.5,.7,.9,1.1,1.3,1.5,1.8,2.2,2.8,3.6]:
  while (Time.get_ticks_msec()-start)/1000.0<m: await process_frame
  await RenderingServer.frame_post_draw
  var img: Image=root.get_viewport().get_texture().get_image(); img.resize(640,360); frames.append(img)
  print("t=",m," ts=%.2f" % Engine.time_scale," cut_at=",game.killcam.cut_at," halves=",game.killcam.halves.size()," kills=",game.kills)
 assert(game.kills==9 and game.killcam.cut_at>0,"the blade connected inside the shot and killed the 9th")
 var sheet:=Image.create(640*3,360*4,false,frames[0].get_format())
 for i in range(12): sheet.blit_rect(frames[i],Rect2i(0,0,640,360),Vector2i((i%3)*640,(i/3)*360))
 sheet.save_png("res://evidence/killcam_blade_cut.png")
 while game.killcam.active: await process_frame
 assert(is_equal_approx(Engine.time_scale,1.0) and not h.cutscene)
 print("LIVE CUT PASS")
 quit()
