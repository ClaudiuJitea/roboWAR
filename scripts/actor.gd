extends CharacterBody3D
class_name SectorActor

const Data = preload("res://scripts/data.gd")
const Specials = preload("res://scripts/specials.gd")
const Robots = preload("res://scripts/robots.gd")
const DroneSwarmScript = preload("res://scripts/drone_swarm.gd")
const AirSupportScript = preload("res://scripts/air_support.gd")
var game: Node
var hero := true
var hero_id := 0
var enemy_id := 0
var boss := false          # campaign / survival boss: phases, HUD health bar, name card
var elite := false         # gold-trimmed robot: tougher, always drops a power-up
var hit_radius := .46      # body radius for shot tests (Data.ENEMIES hit)
var ai := {}               # per-robot behaviour state (robots.gd)
var buffs := {}            # fighter power-ups still running: name -> seconds left
var input_id := 0 # 0 keyboard, 1 first pad, 2 second pad, -1 AI
var team := 0
var hp := 100.0
var max_hp := 100.0
var speed := 5.0
var damage := 10.0
var cadence := .4
var special_base := 12.0
var attack_timer := 0.0
var special_timer := 0.0
var drone_timer := 0.0
var drone_swarm: Node3D
var _drone_held := false
var air_support_timer := 0.0
var _support_chord := false
var _special_held := false
var _special_wait := -1.0
var dodge_timer := 0.0
var dodge_time := 0.0
var invulnerable := 0.0
var heat := 0.0
var charge := 0.0
var shield_time := 0.0
var shield_health := 0.0
var downed_time := 0.0
var revive_progress := 0.0
var dead := false
var downed := false
var aim := Vector3.FORWARD
var aim_point := Vector3.ZERO  # world point the fighter aims at, at gun height
const GUN_HEIGHT := 1.4  # matches game.gd GUN_HEIGHT
var last_move := Vector3.ZERO
var target: SectorActor
var auto_target: SectorActor  # current auto-aim lock (game.auto_aim), null when off or nothing in reach
var upgrades := {}
var model: Node3D
var torso_mesh: MeshInstance3D  # robot body used to locate the blade's body-crossing cut
var anim: AnimationPlayer
var marker: MeshInstance3D
var muzzle: Node3D
var shield_visual: MeshInstance3D
var bar: Label3D
var ai_tick := 0.0
var windup := 0.0
var attack_state := 0
var sidestep := 1.0
var nav_timer := 0.0
var nav_dir := Vector3.ZERO
var slow_time := 0.0
var model_time := 0.0
var gait_phase := 0.0
var enemy_arms: Array[Node3D] = []
var enemy_legs: Array[Node3D] = []
var combo := 0
var action_anim_time := 0.0
var boss_charge_time := 0.0
var boss_charge_dir := Vector3.ZERO
var boss_charge_hit := false
var separation_dir := Vector3.ZERO
var weapon := 0
var slot := 0  # 0 = you / P1, 1 = partner / P2 (drives ring and HUD colour)
var ammo: Array[int] = []
var loadout: Array = []  # signature weapon first, then the shared guns
var spin_nodes: Array[Node3D] = []
var spin_speed := 0.0
var stance := "gun"
const STANCES := {"gun":"aim","blade":"aim_blade","sniper":"aim_sniper","rail":"aim_rail","pistol":"aim_pistol","heavy":"aim_heavy","cast":"aim_cast","shoulder":"aim_shoulder","launcher":"aim_launcher"}
var laser: MeshInstance3D
var laser_dot: MeshInstance3D
var bolt_timer := -1.0
var swing_time := 0.0       # >0 while a blade swing is in motion (drives the blade trail)
var swing_impact := -1.0    # countdown to the strike frame, when damage lands
var swing_power := 1.0
var body_node: Node3D
var flourish := -1.0       # time into a blade twirl (<0 = none)
var idle_time := 0.0
var melee_damage := 0.0
var last_swing := -10.0
var trail_prev := PackedVector3Array()
var cutscene := false      # kill cam replay: input and AI paused, the cut does no damage (the kill cam lands it)
var reload := 0.0
var reload_total := 0.0
var hit_flash := 0.0
var tree: AnimationTree
var loco_blend := Vector2.ZERO
var recoil_kick := 0.0
var hit_tilt := 0.0
var step_sign := 1.0
const UPPER_BONES := ["spine","chest","neck","head","L_shoulder","R_shoulder","L_upper_arm","L_forearm","L_hand","R_upper_arm","R_forearm","R_hand","weapon","barrels"]
var flash_meshes: Array[MeshInstance3D] = []
static var _hit_mat: StandardMaterial3D
var weapon_nodes: Array[Node3D] = []
var weapon_muzzles: Array[Node3D] = []
var weapon_loads: Array[Node3D] = []  # a launcher's loaded round (Blender "Load_<id>"), hidden once it is fired
var blade_markers: Array[Node3D] = []  # ordered samples along the katana's curved cutting edge
var pad_bumpers := [false, false]
var last_damage_type := "kinetic"
var last_hit_from := Vector3.ZERO
var last_hit_color := Color.WHITE
var last_attacker: SectorActor  # who landed the latest hit (kill cam framing)
var last_hit_heavy := false
# Special move in progress (specials.gd): timed events plus a per-frame tick, on game time.
var move_t := -1.0          # seconds into the move, <0 when none is running
var move_end := 0.0
var move_events: Array = [] # [time, Callable], sorted by time
var move_tick := Callable()
var move_cleanup := Callable()  # frees the move's scene props if it ends early
var move_lock := false      # input and AI paused: the fighter only does what the move says
var move_steer := false     # the move turns the body itself (spins, blinks, aimed shots)
var move_lift := 0.0        # extra model height (Nova's jump)
const WEAPON_KIT := "res://assets/models/weapons.glb"
static var _weapon_kit: PackedScene

func setup(g: Node, is_hero: bool, index: int, owner: int) -> void:
	game = g
	hero = is_hero
	hero_id = index if is_hero else 0
	enemy_id = index if not is_hero else 0
	input_id = owner
	team = 0 if hero else 1
	var spec: Dictionary=Data.ENEMIES[index] if not hero else {}
	boss = spec.get("boss",false)
	max_hp = Data.HP[index] if hero else spec.hp
	hp = max_hp
	speed = Data.SPEED[index] if hero else spec.speed
	damage = Data.DAMAGE[index] if hero else spec.damage
	cadence = Data.RATE[index] if hero else spec.cadence
	hit_radius = .42 if hero else spec.hit
	special_base = Data.SPECIAL_CD[index] if hero else 0.0
	weapon = 0
	loadout = Data.loadout(index) if hero else []
	for w in loadout: ammo.append(int(w.mag))
	name = (Data.HEROES[index] if hero else spec.name) + "_" + str(get_instance_id())

# Elite robot (set before it enters the tree): more plating and punch, a little bigger, gold trim.
func make_elite() -> void:
	elite=true; max_hp*=2.2; hp=max_hp; damage*=1.3; hit_radius*=1.12

# Relative size of a robot against a grunt (bosses are ~2.2x).
func body_scale() -> float:
	return float(Data.ENEMIES[enemy_id].scale)*(1.12 if elite else 1.0)

func eye_color() -> Color:
	return Data.ENEMIES[enemy_id].get("eye",Color("ff5a2c"))

