extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.settings.autoaim=0.0  # the hit checks aim by hand; a saved Auto aim setting would lock onto the robot
 game.start_run()
 game.spawn_left=0; game.wave_wait=9999
 var hero=game.heroes[0]
 hero.set_weapon(1)  # shared rifle: the hit test needs a gun muzzle, whatever the saved operative is
 hero.global_position=Vector3(3,0,0)
 game._spawn_enemy(0)
 var enemy=game.enemies[0]
 enemy.global_position=Vector3(3,0,-2)
 enemy.speed=0
 await create_timer(.15).timeout
 var before: float=enemy.hp
 game.hitscan(hero,Vector3(0,0,-1),10,8,1,Color.CYAN)
 assert(enemy.hp<before,"hitscan must damage enemy")
 # a rifle shot whose tracer crosses the robot off-centre must still connect
 # aim straight ahead with the virtual cursor (shots go from the muzzle toward the aim point under the cursor)
 game.cursor_override=game.camera.unproject_position(Vector3(hero.muzzle_position().x,hero.muzzle_position().y,-14))
 await process_frame
 var mx: float=hero.muzzle_position().x
 enemy.global_position=Vector3(mx+.35,0,-2); await physics_frame
 var off: float=enemy.hp
 game.fire_hitscan(hero,Vector3(0,0,-1),game.Data.WEAPONS[0].merged({"spread":0.0}),5,0)
 assert(enemy.hp<off,"off-centre hit inside the body width must connect")
 enemy.global_position=Vector3(mx+1.2,0,-2); await physics_frame
 off=enemy.hp
 game.fire_hitscan(hero,Vector3(0,0,-1),game.Data.WEAPONS[0].merged({"spread":0.0}),5,0)
 assert(enemy.hp==off,"a clear miss must not connect")
 var own: float=hero.hp
 game.hurt(hero,20,hero,hero.global_position)
 assert(hero.hp==own,"friendly fire must be disabled")
 hero.apply_upgrade(game.Data.UPGRADES[0])
 assert(hero.max_hp>game.Data.HP[hero.hero_id],"health upgrade must affect health")
 game.state="paused"
 await create_timer(.2).timeout
 assert(hero.attack_timer==0,"pause must stop actor timers")
 game.state="playing"
 game.enemy_killed(enemy)
 assert(game.enemies.is_empty(),"enemy death must remove enemy")
 game._clear_run()
 game.state="menu"
 game.queue_free()
 await create_timer(.1).timeout
 print("GAMEPLAY PASS: damage, team filtering, upgrade, pause, enemy cleanup")
 quit()
