extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 for i in range(6):
  game.selected=[i,(i+1)%6]; game.mode=1; game.start_run(); game.spawn_left=0; game.wave_wait=9999
  await create_timer(.12).timeout
  var h=game.heroes[0]
  for clip in ["idle","aim","run","run_back","strafe_left","strafe_right","recoil","reload","hit","dodge","downed","death"]: assert(h.anim.has_animation(clip),"fighter must import clip "+clip)
  assert(is_instance_valid(h.tree) and h.tree.active,"fighter must drive the layered animation tree")
  h.aim=Vector3(0,0,-1)
  h.model.rotation=Vector3.ZERO
  assert(h.weapon_nodes.size()==h.loadout.size() and h.loadout.size()==8,"signature + 7 guns must be mounted on the grip")
  assert(h.loadout[0].id==game.Data.SIGNATURES[i].id and h.weapon==0,"operative starts with its signature weapon")
  assert(h.stance==h.loadout[0].stance,"operative starts in its signature weapon stance")
  for w in range(h.loadout.size()):
   h.set_weapon(w); h.attack_timer=0; h.charge=0
   await create_timer(.7).timeout  # let the stance blend and any recoil/reload/slash one-shot finish
   h.model.rotation=Vector3.ZERO; h.aim=Vector3(0,0,-1)
   assert(is_instance_valid(h.weapon_nodes[w]) and h.weapon_nodes[w].visible,"current weapon must be visible")
   var tip: Vector3=h.muzzle_position()-h.global_position
   if h.loadout[w].kind!="melee":
    assert(tip.z<-.4 and tip.y>.6,"muzzle must sit in front of the fighter at weapon height")
    var along: Vector3=(h.muzzle_position()-h.weapon_nodes[w].global_position).normalized()
    assert(absf(along.y)<.42,"%s: gun %s must point forward, not up or down (pitch %.2f)" % [h.name,h.loadout[w].id,along.y])
   h._primary(2.0)
   assert(h.attack_timer>0,"weapon %s must fire" % h.loadout[w].id)
  print("ROSTER ",i," weapons ok, muzzle=",h.muzzle_position()-h.global_position)
  h.attack_timer=0
  h._primary(2.0)
  h._special()
  print("ROSTER ",i," model=",h.model.get_child_count()," attack=",h.attack_timer," special=",h.special_timer)
  game._clear_run(); await create_timer(.05).timeout
 game.selected=[0,3]; game.mode=3; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 assert(game.heroes[0].input_id==1 and game.heroes[1].input_id==2,"two pad ownership")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 print("ROSTER PASS")
 quit()
