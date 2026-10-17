extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.start_run(); game.spawn_left=0; game.wave_wait=9999
 var hero=game.heroes[0]; hero.global_position=Vector3(5,0,0); hero.invulnerable=999
 game._spawn_enemy(5); var boss=game.enemies[0]; boss.global_position=Vector3(5,0,-3); boss.target=hero; boss.windup=.01
 await create_timer(.1).timeout
 boss._enemy_ai(.02)
 assert(boss.boss_charge_time>0,"boss should charge on first attack")
 boss.boss_charge_time=0; boss.windup=.01; boss._enemy_ai(.02)
 assert(boss.attack_state==2,"boss should alternate radial attack")
 game._spawn_enemy(4); var shield=game.enemies[-1]; shield.global_position=Vector3(7,0,-3); shield.aim=Vector3(0,0,1)
 var hp: float=shield.hp
 shield.take_damage(20,hero,hero.global_position)
 assert(shield.hp>hp-20,"frontal shield should reduce damage")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 print("ARCHETYPES PASS: boss charge/radial, shield facing")
 quit()
