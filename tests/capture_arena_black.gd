extends SceneTree
# Sector 07 (black walls, red touches) in play: evidence/arena_black.png

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 var keep: String=game.arena_theme
 game.arena_theme="black"; game.selected=[5,1]; game.mode=1; game.start_run()
 for h in game.heroes: h.invulnerable=999
 await create_timer(5.0).timeout
 root.get_viewport().get_texture().get_image().save_png("res://evidence/arena_black.png")
 print("CAPTURE arena_black kills=",game.kills)
 game.arena_theme=keep
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
