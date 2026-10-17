extends SceneTree
# Each operative fires its signature weapon at a group of enemies: evidence/signature_<id>.png + evidence/signatures_sheet.png

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 for i in range(6):
  game.selected=[i,(i+1)%6]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
  for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
  var h=game.heroes[0]; h.invulnerable=999; h.set_physics_process(false); h.input_id=-1
  h.global_position=Vector3(-4,0,4)
  for k in range(6):
   game._spawn_enemy(k%3); var e=game.enemies[-1]
   e.global_position=Vector3(-5.6+k*.65,0,1.6-(k%2)*.8) if h.loadout[0].kind=="melee" else Vector3(-6.4+k*.9,0,-.5-(k%2)*1.2)
   e.speed=0; e.attack_timer=99; e.hp=minf(e.hp,14.0)
  await create_timer(.6).timeout
  var id: String=h.loadout[0].id
  for f in range({"railrifle":10,"gauntlet":20,"sword":7}.get(id,12)):
   h.aim=Vector3(-.12,0,-1).normalized(); h.model.rotation.y=atan2(-h.aim.x,-h.aim.z)
   h.target=game.enemies[0] if not game.enemies.is_empty() else null
   h.attack_timer=maxf(0,h.attack_timer-.05); h._primary(.05 if id!="railrifle" else .1)
   await physics_frame
  root.get_viewport().get_texture().get_image().save_png("res://evidence/signature_%s.png" % id)
  print("CAPTURE ",id," left=",game.enemies.size())
  game._clear_run(); await create_timer(.2).timeout
 game.queue_free(); await create_timer(.1).timeout
 quit()