func _ready() -> void:
	collision_layer = 2 if hero else 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = .34 if hero else (.33*body_scale() if boss else .29)
	shape.height = 1.55 if hero else (1.16*body_scale() if boss else 1.1)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.height*.5
	add_child(col)
	if hero:
		var path: String = "res://assets/models/" + Data.HEROES[hero_id].to_lower() + ".glb"
		model = Node3D.new(); add_child(model)
		if ResourceLoader.exists(path):
			# Blender's front (-Y) exports facing +Z; turn it so the fighter faces -Z like everything else.
			var body: Node3D = load(path).instantiate()
			body.rotation.y = PI
			model.add_child(body)
			body_node = body
		model.scale=Vector3.ONE*1.25
		anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		var grip:=model.find_child("Grip_*",true,false) as Node3D
		if grip: _mount_weapons(grip)
		if is_instance_valid(anim):
			for loop_name in ["idle","aim","aim_blade","aim_sniper","aim_rail","aim_pistol","aim_heavy","aim_cast","run","run_back","strafe_left","strafe_right","charge"]:
				if anim.has_animation(loop_name): anim.get_animation(loop_name).loop_mode=Animation.LOOP_LINEAR
			if anim.has_animation("aim") and anim.has_animation("run_back"): _setup_tree(); _apply_stance()
			else: anim.play("idle")
		_make_marker()
		_make_shield()  # Dead Eye's barrier and the Barrier power-up
	else:
		model = Node3D.new(); add_child(model)
		_make_enemy_visual()
	bar = Label3D.new()
	bar.font_size = 25
	bar.pixel_size = .009
	bar.position.y = 1.14*body_scale() if boss and not hero else 2.0
	bar.modulate = Color.WHITE if hero else Color("ffb2a3")
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(bar)
	_update_bar()

func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	if glow: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 2.0
	return m

const ENEMY_KIT := "res://assets/models/enemy_kit.glb"
static var _kit_meshes := {}

static func _kit_mesh(part_name: String) -> Mesh:
	if _kit_meshes.is_empty() and ResourceLoader.exists(ENEMY_KIT):
		var scene: Node = load(ENEMY_KIT).instantiate()
		for node in scene.find_children("*","MeshInstance3D",true,false):
			_kit_meshes[String(node.name)] = (node as MeshInstance3D).mesh
		scene.free()
	return _kit_meshes.get(part_name) as Mesh

func _part(pos: Vector3, size: Vector3, mat: Material, kit_name := "") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var kit := _kit_mesh(kit_name) if kit_name != "" else null
	if kit: mesh.mesh = kit
	else:
		var b := BoxMesh.new(); b.size=size; mesh.mesh=b; mesh.material_override=mat
	mesh.position=pos; model.add_child(mesh)
	return mesh

func _enemy_limb(pivot_pos: Vector3, part_offset: Vector3, size: Vector3, material: Material, kit_name: String) -> Node3D:
	var pivot := Node3D.new(); pivot.position=pivot_pos; model.add_child(pivot)
	var mesh := MeshInstance3D.new()
	var kit := _kit_mesh(kit_name)
	if kit: mesh.mesh = kit
	else:
		var box := BoxMesh.new(); box.size=size; mesh.mesh=box; mesh.material_override=material
	mesh.position=part_offset; pivot.add_child(mesh)
	return pivot

func _make_enemy_visual() -> void:
	model.scale=Vector3.ONE*body_scale()*1.25
	var dark := _mat(Color("25282d")); var joint := _mat(Color("121820")); var eye := _mat(Color("ff593b"),true)
	torso_mesh=_part(Vector3(0,.65,0),Vector3(.45,.54,.32),dark,"enemy_torso")
	_part(Vector3(0,1.06,0),Vector3(.46,.43,.43),dark,"enemy_head")
	if _kit_mesh("enemy_head") == null: _part(Vector3(0,1.02,-.224),Vector3(.30,.07,.045),eye)
	for s in [-1.0,1.0]:
		enemy_arms.append(_enemy_limb(Vector3(.35*s,.89,0),Vector3(0,-.22,0),Vector3(.17,.44,.22),joint,"enemy_arm"))
		var leg:=_enemy_limb(Vector3(.14*s,.52,0),Vector3(0,-.25,0),Vector3(.18,.50,.23),joint,"enemy_leg")
		var foot:=MeshInstance3D.new()
		var foot_kit := _kit_mesh("enemy_foot")
		if foot_kit: foot.mesh=foot_kit
		else:
			var foot_box:=BoxMesh.new(); foot_box.size=Vector3(.20,.15,.32); foot.mesh=foot_box; foot.material_override=dark
		foot.position=Vector3(0,-.44,-.10); leg.add_child(foot)
		enemy_legs.append(leg)
	if enemy_id==4:
		_part(Vector3(0,.59,-.32),Vector3(.60,.75,.12),_mat(Color("576273")),"enemy_shield")
	if enemy_id==3:
		_part(Vector3(.28,.64,-.32),Vector3(.17,.15,.51),_mat(Color("9b4234")),"enemy_gun")
	if enemy_id==5:
		_part(Vector3(0,1.38,0),Vector3(.55,.23,.52),_mat(Color("ba402e"),true),"enemy_crown")
	var spec: Dictionary=Data.ENEMIES[enemy_id]
	var glow:=_mat(eye_color(),true)
	match enemy_id:
		6:  # bomber: a glowing charge strapped to its back
			var bomb:=MeshInstance3D.new(); var sph:=SphereMesh.new(); sph.radius=.2; sph.height=.4; bomb.mesh=sph; bomb.material_override=glow
			bomb.position=Vector3(0,.78,.24); model.add_child(bomb)
		7:  # mortar: a tube over the shoulder
			_part(Vector3(.2,1.2,.08),Vector3(.16,.5,.16),_mat(Color("2b3326")))
			_part(Vector3(.2,1.47,.08),Vector3(.18,.05,.18),glow)
		8:  # lancer: a long rifle
			_part(Vector3(.28,.66,-.42),Vector3(.12,.12,.8),_mat(Color("1a2236")))
			_part(Vector3(.28,.66,-.84),Vector3(.07,.07,.07),glow)
		9:  # medic: a green cross on the chest and a beacon
			_part(Vector3(0,.7,-.18),Vector3(.24,.07,.02),glow); _part(Vector3(0,.7,-.18),Vector3(.07,.24,.02),glow)
			_part(Vector3(0,1.32,0),Vector3(.08,.12,.08),glow)
		10: # splitter: a glowing seam down the middle
			_part(Vector3(0,.82,-.165),Vector3(.04,.9,.03),glow)
		11: # forge titan: molten shoulder plates
			for side in [-1.0,1.0]: _part(Vector3(.36*side,1.0,0),Vector3(.24,.12,.3),glow)
		12: # hive mother: brood sacs
			for k in range(3): _part(Vector3(-.2+k*.2,.95,.2),Vector3(.15,.15,.15),glow)
		13: # lancer prime: crown and twin rifles
			_part(Vector3(0,1.36,0),Vector3(.5,.16,.48),glow)
			for side in [-1.0,1.0]: _part(Vector3(.32*side,.66,-.4),Vector3(.1,.1,.7),_mat(Color("1a2236")))
		14: # overseer: crown and a floating halo
			_part(Vector3(0,1.38,0),Vector3(.55,.23,.52),glow,"enemy_crown")
			var ring:=MeshInstance3D.new(); var t:=TorusMesh.new(); t.inner_radius=.42; t.outer_radius=.5; ring.mesh=t; ring.material_override=glow
			ring.position=Vector3(0,1.62,0); model.add_child(ring)
	if spec.has("body"): _tint(spec.body,eye_color())
	if elite:  # gold band across the chest and a gold crest
		var gold:=_mat(Data.ELITE_COLOR,true)
		_part(Vector3(0,.88,0),Vector3(.5,.06,.36),gold); _part(Vector3(0,1.31,0),Vector3(.26,.06,.3),gold)

# Recolours the shared kit parts: body surfaces toward the robot's colour, glowing surfaces (the eyes) to its eye colour.
static var _tints := {}
func _tint(body: Color, eye: Color) -> void:
	for m in model.find_children("*","MeshInstance3D",true,false):
		var mi: MeshInstance3D=m
		if mi.mesh==null or mi.material_override!=null: continue
		for i in range(mi.mesh.get_surface_count()):
			var src:=mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src==null: continue
			var key:="%s|%s|%s" % [src.get_instance_id(),body.to_html(),eye.to_html()]
			if not _tints.has(key):
				var mat:=src.duplicate() as StandardMaterial3D
				if mat.emission_enabled: mat.emission=eye; mat.albedo_color=eye
				else: mat.albedo_color=src.albedo_color.lerp(body,.85)
				_tints[key]=mat
			mi.set_surface_override_material(i,_tints[key])

