extends RefCounted
# Behaviour for the newer robots and the campaign bosses (actor._enemy_ai hands them over here once it has a
# target). Per-robot state lives in actor.ai (a Dictionary), so the actor needs no field per behaviour.
#   6 Bomber        rushes the nearest fighter, flashes on a short fuse and detonates (killed first, it blows up its neighbours)
#   7 Mortar        keeps its distance and lobs shells; a ring on the floor shows where each one lands
#   8 Lancer        paints a red line for a second, then fires a piercing beam down it
#   9 Medic         hangs back with the pack and repairs the robots around it
#   11 Forge Titan  ground slam (leaves molten pools), molten shell volleys; summons brutes when hurt
#   12 Hive Mother  hovers at range: broods runners, mortar barrages, spit fans
#   13 Lancer Prime sweeping beam (twin beams when hurt), blinks away and fires a telegraphed fan
#   14 Overseer     three phases built from all of the above plus the Warden's charge and radial burst

const Data = preload("res://scripts/data.gd")

static func handles(e) -> bool:
	return e.enemy_id in [6,7,8,9] or (e.boss and e.enemy_id!=5)

static func think(e, delta: float, to: Vector3, dist: float) -> void:
	match e.enemy_id:
		6: _bomber(e,delta,dist)
		7: _mortar(e,dist)
		8: _lancer(e,delta,to,dist)
		9: _medic(e,dist)
		_: _boss(e,delta,dist)

# Walk toward (or away from) the target with wall avoidance and crowd separation, like the original robots.
static func steer(e, desired: Vector3) -> void:
	e.last_move=desired
	e._navigate(desired)
	e.last_move=(e.last_move+e.separation_dir*.7).normalized() if e.last_move.length_squared()>.01 else e.separation_dir

# Keep between near and far from the target.
static func keep_range(e, dist: float, near: float, far: float) -> void:
	if dist>far: steer(e,e.aim)
	elif dist<near: steer(e,-e.aim)
	else: steer(e,Vector3.ZERO)

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x,0,v.z)

# ---------------------------------------------------------------- common robots
static func _bomber(e, delta: float, dist: float) -> void:
	var g=e.game
	if e.ai.has("fuse"):
		e.last_move=Vector3.ZERO
		e.ai.fuse-=delta
		var on: bool=int(e.ai.fuse*14.0)%2==0
		e._set_flash(on); e.hit_flash=0.0
		if e.ai.fuse<=0:
			e.ai["self_destruct"]=true
			g.blast(e.global_position,2.6,e.damage,e,Color("ffb000"),0)  # hits the fighters
			g.hurt(e,99999.0,null,e.global_position,"explosive")
		return
	steer(e,e.aim)
	if dist<1.7:
		e.ai["fuse"]=.6
		g.play_sfx("windup"); g.flash(e.global_position+Vector3.UP*1.2,Color("ffb000"),.6)

static func _mortar(e, dist: float) -> void:
	var g=e.game
	if e.windup>0: return
	keep_range(e,dist,8.0,14.0)
	if e.attack_timer<=0 and dist<17.0:
		e.attack_timer=e.cadence
		var aim_at: Vector3=e.target.global_position+e.target.velocity*.5  # leads a moving fighter a little
		g.lob_shell(e,aim_at,e.damage,2.2,Color("ffd24a"))

static func _lancer(e, delta: float, to: Vector3, dist: float) -> void:
	var g=e.game
	if e.ai.has("charge"):
		e.last_move=Vector3.ZERO
		e.aim=e.ai.dir
		e.ai.charge-=delta
		if e.ai.charge<=0:
			g.enemy_beam(e,e.ai.dir,e.damage,Color("4ad8ff"))
			e.ai.erase("charge")
		return
	keep_range(e,dist,7.0,13.0)
	if e.attack_timer<=0 and dist<15.0 and g.line_of_sight(e.global_position,e.target.global_position):
		e.attack_timer=e.cadence
		var dir:=flat(to).normalized()
		e.ai["charge"]=1.0; e.ai["dir"]=dir
		g.telegraph_line(e,dir,26.0,1.0)

