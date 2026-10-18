extends Node3D
# A shared, independent gunship pass. All timing uses game time: pause freezes the aircraft and its ordnance.

const Data = preload("res://scripts/data.gd")
const DURATION := 3.5
const BURSTS := 14
var game
var caller: SectorActor
var center := Vector3.ZERO
var direction := Vector3.FORWARD
var side := Vector3.RIGHT
var elapsed := 0.0
var bursts_fired := 0
var rockets_fired := false
var power := 1.0
var ship: Node3D
var marker: Node3D
var shadow: MeshInstance3D
var rockets: Array[Dictionary] = []
var _trail := 0.0
var _materials := {}
var _amber := Color("ffbf62")

func setup(g, source: SectorActor, point: Vector3, aim: Vector3) -> void:
	game=g; caller=source; center=point
	direction=Vector3(aim.x,0,aim.z).normalized()
	if direction.length_squared()<.01: direction=Vector3.FORWARD
	side=direction.cross(Vector3.UP).normalized()
	power=(1.0+Data.upgrade_value(source,"ability_damage")*.20)*(1.6 if source.buffs.has("overcharge") else 1.0)

func _ready() -> void:
	ship=Node3D.new(); add_child(ship); _make_ship()
	ship.basis=Basis.looking_at(direction,Vector3.UP)
	marker=Node3D.new(); add_child(marker); marker.position=center; marker.basis=Basis.looking_at(direction,Vector3.UP)
	# Broad corner brackets mark the strafe area; a moving aircraft and converging tracers explain the attack.
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			_box(marker,Vector3(x*1.9,.13,z*7),Vector3(.08,.03,1.1),_amber,2.0)
			_box(marker,Vector3(x*1.5,.13,z*7),Vector3(.8,.03,.08),_amber,2.0)
	shadow=MeshInstance3D.new(); var disc:=CylinderMesh.new(); disc.top_radius=2.8; disc.bottom_radius=2.8; disc.height=.01
	shadow.mesh=disc; var shade:=StandardMaterial3D.new(); shade.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_color=Color(0,0,0,.24); shadow.material_override=shade; shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow); shadow.scale=Vector3(1,1,.65)
	game.play_sfx("windup")
	_pose()

func _process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(game) or not is_instance_valid(caller): queue_free(); return
	if caller.is_queued_for_deletion(): queue_free(); return
	if game.state=="paused": return
	if game.state!="playing": queue_free(); return
	elapsed+=delta
	_pose()
	while bursts_fired<BURSTS and elapsed>=.85+bursts_fired*.09:
		_strafe(bursts_fired); bursts_fired+=1
	if elapsed>=1.32 and not rockets_fired:
		rockets_fired=true
		for sign in [-1.0,1.0]: _launch_rocket(center+side*sign*1.25,sign)
	for rocket in rockets:
		if rocket.done: continue
		var k:=clampf((elapsed-rocket.start)/.38,0,1)
		var p: Vector3=rocket.from.lerp(rocket.to,k)+Vector3.UP*sin(PI*k)*.7
		var node: Node3D=rocket.node; node.global_position=p
		if p.distance_to(rocket.to)>.01: node.look_at(rocket.to,Vector3.UP)
		game.fx.exhaust(p,-(rocket.to-rocket.from).normalized())
		if k>=1:
			rocket.done=true; node.visible=false
			game.fx.explosion(rocket.to,2.4,_amber); game.play_sfx("explosion")
			_damage(rocket.to,2.7,92.0,4.0)
			game.shake_amount=maxf(game.shake_amount,.32)
	_trail-=delta
	if _trail<=0:
		_trail=.025
		for sign in [-1.0,1.0]:
			var p: Vector3=ship.global_position+side*sign*.65-direction*1.6
			game.fx.glow.emit(p,-direction*2,.18,.12,Color(.5,2,3.5),0,2,0,0)
			game.fx.puff.emit(p,-direction*.7,.6,.1,Color(.55,.6,.7,.18),0,.2,2,0)
	if elapsed>=DURATION: queue_free()

func _pose() -> void:
	var k:=clampf((elapsed-.25)/2.95,0,1)
	ship.position=center+direction*lerpf(-24,25,k)+Vector3.UP*(5.3+sin(PI*k)*.4)
	ship.basis=Basis.looking_at(direction,Vector3.UP)*Basis(Vector3.FORWARD,sin(k*PI*2)*.1)
	shadow.position=Vector3(ship.position.x,.025,ship.position.z)
	shadow.basis=Basis.looking_at(direction,Vector3.UP).scaled(Vector3(1,1,.65))
	marker.visible=elapsed<2.15
	var pulse:=1.0+.03*sin(elapsed*9)
	marker.scale=Vector3(pulse,1,pulse)

