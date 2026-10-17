extends SceneTree
# While strafing in every direction with the cursor held still, the visible shot line (muzzle -> shot direction)
# must pass through the cursor on screen. Fails if it misses by more than 12 pixels. Uses a virtual cursor, so it
# runs headless and is not disturbed by the real mouse.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.selected=[5,0]; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 var h=game.heroes[0]; h.invulnerable=999
 await create_timer(.5).timeout
 var worst:=0.0
 for w in [0,1,5,6]:
  h.set_weapon(w); await create_timer(.4).timeout
  for mv in ["move_left","move_right","move_up","move_down"]:
   h.global_position=Vector3(0,0,2); await create_timer(.2).timeout
   Input.action_press(mv)
   for f in range(30):
    var vp: Vector2=game.get_viewport().get_visible_rect().size
    game.cursor_override=Vector2(vp.x*.2,vp.y*.25) if f<15 else Vector2(vp.x*.8,vp.y*.3)
    await physics_frame
    if f%5==4:
     var cursor: Vector2=game.cursor_override
     var m: Vector3=h.muzzle_position()
     var d: Vector3=game.shot_dir(h,h.aim)
     var best:=INF
     for k in range(1,60):
      var p: Vector3=m+d*(k*.4)
      best=minf(best,game.camera.unproject_position(p).distance_to(cursor))
     worst=maxf(worst,best)
   Input.action_release(mv)
 print("AIMLINE worst miss on screen = %.1f px" % worst)
 assert(worst<12.0,"shots must pass through the cursor while moving")
 print("AIMLINE PASS")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