# World position of the weapon tip (Blender "Muzzle_<Name>" marker); falls back to a point in front of the chest.
func muzzle_position() -> Vector3:
	if hero and weapon<weapon_muzzles.size() and is_instance_valid(weapon_muzzles[weapon]): return weapon_muzzles[weapon].global_position
	if is_instance_valid(muzzle): return muzzle.global_position
	return global_position+Vector3.UP*.88+aim*.58

func blade_edge_points() -> PackedVector3Array:
	var points:=PackedVector3Array()
	for marker in blade_markers: points.append(marker.global_position)
	if points.is_empty(): return points
	points.append(muzzle_position())
	return points

# Flat direction the current gun's barrel points (grip -> muzzle); ZERO when there is no mounted gun.
func barrel_dir() -> Vector3:
	if not hero or weapon>=weapon_nodes.size() or not is_instance_valid(weapon_nodes[weapon]) or weapon>=weapon_muzzles.size() or not is_instance_valid(weapon_muzzles[weapon]): return Vector3.ZERO
	var v:=weapon_muzzles[weapon].global_position-weapon_nodes[weapon].global_position; v.y=0
	return v.normalized() if v.length_squared()>.0001 else Vector3.ZERO

# Body yaw that lines the barrel up with the aim point. The gun sits off to the side of the body, so turning the
# body centre toward the cursor leaves the barrel pointing parallel to it while the shot (muzzle -> aim point)
# leaves at an angle; this turns a little further so the shot runs straight down the barrel.
func _facing_yaw() -> float:
	var yaw:=atan2(-aim.x,-aim.z)
	if not hero or loadout.is_empty() or loadout[weapon].kind=="melee" or aim_point==Vector3.ZERO: return yaw
	var barrel:=barrel_dir()
	if barrel==Vector3.ZERO: return yaw
	var fwd:=-model.global_transform.basis.z; fwd.y=0
	if fwd.length_squared()<.001: return yaw
	var body:=atan2(-fwd.x,-fwd.z)  # current world yaw of the model
	var tip:=muzzle_position()
	var m:=tip-global_position; m.y=0
	var to:=aim_point-global_position; to.y=0
	# barrel line in the body's own frame: its sideways offset from the body centre and its direction
	var b:=barrel.rotated(Vector3.UP,-body)
	var ml:=m.rotated(Vector3.UP,-body)
	var side:=ml-b*ml.dot(b)
	var d:=to.length()
	if d<side.length()+.6: return yaw  # cursor almost on top of the fighter: just face it
	var target_local:=side+b*sqrt(d*d-side.length_squared())
	var want:=atan2(-to.x,-to.z)-atan2(-target_local.x,-target_local.z)
	return model.rotation.y+angle_difference(body,want)

# Mounts every gun from weapons.glb on the fighter's Grip socket; only the current one is visible.
func _mount_weapons(grip: Node3D) -> void:
	if _weapon_kit==null and ResourceLoader.exists(WEAPON_KIT): _weapon_kit=load(WEAPON_KIT)
	if _weapon_kit==null: return
	var kit:=_weapon_kit.instantiate()
	for w in loadout:
		var node:=kit.find_child("W_"+w.id,true,false) as Node3D
		spin_nodes.append(null)
		if node==null: weapon_nodes.append(null); weapon_muzzles.append(null); weapon_loads.append(null); continue
		spin_nodes[-1]=node.find_child("Spin_*",true,false) as Node3D
		for n in [node]+node.find_children("*","",true,false): n.owner=null  # detach from the kit scene before reparenting
		node.get_parent().remove_child(node); grip.add_child(node); node.transform=Transform3D.IDENTITY
		weapon_nodes.append(node); weapon_muzzles.append(node.find_child("Muzzle_*",true,false) as Node3D)
		if w.kind=="melee":
			for sample in node.find_children("BladeEdge_*","Node3D",true,false): blade_markers.append(sample)
			blade_markers.sort_custom(func(a: Node3D,b: Node3D) -> bool: return a.name<b.name)
		weapon_loads.append(node.find_child("Load_*",true,false) as Node3D)
	kit.free()
	_show_weapon()
	_apply_stance()

# One-handed blades use the sheet's low side stance; everything else is shouldered.
func _apply_stance() -> void:
	if not is_instance_valid(tree) or loadout.is_empty(): return
	stance=String(loadout[weapon].get("stance","gun"))
	tree.set("parameters/stance/transition_request",stance)

# Laser pointer for scoped weapons: a beam from the muzzle to the aim point (the cursor on the floor, or the first
# robot / wall in the way) with a reticle there that spins slowly and snaps tighter when it locks onto a robot.
var reticle: Node3D
var reticle_ring: MeshInstance3D
var reticle_ticks: Array[MeshInstance3D] = []
var reticle_lock := 0.0
var reticle_spin := 0.0

func _laser_mat(alpha: float) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test=true; m.albedo_color=Color(1.0,.12,.16,alpha); m.render_priority=2
	return m

func _build_pointer() -> void:
	laser=MeshInstance3D.new(); var cyl:=CylinderMesh.new(); cyl.top_radius=.018; cyl.bottom_radius=.018; cyl.height=1.0; cyl.radial_segments=4; cyl.rings=1
	laser.mesh=cyl; laser.material_override=_laser_mat(.55); laser.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; laser.top_level=true; add_child(laser)
	reticle=Node3D.new(); reticle.top_level=true; add_child(reticle)
	reticle_ring=MeshInstance3D.new(); var t:=TorusMesh.new(); t.inner_radius=.30; t.outer_radius=.34; t.rings=32; t.ring_segments=4
	reticle_ring.mesh=t; reticle_ring.material_override=_laser_mat(.9); reticle_ring.rotation.x=PI/2; reticle.add_child(reticle_ring)
	for k in range(4):
		var tick:=MeshInstance3D.new(); var bx:=BoxMesh.new(); bx.size=Vector3(.04,.16,.01); tick.mesh=bx; tick.material_override=_laser_mat(.95)
		tick.position=Vector3(0,.46,0).rotated(Vector3.FORWARD,k*PI/2); tick.rotation.z=k*PI/2; reticle.add_child(tick); reticle_ticks.append(tick)
	laser_dot=MeshInstance3D.new(); var dot:=SphereMesh.new(); dot.radius=.045; dot.height=.09; laser_dot.mesh=dot; laser_dot.material_override=_laser_mat(1.0)
	reticle.add_child(laser_dot)
	for n in [laser,reticle_ring,laser_dot]: (n as GeometryInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _update_laser() -> void:
	var on: bool=hero and not dead and not downed and not loadout.is_empty() and loadout[weapon].get("laser",false) and reload<=0
	if not on:
		if is_instance_valid(laser): laser.visible=false; reticle.visible=false
		return
	if not is_instance_valid(laser): _build_pointer()
	var a:=muzzle_position()
	# aim point: the cursor for the mouse player, the current target for AI / pads, clamped to the scope's range
	var goal:=aim_point if aim_point!=Vector3.ZERO else global_position+aim*18.0+Vector3.UP*GUN_HEIGHT
	goal.y=a.y
	var flat:=goal-global_position; flat.y=0
	if flat.length()>34.0: goal=global_position+flat.normalized()*34.0+Vector3(0,goal.y,0)
	var q:=PhysicsRayQueryParameters3D.create(a,goal,1|2|4); q.exclude=[get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(q)
	var locked:=false
	var b:=goal
	if not hit.is_empty() and not (hit.collider is SectorActor and hit.collider.team==team):
		b=hit.position; locked=hit.collider is SectorActor
	# lock onto a robot whose body the shot line crosses (same test the bullets use)
	var flat_dir:=b-a; flat_dir.y=0
	if flat_dir.length()>.2:
		var tr: Array=game.trace_shot(self,game.shot_origin(self),flat_dir.normalized(),flat_dir.length(),1)
		if not tr[0].is_empty():
			var p: Vector3=tr[0][0][1]; b=Vector3(p.x,a.y,p.z); locked=true
	var v:=b-a
	if v.length()<.1: laser.visible=false; reticle.visible=false; return
	laser.visible=true; reticle.visible=true
	laser.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,v.normalized()))*Basis.from_scale(Vector3(1,v.length(),1)),(a+b)*.5)
	# reticle faces the camera so it reads as a 2D pointer from the top-down view
	reticle_lock=move_toward(reticle_lock,1.0 if locked else 0.0,get_physics_process_delta_time()*8.0)
	var cam: Camera3D=game.camera
	reticle.global_position=b
	if is_instance_valid(cam): reticle.look_at(b+(b-cam.global_position).normalized(),Vector3.UP)  # +Z toward the camera
	reticle_spin+=get_physics_process_delta_time()*(1.2+reticle_lock*4.0)
	var sc:=lerpf(1.0,.62,reticle_lock)*(1.0+.06*sin(Time.get_ticks_msec()*.01))
	reticle.scale=Vector3.ONE*1.5
	reticle_ring.scale=Vector3.ONE*sc
	for k in range(reticle_ticks.size()):
		var ang:=k*PI/2+reticle_spin
		reticle_ticks[k].position=Vector3(0,lerpf(.48,.30,reticle_lock),0).rotated(Vector3.FORWARD,ang); reticle_ticks[k].rotation.z=ang
	(reticle_ring.material_override as StandardMaterial3D).albedo_color.a=lerpf(.75,1.0,reticle_lock)

