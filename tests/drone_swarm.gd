extends SceneTree
var game

func _initialize() -> void:
 call_deferred("run")

func setup(hero := 0, coop := false):
 game._clear_run(); await process_frame
 game.selected=[hero,(hero+1)%6]; game.mode=2 if coop else 0; game.campaign=false; game.start_run()
 game.settings.killcam=1.0; game.cinematic=false; game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 for body in game.arena.find_children("*","StaticBody3D",true,false): body.collision_layer=0
 for h in game.heroes: h.set_physics_process(false); h.set_process(false)
 var h=game.heroes[0]; h.global_position=Vector3(0,0,7); h.aim=Vector3.FORWARD
 await physics_frame
 return h

func target(at: Vector3, kind := 0):
 game._spawn_enemy(kind); var e=game.enemies[-1]
 e.global_position=at; e.hp=2000; e.max_hp=2000; e.set_physics_process(false)
 return e

func deploy(h):
 assert(h.call_drone_swarm(),"swarm deploys")
 h.drone_swarm.set_physics_process(false)
 return h.drone_swarm

func advance(swarm, seconds: float) -> void:
 for i in range(ceili(seconds/.025)):
  if swarm.is_queued_for_deletion(): return
  swarm._physics_process(.025)

func mouse(pressed: bool) -> void:
 var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_MIDDLE; event.pressed=pressed
 Input.parse_input_event(event); Input.flush_buffered_events()

func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 for hero in range(6):
  var h=await setup(hero)
  var victims: Array=[]
  for i in range(9): victims.append(target(Vector3((i%3-1)*4.0,0,-float(i/3)*4)))
  await physics_frame
  var ammo: Array=h.ammo.duplicate()
  var swarm=deploy(h)
  assert(swarm.drones.size()==3 and h.drone_timer==40,"exactly three drones and independent cooldown")
  assert(not h.call_drone_swarm(),"one active swarm per operative")
  advance(swarm,4.95)
  for e in victims: assert(e.hp<2000,"ray guns cycle through the entire visible crowd")
  assert(swarm.shots>30 and swarm.impacts==0,"five seconds of rays before any kamikaze")
  assert(h.ammo==ammo and h.special_timer==0 and h.air_support_timer==0 and h.move_t<0,"deployment preserves weapons, movement and other cooldowns")
  advance(swarm,.1)
  var assigned: Array=[]
  for d in swarm.drones:
   assert(d.state=="dive" and not assigned.has(d.target),"drones spread their dives across survivors")
   assigned.append(d.target)
  advance(swarm,4)
  assert(swarm.impacts==3 and swarm.is_queued_for_deletion(),"each drone explodes once, then swarm cleans up")
  assert(not h.call_drone_swarm(),"finishing a swarm cannot bypass its cooldown")
  print("DRONES ",game.Data.HEROES[hero]," PASS")
 var h=await setup(0,true)
 var swarm=deploy(h)
 advance(swarm,8)
 assert(swarm.shots==0 and swarm.impacts==0 and swarm.status()=="ARMED / HOVER","empty arena leaves armed drones hovering")
 assert(not game._combat_action_active(),"waiting drones never prevent the next wave")
 h.drone_timer=0
 assert(not h.call_drone_swarm(),"an indefinitely hovering swarm cannot be stacked after recharge")
 h.global_position=Vector3(9,0,9); advance(swarm,1)
 for d in swarm.drones: assert(d.body.global_position.distance_to(h.global_position)<4,"waiting drones follow the player")
 var saved: float=swarm.elapsed; var cooldown: float=h.drone_timer
 game.state="paused"; swarm._physics_process(3); h._physics_process(3)
 assert(swarm.elapsed==saved and h.drone_timer==cooldown,"pause freezes swarm and cooldown")
 game.state="upgrade"; swarm._physics_process(3)
 assert(swarm.elapsed==saved and not swarm.is_queued_for_deletion(),"waiting swarm survives upgrade screens")
 game.state="playing"
 var e=target(Vector3(9,0,0)); await physics_frame
 advance(swarm,.05)
 assert(swarm.attacking() and swarm.shots==0,"new arrivals trigger immediate kamikaze, without restarting ray phase")
 game.enemies.erase(e); e.queue_free(); await process_frame
 advance(swarm,.1)
 assert(not swarm.attacking() and swarm.impacts==0,"losing a target returns drones to hover instead of exploding in empty space")
 e=target(Vector3(7,0,1)); e.hp=1
 await physics_frame
 var ally=game.heroes[1]; ally.global_position=e.global_position; var ally_hp: float=ally.hp
 game.kills=8
 advance(swarm,3)
 assert(game.kills==9 and not game.killcam.active,"drone kills retain their own staging")
 assert(swarm.impacts==1,"remaining drones survive when the first explosion clears all targets")
 assert(ally.hp==ally_hp,"kamikaze splash cannot hurt a partner")
 advance(swarm,.1)
 assert(not game._combat_action_active(),"retargeted empty dives release the wave transition")
 game.wave=2; game.wave_wait=0; game._process(.016)
 assert(game.state=="upgrade","surviving drones permit upgrades")
 print("DRONES hover / retarget / friendly fire / wave handoff PASS")
 h=await setup()
 e=target(Vector3(0,0,-4))
 var wall:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(12,12,.4)
 shape.shape=box; wall.add_child(shape); game.add_child(wall); wall.position=Vector3(0,3,1)
 await physics_frame
 swarm=deploy(h); advance(swarm,4.95)
 assert(e.hp==2000 and swarm.shots==0,"ray guns respect cover")
 wall.queue_free(); await physics_frame
 advance(swarm,3)
 assert(swarm.impacts==3,"drones still complete their terminal attacks")
 h=await setup()
 e=target(Vector3(0,0,1),5); await physics_frame
 swarm=deploy(h); advance(swarm,9)
 assert(e.hp>1600 and e.hp<2000,"boss damage is bounded")
 print("DRONES cover / boss balance PASS")
 h=await setup()
 h.downed=true; assert(not h.call_drone_swarm(),"downed operatives cannot deploy")
 h.downed=false; h.dead=true; assert(not h.call_drone_swarm(),"dead operatives cannot deploy")
 h.dead=false
 # Actual middle mouse input, including during a committed character special.
 h._special(); assert(h.move_t>=0)
 mouse(true); h._physics_process(.016)
 swarm=h.drone_swarm; assert(is_instance_valid(swarm),"MMB works during a special")
 swarm.set_physics_process(false)
 h.drone_timer=0
 for i in range(4): h._physics_process(.016)
 assert(get_nodes_in_group("drone_swarm").size()==1,"holding MMB cannot repeat deployment")
 mouse(false); h._physics_process(.016)
 swarm.queue_free(); await process_frame
 mouse(true); h._physics_process(.016); mouse(false)
 assert(is_instance_valid(h.drone_swarm) and h.drone_swarm!=swarm,"release and fresh press rearm deployment")
 swarm=h.drone_swarm; var stopped: float=swarm.elapsed
 game._clear_run(); swarm._physics_process(.5)
 assert(swarm.elapsed==stopped,"queued drones cannot attack a restarted run")
 await process_frame
 assert(get_nodes_in_group("drone_swarm").is_empty(),"reset frees all swarm nodes")
 game.queue_free(); await create_timer(.1,true,false,true).timeout
 print("DRONE SWARM PASS")
 quit()
