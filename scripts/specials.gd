extends RefCounted
# Special moves (right click / left trigger): one crowd-clearing move per operative. Each is a short timeline on the
# actor (actor.move_at events plus an optional per-frame actor.move_tick), run on game time, so hitstop slows it
# and pause stops it. The fighter is invulnerable through the committed part of every move.
#   0 Magnus  BULLET HURRICANE  two full turns with the minigun firing all round, then a ground-slam shockwave
#   1 Albert  HUNDRED CUTS      blinks between up to 6 robots marking each, chiburi, then they all split at once
#             KAITEN-GIRI       with 3+ robots within reach: a 360 degree plasma whirlwind instead
#   2 Theo    DEAD EYE          time slows, up to 8 robots are marked, then a crit for each in quick succession
#   3 Iris    HALO ARRAY        a jump and two star volleys of piercing rail beams
#   4 Seren   SINGULARITY       a black hole at the aim point pulls robots together, then collapses into arc lightning
#   5 Nadia   ORBITAL LANCE     paints a lane with the laser; a barrage of strikes runs down it

const Data = preload("res://scripts/data.gd")
const BOSS_SCALE := .4  # specials clear crowds; they do not delete the Warden

static func start(a) -> void:
	a.move_t=0.0; a.move_events.clear(); a.move_lock=true
	if a.weapon!=0: a.set_weapon(0)  # every move is performed with the signature weapon
	match a.hero_id:
		0: _hurricane(a)
		1:
			if crowd(a.game,a.global_position,3.4)>=3: _kaiten(a)
			else: _hundred_cuts(a)
		2: _dead_eye(a)
		3: _halo(a)
		4: _singularity(a)
		5: _orbital(a)
	a.move_events.sort_custom(func(x,y): return x[0]<y[0])

# ---------------------------------------------------------------- helpers
static func power(a) -> float:
	return (1.0+Data.upgrade_value(a,"ability_damage")*.20)*(1.6 if a.buffs.has("overcharge") else 1.0)

static func hit(a, e, amount: float, type: String, knock: float, at := Vector3.INF, crit := false) -> void:
	if not is_instance_valid(e) or e.dead: return
	if e.boss: amount*=BOSS_SCALE
	a.game.hurt(e,amount,a,a.global_position if at==Vector3.INF else at,type,knock,crit)

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x,0,v.z)

# Live robots within radius of pos, nearest first.
static func nearest(a, pos: Vector3, radius: float, count: int, sight := true) -> Array:
	var found: Array=[]
	for e in a.game.enemies:
		if not is_instance_valid(e) or e.dead: continue
		var d: float=flat(e.global_position-pos).length()
		if d<=radius and (not sight or a.game.line_of_sight(pos,e.global_position)): found.append([d,e])
	found.sort_custom(func(x,y): return x[0]<y[0])
	return found.slice(0,count).map(func(f): return f[1])

static func crowd(game, pos: Vector3, radius: float) -> int:
	var n:=0
	for e in game.enemies:
		if is_instance_valid(e) and not e.dead and flat(e.global_position-pos).length()<=radius: n+=1
	return n

# Turn the body to d at once (the move steers the model itself while move_steer is on).
static func face(a, d: Vector3) -> void:
	d=flat(d)
	if d.length_squared()<.001: return
	a.aim=d.normalized(); a.model.rotation.y=atan2(-d.x,-d.z)

static func tag(a, text: String) -> void:
	a.game.ui.weapon_tag(a,text,Data.COLORS[a.hero_id])

static func _glow_mat(c: Color, alpha: float, energy := 2.5) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color=Color(c.r*energy,c.g*energy,c.b*energy,alpha); m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

