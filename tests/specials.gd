extends SceneTree
# Every operative's special move: surrounded by robots, right click must hurt the crowd, run to its end and
# hand control back. Ronin is tested twice: spread out (Hundred Cuts) and pressed in close (Kaiten-giri).

var passed := 0

func _initialize() -> void:
 call_deferred("run")

func _ring(game, center: Vector3, radius: float, n: int) -> Array:
 var out: Array=[]
 for k in range(n):
  game._spawn_enemy(0)
  var e=game.enemies[-1]
  e.global_position=center+Vector3(cos(k*TAU/n),0,sin(k*TAU/n))*radius
  e.speed=0; e.max_hp=500; e.hp=500  # tough dummies: measure damage, keep them standing
  out.append(e)
 return out

func _case(game, hero_id: int, radius: float, label: String) -> void:
 game.selected=[hero_id,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 await create_timer(.15).timeout
 var h=game.heroes[0]
 h.input_id=-1  # driven like the companion: no mouse needed
 h.global_position=Vector3(0,0,1); h.aim=Vector3(0,0,-1); h.aim_point=Vector3(0,1.4,-5)
 h.set_weapon(2)  # the move must switch back to the signature weapon
 var crowd: Array=_ring(game,h.global_position,radius,6)
 await physics_frame
 h.special_timer=0
 h._special()
 assert(h.move_t>=0,"%s: special must start a move" % label)
 assert(h.weapon==0,"%s: move is performed with the signature weapon" % label)
 assert(h.special_timer>0,"%s: special goes on cooldown" % label)
 var waited:=0.0
 while h.move_t>=0 and waited<4.0:
  await physics_frame; waited+=1.0/60.0/maxf(Engine.time_scale,.01)
 assert(h.move_t<0,"%s: move must end" % label)
 assert(not h.move_lock and not h.move_steer and h.move_lift==0.0,"%s: control returns after the move" % label)
 var hit:=0
 for e in crowd: if is_instance_valid(e) and e.hp<500: hit+=1
 assert(hit>=3,"%s: move must hurt the crowd (hit %d of 6)" % [label,hit])
 assert(get_nodes_in_group("transient").filter(func(n): return n is MeshInstance3D and not n.is_queued_for_deletion() and n.mesh is SphereMesh and n.get_child_count()>0).is_empty(),"%s: props are cleaned up" % label)
 print("SPECIAL ",label," hit ",hit,"/6 in ",snappedf(waited,.01),"s")
 passed+=1
 game._clear_run(); await create_timer(.05).timeout

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 await _case(game,0,3.0,"Bastion Bullet Hurricane")
 await _case(game,1,6.0,"Ronin Hundred Cuts")
 await _case(game,1,2.2,"Ronin Kaiten-giri")
 await _case(game,2,5.0,"Marshal Dead Eye")
 await _case(game,3,4.0,"Nova Halo Array")
 await _case(game,4,4.0,"Hex Singularity")
 await _case(game,5,5.0,"Kestrel Ghostline")
 game.queue_free(); await create_timer(.1).timeout
 if passed!=7: print("SPECIALS FAIL: %d of 7 cases finished" % passed); quit(1); return
 print("SPECIALS PASS")
 quit()
