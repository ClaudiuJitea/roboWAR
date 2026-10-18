extends SceneTree
# Use real AnimationTree poses, curved blade markers and robot geometry for every combo, live and replayed.
# A fixed torso plane, generic diagonal or frame-rate-dependent motion threshold cannot satisfy these checks.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 var frames: Array[Image]=[]
 for scenario in range(3):
  var replay:=scenario==1
  for combo in range(3):
   game._clear_run(); await process_frame
   game.selected=[1,2]; game.mode=0; game.campaign=false; game.start_run()
   game.settings.killcam=1.0; game.cinematic=false; game.spawn_left=0; game.wave_wait=9999; game.kills=8
   var h=game.heroes[0]; h.input_id=-1; h.invulnerable=999; h.set_physics_process(false); h.set_process(false)
   var yaw: float=[0.0,.9,-1.2][scenario]
   h.global_position=Vector3(0,0,4.2).rotated(Vector3.UP,yaw); h.model.rotation.y=yaw
   h.aim=Vector3.FORWARD.rotated(Vector3.UP,yaw)
   game._spawn_enemy(5 if scenario==2 else 0); var v=game.enemies[-1]
   var distance:=2.9 if scenario==2 else 1.6
   v.global_position=h.global_position+h.aim*distance; v.speed=0; v.attack_timer=999; v.hp=1
   await create_timer(.35).timeout
   assert(h.blade_edge_points().size()>3,"blade samples come from the curved model edge")
   if replay:
    h.combo=combo; game.hurt(v,9999.0,h,h.global_position)
   else:
    h.attack_timer=0; h.combo=(combo+2)%3; h.last_swing=Time.get_ticks_msec()/1000.0; h._primary(.016)
   var kc=game.killcam
   assert(kc.active and kc.style=="orbit" and kc.live!=replay,"expected live/replayed blade shot")
   h.set_physics_process(true)
   var deadline:=Time.get_ticks_msec()+6000
   while kc.active and kc.cut_at<0 and Time.get_ticks_msec()<deadline: await process_frame
   assert(kc.halves.size()==2 and not kc._blade_contact.is_empty(),"actual blade contact must split the robot")
   var contact: Dictionary=kc._blade_contact
   var edge: PackedVector3Array=h.blade_edge_points(); var segment: int=contact.segment
   # The displayed cut passes through the contacted blade segment and follows its swept direction.
   assert(absf(kc.cut_n.dot(contact.a-kc.cut_p))<.0001,"slice contains the contacted edge base")
   assert(absf(kc.cut_n.dot(contact.b-kc.cut_p))<.0001,"slice contains the contacted edge tip")
   assert(absf(kc.cut_n.dot(contact.motion))<.0001,"slice follows the actual sweep, without artistic tilt")
   assert(absf(kc.cut_n.dot(edge[segment]-kc.cut_p))<.04,"slice remains aligned with the visible blade base")
   assert(absf(kc.cut_n.dot(edge[segment+1]-kc.cut_p))<.04,"slice remains aligned with the visible blade tip")
   var touched:=false
   for surface in kc._cut_surfaces:
    if surface.mesh.get_aabb().grow(.001).has_point(surface.to_local(kc.cut_p)): touched=true
   assert(touched,"cut is anchored where the blade contacts robot geometry")
   if combo==2: assert(absf(kc.cut_n.y)<.35,"the overhead finisher follows its vertical blade path")
   assert(game.kills==9,"contact applies lethal damage once")
   print("BLADE PATH ","replay" if replay else ("boss" if scenario==2 else "live")," combo=",combo," normal=",kc.cut_n," point=",kc.cut_p," action_time=",kc.cut_at)
   if DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    var img: Image=root.get_viewport().get_texture().get_image(); img.resize(640,360); frames.append(img)
   kc.stop()
 if not frames.is_empty():
  var sheet:=Image.create(1920,360*(frames.size()/3),false,frames[0].get_format())
  for i in range(frames.size()): sheet.blit_rect(frames[i],Rect2i(0,0,640,360),Vector2i((i%3)*640,(i/3)*360))
  sheet.save_png("res://evidence/killcam_blade_path.png")
 game._clear_run(); game.queue_free(); await create_timer(.35,true,false,true).timeout
 print("BLADE PATH PASS")
 quit()
