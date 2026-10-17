extends SceneTree
# Scripted Survival fight for the README gameplay clip: Magnus (AI) and Nadia (AI companion) against a mixed
# crowd, Magnus cycling through his weapons. Record with Godot's movie maker, then convert with ffmpeg:
#   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/gameplay.avi --script res://tests/record_gameplay.gd

const SECONDS := 26.0
const COMMON := [0,1,2,3,4,6,7,8,9,10]  # Data.ENEMIES without the bosses (5, 11-14)
const SCHEDULE := [["minigun",0.0],["rocket",6.0],["shotgun",11.0],["rifle",15.5],["smg",19.5],["minigun",23.0]]

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.campaign=false; game.survival_arena="white"; game.selected=[0,5]; game.mode=1
 game.start_run(); game.wave_wait=9999
 var h=game.heroes[0]; h.input_id=-1  # the AI drives Magnus too
 for x in game.heroes: x.invulnerable=9999
 var t:=0.0; var next:=0; var spawned:=0
 while t<SECONDS:
  if next<SCHEDULE.size() and t>=SCHEDULE[next][1]:
   for i in range(h.loadout.size()): if h.loadout[i].id==SCHEDULE[next][0]: h.set_weapon(i)
   next+=1
  # keep a crowd of mixed robots coming
  if game.enemies.size()<22 and spawned<140: game._spawn_enemy(COMMON[spawned%COMMON.size()]); spawned+=1
  await process_frame
  t+=1.0/30.0
 quit()
