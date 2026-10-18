extends Node3D
# Three reusable-looking quad-rotors, each consumed by its final impact. Hovering never holds up a wave.
const Data = preload("res://scripts/data.gd")
const GUN_SECONDS := 5.0
const RAY_INTERVAL := .4
const DIVE_SPEED := 22.0
var game
var caller: SectorActor
var elapsed := 0.0
var power := 1.0
var drones: Array[Dictionary] = []
var shots := 0
var impacts := 0
var _materials := {}

func setup(g, source: SectorActor) -> void:
	game=g; caller=source
	power=(1.0+Data.upgrade_value(source,"ability_damage")*.20)*(1.6 if source.buffs.has("overcharge") else 1.0)

func _ready() -> void:
	for i in range(3):
		var body:=Node3D.new(); add_child(body)
		var rotors:=_build(body)
		drones.append({"body":body,"rotors":rotors,"target":null,"state":"escort","fire":.25+i*.12,"turn":i,"dive_time":0.0})
		body.global_position=_hover(i)
	game.play_sfx("windup")

func status() -> String:
	if elapsed<GUN_SECONDS: return "RAYS %.1fs" % (GUN_SECONDS-elapsed)
	for d in drones:
		if d.state=="dive": return "DIVING"
	return "ARMED / HOVER"

func attacking() -> bool:
	for d in drones:
		if d.state=="dive": return true
	return false

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(game) or not is_instance_valid(caller): queue_free(); return
	if caller.is_queued_for_deletion() or caller.dead: queue_free(); return
	# Upgrade screens preserve waiting drones for the next wave. New chapters/reset remove transient nodes.
	if game.state in ["paused","upgrade","briefing","debrief"]: return
	if game.state!="playing": queue_free(); return
	if is_instance_valid(game.killcam) and game.killcam.active: return
	elapsed+=delta
	var reserved: Array=[]
	for d in drones:
		if d.state=="dive" and _alive(d.target): reserved.append(d.target)
	for i in range(drones.size()):
		var d: Dictionary=drones[i]
		if d.state=="spent": continue
		var body: Node3D=d.body
		for rotor: Node3D in d.rotors: rotor.rotate_y(delta*65)
		if elapsed>=GUN_SECONDS:
			if d.state=="dive" and not _alive(d.target):
				d.state="escort"; d.target=null
			if d.state!="dive":
				d.target=_dive_target(body.global_position,reserved)
				if _alive(d.target):
					d.state="dive"; d.dive_time=0.0; reserved.append(d.target)
			if d.state=="dive":
				d.dive_time+=delta
				var goal: Vector3=_aim_at(d.target)
				# Rise above cover before the terminal dive; every frame homes on the surviving robot.
				var destination:=goal+Vector3.UP*4.5 if d.dive_time<.25 else goal
				var before:=body.global_position
				body.global_position=before.move_toward(destination,DIVE_SPEED*delta)
				_face(body,goal,delta)
				game.fx.glow.emit(before,Vector3.UP*.3,.2,.15,Color(3,1.0,.15),0,2,0,0)
				if body.global_position.distance_to(goal)<.45 and d.dive_time>=.25:
					_impact(d,goal)
				continue
		body.global_position=body.global_position.lerp(_hover(i),1.0-exp(-delta*7))
		if elapsed<GUN_SECONDS:
			d.fire-=delta
			if d.fire<=0:
				d.fire+=RAY_INTERVAL
				_ray(d)
			if _alive(d.target): _face(body,_aim_at(d.target),delta)
			else: _face(body,body.global_position+caller.aim,delta)
		else: _face(body,body.global_position+caller.aim,delta)
	if drones.all(func(d): return d.state=="spent"): queue_free()

