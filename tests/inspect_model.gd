extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.start_run()
 var model=game.heroes[0].model
 for child in model.get_children(): print(child.name," ",child.get_class())
 var anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
 print("ANIM ",anim, " NAMES ",anim.get_animation_list() if anim else [])
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout; quit()
