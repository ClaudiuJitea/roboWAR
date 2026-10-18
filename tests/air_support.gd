extends SceneTree

var game

func _initialize() -> void:
 call_deferred("run")

func setup(hero: int, coop := false):
 game._clear_run(); await process_frame
 game.selected=[hero,(hero+1)%6]; game.mode=2 if coop else 0; game.campaign=false; game.start_run()
 game.settings.killcam=1.0; game.cinematic=false; game.spawn_left=0; game.wave_wait=9999
 for e in game.enemies.duplicate(): game.enemies.erase(e); e.queue_free()
 for h in game.heroes: h.set_physics_process(false); h.set_process(false)
 var h=game.heroes[0]; h.global_position=Vector3(3,0,6); h.aim=Vector3.FORWARD; h.set_weapon(1)
 h.attack_timer=0
 await process_frame
 game._spawn_enemy(0); var e=game.enemies[-1]
 e.global_position=Vector3(3,0,-2); e.max_hp=1000; e.hp=1000; e.set_physics_process(false)
 await physics_frame
 game.cursor_override=game.camera.unproject_position(Vector3(3,0,-2))
 return h

func active() -> Array:
 return get_nodes_in_group("air_support").filter(func(n): return not n.is_queued_for_deletion())

func advance(support, until: float) -> void:
 support.set_process(false)
 while support.elapsed<until and not support.is_queued_for_deletion(): support._process(.05)