func _alive(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.dead and game.enemies.has(enemy)

func _aim_at(enemy: SectorActor) -> Vector3:
	return enemy.global_position+Vector3.UP*maxf(.8,enemy.body_scale()*.7)

func _hover(index: int) -> Vector3:
	var angle:=TAU*float(index)/3.0+elapsed*.35
	var at: Vector3=caller.global_position+Vector3(cos(angle)*2.1,2.9+sin(elapsed*3+index)*.16,sin(angle)*2.1)
	at.x=clampf(at.x,-21,21); at.z=clampf(at.z,-16,16)
	return at

func _face(body: Node3D, point: Vector3, delta: float) -> void:
	var direction:=point-body.global_position
	if direction.length_squared()<.001: return
	# Keep the four rotors upright during the escort; pitch into the terminal dive.
	var flat:=Vector3(direction.x,0,direction.z)
	if flat.length_squared()>.001: body.rotation.y=lerp_angle(body.rotation.y,atan2(-flat.x,-flat.z),minf(1,delta*12))
	body.rotation.x=lerpf(body.rotation.x,clampf(atan2(direction.y,maxf(flat.length(),.01)),-.7,.7),minf(1,delta*8))

func _ray(d: Dictionary) -> void:
	var body: Node3D=d.body
	var origin:=body.global_position+body.global_basis*Vector3(0,-.13,-.62)
	var available: Array=[]
	for enemy: SectorActor in game.enemies:
		if not _alive(enemy): continue
		var q:=PhysicsRayQueryParameters3D.create(origin,_aim_at(enemy),1)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty(): available.append(enemy)
	if available.is_empty(): d.target=null; return
	# Cycle the whole visible crowd instead of having all three guns tunnel on its nearest robot.
	var enemy: SectorActor=available[int(d.turn)%available.size()]
	d.turn+=3; d.target=enemy
	var end:=_aim_at(enemy)
	game._beam(origin,end,Color("65f5ff"),.045,.12)
	game.fx.muzzle(origin,(end-origin).normalized(),Color("65f5ff"),.45)
	game.fx.sparks(end,Color("65f5ff"),4,2.0)
	game.play_sfx("bolt")
	shots+=1
	game.hurt(enemy,14.0*power*(.4 if enemy.boss else 1.0),caller,origin,"drone_ray",.15)

func _dive_target(at: Vector3, reserved: Array):
	var best=null; var distance:=INF
	for enemy: SectorActor in game.enemies:
		if not _alive(enemy): continue
		var score:=at.distance_squared_to(enemy.global_position)+(10000.0 if reserved.has(enemy) else 0.0)
		if score<distance: best=enemy; distance=score
	return best

func _impact(d: Dictionary, at: Vector3) -> void:
	# Mark the drone spent before damage: chain explosions may remove several other targets immediately.
	d.state="spent"; d.target=null; d.body.visible=false; impacts+=1
	game.fx.explosion(at,2.6,Color("ffbd62")); game.play_sfx("explosion")
	game.shake_amount=maxf(game.shake_amount,.25)
	for enemy: SectorActor in game.enemies.duplicate():
		if not _alive(enemy): continue
		var flat:=enemy.global_position-at; flat.y=0
		if flat.length()>2.8: continue
		var damage:=120.0*power*lerpf(1.0,.6,flat.length()/2.8)*(.4 if enemy.boss else 1.0)
		game.hurt(enemy,damage,caller,at,"drone_blast",3.0)

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var part:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; part.mesh=mesh
	var key:=color.to_html()+str(glow)
	if not _materials.has(key):
		var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.metallic=.55; mat.roughness=.55
		if glow>0: mat.emission_enabled=true; mat.emission=color; mat.emission_energy_multiplier=glow
		_materials[key]=mat
	part.material_override=_materials[key]; parent.add_child(part); part.position=at
	return part

func _build(body: Node3D) -> Array[Node3D]:
	# Reference: graphite armored cabin, amber panels, cyan front optic, four outboard cross rotors and twin guns.
	var armor:=Color("39494f"); var dark:=Color("172329"); var amber:=Color("d99b32")
	_box(body,Vector3.ZERO,Vector3(.64,.4,1.02),dark)
	_box(body,Vector3(0,.02,0),Vector3(.57,.36,.9),armor)
	var nose:=_box(body,Vector3(0,.12,-.4),Vector3(.48,.12,.3),armor); nose.rotation.x=-.35
	_box(body,Vector3(0,-.02,-.52),Vector3(.2,.18,.035),Color("39e6e5"),2.5)
	_box(body,Vector3(0,.235,.02),Vector3(.38,.05,.6),armor)
	_box(body,Vector3(0,.23,-.25),Vector3(.32,.04,.14),amber)
	for sign in [-1.0,1.0]:
		_box(body,Vector3(sign*.302,0,.05),Vector3(.035,.22,.3),amber)
		for n in range(3): _box(body,Vector3(sign*.312,.15,.1+n*.07),Vector3(.04,.035,.035),amber)
		_box(body,Vector3(sign*.16,-.23,-.4),Vector3(.1,.1,.5),dark)
		_box(body,Vector3(sign*.16,-.23,-.66),Vector3(.055,.055,.025),Color("65f5ff"),1.6)
	var rotors: Array[Node3D]=[]
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			_box(body,Vector3(x*.49,.02,z*.33),Vector3(.5,.09,.13),armor)
			_box(body,Vector3(x*.74,.02,z*.33),Vector3(.23,.29,.23),dark)
			_box(body,Vector3(x*.74,.04,z*.33),Vector3(.19,.26,.19),armor)
			var rotor:=Node3D.new(); body.add_child(rotor); rotor.position=Vector3(x*.74,.23,z*.33)
			_box(rotor,Vector3.ZERO,Vector3(.57,.025,.055),dark)
			_box(rotor,Vector3.ZERO,Vector3(.055,.025,.57),dark)
			_box(rotor,Vector3(0,.035,0),Vector3(.07,.055,.07),armor)
			rotors.append(rotor)
	return rotors