static func _medic(e, dist: float) -> void:
	var g=e.game
	# stay with the pack, away from the fighters
	var pack:=Vector3.ZERO; var n:=0
	for o in g.enemies:
		if o==e or not is_instance_valid(o) or o.dead: continue
		if o.global_position.distance_to(e.global_position)<12.0: pack+=o.global_position; n+=1
	var desired: Vector3=-e.aim if dist<7.0 else Vector3.ZERO
	if n>0 and dist>=7.0:
		var v:=flat(pack/n-e.global_position)
		if v.length()>2.5: desired=v.normalized()
	steer(e,desired)
	if e.attack_timer<=0:
		e.attack_timer=e.cadence
		var healed:=0
		for o in g.enemies:
			if o==e or not is_instance_valid(o) or o.dead or o.hp>=o.max_hp: continue
			if o.global_position.distance_to(e.global_position)>6.0: continue
			o.hp=minf(o.max_hp,o.hp+o.max_hp*(.03 if o.boss else .25)); o._update_bar()
			g._beam(e.global_position+Vector3.UP*1.0,o.global_position+Vector3.UP*.8,Color("3aff9a"),.05,.35)
			g.flash(o.global_position+Vector3.UP*1.2,Color("3aff9a"),.35)
			healed+=1
		if healed>0: g.play_sfx("pickup")

# ---------------------------------------------------------------- bosses
# Shared frame: phase tracking (announced by game.boss_phase), an attack cooldown, and one attack running at a time
# (ai.busy counts down while it plays; ai.tick runs every frame meanwhile).
static func _boss(e, delta: float, dist: float) -> void:
	var g=e.game
	var phases: int=3 if e.enemy_id==14 else 2
	var frac: float=e.hp/e.max_hp
	var phase:=1
	if phases==3: phase=1+(1 if frac<.66 else 0)+(1 if frac<.33 else 0)
	elif frac<.5: phase=2
	if phase!=int(e.ai.get("phase",1)):
		e.ai["phase"]=phase
		g.boss_phase(e,phase)
	if e.enemy_id==12: e.move_lift=.5+sin(e.model_time*2.0)*.25  # the Hive Mother hovers
	if float(e.ai.get("busy",0.0))>0:
		e.ai.busy-=delta
		e.last_move=Vector3.ZERO
		var tick=e.ai.get("tick")
		if tick is Callable and (tick as Callable).is_valid(): tick.call(delta)
		if e.ai.busy<=0: e.ai.erase("tick")
		return
	var prefer: float={11:2.5,12:9.0,13:8.0,14:5.0}.get(e.enemy_id,4.0)
	keep_range(e,dist,prefer-1.5,prefer+1.5)
	e.ai["cool"]=float(e.ai.get("cool",2.0))-delta
	if e.ai.cool>0: return
	var n: int=int(e.ai.get("n",0)); e.ai["n"]=n+1
	var fast: float=[1.0,1.0,.72,.55][phase]
	match e.enemy_id:
		11:
			match n%3:
				0,2: _slam(e,5.0,3 if phase==1 else 5)
				1: _volley(e,3 if phase==1 else 5,e.target.global_position,1.5)
			if phase==2 and n%4==3: _summon(e,2,2)
			e.ai["cool"]=2.6*fast
		12:
			match n%3:
				0: _summon(e,1,4 if phase==1 else 6)
				1: _volley(e,6 if phase==1 else 10,e.target.global_position,4.0)
				2: _spit(e,7 if phase==1 else 11)
			if phase==2 and n%5==4: _summon(e,9,1)
			e.ai["cool"]=2.4*fast
		13:
			if n%2==0: _sweep(e,2 if phase==2 else 1)
			else: _blink_fan(e)
			e.ai["cool"]=2.2*fast
		14:
			match phase:
				1:
					match n%3:
						0: _charge(e)
						1: g.boss_burst(e)
						2: _summon(e,[4,8][n%2],2)
				2:
					match n%3:
						0: _sweep(e,1)
						1: _volley(e,8,e.target.global_position,4.0)
						2: _summon(e,6,3)
				3:
					match n%4:
						0: _slam(e,5.5,4)
						1: _sweep(e,2)
						2: _spit(e,13)
						3: _charge(e)
			e.ai["cool"]=2.0*fast

static func _charge(e) -> void:
	e.game.telegraph(e,.4)
	e.boss_charge_time=.55; e.boss_charge_dir=e.aim; e.boss_charge_hit=false

