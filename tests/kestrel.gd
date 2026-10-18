extends SceneTree
# Ghostline's three rifle shots pierce enemies and shields, respect world cover, and remain bounded on bosses.

var game

func _initialize() -> void:
 call_deferred("run")

func setup():
 game._clear_run(); await process_frame
 game.selected=[5,0]; game.mode=0; game.campaign=false; game.start_run()
 game.settings.killcam=1.0; game.cinematic=false; game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 # Use a clear test range; the separate cover case adds a known wall to this range.
 for body in game.arena.find_children("*","StaticBody3D",true,false): body.collision_layer=0
 var h=game.heroes[0]; h.set_physics_process(false); h.set_process(false)
 h.input_id=-1; h.global_position=Vector3(0,0,8); h.aim=Vector3.FORWARD; h.aim_point=Vector3(0,1.4,-8)
 await physics_frame
 return h

func target(z: float, kind := 0):
 game._spawn_enemy(kind); var e=game.enemies[-1]
 e.global_position=Vector3(0,0,z); e.set_physics_process(false); e.max_hp=2000; e.hp=2000
 e.aim=Vector3.BACK
 return e

func finish(h) -> void:
 while h.move_t>=0: h._run_move(.025)

func props() -> Array:
 return get_nodes_in_group("ghostline_marks").filter(func(n): return not n.is_queued_for_deletion())

func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 var h=await setup()
 var near=target(3); var shield=target(0,4); var far=target(-3)
 await physics_frame
 var ammo: int=h.ammo[0]
 h._special()
 assert(props().size()==3 and h.weapon==0,"weak points are marked for the signature sniper")
 finish(h)
 for e in [near,shield,far]: assert(is_equal_approx(2000-e.hp,675.0),"three piercing critical shots cross the whole line, including frontal shields")
 assert(h.ammo[0]==ammo and h.special_timer>0,"Ghostline uses its cooldown rather than magazine ammunition")
 assert(props().is_empty() and not h.move_lock and not h.move_steer,"marks and input lock clear after the salvo")
 print("GHOSTLINE piercing / armour PASS")
 h=await setup()
 near=target(3); far=target(-3)
 var wall:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(4,4,.4)
 shape.shape=box; wall.add_child(shape); game.add_child(wall); wall.global_position=Vector3(0,1.5,0)
 await physics_frame
 h._special(); finish(h)
 assert(near.hp<2000 and far.hp==2000,"piercing shots stop at world cover")
 wall.queue_free()
 print("GHOSTLINE cover PASS")
 h=await setup()
 var boss=target(0,5); await physics_frame
 h._special(); finish(h)
 assert(is_equal_approx(2000-boss.hp,270.0),"the full boss salvo is scaled rather than deleting the boss")
 print("GHOSTLINE boss balance PASS")
 h=await setup()
 near=target(2); far=target(-2); await physics_frame
 h._special()
 game.enemies.erase(near); near.queue_free(); await process_frame
 finish(h)
 assert(far.hp<2000,"destroyed marks are safely retargeted")
 h.special_timer=0; h._special(); h.end_move()
 assert(props().is_empty(),"interrupting a salvo removes its marks")
 h.special_timer=0
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 h._special(); finish(h)
 assert(props().is_empty(),"an empty range is handled cleanly")
 h=await setup()
 near=target(2); near.hp=1; await physics_frame
 h._special()
 while game.kills==0: h._run_move(.025)
 assert(h.move_events.is_empty() and h.move_end<1.0 and Engine.time_scale<1,"a clearing shot gets the finish beat without two empty follow-up shots")
 finish(h)
 h=await setup()
 target(2); target(-2); target(-6); await physics_frame
 h.special_timer=0; h.attack_timer=999; h.ai_tick=0
 h._companion_ai(.016)
 assert(h.move_t>=0 and h.special_timer>0,"AI Kestrel uses Ghostline at sniper range")
 h.end_move()
 game._clear_run(); game.queue_free(); await create_timer(.3,true,false,true).timeout
 print("KESTREL PASS")
 quit()
