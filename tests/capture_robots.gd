extends SceneTree
# Line-up of the newer robots (back row: bomber, mortar, lancer, medic, splitter, an elite grunt) and the five
# bosses (front row), standing still and facing the camera: evidence/robots_lineup.png

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.settings.killcam=0.0
 game.campaign=false; game.survival_arena="cryo"; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 await create_timer(.3).timeout
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.global_position=Vector3(0,0,9); h.set_physics_process(false); h.visible=false
 var row: Array=[]
 for i in range(6):
  var id: int=[6,7,8,9,10,0][i]
  var e=game.spawn_enemy_at(id,Vector3(-7.5+i*3.0,0,-3.5),false)
  if i==5: e.queue_free(); game.enemies.erase(e); e=null
  if e==null:
   var a=game.Actor.new(); a.setup(game,false,0,-2); a.make_elite(); a.position=Vector3(7.5,0,-3.5); game.add_child(a); game.enemies.append(a); e=a
  row.append(e)
 for i in range(5):
  row.append(game.spawn_enemy_at([5,11,12,13,14][i],Vector3(-10+i*5.0,0,2.5),false))
 game.boss_actor=null; game.ui.card_time=0.0; game.ui.card_box.visible=false
 await create_timer(.2).timeout
 for e in row:
  e.set_physics_process(false); e.model.rotation=Vector3(0,PI,0)
  if e.enemy_id==12: e.model.position.y=.4
 game.camera_center=Vector3(0,0,-.5)
 await create_timer(.6).timeout
 root.get_viewport().get_texture().get_image().save_png("res://evidence/robots_lineup.png")
 print("CAPTURE robots")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
