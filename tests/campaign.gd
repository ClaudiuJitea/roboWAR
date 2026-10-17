extends SceneTree
# Operation Meridian end to end: briefing -> three waves -> boss (left alive a few seconds so every attack pattern
# runs against an invulnerable squad) -> debrief -> upgrades -> next chapter in its own environment ... -> victory.
# Also lets every new robot type act around the squad, and checks a Survival boss per arena.

func _initialize() -> void:
 call_deferred("run")

func _kill_all(game) -> void:
 var h=game.heroes[0]
 for e in game.enemies.duplicate():
  if is_instance_valid(e) and not e.dead: game.hurt(e,99999.0,h,e.global_position,"kinetic")

func _guard(game) -> void:
 for h in game.heroes: h.invulnerable=999.0; h.hp=h.max_hp

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.unlocked=1; game.settings.killcam=0.0
 game.campaign=true; game.start_chapter=0; game.mode=1; game.selected=[1,4]
 game.start_run()
 assert(game.state=="briefing","a campaign run opens on the briefing")
 var chapters: int=game.Campaign.CHAPTERS.size()
 for ch in range(chapters):
  assert(game.chapter==ch,"chapter %d expected, at %d" % [ch,game.chapter])
  assert(game.arena_theme==game.Campaign.CHAPTERS[ch].arena,"chapter %d plays in its own environment" % ch)
  assert(is_instance_valid(game.arena) and game.arena.theme==game.arena_theme,"arena rebuilt for the chapter")
  game.deploy()
  assert(game.state=="playing" and game.wave==1,"deploy starts wave 1")
  assert(game.ui.radio_msg[1]!="","radio speaks at the start of the chapter")
  var saw_boss:=false
  var guard:=0.0
  while game.state!="debrief" and guard<240.0:
   _guard(game)
   if game.state=="upgrade": game.pick_upgrade(0)
   elif game.state=="playing":
    if game.wave>=4 and is_instance_valid(game.boss_actor):
     if not saw_boss:
      saw_boss=true
      assert(game.boss_actor.enemy_id==int(game.Campaign.CHAPTERS[ch].boss),"the chapter's boss arrives")
      game.boss_actor.global_position=game.heroes[0].global_position+Vector3(0,0,-5)
      for k in range(480):  # ~8 s of the boss fighting
       _guard(game); await physics_frame
      game.boss_actor.hp=game.boss_actor.max_hp*.3  # into the last phase
      for k in range(300):
       _guard(game); await physics_frame
     game.spawn_left=0
     _kill_all(game)
    else:
     game.spawn_left=0; game.wave_wait=0
     _kill_all(game)
   await physics_frame; guard+=1.0/60.0
  assert(saw_boss,"chapter %d had its boss fight" % ch)
  assert(game.state=="debrief","chapter %d ends on the debrief" % ch)
  assert(game.unlocked>=mini(ch+2,chapters),"clearing a chapter unlocks the next")
  print("CAMPAIGN chapter ",ch+1," clear: ",game.Campaign.CHAPTERS[ch].title," kills=",game.kills)
  game.continue_after_debrief()
  while game.state=="upgrade": game.pick_upgrade(0); await process_frame
  if ch<chapters-1:
   assert(game.state=="briefing","next chapter opens on its briefing")
   for h in game.heroes: assert(not h.dead and not h.downed and h.hp>0,"squad is back on its feet for the next chapter")
 assert(game.state=="results","the last debrief leads to the results")
 print("CAMPAIGN complete, score ",game.score)
 # every new robot acts around the squad without errors
 game.campaign=false; game.survival_arena="toxic"; game.mode=0; game.start_run(); game.spawn_left=0; game.wave_wait=9999
 await create_timer(.2).timeout
 for id in [6,7,8,9,10]:
  var e=game.spawn_enemy_at(id,game.heroes[0].global_position+Vector3(4,0,-4),false)
 game.enemies[0].hp=1.0  # a bomber: hurt a little so the medic has someone to repair
 for k in range(360):
  _guard(game); await physics_frame
 var bombers:=0
 for e in game.enemies: if is_instance_valid(e) and e.enemy_id==6: bombers+=1
 print("ROBOTS left after 6 s: ",game.enemies.size()," (bombers ",bombers,")")
 _kill_all(game); await physics_frame
 # survival: each arena brings its own boss on wave 10
 for key in game.Data.ARENA_ORDER:
  game.survival_arena=key; game.start_run(); game.spawn_left=0; game.wave_wait=9999
  game.wave=9; game.wave_wait=0; game._next_wave()
  assert(is_instance_valid(game.boss_actor) and game.boss_actor.enemy_id==int(game.Data.ARENAS[key].boss),"survival boss for %s" % key)
  await physics_frame
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 print("CAMPAIGN PASS")
 quit()
