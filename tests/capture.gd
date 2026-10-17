extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.mode=1; game.start_run()
 await create_timer(4.0).timeout
 var image=root.get_viewport().get_texture().get_image()
 image.save_png("res://evidence/arena.png")
 print("CAPTURE ",image.get_size())
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
