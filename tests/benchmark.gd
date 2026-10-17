extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func sample(seconds: float) -> Dictionary:
 var fps_total:=0.0; var process_total:=0.0; var physics_total:=0.0; var count:=0
 for i in range(int(seconds*4)):
  await create_timer(.25).timeout
  fps_total+=Engine.get_frames_per_second()
  process_total+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
  physics_total+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
  count+=1
 return {"fps":fps_total/count,"process_ms":process_total/count,"physics_ms":physics_total/count}

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.mode=1; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for h in game.heroes: h.invulnerable=999
 for i in range(80): game._spawn_enemy(i%5)
 await create_timer(2.0).timeout
 var high: Dictionary=await sample(4.0)
 print("BENCH HIGH renderer=",ProjectSettings.get_setting("rendering/renderer/rendering_method")," enemies=",game.enemies.size()," ",high)
 root.get_viewport().get_texture().get_image().save_png("res://evidence/crowd.png")
 game.settings.effects=0
 await create_timer(1.0).timeout
 var low: Dictionary=await sample(4.0)
 print("BENCH LOW effects=0 enemies=",game.enemies.size()," ",low)
 game.settings.effects=1
 await create_timer(1.0).timeout
 var high_again: Dictionary=await sample(4.0)
 print("BENCH HIGH AGAIN enemies=",game.enemies.size()," ",high_again)
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