func _show_weapon() -> void:
	for i in range(weapon_nodes.size()):
		if is_instance_valid(weapon_nodes[i]): weapon_nodes[i].visible=i==weapon

func set_weapon(index: int) -> void:
	index=posmod(index,loadout.size())
	if index==weapon: return
	weapon=index; charge=0; attack_timer=maxf(attack_timer,.12); reload=0
	if ammo[weapon]<=0: _start_reload()
	_show_weapon()
	game.play_sfx("switch")
	game.ui.weapon_tag(self,loadout[weapon].name,loadout[weapon].color)
	_apply_stance()
	if loadout[weapon].kind=="melee": flourish=0.0  # twirl the blade as it is drawn

func _start_reload() -> void:
	if int(loadout[weapon].mag)<=0: reload=0; return
	reload=loadout[weapon].reload*(1.0-Data.upgrade_value(self,"rate")*.10)*(.6 if buffs.has("rapid") else 1.0)
	reload_total=reload
	if hero: _play_anim("reload")

func weapon_color() -> Color:
	return loadout[weapon].color if hero and not loadout.is_empty() else Color("ff6746")

# Layered animation: legs from a directional blend space (relative to where the fighter faces),
# upper body holds the aim and layers recoil, reload and hit/special one-shots on top.
func _setup_tree() -> void:
	var prefix:=String(anim.get_animation("idle").track_get_path(0)).get_slice(":",0)
	var bt:=AnimationNodeBlendTree.new()
	var loco:=AnimationNodeBlendSpace2D.new(); loco.min_space=Vector2(-1,-1); loco.max_space=Vector2(1,1)
	for pt in [["idle",Vector2.ZERO],["run",Vector2(0,1)],["run_back",Vector2(0,-1)],["strafe_left",Vector2(-1,0)],["strafe_right",Vector2(1,0)]]:
		var a:=AnimationNodeAnimation.new(); a.animation=pt[0]; loco.add_blend_point(a,pt[1],-1,pt[0])
	bt.add_node("loco",loco)
	bt.add_node("loco_speed",AnimationNodeTimeScale.new()); bt.connect_node("loco_speed",0,"loco")
	# stance: one looping hold per weapon class (Data stance field), cross-faded by a transition
	var st:=AnimationNodeTransition.new(); st.xfade_time=.22; st.input_count=STANCES.size()
	bt.add_node("stance",st)
	var idx:=0
	for key in STANCES:
		var clip: String=STANCES[key] if anim.has_animation(STANCES[key]) else "aim"
		var a:=AnimationNodeAnimation.new(); a.animation=clip; bt.add_node("stance_"+key,a)
		st.set_input_name(idx,key); bt.connect_node("stance",idx,"stance_"+key); idx+=1
	var last: String="stance"
	var flinch_node: AnimationNodeOneShot
	for shot in [["recoil","recoil",.02,.08],["reload","reload",.08,.12],["action","hit",.06,.12],["flinch","hit",.05,.12]]:
		var one:=AnimationNodeOneShot.new(); one.fadein_time=shot[2]; one.fadeout_time=shot[3]; bt.add_node(shot[0],one)
		var clip:=AnimationNodeAnimation.new(); clip.animation=shot[1]; bt.add_node(shot[0]+"_anim",clip)
		var src: String=shot[0]+"_anim"
		if shot[0]=="reload" or shot[0]=="action":
			bt.add_node(shot[0]+"_speed",AnimationNodeTimeScale.new()); bt.connect_node(shot[0]+"_speed",0,src); src=shot[0]+"_speed"
		bt.connect_node(shot[0],0,last); bt.connect_node(shot[0],1,src); last=shot[0]
		if shot[0]=="flinch":  # filtered later, once the skeleton's real bone names are known
			flinch_node=bt.get_node("flinch")
	var mix:=AnimationNodeBlend2.new(); mix.filter_enabled=true
	# Filter by the skeleton's real bone names: glTF import renames bones that clash with mesh names
	# (e.g. "R_upper_arm" becomes "R_upper_arm_2"), so match on the base name.
	var skel:=model.find_child("*",true,false) as Skeleton3D
	for n in model.find_children("*","Skeleton3D",true,false): skel=n
	var suffix:=RegEx.create_from_string("_\\d+$")
	if skel:
		for i in range(skel.get_bone_count()):
			var bone_name:=skel.get_bone_name(i)
			if suffix.sub(bone_name,"") in UPPER_BONES: mix.set_filter_path(NodePath(prefix+":"+bone_name),true)
			if flinch_node and suffix.sub(bone_name,"") in ["spine","chest","neck","head"]: flinch_node.filter_enabled=true; flinch_node.set_filter_path(NodePath(prefix+":"+bone_name),true)
	else:
		for bone in UPPER_BONES: mix.set_filter_path(NodePath(prefix+":"+bone),true)
	bt.add_node("upper_mix",mix); bt.connect_node("upper_mix",0,"loco_speed"); bt.connect_node("upper_mix",1,last)
	var full:=AnimationNodeOneShot.new(); full.fadein_time=.06; full.fadeout_time=.12; bt.add_node("full",full)
	var full_clip:=AnimationNodeAnimation.new(); full_clip.animation="dodge"; bt.add_node("full_anim",full_clip)
	bt.connect_node("full",0,"upper_mix"); bt.connect_node("full",1,"full_anim")
	var life:=AnimationNodeTransition.new(); life.input_count=3; life.xfade_time=.15
	life.set_input_name(0,"alive"); life.set_input_name(1,"downed"); life.set_input_name(2,"dead")
	bt.add_node("life",life); bt.connect_node("life",0,"full")
	for state in [["downed","downed"],["dead","death"]]:
		var c:=AnimationNodeAnimation.new(); c.animation=state[1]; bt.add_node(state[0]+"_anim",c)
	bt.connect_node("life",1,"downed_anim"); bt.connect_node("life",2,"dead_anim")
	bt.connect_node("output",0,"life")
	anim.stop()
	tree=AnimationTree.new(); tree.tree_root=bt
	anim.get_parent().add_child(tree)
	tree.anim_player=tree.get_path_to(anim)
	tree.set("parameters/upper_mix/blend_amount",1.0)
	tree.active=true

