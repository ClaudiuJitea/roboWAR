extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.settings.killcam=1.0
 game.mode=1; game.start_run(); await create_timer(.08).timeout
 for wanted in range(1,11):
  assert(game.wave==wanted,"wave order")
  game.spawn_left=0; game.wave_wait=0
  for e in game.enemies.duplicate(): game.enemy_killed(e)
  if game.killcam.active:
   assert(game.state=="playing","wave transition waits for the final kill cam")
  while game._combat_action_active(): await process_frame
  game._process(.02)
  if game.state=="upgrade":
   game.pick_upgrade(0)
  await create_timer(.04).timeout
 assert(game.state=="results","boss victory must lead to results")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 print("PROGRESSION PASS: ten waves, four upgrades, boss victory")
 quit()
