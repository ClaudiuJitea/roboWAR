extends SceneTree
# Ghostline acquisition / rifle salvo and the shared gunship pass, rendered as two four-frame strips.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 for kind in ["ghostline","air_support"]:
  game.selected=[5,0]; game.mode=0; game.campaign=false; game.survival_arena="white"; game.start_run()
  game.spawn_left=0; game.wave_wait=9999; game.cinematic=false; game.settings.killcam=0.0
  var h=game.heroes[0]; h.global_position=Vector3(0,0,6); h.invulnerable=999; h.attack_timer=999; h.special_timer=999
  h.aim=Vector3.FORWARD; h.set_process(false); h.set_physics_process(false)
  for i in range(8):
   game._spawn_enemy(i%3); var e=game.enemies[-1]
   e.global_position=Vector3(-2.4+(i%3)*2.4,0,-1.0-(i/3)*2.5); e.hp=900; e.max_hp=900; e.speed=0; e.attack_timer=999
  await create_timer(.6).timeout
  game.ui.announce("",0)
  h.set_physics_process(true); h.special_timer=0 if kind=="ghostline" else 999
  game.cursor_override=game.camera.unproject_position(Vector3(0,0,-3))
  if kind=="ghostline": h._special()
  else: h.call_air_support()
  var marks: Array=[.45,.74,1.14,1.56] if kind=="ghostline" else [.3,1.05,1.45,1.75]
  var start: float=game.elapsed
  var frames: Array[Image]=[]
  for mark in marks:
   while game.elapsed-start<mark: await process_frame
   await RenderingServer.frame_post_draw
   var img: Image=root.get_viewport().get_texture().get_image(); img.resize(640,360); frames.append(img)
  var sheet:=Image.create(1280,720,false,frames[0].get_format())
  for i in range(4): sheet.blit_rect(frames[i],Rect2i(0,0,640,360),Vector2i((i%2)*640,(i/2)*360))
  sheet.save_png("res://evidence/%s.png" % kind)
  print("CAPTURE ",kind," PASS")
  game._clear_run(); await create_timer(.1,true,false,true).timeout
 game.queue_free(); await create_timer(.1,true,false,true).timeout; quit()
