extends SceneTree
# Fires each weapon into a group of enemies and saves evidence/weapon_<id>.png mid-effect.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[0,3]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 var h=game.heroes[0]; h.invulnerable=9999; h.set_physics_process(false); h.input_id=-1
 var frames := {"rifle":14,"smg":22,"shotgun":10,"railgun":9,"rocket":21,"grenade":50,"plasma":30}
 for w in range(1,h.loadout.size()):
  var id: String=h.loadout[w].id
  for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
  await create_timer(.6).timeout
  h.global_position=Vector3(-4,0,5); h.velocity=Vector3.ZERO
  for k in range(7):
   game._spawn_enemy(k%3)
   var e=game.enemies[-1]; e.global_position=Vector3(-6.5+k*.9,0,-.5-(k%2)*1.2); e.speed=0; e.hp=minf(e.hp,12.0); e.attack_timer=99
  await create_timer(.3).timeout
  h.set_weapon(w)
  for f in range(frames[id]):
   h.aim=Vector3(-.12,0,-1).normalized(); h.model.rotation.y=atan2(-h.aim.x,-h.aim.z); h.last_move=Vector3.ZERO
   h.target=game.enemies[3] if game.enemies.size()>3 else null
   if h.target: h.aim_point=h.target.global_position  # as mouse/auto aim do: shots converge from the muzzle
   h.attack_timer=maxf(0,h.attack_timer-.05)
   h._primary(.05 if id!="railgun" else .2)
   await physics_frame
  root.get_viewport().get_texture().get_image().save_png("res://evidence/weapon_%s.png" % id)
  print("CAPTURE ",id," enemies_left=",game.enemies.size())
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