func _tree_shot(param: String, clip := "") -> void:
	if clip!="": (tree.tree_root as AnimationNodeBlendTree).get_node(param+"_anim").animation=clip
	tree.set("parameters/%s/request" % param,AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _set_flash(on: bool) -> void:
	if _hit_mat==null:
		_hit_mat=StandardMaterial3D.new(); _hit_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_mat.albedo_color=Color(1,1,1,.75); _hit_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; _hit_mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	if flash_meshes.is_empty() and is_instance_valid(model):
		for m in model.find_children("*","MeshInstance3D",true,false): flash_meshes.append(m)
	for m in flash_meshes:
		if is_instance_valid(m): m.material_overlay=_hit_mat if on else null

func _make_marker() -> void:
	marker=MeshInstance3D.new(); var ring:=TorusMesh.new(); ring.inner_radius=.44; ring.outer_radius=.53; marker.mesh=ring
	var c: Color=Data.PLAYER_COLORS[mini(slot,1)]
	marker.material_override=_mat(c,true); marker.position.y=.045; add_child(marker)

func _make_shield() -> void:
	shield_visual=MeshInstance3D.new()
	var sphere:=SphereMesh.new(); sphere.radius=1.02; sphere.height=2.04; shield_visual.mesh=sphere
	var m:=StandardMaterial3D.new(); m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color=Color(.96,.68,.12,.16); m.emission_enabled=true; m.emission=Color("f9b830"); m.emission_energy_multiplier=.4; m.cull_mode=BaseMaterial3D.CULL_DISABLED
	shield_visual.material_override=m; shield_visual.position.y=1.0; shield_visual.visible=false; add_child(shield_visual)

# Mouse player: aim at the cursor (on the plane at the real muzzle height, which varies by stance); with auto
# aim on, snap to the best robot near that direction instead.
func _mouse_aim() -> void:
	var h:=muzzle_position().y
	aim_point=game.mouse_aim(h) as Vector3
	var v:=aim_point-global_position; v.y=0
	var lock:=game.auto_aim(self,v.normalized() if v.length_squared()>.04 else aim,h) as Vector3
	if lock!=Vector3.ZERO: aim_point=lock; v=lock-global_position; v.y=0
	if v.length_squared()>.04: aim=v.normalized()

# Aim, facing and the sniper pointer run every rendered frame on real time, so the cursor target keeps moving
# smoothly even while the game is in slow motion.
func _process(delta: float) -> void:
	if not hero or dead or downed or input_id!=0 or not is_instance_valid(game) or game.state!="playing": return
	var real:=delta/maxf(Engine.time_scale,.01)
	if not cutscene: _mouse_aim()
	if is_instance_valid(model) and not move_steer: model.rotation.y=lerp_angle(model.rotation.y,_facing_yaw(),clampf(real*10.0,0,1))
	if Engine.time_scale<1.0: _update_laser()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.state!="playing": return
	attack_timer=maxf(0,attack_timer-delta); special_timer=maxf(0,special_timer-delta); dodge_timer=maxf(0,dodge_timer-delta)
	air_support_timer=maxf(0,air_support_timer-delta)
	drone_timer=maxf(0,drone_timer-delta)
	invulnerable=maxf(0,invulnerable-delta); shield_time=maxf(0,shield_time-delta)
	for k in buffs.keys():
		buffs[k]-=delta
		if buffs[k]<=0: buffs.erase(k)
	if shield_time<=0: shield_health=0
	if is_instance_valid(shield_visual): shield_visual.visible=shield_time>0
	action_anim_time=maxf(0,action_anim_time-delta)
	slow_time=maxf(0,slow_time-delta)
	if bolt_timer>0:
		bolt_timer-=delta
		if bolt_timer<=0: game.play_sfx("rack"); game.fx.shell(muzzle_position()-aim*1.0,aim)
	_update_laser()
	if swing_impact>0:
		swing_impact-=delta
		if swing_impact<=0: land_cut()
	if swing_time>0:
		swing_time-=delta
		# trail only through the strike: from just before impact to shortly after it
		var strike: bool=swing_impact<.09 and swing_impact>-.15 or cutscene and swing_impact<.15 and swing_impact>-.2
		if swing_impact<=0: swing_impact-=delta
		if not strike: trail_prev.clear()
		elif weapon<weapon_nodes.size() and is_instance_valid(weapon_nodes[weapon]) and loadout[weapon].kind=="melee":
			var edge:=blade_edge_points()
			if trail_prev.size()==edge.size(): game.fx.blade_ribbon(trail_prev,edge,loadout[weapon].color,cutscene)
			trail_prev=edge
	if is_instance_valid(body_node):
		# chiburi (flick the blade clean) on drawing the katana and after standing still with it for a while
		var blade_out: bool=not loadout.is_empty() and loadout[weapon].kind=="melee" and weapon<weapon_nodes.size() and is_instance_valid(weapon_nodes[weapon])
		idle_time=idle_time+delta if blade_out and velocity.length()<.3 and swing_time<=0 else 0.0
		if blade_out and (flourish>=0 or idle_time>5.0):
			flourish=-1.0; idle_time=0.0
			if is_instance_valid(tree) and anim.has_animation("chiburi"):
				tree.set("parameters/action_speed/scale",1.0); _tree_shot("action","chiburi")
	if spin_speed>0:
		spin_speed=maxf(0,spin_speed-delta*30.0)
		if weapon<spin_nodes.size() and is_instance_valid(spin_nodes[weapon]): spin_nodes[weapon].rotate_object_local(Vector3.FORWARD,spin_speed*delta)
	if hit_flash>0:
		hit_flash-=delta
		if hit_flash<=0: _set_flash(false)
	if reload>0:
		reload-=delta
		if reload<=0 and hero: ammo[weapon]=int(loadout[weapon].mag); game.play_sfx("switch")
	if hero and weapon<weapon_loads.size() and is_instance_valid(weapon_loads[weapon]):
		# the loaded round leaves with the shot and slides back in halfway through the reload
		weapon_loads[weapon].visible=ammo[weapon]>0 or (reload>0 and reload<reload_total*.5)
	nav_timer=maxf(0,nav_timer-delta)
	if dead: return
	if downed:
		_play_anim("downed")
		downed_time-=delta
		bar.text="REVIVE  %d" % ceili(downed_time)
		if downed_time<=0: dead=true; visible=false; game.check_defeat()
		return
	if hero and input_id>=0 and not cutscene: _drone_input()
	if hero and input_id>=0 and move_lock and not cutscene:
		var joy: int=game.joy_for(input_id)
		var firing: bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) if input_id==0 else joy>=0 and Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_RIGHT)>.45
		var special: bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) if input_id==0 else joy>=0 and Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_LEFT)>.45
		_support_input(firing,special)
		_special_held=special; _special_wait=-1.0
	if move_t>=0: _run_move(delta)
	if cutscene: last_move=Vector3.ZERO
	elif move_lock: last_move=Vector3.ZERO
	elif hero:
		if input_id==-1: _companion_ai(delta)
		else: _player_input(delta)
	else: _enemy_ai(delta)
	if dodge_time>0:
		dodge_time-=delta
		velocity=last_move*15.0
	else:
		var target_velocity:=last_move*speed*(.55 if slow_time>0 else 1.0)*(1.0+Data.upgrade_value(self,"speed")*.10)*(1.35 if buffs.has("haste") else 1.0)
		velocity=velocity.move_toward(target_velocity,delta*(18.0 if last_move.length_squared()>.01 else 24.0))
	move_and_slide()
	var horizontal_speed:=Vector2(velocity.x,velocity.z).length()
	var movement_ratio:=clampf(horizontal_speed/maxf(speed,.01),0.0,1.5)
	if is_instance_valid(tree):
		# leg blend from velocity in the fighter's own frame: forward/back run, strafes, idle in between
		var basis:=model.global_transform.basis
		var fwd:=-basis.z; fwd.y=0; fwd=fwd.normalized()
		var right:=basis.x; right.y=0; right=right.normalized()
		var want:=Vector2(velocity.dot(right),velocity.dot(fwd))/maxf(speed,.01)
		if want.length()>1: want=want.normalized()
		loco_blend=loco_blend.lerp(want,clampf(delta*10.0,0,1))
		tree.set("parameters/loco/blend_position",loco_blend)
		tree.set("parameters/loco_speed/scale",clampf(movement_ratio*1.15,.85,1.45) if movement_ratio>.2 else 1.0)
	elif hero and action_anim_time<=0:
		var locomotion:="run" if horizontal_speed>.45 else "idle"
		_play_anim(locomotion)
		if is_instance_valid(anim): anim.speed_scale=clampf(movement_ratio,0.72,1.35) if locomotion=="run" else 1.0
	position.x=clampf(position.x,-22.8,22.8); position.z=clampf(position.z,-17.8,17.8)
	if aim.length_squared()>.001 and not move_steer:
		model.rotation.y=lerp_angle(model.rotation.y,_facing_yaw(),clampf(delta*10.0,0,1))
	model_time+=delta
	var prev_phase:=gait_phase
	gait_phase+=delta*(7.0+movement_ratio*4.0)*minf(movement_ratio,1.0)
	var idle_breath:=sin(model_time*2.0)*.007
	var step_bob:=absf(sin(gait_phase))*.035*minf(movement_ratio,1.0)
	# footstep dust each time a foot plants while running
	if hero and movement_ratio>.55 and floor(prev_phase/PI)!=floor(gait_phase/PI):
		step_sign=-step_sign
		var side:=model.global_transform.basis.x.normalized()*.2*step_sign
		game.fx.dust(global_position+side+Vector3.UP*.05)
	recoil_kick=move_toward(recoil_kick,0.0,delta*.9)
	hit_tilt=move_toward(hit_tilt,0.0,delta*1.6)
	var facing:=-model.global_transform.basis.z; facing.y=0
	var kick:=-facing.normalized()*recoil_kick if facing.length_squared()>.001 else Vector3.ZERO
	model.position=Vector3(kick.x,lerpf(model.position.y,idle_breath+step_bob+move_lift,clampf(delta*12.0,0,1)),kick.z)
	var local_right:=Vector3.RIGHT.rotated(Vector3.UP,model.rotation.y)
	var strafe:=velocity.dot(local_right)/maxf(speed,.01)
	var forward:=velocity.dot(facing.normalized() if facing.length_squared()>.001 else aim)/maxf(speed,.01)
	# lean into movement, settle back when stopping; enemies rock back when hit
	model.rotation.z=lerpf(model.rotation.z,-strafe*.07,clampf(delta*7.0,0,1))
	model.rotation.x=lerpf(model.rotation.x,-forward*.06+hit_tilt+recoil_kick*.6,clampf(delta*9.0,0,1))
	if not hero and enemy_legs.size()==2:
		var swing:=sin(gait_phase)*.50*minf(movement_ratio,1.0)
		enemy_legs[0].rotation.x=swing
		enemy_legs[1].rotation.x=-swing
		enemy_arms[0].rotation.x=-swing*.65+sin(model_time*2.0)*.025
		enemy_arms[1].rotation.x=swing*.65-sin(model_time*2.0)*.025

