extends SceneTree
# Kill cam: every 9th kill runs a cinematic picked by how the robot died (bullet cam / impact zoom for guns,
# blast crane for explosives, blade orbit for the katana), then hands back to the gameplay camera at full speed.
# Saves evidence/killcam_<style>.png (five frames across each shot). Also checks the shot eases: time slows
# gradually at the start and is back near full speed just before the end (no hard cuts).

func _initialize() -> void:
 call_deferred("run")

func shoot_nine(game, h, w: int, dmg_type: String) -> void:
 h.set_weapon(w)
 for k in range(9):
  game._spawn_enemy(0); var e=game.enemies[-1]
  e.global_position=h.global_position+Vector3(-3.0+k*.2,0,-6.0); e.speed=0; e.attack_timer=99
  await physics_frame
  game.hurt(e,9999.0,h,h.global_position,dmg_type)
  await physics_frame

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.settings.killcam=1.0
 var plan:=[[2,0,"kinetic","bullet"],[2,0,"kinetic","zoom"],[0,5,"explosive","crane"],[1,0,"energy","orbit"]]  # [hero, weapon slot, damage, expected]
 var sheet_rows: Array=[]
 for step in plan:
  game._clear_run(); await create_timer(.1).timeout
  game.selected=[step[0],(step[0]+1)%6]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
  for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
  game.cinematic=false
  var h=game.heroes[0]; h.invulnerable=999; h.input_id=-1; h.global_position=Vector3(0,0,4)
  for o in game.heroes.slice(1): o.global_position=Vector3(30,0,30)
  if step[3]=="zoom": game.killcam._gun_alt=1
  await shoot_nine(game,h,step[1],step[2])
  assert(game.killcam.active,"kill cam must start on the 9th kill")
  assert(game.killcam.style==step[3],"style %s expected, got %s" % [step[3],game.killcam.style])
  assert(not game.camera.current,"kill cam camera takes over")
  var frames: Array[Image]=[]
  var total: float=game.killcam.DURATION[step[3]]
  var marks:=[.35,total*.3,total*.5,total*.7,total-.45]  # easing in, the shot, easing out
  var start:=Time.get_ticks_msec()
  await process_frame
  assert(Engine.time_scale>.6,"time slows gradually at the start, not with a cut (%.2f)" % Engine.time_scale)
  var vp_cam: Camera3D=root.get_viewport().get_camera_3d()
  var prev: Vector3=vp_cam.global_position if vp_cam else Vector3.ZERO
  var max_step:=0.0; var steps:=0.0; var n:=0
  for m in marks:
   while (Time.get_ticks_msec()-start)/1000.0<m:
    await process_frame
    var c: Camera3D=root.get_viewport().get_camera_3d()
    if c:
     var d: float=c.global_position.distance_to(prev); prev=c.global_position
     max_step=maxf(max_step,d); steps+=d; n+=1
   await RenderingServer.frame_post_draw
   var img: Image=root.get_viewport().get_texture().get_image(); img.resize(384,216); frames.append(img)
  while game.killcam.active and (Time.get_ticks_msec()-start)/1000.0<total-.12: await process_frame
  assert(not game.killcam.active or Engine.time_scale>.85,"time is nearly back to full speed before the end (%.2f)" % Engine.time_scale)
  while game.killcam.active and (Time.get_ticks_msec()-start)/1000.0<total+1.0: await process_frame
  await process_frame
  assert(not game.killcam.active,"kill cam must end")
  assert(is_equal_approx(Engine.time_scale,1.0),"time back to normal")
  assert(game.camera.current,"gameplay camera restored")
  var row:=Image.create(384*5,216,false,frames[0].get_format())
  for i in range(5): row.blit_rect(frames[i],Rect2i(0,0,384,216),Vector2i(i*384,0))
  row.save_png("res://evidence/killcam_%s.png" % step[3])
  print("KILLCAM ",step[3]," camera: largest per-frame move %.2f m, average %.3f m over %d frames" % [max_step,steps/maxf(n,1),n])
  assert(max_step<1.5,"no camera jump cuts")
  print("KILLCAM ",step[3]," ok, kills=",game.kills)
 # off switch
 game._clear_run(); await create_timer(.1).timeout
 game.settings.killcam=0.0
 game.selected=[2,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h2=game.heroes[0]; h2.invulnerable=999; h2.input_id=-1
 await shoot_nine(game,h2,0,"kinetic")
 assert(not game.killcam.active,"setting off: no kill cam")
 game.settings.killcam=1.0
 print("KILLCAM PASS")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
