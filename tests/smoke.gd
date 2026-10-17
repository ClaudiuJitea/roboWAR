extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var scene: PackedScene=load("res://scenes/main.tscn")
 var game=scene.instantiate()
 root.add_child(game)
 game.mode=1
 game.start_run()
 await create_timer(6.0).timeout
 print("MODEL ",game.heroes[0].model.get_child_count()," ",game.heroes[0].model.get_class()," global=",game.heroes[0].global_position)
 print("SMOKE state=",game.state," wave=",game.wave," heroes=",game.heroes.size()," enemies=",game.enemies.size())
 quit()
