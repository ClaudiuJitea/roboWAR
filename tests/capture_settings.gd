extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.ui.show_settings("menu")
 await create_timer(.2).timeout
 root.get_viewport().get_texture().get_image().save_png("res://evidence/settings.png")
 game.queue_free(); await create_timer(.1).timeout
 quit()