func _player_input(delta: float) -> void:
	var mv := Vector2.ZERO
	var firing := false
	var special := false
	var dodge := false
	if input_id==0:
		mv=Input.get_vector("move_left","move_right","move_up","move_down")
		firing=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		special=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		dodge=Input.is_action_just_pressed("dodge")
		if Input.is_action_just_pressed("weapon_prev"): set_weapon(weapon-1)
		if Input.is_action_just_pressed("weapon_next"): set_weapon(weapon+1)
		for i in range(loadout.size()):
			if Input.is_action_just_pressed("weapon_%d" % (i+1)): set_weapon(i)
		_mouse_aim()
	else:
		var joy: int = game.joy_for(input_id)
		if joy>=0:
			mv=Vector2(Input.get_joy_axis(joy,JOY_AXIS_LEFT_X),Input.get_joy_axis(joy,JOY_AXIS_LEFT_Y))
			if mv.length()<.18: mv=Vector2.ZERO
			var a:=Vector2(Input.get_joy_axis(joy,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy,JOY_AXIS_RIGHT_Y))
			var stick:=Vector3(a.x,0,a.y).normalized() if a.length()>.25 else Vector3.ZERO
			# auto aim: lock near the stick direction, or onto the nearest robot while the stick is idle
			var lock:=game.auto_aim(self,stick,GUN_HEIGHT) as Vector3
			if lock!=Vector3.ZERO:
				var to:=lock-global_position; to.y=0
				if to.length_squared()>.04: stick=to.normalized()
			if stick!=Vector3.ZERO:
				var wanted:=stick
				aim=aim.lerp(wanted,clampf(delta*8.0*maxf(.3,game.settings.sensitivity),0,1)).normalized()
			firing=Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_RIGHT)>.45
			special=Input.get_joy_axis(joy,JOY_AXIS_TRIGGER_LEFT)>.45
			dodge=Input.is_joy_button_pressed(joy,JOY_BUTTON_A) and dodge_timer<=0
			var bumpers:=[Input.is_joy_button_pressed(joy,JOY_BUTTON_LEFT_SHOULDER),Input.is_joy_button_pressed(joy,JOY_BUTTON_RIGHT_SHOULDER)]
			if bumpers[0] and not pad_bumpers[0]: set_weapon(weapon-1)
			if bumpers[1] and not pad_bumpers[1]: set_weapon(weapon+1)
			pad_bumpers=bumpers
		else: game.ui.announce("CONTROLLER %d DISCONNECTED" % input_id,.3)
	if mv.length()>1: mv=mv.normalized()
	last_move=Vector3(mv.x,0,mv.y)
	if game.heroes.size()>1:
		var other: SectorActor=game.heroes[0] if game.heroes[0]!=self else game.heroes[1]
		if is_instance_valid(other) and not other.dead:
			var separation:=global_position-other.global_position; separation.y=0
			if separation.length()>18 and last_move.dot(separation.normalized())>0:
				last_move=last_move.slide(separation.normalized())*.5
				game.ui.announce("TEAM DISTANCE LIMIT",.3)
	if input_id!=0:
		aim_point=global_position+aim*12.0+Vector3.UP*GUN_HEIGHT
		if is_instance_valid(auto_target) and game.settings.autoaim>=.5:
			aim_point=Vector3(auto_target.global_position.x,GUN_HEIGHT,auto_target.global_position.z)
	if dodge and dodge_timer<=0: _dodge()
	_attack_input(firing,special,delta)
	if input_id==0 and Input.is_action_pressed("interact") or input_id>0 and game.joy_for(input_id)>=0 and Input.is_joy_button_pressed(game.joy_for(input_id),JOY_BUTTON_X):
		_try_revive(delta)

# Both buttons/triggers take priority. A short grace period on right-click accepts either press order;
# releasing either button rearms the chord. A held right button never leaks a special on release of the left.
func _attack_input(firing: bool, special: bool, delta: float) -> void:
	if _support_input(firing,special): return
	if special and not _special_held: _special_wait=.12
	if _special_wait>=0:
		_special_wait-=delta
		if _special_wait<=0 or not special:
			_special_wait=-1.0; _special()
	_special_held=special
	if firing and not move_lock: _primary(delta)
	else: charge=maxf(0,charge-delta*.35)

func _support_input(firing: bool, special: bool) -> bool:
	if firing and special:
		_special_wait=-1.0
		if not _support_chord: call_air_support()
		_support_chord=true; _special_held=true
		return true
	_support_chord=false
	return false

func _drone_input() -> void:
	var joy: int=game.joy_for(input_id)
	var pressed: bool=Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) if input_id==0 else joy>=0 and Input.is_joy_button_pressed(joy,JOY_BUTTON_RIGHT_STICK)
	if pressed and not _drone_held: call_drone_swarm()
	_drone_held=pressed

func call_drone_swarm() -> bool:
	if dead or downed or cutscene or not is_instance_valid(game) or game.state!="playing": return false
	if is_instance_valid(game.killcam) and game.killcam.active: return false
	if is_instance_valid(drone_swarm) and not drone_swarm.is_queued_for_deletion():
		game.ui.weapon_tag(self,"DRONES  "+drone_swarm.status(),Data.COLORS[hero_id]); return false
	if drone_timer>0:
		game.ui.weapon_tag(self,"DRONES  %ds" % ceili(drone_timer),Data.COLORS[hero_id]); return false
	drone_swarm=DroneSwarmScript.new(); drone_swarm.setup(game,self)
	game.add_child(drone_swarm); drone_swarm.add_to_group("transient"); drone_swarm.add_to_group("drone_swarm")
	drone_timer=Data.DRONE_COOLDOWN
	game.ui.weapon_tag(self,"DRONE SWARM DEPLOYED",Data.COLORS[hero_id])
	return true