func _strafe(index: int) -> void:
	var k:=float(index)/(BURSTS-1)
	var impact:=center+direction*lerpf(-6.5,6.5,k)
	impact.x=clampf(impact.x,-22,22); impact.z=clampf(impact.z,-17,17)
	for sign in [-1.0,1.0]:
		var p: Vector3=impact+side*sign*.9
		var muzzle: Vector3=ship.global_position+direction*1.6+side*sign*.65-Vector3.UP*.25
		game._beam(muzzle,p+Vector3.UP*.12,_amber,.035,.1)
		game.fx.muzzle(muzzle,(p-muzzle).normalized(),_amber,.65)
		game.fx.sparks(p+Vector3.UP*.12,_amber,5,3.5)
		if index%3==0: game.fx.dust(p)
		_damage(p,1.4,31.0,.8)
	if index%2==0: game.play_sfx("minigun")
	game.shake_amount=maxf(game.shake_amount,.09)

func _damage(point: Vector3, radius: float, amount: float, knock: float) -> void:
	for enemy: SectorActor in game.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead: continue
		var flat:=enemy.global_position-point; flat.y=0
		if flat.length()>=radius: continue
		var damage:=amount*power*lerpf(1.0,.55,flat.length()/radius)*(.4 if enemy.boss else 1.0)
		# Aerial kills keep their own staging instead of interrupting the visible aircraft with a weapon kill cam.
		game.hurt(enemy,damage,caller,point,"air_support",knock)

func _launch_rocket(point: Vector3, sign: float) -> void:
	point.x=clampf(point.x,-22,22); point.z=clampf(point.z,-17,17)
	var node:=Node3D.new(); add_child(node)
	var body:=_box(node,Vector3.ZERO,Vector3(.12,.12,.7),Color("c1c8cd")); body.rotation.z=PI/4
	_box(node,Vector3(0,0,.35),Vector3(.1,.1,.07),_amber,4.0)
	var origin:=ship.global_position+side*sign*1.2-Vector3.UP*.3
	node.global_position=origin
	rockets.append({"node":node,"from":origin,"to":point,"start":elapsed,"done":false})
	game.play_sfx("rocket")

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var part:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=dimensions; part.mesh=mesh
	var key:=color.to_html()+str(glow)
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.metallic=.65; mat.roughness=.4
		if glow>0: mat.emission_enabled=true; mat.emission=color; mat.emission_energy_multiplier=glow
		_materials[key]=mat
	part.material_override=_materials[key]; parent.add_child(part); part.position=at
	return part

func _make_ship() -> void:
	var armor:=Color("394653"); var dark:=Color("151e28"); var silver:=Color("8a9aa6")
	_box(ship,Vector3(0,0,.1),Vector3(.85,.55,3.3),armor)
	var nose:=_box(ship,Vector3(0,-.04,-1.9),Vector3(.6,.35,1.2),armor); nose.rotation.x=-.13
	_box(ship,Vector3(0,.29,-.95),Vector3(.55,.2,.8),Color("6bd6f1"),.7)
	for sign in [-1.0,1.0]:
		var wing:=_box(ship,Vector3(sign*1.6,-.05,.05),Vector3(2.8,.13,.8),armor); wing.rotation.y=sign*.27
		var tail:=_box(ship,Vector3(sign*.7,.12,1.55),Vector3(1.4,.12,.5),silver); tail.rotation.y=sign*.2
		var fin:=_box(ship,Vector3(sign*.55,.5,1.45),Vector3(.1,.8,.7),armor); fin.rotation.z=sign*-.25
		_box(ship,Vector3(sign*.65,-.05,.7),Vector3(.42,.42,1.65),dark)
		_box(ship,Vector3(sign*.65,-.05,1.56),Vector3(.32,.3,.07),Color("62ccff"),3.5)
		_box(ship,Vector3(sign*.65,-.3,-1.15),Vector3(.12,.12,1.2),dark)
		_box(ship,Vector3(sign*2.25,-.18,.15),Vector3(.2,.22,1.25),dark)
		_box(ship,Vector3(sign*2.3,.04,-.3),Vector3(.3,.08,.22),_amber,1.8)
