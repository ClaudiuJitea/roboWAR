extends SceneTree
# In-game HUD capture: evidence/hud.png (stats strip, both player cards, weapon tag).

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 var keep: String=game.arena_theme; game.arena_theme=OS.get_environment("HUD_ARENA") if OS.get_environment("HUD_ARENA")!="" else keep
 game.selected=[2,4]; game.mode=1; game.start_run()
 for h in game.heroes: h.invulnerable=999
 await create_timer(6.0).timeout
 var you=game.heroes[0]; you.hp=you.max_hp*.62; you.ammo[you.weapon]=17
 you.set_weapon(5)
 await create_timer(.3).timeout
 root.get_viewport().get_texture().get_image().save_png("res://evidence/hud.png")
 print("CAPTURE hud kills=",game.kills," time=",int(game.elapsed))
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