func call_air_support() -> bool:
	if dead or downed or cutscene or not is_instance_valid(game) or game.state!="playing": return false
	if is_instance_valid(game.killcam) and game.killcam.active: return false
	if air_support_timer>0:
		game.ui.weapon_tag(self,"AIR SUPPORT  %ds" % ceili(air_support_timer),Data.COLORS[hero_id])
		return false
	var goal: Vector3=game.mouse_plane(0.0) if input_id==0 else global_position+aim*10.0
	if input_id<0 and is_instance_valid(target): goal=target.global_position
	var to:=Vector3(goal.x-global_position.x,0,goal.z-global_position.z)
	if to.length()<1.0: to=aim*7.0
	if to.length()>18.0: to=to.normalized()*18.0
	goal=global_position+to; goal.y=0
	goal.x=clampf(goal.x,-20,20); goal.z=clampf(goal.z,-15,15)
	var support=AirSupportScript.new()
	support.setup(game,self,goal,aim)
	game.add_child(support); support.add_to_group("transient"); support.add_to_group("air_support")
	air_support_timer=Data.AIR_SUPPORT_COOLDOWN
	game.ui.weapon_tag(self,"GUNSHIP INBOUND",Data.COLORS[hero_id])
	return true

func _companion_ai(delta: float) -> void:
	ai_tick-=delta
	if ai_tick<=0:
		ai_tick=.16
		target=game.closest_enemy(global_position)
	var human: SectorActor=game.closest_human(global_position)
	var down: SectorActor=game.closest_downed(global_position)
	if is_instance_valid(down):
		var v:=down.global_position-global_position; v.y=0
		last_move=v.normalized() if v.length()>1.5 else Vector3.ZERO
		_navigate(last_move)
		if v.length()<2.1: _try_revive(delta)
	elif is_instance_valid(target):
		var v:=target.global_position-global_position; v.y=0
		aim=v.normalized()
		aim_point=target.global_position+Vector3.UP*GUN_HEIGHT
		var melee: bool=not loadout.is_empty() and loadout[weapon].kind=="melee"
		var far:=2.0 if melee else 8.0
		var near:=.9 if melee else 4.0
		if v.length()>far: last_move=aim
		elif v.length()<near: last_move=-aim
		else: last_move=Vector3.ZERO
		_navigate(last_move)
		_primary(delta)
		# Kestrel takes her shot from sniper range; the other operatives save their move for a nearby crowd.
		if special_timer<=0:
			var ready: bool=Specials.crowd(game,global_position,5.0)>=3 or target.boss and v.length()<6
			if hero_id==5: ready=Specials.nearest(self,global_position,28.0,3).size()>=3 or target.boss and not target.dead and v.length()<28 and game.line_of_sight(global_position,target.global_position)
			if ready: _special()
	elif is_instance_valid(human):
		var v:=human.global_position-global_position; v.y=0
		last_move=v.normalized() if v.length()>3 else Vector3.ZERO
		_navigate(last_move)

func _navigate(desired: Vector3) -> void:
	if desired.length_squared()<.01: return
	var space:=get_world_3d().direct_space_state
	var q:=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.55,global_position+desired*1.5+Vector3.UP*.55,1)
	if not space.intersect_ray(q).is_empty():
		if is_instance_valid(target):
			if nav_timer<=0:
				nav_timer=.7+randf()*.35
				nav_dir=game.arena.path_direction(global_position,target.global_position)
			last_move=nav_dir
		else:
			last_move=Vector3(-desired.z,0,desired.x)*sidestep
			if randf()<.008: sidestep=-sidestep

func _enemy_ai(delta: float) -> void:
	ai_tick-=delta
	if ai_tick<=0:
		ai_tick=.13+randf()*.13
		target=game.closest_active_hero(global_position)
		separation_dir=game.enemy_separation(self)
	if not is_instance_valid(target): last_move=Vector3.ZERO; return
	if enemy_id==5 and hp<max_hp*.5:
		speed=2.9; cadence=1.0
	if boss_charge_time>0:
		boss_charge_time-=delta
		last_move=boss_charge_dir*3.0
		if not boss_charge_hit and global_position.distance_to(target.global_position)<1.65:
			game.hurt(target,damage*1.5,self,target.global_position,"charge",6.0)
			boss_charge_hit=true
		return
	var to:=target.global_position-global_position; to.y=0
	var dist:=to.length(); if dist<.01: return
	if not ai.has("charge"): aim=to/dist  # a charging lancer keeps its line
	if Robots.handles(self): Robots.think(self,delta,to,dist); return
	if windup>0:
		windup-=delta; last_move=Vector3.ZERO
		if windup<=0:
			if enemy_id==3: game.spawn_projectile(self, aim, damage, Color("ff6746"), 9.0)
			elif enemy_id==5:
				attack_state+=1
				if attack_state%2==0: game.boss_burst(self)
				else: boss_charge_time=.55; boss_charge_dir=aim; boss_charge_hit=false
			elif dist<1.5:
				game.hurt(target,damage,self,global_position,"melee",4.0 if enemy_id==2 else 1.2)
				if enemy_id==1: dodge_time=.16; last_move=aim
			attack_timer=cadence
		return
	var desired:=aim
	if enemy_id==3 and dist<7: desired=-aim
	elif enemy_id==3 and dist<12: desired=Vector3.ZERO
	elif dist<1.0: desired=Vector3.ZERO
	last_move=desired
	_navigate(desired)
	last_move=(last_move+separation_dir*.7).normalized() if last_move.length_squared()>.01 else separation_dir
	if attack_timer<=0 and dist<(12.0 if enemy_id==3 else (3.3 if enemy_id==5 else 1.45)) and game.line_of_sight(global_position,target.global_position):
		windup=.85 if enemy_id==5 else (.55 if enemy_id==3 else (.6 if enemy_id==2 else .32))
		game.telegraph(self, windup)

func _dodge() -> void:
	if last_move.length_squared()<.1: last_move=aim
	dodge_time=.17; invulnerable=.23
	dodge_timer=2.5*(1.0-Data.upgrade_value(self,"dodge")*.15)
	game.flash(global_position+Vector3.UP*.6,Color("faf6d5"),.3)
	_play_anim("dodge",.18)
	var blast:=Data.upgrade_value(self,"blast_dodge")
	if blast>0:  # Blast dodge upgrade: a shockwave where the dodge starts
		for e in game.enemies.duplicate():
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position)<2.6:
				game.hurt(e,25.0*blast,self,global_position,"shock",4.0)
		game.fx._ring(global_position,Data.PLAYER_COLORS[mini(slot,1)],2.8,.25)

# Power-up pickup (pickup.gd): timed ones run in buffs, the rest act at once.
func apply_powerup(kind: String) -> void:
	var p: Dictionary=Data.POWERUPS[kind]
	var t: float=p.time*(1.0+Data.upgrade_value(self,"scavenger")*.4)
	match kind:
		"health": hp=minf(max_hp,hp+25); _update_bar()
		"surge": special_timer=0.0
		"barrier": shield_time=maxf(shield_time,t); shield_health=maxf(shield_health,80.0)
	if t>0: buffs[kind]=t
	game.ui.weapon_tag(self,p.name,p.color)

