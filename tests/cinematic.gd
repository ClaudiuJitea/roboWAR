extends SceneTree
# Slow motion happens once per run, at the first kill, and lasts well under a second of real time; later kills and
# waves never slow the game. While slowed, the mouse aim keeps tracking the cursor.
# The every-9th-kill kill cam is switched off here; tests/killcam.gd covers it.

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.settings.killcam=0.0
 game.selected=[5,0]; game.mode=1; game.start_run()
 for h in game.heroes: h.invulnerable=999; h.special_timer=999  # specials have their own deliberate time beats
 var me=game.heroes[0]
 var t0:=Time.get_ticks_msec(); var last:=t0; var slow_ms:=0; var slow_after_first:=0; var tracked:=false; var first_kill_at:=-1
 while Time.get_ticks_msec()-t0<14000:
  await process_frame
  var now:=Time.get_ticks_msec()
  if Engine.time_scale<1.0:
   slow_ms+=now-last
   if first_kill_at>=0 and now-first_kill_at>800: slow_after_first+=now-last
   # move the virtual cursor during the slow-motion beat; the aim must follow on the same frame
   var vp: Vector2=game.get_viewport().get_visible_rect().size
   game.cursor_override=Vector2(vp.x*(.2+.6*randf()),vp.y*.3)
   await process_frame
   var want: Vector3=game.mouse_aim(me.muzzle_position().y)-me.global_position; want.y=0
   if want.length()>.5 and me.aim.dot(want.normalized())>.99: tracked=true
  last=Time.get_ticks_msec()
  if first_kill_at<0 and game.kills>0: first_kill_at=now
  if game.wave==1 and game.wave_wait<=0 and game.spawn_left==0 and game.enemies.is_empty(): game._next_wave()
 print("CINEMATIC slow_total=",slow_ms," ms, slow after first kill window=",slow_after_first," ms, kills=",game.kills," wave=",game.wave," aim_tracked=",tracked)
 assert(game.kills>1,"several kills needed for this check")
 assert(slow_ms>0 and slow_ms<700,"one short slow-motion beat")
 assert(slow_after_first==0,"no slow motion after the first kill")
 assert(tracked,"aim follows the cursor during slow motion")
 print("CINEMATIC PASS")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
