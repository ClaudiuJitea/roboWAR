extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.mode=1; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 await create_timer(.1).timeout
 var human=game.heroes[0]; var ai=game.heroes[1]
 human.global_position=Vector3(2,0,2); ai.global_position=Vector3(2.5,0,2)
 human.downed=true; human.hp=0
 ai._try_revive(2.6)
 assert(not human.downed and human.hp>0,"AI must revive human")
 ai.downed=true; ai.hp=0
 human._try_revive(2.6)
 assert(not ai.downed and ai.hp>0,"human must revive AI")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 print("REVIVE PASS: both directions")
 quit()
