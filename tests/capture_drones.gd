extends SceneTree
# Actual production meshes, ray effects and terminal dives; no replacement showcase assets.
var game
var frames: Array[Image]=[]

func _initialize() -> void:
 call_deferred("run")

func frame() -> void:
 game.ui.update_hud()
 await RenderingServer.frame_post_draw
 var img: Image=root.get_viewport().get_texture().get_image(); img.resize(640,360); frames.append(img)

func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[0,0]; game.mode=0; game.campaign=false; game.survival_arena="white"; game.start_run()
 game.spawn_left=0; game.wave_wait=9999; game.cinematic=false; game.settings.killcam=0.0
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 for body in game.arena.find_children("*","StaticBody3D",true,false): body.collision_layer=0
 var h=game.heroes[0]; h.global_position=Vector3(0,0,5); h.invulnerable=999; h.aim=Vector3.FORWARD
 h.set_process(false); h.set_physics_process(false)
 await create_timer(.4).timeout
 game.ui.announce("",0); game.set_process(false)
 h.call_drone_swarm(); var swarm=h.drone_swarm; swarm.set_physics_process(false)
 # Close view of the complete quad-rotor model, cyan optic and twin underslung ray guns.
 var drone: Node3D=swarm.drones[0].body
 game.camera.global_position=drone.global_position+Vector3(3,2.4,-3.8)
 game.camera.look_at(drone.global_position,Vector3.UP)
 game.ui.hud.visible=false
 await frame()
 game.ui.hud.visible=true
 game.camera.global_position=Vector3(13,18,20); game.camera.look_at(Vector3(0,0,1),Vector3.UP)
 for i in range(7):
  game._spawn_enemy(i%3); var e=game.enemies[-1]
  e.global_position=Vector3((i%3-1)*4,0,-1-float(i/3)*4); e.hp=2000; e.max_hp=2000; e.set_physics_process(false)
 await physics_frame
 swarm.set_physics_process(true)
 while swarm.elapsed<1.0: await physics_frame
 var shots: int=swarm.shots
 while swarm.shots==shots: await physics_frame
 await frame()
 while swarm.elapsed<5.3: await physics_frame
 await frame()
 while swarm.impacts==0 and not swarm.is_queued_for_deletion(): await physics_frame
 await frame()
 var sheet:=Image.create(1280,720,false,frames[0].get_format())
 for i in range(4): sheet.blit_rect(frames[i],Rect2i(0,0,640,360),Vector2i((i%2)*640,(i/2)*360))
 sheet.save_png("res://evidence/drone_swarm.png")
 print("DRONE CAPTURE PASS")
 game.queue_free(); await create_timer(.2,true,false,true).timeout; quit()
