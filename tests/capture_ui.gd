extends SceneTree
# Captures every menu screen for visual review: evidence/ui_<screen>.png

func _initialize() -> void:
 call_deferred("run")

func shot(name: String) -> void:
 await create_timer(.25).timeout
 root.get_viewport().get_texture().get_image().save_png("res://evidence/ui_%s.png" % name)
 print("CAPTURE ",name)

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 await shot("menu")
 game.mode=1; game.ui.show_selection(); await shot("setup")
 game.mode=2; game.ui.show_selection(); await shot("setup_coop")
 game.ui.show_settings("menu"); await shot("settings")
 game.mode=1; game.start_run(); await create_timer(.5).timeout
 game.state="paused"; game.ui.show_pause(); await shot("pause")
 var offers: Array[Dictionary]=[game.Data.UPGRADES[0],game.Data.UPGRADES[3],game.Data.UPGRADES[9]]
 game.ui.show_upgrades(game.heroes[0],offers); await shot("upgrade")
 game.ui.show_results(true); await shot("results")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