# ---------------------------------------------------------------- 0 Magnus: Bullet Hurricane
static func _hurricane(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=Data.COLORS[0]
	var w: Dictionary=a.loadout[0]
	var s:={"yaw":a.model.rotation.y,"sfx":0.0}
	tag(a,"BULLET HURRICANE")
	a.move_end=2.3; a.invulnerable=2.4; a.move_steer=true
	g.play_sfx("windup"); a._play_anim("special",.35)
	g.fx._ring(a.global_position,c,2.2,.3)
	a.move_tick=func(delta: float) -> void:
		if a.move_t<.15 or a.move_t>1.95: return
		s.yaw+=delta*7.0  # two full turns
		a.model.rotation.y=s.yaw
		var d:=Vector3(-sin(s.yaw),0,-cos(s.yaw))
		a.aim=d; a.spin_speed=38.0
		var muzzle: Vector3=a.muzzle_position()
		for k in range(2):
			var dir:=d.rotated(Vector3.UP,randf_range(-.08,.08))
			var start: Vector3=a.global_position+Vector3.UP*.88+dir*.4
			var r: Array=g.trace_shot(a,start,dir,15.0,2)
			for h in r[0]:
				hit(a,h[0],a.damage*.9*mul,"kinetic",.9,h[1]-dir*2.0)
				g.fx.sparks(h[1],Color("ffcf7a"),3,3.5)
			var end: Vector3=r[1]; end.y=muzzle.y
			g._beam(muzzle,end,w.color,.03,.05)
		s.sfx-=delta
		if s.sfx<=0:
			s.sfx=.06; g.play_sfx("minigun"); g.fx.muzzle(muzzle,d,w.color,1.2); g.fx.shell(muzzle-d*.5,d)
		g.shake_amount=maxf(g.shake_amount,.12)
	var slam:=func() -> void:
		var p: Vector3=a.global_position
		for e in nearest(a,p,4.8,99,false): hit(a,e,a.damage*5.0*mul,"explosive",7.0,p)
		g.fx._flash_mesh(p+Vector3.UP*.5,c,3.0,.25)
		g.fx._ring(p,c,5.5,.4); g.fx._ring(p,Color(1,1,1),3.0,.25)
		for i in range(20): g.fx.dust(p+Vector3(cos(i*TAU/20),0,sin(i*TAU/20))*randf_range(.8,3.5))
		g.play_sfx("explosion"); g.shake_amount=maxf(g.shake_amount,.6); g.hitstop(.12)
		a._play_anim("special",.3); a.move_steer=false
	a.move_at(2.0,slam)

# ---------------------------------------------------------------- 1 Albert: Hundred Cuts / Kaiten-giri
static func _hundred_cuts(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=a.loadout[0].color
	var marks: Array=nearest(a,a.global_position,9.0,6)
	if marks.is_empty(): _iai_dash(a); return
	tag(a,"HUNDRED CUTS")
	a.move_steer=true
	g.hitstop(.35); g.play_sfx("windup"); a._play_anim("special",.3)
	var step:=.11
	for i in range(marks.size()):
		var blink:=func() -> void:
			var e=marks[i]
			if not is_instance_valid(e) or e.dead: return
			var from: Vector3=a.global_position
			var d:=flat(e.global_position-from)
			var dir: Vector3=d.normalized() if d.length()>.1 else a.aim
			var to: Vector3=e.global_position+dir*1.0  # cut straight through, land on the far side
			if not g.arena.valid_spawn(to): to=e.global_position-dir*1.0
			if not g.arena.valid_spawn(to): to=from
			to.y=from.y
			g._beam(from+Vector3.UP*.9,to+Vector3.UP*.9,c,.07,.3)  # afterimage streak
			for k in range(4): g.fx.trail(from.lerp(to,k/4.0)+Vector3.UP*.9,Color(c.r,c.g,c.b,.5),.8)
			a.global_position=to
			face(a,dir)
			a._play_anim("slash_%d" % (i%3+1))
			var chest: Vector3=e.global_position+Vector3.UP*.9
			g.fx.slash(chest,dir,1.3,c); g.fx.sparks(chest,c,8,4.5)
			g.flash(e.global_position+Vector3.UP*1.7,c,.9)
			e.slow_time=maxf(e.slow_time,1.5); e._set_flash(true); e.hit_flash=.5
			g.play_sfx("sword")
		a.move_at(.08+i*step,blink)
	var last: float=.08+marks.size()*step
	a.move_at(last+.05,func() -> void: a.flourish=0.0)  # chiburi: flick the blade clean
	var release:=func() -> void:
		for e in marks:
			if not is_instance_valid(e) or e.dead: continue
			hit(a,e,a.damage*3.4*mul,"energy",3.0,e.global_position-a.aim)
			g.fx.slash(e.global_position+Vector3.UP*.9,Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized(),1.0,c)
		g.play_sfx("blade_hit"); g.shake_amount=maxf(g.shake_amount,.4); g.hitstop(.18)
		a.move_steer=false
	a.move_at(last+.4,release)
	a.move_end=last+.5; a.invulnerable=a.move_end+.2

# No robot in reach: the old lunge, a straight dash and one wide cut.
static func _iai_dash(a) -> void:
	var g=a.game; var mul:=power(a)
	tag(a,"IAI DASH")
	a.move_end=.2; a.invulnerable=.3
	var dash:=func() -> void:
		for i in range(5):
			var next: Vector3=a.global_position+a.aim*.68
			if not g.arena.valid_spawn(next): break
			a.global_position=next
		g.melee(a,3.0,a.damage*2.8*mul,2.0,Data.COLORS[1]); g.play_sfx("sword")
		a._play_anim("slash_3")
	a.move_at(0.0,dash)

static func _kaiten(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=a.loadout[0].color
	tag(a,"KAITEN-GIRI")
	a.move_steer=true; a.invulnerable=.9; a.move_end=.75
	var s:={"yaw":a.model.rotation.y,"prev":PackedVector3Array()}
	g.play_sfx("sword"); a._play_anim("slash_1")
	a.move_tick=func(delta: float) -> void:
		if a.move_t>=.6: s.prev=PackedVector3Array(); return
		s.yaw+=delta*21.0  # two full turns
		a.model.rotation.y=s.yaw; a.aim=Vector3(-sin(s.yaw),0,-cos(s.yaw))
		if a.weapon_nodes.is_empty() or not is_instance_valid(a.weapon_nodes[0]): return
		var tip: Vector3=a.muzzle_position()
		var hilt: Vector3=a.weapon_nodes[0].global_position.lerp(tip,.18)
		if s.prev.size()==2: g.fx.blade_quad(s.prev[0],s.prev[1],hilt,tip,c)
		s.prev=PackedVector3Array([hilt,tip])
		g.fx.ember(tip,c)
	for t in [.15,.45]:
		var pulse:=func() -> void:
			var p: Vector3=a.global_position
			for e in nearest(a,p,3.9,99,false): hit(a,e,a.damage*1.8*mul,"energy",4.5,p)
			for k in range(3): g.fx.slash(p+Vector3.UP*.9,a.aim.rotated(Vector3.UP,k*TAU/3),3.4,c)
			g.play_sfx("blade_hit"); g.shake_amount=maxf(g.shake_amount,.3)
			a._play_anim("slash_2" if t<.3 else "slash_3")
		a.move_at(t,pulse)
	var finish:=func() -> void:
		g.fx._ring(a.global_position,c,4.4,.3); g.hitstop(.1); a.move_steer=false
	a.move_at(.62,finish)

# ---------------------------------------------------------------- 2 Theo: Dead Eye
static func _dead_eye(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=a.loadout[0].color
	var marks: Array=nearest(a,a.global_position,20.0,8)
	var red:=Color("ff3a3a")
	tag(a,"DEAD EYE")
	a.move_steer=true
	g.hitstop(.55); g.play_sfx("windup")
	var n: int=maxi(marks.size(),3)
	var gap:=.09
	a.move_end=.22+n*gap+.2
	a.shield_time=a.move_end+1.0; a.shield_health=60.0*mul  # a short barrier while he stands and shoots
	for i in range(marks.size()):
		g.flash(marks[i].global_position+Vector3.UP*2.1,red,.3+i*gap)
		g.fx._ring(marks[i].global_position,red,1.1,.3)
	for i in range(n):
		var shot:=func() -> void:
			var e=marks[i] if i<marks.size() else null
			if not is_instance_valid(e) or e.dead:
				var left: Array=nearest(a,a.global_position,20.0,1)
				e=left[0] if not left.is_empty() else null
			var dir: Vector3=a.aim.rotated(Vector3.UP,(i-1)*.25)
			if e!=null: dir=flat(e.global_position-a.global_position).normalized()
			face(a,dir)
			var muzzle: Vector3=a.muzzle_position()
			var r: Array=g.trace_shot(a,a.global_position+Vector3.UP*.88,dir,22.0,1)
			for h in r[0]:
				hit(a,h[0],a.damage*2.6*mul,"kinetic",2.0,h[1]-dir,true)
				g.fx.sparks(h[1],Color("ffcf7a"),8,4.5)
			var end: Vector3=r[1]; end.y=muzzle.y
			g._beam(muzzle,end,c,.05,.1); g.fx.muzzle(muzzle,dir,c,1.5); g.fx.shell(muzzle-dir*.5,dir)
			g.play_sfx("pistol"); a._play_anim("attack"); a.recoil_kick=.12
		a.move_at(.22+i*gap,shot)
	a.move_at(a.move_end-.05,func() -> void: a.move_steer=false)

# ---------------------------------------------------------------- 3 Iris: Halo Array
static func _halo(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=a.loadout[0].color
	tag(a,"HALO ARRAY")
	a.move_end=1.0; a.invulnerable=1.1
	g.play_sfx("windup"); a._play_anim("special",.35)
	a.move_tick=func(_delta: float) -> void:
		a.move_lift=sin(PI*clampf(a.move_t/.95,0,1))*1.1
		if a.move_t<.4: g.fx.charge_orb(a.global_position+Vector3.UP*(1.3+a.move_lift),a.move_t/.4,c)
	var volley:=func(offset: float, scale: float) -> void:
		var o: Vector3=a.global_position+Vector3.UP*(1.4+a.move_lift)
		var base: float=a.model.rotation.y+offset
		for k in range(8):
			var dir:=Vector3(sin(base+k*TAU/8),0,cos(base+k*TAU/8))
			var r: Array=g.trace_shot(a,a.global_position+Vector3.UP*.88,dir,30.0,999,.3)
			for h in r[0]: hit(a,h[0],a.damage*1.5*mul*scale,"energy",2.5,h[1]-dir)
			var end: Vector3=r[1]
			g.fx.rail_beam(o,Vector3(end.x,1.0,end.z),c); g.fx.sparks(end,c,6,5.0)
		g.fx._ring(a.global_position,c,4.0,.3); g.play_sfx("rail"); g.shake_amount=maxf(g.shake_amount,.35)
	var first:=func() -> void:
		volley.call(0.0,1.0)
		g.hitstop(.15)
	var second:=func() -> void:
		volley.call(PI/8,.6)  # offset half a step to fill the gaps
	a.move_at(.4,first)
	a.move_at(.62,second)

# ---------------------------------------------------------------- 4 Seren: Singularity
static func _singularity(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=a.loadout[0].color
	tag(a,"SINGULARITY")
	var center: Vector3=a.aim_point
	if a.input_id==-1 and is_instance_valid(a.target): center=a.target.global_position
	var v:=flat(center-a.global_position)
	if v.length()<2.0: v=a.aim*5.0
	elif v.length()>11.0: v=v.normalized()*11.0
	center=flat(a.global_position+v)
	if not g.arena.valid_spawn(center): center=flat(a.global_position+a.aim*3.0)
	var top: Vector3=center+Vector3.UP*1.2
	a.invulnerable=.4; a.move_end=2.55
	# the orb: a dark core in a violet halo
	var orb:=MeshInstance3D.new(); var core:=SphereMesh.new(); core.radius=.42; core.height=.84; orb.mesh=core
	var core_mat:=StandardMaterial3D.new(); core_mat.albedo_color=Color("07020c"); core_mat.emission_enabled=true; core_mat.emission=c; core_mat.emission_energy_multiplier=.35
	orb.material_override=core_mat; orb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo:=MeshInstance3D.new(); var shell:=SphereMesh.new(); shell.radius=.85; shell.height=1.7; halo.mesh=shell
	var halo_mat:=_glow_mat(c,.55,3.5); halo_mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD; halo.material_override=halo_mat
	halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; orb.add_child(halo)
	# a glowing swirl on the floor under the hole, shown once it lands, so the pull zone reads from above
	var disc:=MeshInstance3D.new(); var plate:=CylinderMesh.new(); plate.top_radius=1.0; plate.bottom_radius=1.0; plate.height=.01; plate.radial_segments=32
	disc.mesh=plate; var disc_mat:=_glow_mat(c,.18,1.6); disc_mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD; disc.material_override=disc_mat
	disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; disc.position.y=-1.15; disc.visible=false; orb.add_child(disc)
	g.add_child(orb); orb.add_to_group("transient"); orb.global_position=a.muzzle_position()
	var from: Vector3=orb.global_position
	# props sit in a shared dict: a lambda that captures a node directly errors once the node is freed
	var s:={"dmg":.25,"orb":orb}
	a.move_cleanup=func() -> void:
		if is_instance_valid(s.orb): s.orb.queue_free()
	a._play_anim("cast",.35); g.play_sfx("plasma")
	a.move_tick=func(delta: float) -> void:
		if not is_instance_valid(s.orb): return
		var ball: MeshInstance3D=s.orb; var glow: MeshInstance3D=ball.get_child(0); var floor_disc: MeshInstance3D=ball.get_child(1)
		var t: float=a.move_t
		if t<.3:
			ball.global_position=from.lerp(top,t/.3)+Vector3.UP*sin(PI*t/.3)*1.2
			return
		if t>=2.3: return
		ball.global_position=top
		ball.scale=Vector3.ONE*(1.0+.15*sin(t*30.0))
		glow.scale=Vector3.ONE*(1.0+.25*sin(t*13.0))
		floor_disc.visible=true
		floor_disc.scale=Vector3(1,1,1)*lerpf(6.0,3.0,clampf((t-.3)/1.6,0,1))/ball.scale.x  # the zone tightens as it pulls
		floor_disc.rotation.y+=delta*6.0
		for e in g.enemies:
			if not is_instance_valid(e) or e.dead: continue
			var to:=flat(center-e.global_position)
			var dist:=to.length()
			if dist>7.0 or dist<.7: continue
			var pull:=(6.5*(1.0-dist/9.0)+1.5)*(.25 if e.boss else 1.0)
			e.move_and_collide(to/dist*minf(dist-.6,pull*delta))
			e.slow_time=maxf(e.slow_time,.3)
		s.dmg-=delta
		if s.dmg<=0:
			s.dmg=.25
			for e in nearest(a,center,3.5,99,false): hit(a,e,a.damage*.3*mul,"energy",0.0,center)
		for k in range(3):  # motes spiralling in
			var ang:=randf()*TAU; var r:=randf_range(2.0,6.5)
			var p:=center+Vector3(cos(ang),randf_range(.2,1.6),sin(ang))*Vector3(r,1,r)
			var tangent:=Vector3(-sin(ang),0,cos(ang))*2.0
			g.fx.glow.emit(p,(top-p)*2.2+tangent,.4,.05,c*3.0,0,0,0,0)
	a.move_at(.35,func() -> void: a.move_lock=false)  # she keeps fighting while it pulls
	var collapse:=func() -> void:
		for e in nearest(a,center,6.0,10,false):
			var at: Vector3=e.global_position+Vector3.UP*.8
			var mid: Vector3=top.lerp(at,.5)+Vector3(randf_range(-.6,.6),randf_range(-.3,.3),randf_range(-.6,.6))
			g._beam(top,mid,Color("c99bff"),.06,.3); g._beam(mid,at,Color("c99bff"),.06,.3)
			hit(a,e,a.damage*3.4*mul,"energy",6.0,center)
		g.fx._flash_mesh(top,c,4.5,.35); g.fx._ring(center,c,6.5,.4); g.fx._ring(center,Color(1,1,1),3.5,.25)
		g.fx.sparks(top,c,30,8.0)
		g.play_sfx("explosion"); g.play_sfx("bolt"); g.shake_amount=maxf(g.shake_amount,.55); g.hitstop(.14)
		if is_instance_valid(s.orb): s.orb.queue_free()
	a.move_at(2.3,collapse)

# ---------------------------------------------------------------- 5 Nadia: Orbital Lance
static func _orbital(a) -> void:
	var g=a.game; var mul:=power(a); var c: Color=Data.COLORS[5]
	tag(a,"ORBITAL LANCE")
	var dir:=flat(a.aim).normalized()
	var start: Vector3=flat(a.global_position)+dir*1.5
	# the lane runs 18 m or to the arena edge
	var length:=18.0
	for axis in [[dir.x,start.x,22.5],[dir.z,start.z,17.5]]:
		if absf(axis[0])>.001: length=minf(length,((axis[2] if axis[0]>0 else -axis[2])-axis[1])/axis[0])
	length=maxf(length,2.0)
	a.invulnerable=.5; a.move_end=.85+10*.07+.3
	var strip:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.35,.02,1.0); strip.mesh=box
	var mat:=_glow_mat(Color(1,.2,.25),.6,2.0); mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD; strip.material_override=mat
	strip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(strip); strip.add_to_group("transient")
	strip.global_basis=Basis.looking_at(dir,Vector3.UP); strip.scale=Vector3(1,1,.01); strip.global_position=start+Vector3.UP*.06
	var s:={"strip":strip}
	a.move_cleanup=func() -> void:
		if is_instance_valid(s.strip): s.strip.queue_free()
	g.play_sfx("windup"); a._play_anim("special",.35)
	a.move_tick=func(_delta: float) -> void:
		if not is_instance_valid(s.strip): return
		var lane: MeshInstance3D=s.strip
		var k: float=clampf(a.move_t/.45,.01,1.0)  # the laser sweeps out to the end of the lane
		lane.scale=Vector3(1,1,length*k)
		lane.global_position=start+dir*length*k*.5+Vector3.UP*.06
		mat.albedo_color.a=.45+.35*sin(a.move_t*40.0)
	a.move_at(.45,func() -> void: a.move_lock=false)
	for i in range(10):
		var p: Vector3=start+dir*length*(i+.5)/10.0
		var strike:=func() -> void:
			g._beam(p+Vector3.UP*22.0,p,Color(1,.3,.35),.22,.25)
			g.fx.explosion(p,2.4,c)
			for e in nearest(a,p,2.6,99,false):
				var d: float=flat(e.global_position-p).length()
				hit(a,e,a.damage*.85*mul*lerpf(1.0,.5,d/2.6),"explosive",4.0,p)
			if i%2==0: g.play_sfx("explosion")
			g.shake_amount=maxf(g.shake_amount,.4)
			if i==0: g.hitstop(.1)
		a.move_at(.85+i*.07,strike)