func _primary(delta: float) -> void:
	var w: Dictionary=loadout[weapon]
	var infinite: bool=int(w.mag)<=0
	if reload>0: return
	if not infinite and ammo[weapon]<=0: _start_reload(); return
	if w.kind=="rail":
		if attack_timer>0: return
		charge=minf(1.0,charge+delta/w.charge*(1.0+Data.upgrade_value(self,"heat")*.15))
		if charge<1.0:
			_play_anim("charge",.08)
			game.fx.charge_orb(muzzle_position(),charge,w.color)
			return
	if attack_timer>0: return
	var d: float=w.damage*(1.0+Data.upgrade_value(self,"damage")*.15)*(1.6 if buffs.has("overcharge") else 1.0)
	var pierce:=int(Data.upgrade_value(self,"pierce"))
	if w.get("spin",false): spin_speed=minf(38.0,spin_speed+delta*160.0)
	match w.kind:
		"melee":
			var now:=Time.get_ticks_msec()/1000.0
			combo=(combo+1)%3 if now-last_swing<.9 else 0
			last_swing=now
			swing_power=1.6 if combo==2 else 1.0
			# damage lands on the cut's strike key (clips play at 1.6x): kesa / gyaku-kesa ~0.2 s, shomen ~0.23 s
			swing_impact=.2 if combo<2 else .23
			swing_time=.42 if combo<2 else .55; trail_prev.clear()
			flourish=-1.0
			melee_damage=d*swing_power
			if hero and is_instance_valid(game.killcam): game.killcam.predict_cut(self,cut_reach(w),melee_damage)  # a 9th kill coming: film it live
		"hitscan": game.fire_hitscan(self,aim,w,d,pierce)
		"rail": game.fire_rail(self,aim,w,d); charge=0
		_: game.fire_projectile(self,aim,w,d)
	attack_timer=w.rate*(1.0-Data.upgrade_value(self,"rate")*.10)*(.6 if buffs.has("rapid") else 1.0)
	if not infinite:
		ammo[weapon]-=1
		if ammo[weapon]<=0: _start_reload()
	if w.kind=="melee":
		_play_anim("slash_%d" % (combo+1))
		attack_timer*=1.5 if combo==2 else 1.0
	else:
		recoil_kick=minf(.16,recoil_kick+.035+w.knock*.025)
		_play_anim("attack",.16)
		if w.get("bolt",false): bolt_timer=.36
	game.shot_fx(self,w)

# Normal gameplay uses the strike key; a filmed swing may land earlier when its animated edge touches.
func land_cut() -> void:
	swing_impact=-.0001
	var w: Dictionary=loadout[weapon]
	if cutscene and not game.killcam.live: game.killcam.blade_connects(self)  # replay: hold damage
	elif w.kind=="melee":
		if not cutscene: velocity+=aim*(8.0 if swing_power>1.2 else 3.5)
		game.fire_melee(self,aim,cut_reach(w),melee_damage)
		if cutscene: game.killcam.blade_connects(self)

# The blade arc for the current cut: the shomen finisher reaches further on a narrower arc.
func cut_reach(w: Dictionary) -> Dictionary:
	var finisher: bool=swing_power>1.2
	return w.merged({"radius":w.radius+(.6 if finisher else 0.0),"arc":.7 if finisher else w.arc})

# Kill cam replay of the finishing cut (combo index 0-2), on game time so it plays in slow motion.
func replay_cut(index: int) -> void:
	combo=index; swing_power=1.6 if index==2 else 1.0
	swing_impact=.2 if index<2 else .23
	swing_time=.42 if index<2 else .55; trail_prev.clear(); flourish=-1.0; idle_time=0.0
	_play_anim("slash_%d" % (index+1))

func _special() -> void:
	if special_timer>0 or move_t>=0: return
	special_timer=special_base*(1.0-Data.upgrade_value(self,"special")*.13)
	Specials.start(self)

func move_at(t: float, f: Callable) -> void:
	move_events.append([t,f])

func _run_move(delta: float) -> void:
	move_t+=delta
	while move_t>=0 and not move_events.is_empty() and move_events[0][0]<=move_t:
		(move_events.pop_front()[1] as Callable).call()
	if move_t<0: return
	if move_tick.is_valid(): move_tick.call(delta)
	if move_t>=move_end: end_move()

func end_move() -> void:
	if move_cleanup.is_valid(): move_cleanup.call()
	move_t=-1.0; move_events.clear(); move_tick=Callable(); move_cleanup=Callable()
	move_lock=false; move_steer=false; move_lift=0.0

func _try_revive(delta: float) -> void:
	var other: SectorActor=game.closest_downed(global_position)
	if is_instance_valid(other) and other!=self and global_position.distance_to(other.global_position)<2.2:
		other.revive_progress+=delta
		if other.revive_progress>=2.5:
			other.downed=false; other.dead=false; other.hp=minf(other.max_hp,other.max_hp*.42+Data.upgrade_value(self,"revive")*20.0)
			other.revive_progress=0; other.invulnerable=1.5; other._update_bar(); other._play_anim("revive",.35); game.flash(other.global_position+Vector3.UP,Color("6fffd4"),1.4)

func take_damage(amount: float, source: SectorActor, from_pos: Vector3, damage_type := "kinetic", knockback := 0.0, critical := false) -> void:
	if dead or downed or invulnerable>0 or (is_instance_valid(source) and source.team==team): return
	if critical: amount*=1.5
	if hero and shield_time>0:
		shield_health-=amount
		if shield_health<=0: shield_time=0
		game.flash(global_position+Vector3.UP,Color("ffc759"),.25)
		return
	if not hero and enemy_id==4 and is_instance_valid(source) and damage_type!="precision":
		var to_source:=(source.global_position-global_position).normalized()
		if aim.dot(to_source)>.25: amount*=.3
	if hero: amount*=1.0-Data.upgrade_value(self,"armor")*.08
	last_damage_type=damage_type; last_hit_from=from_pos
	if is_instance_valid(source) and source.hero: last_hit_color=source.weapon_color(); last_attacker=source
	last_hit_heavy=amount>=60.0
	hp-=amount
	if knockback>0:
		var away:=global_position-from_pos; away.y=0
		if away.length_squared()>.001: velocity+=away.normalized()*knockback
	_play_anim("hit",.18)
	if hero: game.flash(global_position+Vector3.UP*.8,Color("ff6039"),.22)
	else:
		# white hit flash and a short stagger so every connecting shot reads clearly
		_set_flash(true); hit_flash=.07; hit_tilt=minf(.35,hit_tilt+.12+knockback*.04)
		slow_time=maxf(slow_time,.18)
	if hero: game.play_sfx("damage")
	if hp<=0:
		hp=0
		if hero: end_move(); downed=true; downed_time=20.0; _play_anim("downed"); game.check_defeat()
		else: dead=true; _play_anim("death"); game.enemy_killed(self)
	_update_bar()

func _update_bar() -> void:
	if is_instance_valid(bar): bar.text="%s%s  %d/%d" % ["ELITE " if elite else "",(Data.HEROES[hero_id] if hero else Data.enemy_name(enemy_id)),ceili(hp),ceili(max_hp)]
	if is_instance_valid(bar): bar.visible=downed or (not hero and not boss and hp<max_hp)  # bosses use the HUD bar

func apply_upgrade(u: Dictionary) -> void:
	var k: String=u.key
	upgrades[k]=int(upgrades.get(k,0))+1
	if k=="health": max_hp+=25; hp=minf(max_hp,hp+25)
	_update_bar()

func _play_anim(clip: String, lock_time := 0.0) -> void:
	if is_instance_valid(tree):
		match clip:
			"idle","run","charge": pass
			"attack": _tree_shot("recoil","recoil_"+stance if anim.has_animation("recoil_"+stance) else "recoil")
			"reload":
				var rclip: String="reload_"+stance if anim.has_animation("reload_"+stance) else "reload"
				tree.set("parameters/reload_speed/scale",anim.get_animation(rclip).length/maxf(reload,.2))
				_tree_shot("reload",rclip)
			"hit","special","cast": _tree_shot("flinch",clip)
			"slash_1","slash_2","slash_3":
				tree.set("parameters/action_speed/scale",1.6)
				_tree_shot("action",clip if anim.has_animation(clip) else "special")
			"dodge","revive","victory":
				if clip=="revive": tree.set("parameters/life/transition_request","alive")
				_tree_shot("full",clip)
			"downed": tree.set("parameters/life/transition_request","downed")
			"death": tree.set("parameters/life/transition_request","dead")
		return
	if not is_instance_valid(anim) or not anim.has_animation(clip): return
	if clip!="run" and clip!="idle": anim.speed_scale=1.0
	if anim.current_animation!=clip or not anim.is_playing(): anim.play(clip,.09)
	action_anim_time=maxf(action_anim_time,lock_time)