# Ground slam: a warning ring, then a shockwave around the boss and molten pools that linger.
static func _slam(e, radius: float, pools: int) -> void:
	var g=e.game
	var at: Vector3=flat(e.global_position)
	g.warn_ring(at,radius,.9,Color("ff5a2a"))
	g.play_sfx("windup")
	e.ai["busy"]=1.0
	var s:={"done":false}
	e.ai["tick"]=func(_delta: float) -> void:
		if s.done or e.ai.busy>.1: return
		s.done=true
		for h in g.heroes:
			if is_instance_valid(h) and not h.dead and not h.downed and flat(h.global_position-at).length()<radius:
				g.hurt(h,e.damage,e,at,"shock",7.0)
		g.fx._ring(at,Color("ff7a1a"),radius*1.2,.4); g.fx._ring(at,Color(1,.9,.6),radius*.6,.25)
		for i in range(16): g.fx.dust(at+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*randf_range(1.0,radius))
		g.play_sfx("explosion"); g.shake_amount=maxf(g.shake_amount,.6)
		for i in range(pools):
			var p: Vector3=at+Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()*randf_range(2.0,7.0)
			if g.arena.valid_spawn(p): g.hazard(p,1.6,5.0,14.0,Color("ff6a1a"))

# Lobbed shells scattered around a point (warning rings show where each lands).
static func _volley(e, count: int, around: Vector3, spread: float) -> void:
	var g=e.game
	g.play_sfx("grenade")
	for i in range(count):
		var p: Vector3=around+Vector3(randf_range(-1,1),0,randf_range(-1,1))*spread
		if i==0: p=around
		g.lob_shell(e,p,e.damage*.8,2.2,e.eye_color())

# A fan of slow orbs toward the target.
static func _spit(e, count: int) -> void:
	var g=e.game
	var spread:=1.1
	for i in range(count):
		var d: Vector3=e.aim.rotated(Vector3.UP,-spread*.5+spread*i/maxf(count-1,1))
		g.spawn_projectile(e,d,e.damage*.6,e.eye_color(),8.0)
	g.play_sfx("plasma")

# Brings in reinforcements at the boss's side (capped so the arena never floods).
static func _summon(e, id: int, count: int) -> void:
	var g=e.game
	for i in range(count):
		if g.enemies.size()>=32: return
		var p: Vector3=e.global_position+Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()*randf_range(2.0,3.5)
		if not g.arena.valid_spawn(p): continue
		g.spawn_enemy_at(id,p)

# Rotating beam: a short warning line, then it sweeps ~200 degrees (two opposite beams in the last phase).
static func _sweep(e, beams: int) -> void:
	var g=e.game
	var start: float=atan2(e.aim.x,e.aim.z)-1.75
	var dir0:=Vector3(sin(start),0,cos(start))
	for k in range(beams): g.telegraph_line(e,dir0.rotated(Vector3.UP,k*PI),26.0,.8)
	e.ai["busy"]=2.5
	var s:={"t":0.0,"hit":{}}
	e.ai["tick"]=func(delta: float) -> void:
		s.t+=delta
		if s.t<.8 or s.t>2.4: return
		var ang: float=start+3.5*(s.t-.8)/1.6
		for k in range(beams):
			var d:=Vector3(sin(ang+k*PI),0,cos(ang+k*PI))
			var from: Vector3=e.global_position+Vector3.UP*.88
			var r: Array=g.trace_shot(e,from,d,26.0,4,.15)
			for h in r[0]:
				var key: int=h[0].get_instance_id()
				if float(s.hit.get(key,-1.0))>s.t: continue
				s.hit[key]=s.t+.3
				g.hurt(h[0],e.damage*.55,e,from,"energy",2.0)
			var end: Vector3=r[1]
			g._beam(e.global_position+Vector3.UP*1.6,Vector3(end.x,1.0,end.z),e.eye_color(),.13,.06)
			g.fx.sparks(end,e.eye_color(),2,3.0)
		e.model.rotation.y=atan2(-sin(ang),-cos(ang))

# Blinks to a new spot, then fires a telegraphed three-beam fan.
static func _blink_fan(e) -> void:
	var g=e.game
	var target: Vector3=e.target.global_position
	for tries in range(12):
		var p: Vector3=target+Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()*randf_range(8.0,12.0)
		if g.arena.valid_spawn(p):
			g.fx._flash_mesh(e.global_position+Vector3.UP*1.4,e.eye_color(),2.0,.3)
			e.global_position=p
			g.fx._flash_mesh(p+Vector3.UP*1.4,e.eye_color(),2.0,.3)
			break
	var aim:=flat(target-e.global_position).normalized()
	e.aim=aim
	var dirs: Array=[aim.rotated(Vector3.UP,-.35),aim,aim.rotated(Vector3.UP,.35)]
	for d in dirs: g.telegraph_line(e,d,26.0,.75)
	g.play_sfx("windup")
	e.ai["busy"]=1.0
	var s:={"done":false}
	e.ai["tick"]=func(_delta: float) -> void:
		if s.done or e.ai.busy>.25: return
		s.done=true
		for d in dirs: g.enemy_beam(e,d,e.damage,e.eye_color())