func mouse(button: MouseButton, pressed: bool) -> void:
 var event:=InputEventMouseButton.new(); event.button_index=button; event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 for hero in range(6):
  var h=await setup(hero)
  var ammo: int=h.ammo[1]
  h._attack_input(true,true,.016)
  assert(active().size()==1,"every operative can call a gunship")
  assert(h.weapon==1 and h.ammo[1]==ammo,"the chord consumes no primary round or weapon switch")
  assert(h.special_timer==0 and h.move_t<0,"air support has a separate cooldown and leaves the operative free")
  assert(is_equal_approx(h.air_support_timer,game.Data.AIR_SUPPORT_COOLDOWN),"air cooldown begins on call-in")
  var support=active()[0]; support.set_process(false)
  assert(support.center.distance_to(Vector3(3,0,-2))<.02,"the pass targets the cursor")
  h.air_support_timer=0
  for i in range(10): h._attack_input(true,true,.1)
  assert(active().size()==1,"holding the chord never repeats, even when the cooldown becomes ready")
  h.air_support_timer=20
  h._attack_input(false,true,.2)
  assert(h.special_timer==0,"releasing left while holding right cannot leak a special")
  h._attack_input(false,false,.016); h._attack_input(true,true,.016)
  assert(active().size()==1 and h.special_timer==0,"a cooling-down chord cannot consume the special instead")
  var victim=game.enemies[-1]
  advance(support,4.9)
  assert(not support.is_queued_for_deletion(),"the barrage stays active throughout its fifth second")
  advance(support,5.1)
  assert(victim.hp<1000,"the strafe damages enemies for every operative")
  assert(support.bursts_fired==support.BURSTS and support.rockets_fired,"the complete pass fires its guns and rockets")
  assert(support.shell_impacts==40 and support.rocket_impacts==8,"all forty explosive shells and eight heavy rockets detonate")
  assert(support.rockets.all(func(r): return r.done) and support.shells.all(func(r): return r.done),"no ordnance is discarded before impact")
  assert(support.is_queued_for_deletion(),"the aircraft cleans up at five seconds")
  print("AIR SUPPORT ",game.Data.HEROES[hero]," PASS")
 # Expanded rocket splash and real explosive-shell damage, with existing upgrade and boss scaling.
 var heavy=await setup(0,true)
 var dummy=game.enemies[-1]; dummy.global_position=Vector3(6.5,0,-2)
 heavy.upgrades.ability_damage=2; heavy.buffs.overcharge=10.0
 heavy._attack_input(true,true,.016)
 var barrage=active()[0]; barrage.set_process(false)
 barrage._damage(Vector3(3,0,-2),barrage.ROCKET_RADIUS,barrage.ROCKET_DAMAGE,6)
 assert(dummy.hp<900,"heavy rockets reach enemies 3.5m from impact and scale with ability power")
 dummy.hp=1000; dummy.global_position=Vector3(3,0,-2)
 barrage._damage(dummy.global_position,barrage.SHELL_RADIUS,barrage.SHELL_DAMAGE,3)
 assert(is_equal_approx(dummy.hp,1000-52.0*1.4*1.6),"cannon shells deal grenade-strength splash rather than tracer-only hits")
 dummy.boss=true; dummy.hp=1000
 barrage._damage(dummy.global_position,barrage.ROCKET_RADIUS,barrage.ROCKET_DAMAGE,6)
 assert(is_equal_approx(dummy.hp,1000-130.0*1.4*1.6*.4),"boss damage retains support scaling")
 # Left-first presses also work, without consuming the operative's cooling-down special.
 var left=await setup(0)
 left.special_timer=20
 left._attack_input(true,false,.016)
 assert(left.ammo[1]==29,"ordinary left-click fire stays immediate")
 left._attack_input(true,true,.016)
 assert(active().size()==1 and left.ammo[1]==29 and left.special_timer==20,"left-first chord calls support independently of the special")
 # Right-first presses get the same chord priority; an ordinary right-click tap still casts the special.
 var h=await setup(5,true)
 game.heroes[1].global_position=Vector3(3,0,-2)
 var ally_hp: float=game.heroes[1].hp
 h._attack_input(false,true,.03)
 assert(h.special_timer==0 and h.move_t<0,"right-click grace accepts the second button")
 h._attack_input(true,true,.03)
 assert(game.heroes[1].air_support_timer==0,"each co-op player owns their support cooldown")
 var support=active()[0]; support.set_process(false)
 h._attack_input(true,false,.016)
 assert(h.ammo[1]==29,"primary fire resumes when the right button is released")
 h._attack_input(false,false,.016)
 h._attack_input(false,true,.016); h._attack_input(false,false,.016)
 assert(h.special_timer>0 and h.move_t>=0,"a plain right-click tap still starts Ghostline")
 # Call support during a committed special through the actual mouse input path.
 h.air_support_timer=0
 mouse(MOUSE_BUTTON_LEFT,true); mouse(MOUSE_BUTTON_RIGHT,true)
 h._physics_process(.016)
 mouse(MOUSE_BUTTON_LEFT,false); mouse(MOUSE_BUTTON_RIGHT,false)
 assert(active().size()==2 and h.move_t>=0,"support is available during the operative's special")
 var before: float=support.elapsed; var cooldown: float=h.air_support_timer
 game.state="paused"; support._process(1); h._physics_process(1)
 assert(support.elapsed==before and h.air_support_timer==cooldown,"pause freezes aircraft and cooldown")
 game.state="playing"; advance(support,5.1)
 assert(game.heroes[1].hp==ally_hp,"air support cannot hurt a partner standing in the impact zone")
 # A ninth aerial kill keeps the aircraft on screen, then permits the upgrade screen when the pass ends.
 h=await setup(1)
 h._attack_input(true,true,.016); support=active()[0]; support.set_process(false)
 game.kills=8; game.wave=2; game.wave_wait=0; game.enemies[-1].hp=1
 advance(support,2.6)
 assert(game.kills==9 and not game.killcam.active,"aerial kills do not start a weapon kill cam")
 game._process(.016)
 assert(game.state=="playing","a wave-ending pass finishes before upgrades")
 advance(support,5.1); await process_frame
 game._process(.016)
 assert(game.state=="upgrade","upgrades follow the completed aircraft pass")
 # Frame hitches must not drop the final shells/rockets when the five-second lifetime expires.
 h=await setup(0)
 h._attack_input(true,true,.016); support=active()[0]; support.set_process(false)
 for i in range(10): support._process(.5)
 assert(support.is_queued_for_deletion() and support.shell_impacts==40 and support.rocket_impacts==8,"all scheduled ordnance lands even at two frames per second")
 h=await setup(0)
 h._attack_input(true,true,.016); support=active()[0]
 var stopped: float=support.elapsed
 game._clear_run(); support._process(.5)
 assert(support.elapsed==stopped,"queued aircraft cannot act against a restarted run")
 await process_frame
 assert(active().is_empty(),"reset removes aircraft and ordnance")
 game.queue_free(); await create_timer(.1,true,false,true).timeout
 print("AIR SUPPORT PASS")
 quit()
