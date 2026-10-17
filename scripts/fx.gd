extends Node3D
class_name SectorFx
## Lightweight effects: MultiMesh particle pools (voxels, glow sparks, smoke puffs), explosions,
## railgun beams, damage numbers and enemy disintegration.

var game: Node
var solid: Pool    # lit voxel debris, shell casings
var glow: Pool     # unshaded HDR sparks, embers, disintegration motes
var puff: Pool     # soft transparent smoke
var fire: Pool     # unshaded HDR fireball puffs
var scorches: Array[MeshInstance3D] = []
var numbers: Array[Label3D] = []
var number_vel: Array[Vector3] = []
var number_life: PackedFloat32Array = []
var number_next := 0
var number_font: FontVariation

class Pool:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var cap := 0
	var n := 0
	var pos := PackedVector3Array(); var vel := PackedVector3Array(); var axis := PackedVector3Array()
	var life := PackedFloat32Array(); var max_life := PackedFloat32Array(); var size := PackedFloat32Array()
	var grav := PackedFloat32Array(); var drag := PackedFloat32Array(); var grow := PackedFloat32Array(); var spin := PackedFloat32Array()
	var col := PackedColorArray()
	var fade_alpha := false
	var fade_hold := 1.0  # alpha stays full until life fraction drops below 1/fade_hold

	func _init(parent: Node3D, mesh: Mesh, material: Material, capacity: int, alpha: bool) -> void:
		cap = capacity; fade_alpha = alpha
		mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
		mm.mesh = mesh; mm.instance_count = cap; mm.visible_instance_count = 0
		mmi = MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-60,-5,-60), Vector3(120,40,120))
		parent.add_child(mmi)
		# packed arrays are values, so each member is resized directly
		pos.resize(cap); vel.resize(cap); axis.resize(cap)
		life.resize(cap); max_life.resize(cap); size.resize(cap); grav.resize(cap)
		drag.resize(cap); grow.resize(cap); spin.resize(cap); col.resize(cap)

	func emit(p: Vector3, v: Vector3, l: float, s: float, c: Color, g := 9.8, d := 0.0, gr := 0.0, sp := 6.0) -> void:
		var i := n
		if n >= cap: i = randi() % cap  # pool full: recycle a random slot
		else: n += 1
		pos[i] = p; vel[i] = v; life[i] = l; max_life[i] = l; size[i] = s; col[i] = c
		grav[i] = g; drag[i] = d; grow[i] = gr; spin[i] = sp
		axis[i] = Vector3(randf()-.5, randf()-.5, randf()-.5).normalized()

	func update(delta: float) -> void:
		var i := 0
		while i < n:
			life[i] -= delta
			if life[i] <= 0:
				n -= 1
				pos[i] = pos[n]; vel[i] = vel[n]; axis[i] = axis[n]; life[i] = life[n]; max_life[i] = max_life[n]
				size[i] = size[n]; col[i] = col[n]; grav[i] = grav[n]; drag[i] = drag[n]; grow[i] = grow[n]; spin[i] = spin[n]
				continue
			var v := vel[i]
			v.y -= grav[i] * delta
			if drag[i] > 0: v *= maxf(0.0, 1.0 - drag[i] * delta)
			var p := pos[i] + v * delta
			var s := size[i]
			var t := life[i] / max_life[i]  # 1 -> 0
			if grav[i] > 0 and p.y < s * .5 and v.y < 0:
				p.y = s * .5; v.y *= -.32; v.x *= .55; v.z *= .55
			pos[i] = p; vel[i] = v
			var scale := s * (1.0 + grow[i] * (1.0 - t))
			if not fade_alpha and t < .35: scale *= t / .35
			var basis := Basis(axis[i], (max_life[i] - life[i]) * spin[i]).scaled(Vector3.ONE * scale)
			mm.set_instance_transform(i, Transform3D(basis, p))
			var c := col[i]
			if fade_alpha: c.a *= minf(1.0, t * fade_hold)
			mm.set_instance_color(i, c)
			i += 1
		mm.visible_instance_count = n

	func clear() -> void:
		n = 0; mm.visible_instance_count = 0

func _ready() -> void:
	var cube := BoxMesh.new(); cube.size = Vector3.ONE
	var solid_mat := StandardMaterial3D.new(); solid_mat.vertex_color_use_as_albedo = true; solid_mat.roughness = .55; solid_mat.metallic = .2
	solid = Pool.new(self, cube, solid_mat, 2200, false)
	var glow_mat := StandardMaterial3D.new(); glow_mat.vertex_color_use_as_albedo = true; glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow = Pool.new(self, cube, glow_mat, 1800, false)
	var ball := SphereMesh.new(); ball.radius = .5; ball.height = 1.0; ball.radial_segments = 10; ball.rings = 6
	var puff_mat := StandardMaterial3D.new(); puff_mat.vertex_color_use_as_albedo = true; puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.roughness = 1.0; puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX; puff_mat.vertex_color_is_srgb = true
	puff = Pool.new(self, ball, puff_mat, 900, true); puff.fade_hold = 1.8
	var fire_mat := StandardMaterial3D.new(); fire_mat.vertex_color_use_as_albedo = true; fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fire_mat.render_priority = 1  # fire draws over smoke
	fire_mat.vertex_color_is_srgb = true  # colours below are authored as sRGB
	fire = Pool.new(self, ball, fire_mat, 600, true); fire.fade_hold = 2.8
	number_font = FontVariation.new(); number_font.base_font = load("res://assets/fonts/Orbitron.ttf")
	number_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	for i in range(40):
		var l := Label3D.new(); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.font = number_font
		l.font_size = 44; l.outline_size = 10; l.outline_modulate = Color("111b35"); l.pixel_size = .01; l.visible = false
		add_child(l); numbers.append(l); number_vel.append(Vector3.ZERO)
	number_life.resize(40)

func _amount() -> float:
	return clampf(game.settings.effects, 0.0, 1.0) if is_instance_valid(game) else 1.0

func _count(base: int) -> int:
	return maxi(1, int(round(base * (.25 + .75 * _amount()))))

func _process(delta: float) -> void:
	if is_instance_valid(game) and game.state == "paused": return
	solid.update(delta); glow.update(delta); puff.update(delta); fire.update(delta)
	for i in range(numbers.size()):
		if number_life[i] <= 0: continue
		number_life[i] -= delta
		var l := numbers[i]
		l.position += number_vel[i] * delta
		number_vel[i].y -= 3.0 * delta
		l.modulate.a = clampf(number_life[i] / .35, 0, 1)
		if number_life[i] <= 0: l.visible = false

func clear() -> void:
	solid.clear(); glow.clear(); puff.clear(); fire.clear(); scorches.clear()
	for i in range(numbers.size()): number_life[i] = 0; numbers[i].visible = false
	for c in get_children():
		if c.is_in_group("fx_temp"): c.queue_free()

static func _rand_dir() -> Vector3:
	return Vector3(randf()-.5, randf()-.5, randf()-.5).normalized()

# ---------------------------------------------------------------- weapon effects
func muzzle(p: Vector3, dir: Vector3, c: Color, strength := 1.0) -> void:
	for i in range(_count(int(5 * strength))):
		glow.emit(p, (dir * randf_range(3, 7) + _rand_dir() * 1.6) * strength, randf_range(.05, .11), randf_range(.03, .06), c * 3.0, 0, 4, 0, 0)
	_flash_mesh(p, c, .13 * strength, .06)

func shell(p: Vector3, dir: Vector3) -> void:
	if _amount() < .3: return
	var side := dir.cross(Vector3.UP).normalized() * -1.0
	solid.emit(p, side * randf_range(1.6, 2.6) + Vector3.UP * randf_range(1.5, 2.6), randf_range(.9, 1.4), .045, Color("d8b04a"), 9.8, .4, 0, 18)

func sparks(p: Vector3, c: Color, n := 6, speed := 3.5) -> void:
	for i in range(_count(n)):
		var v := _rand_dir() * randf_range(.4, 1.0) * speed; v.y = absf(v.y) + 1.0
		glow.emit(p, v, randf_range(.15, .32), randf_range(.03, .055), c * 2.5, 6, 1.5, 0, 0)

func trail(p: Vector3, c: Color, big := 1.0) -> void:
	puff.emit(p + _rand_dir() * .05, Vector3.UP * .35 + _rand_dir() * .15, randf_range(.5, .8) * big, .22 * big, c, 0, 1.2, 1.6, 0)

# Glowing crescent for blade swings: a ribbon over a ~150 degree arc around the aim, fading out fast.
func slash(center: Vector3, dir: Vector3, radius: float, c: Color) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := atan2(dir.x, dir.z)
	var steps := 18
	for i in range(steps):
		var a0 := base - 1.3 + 2.6 * i / steps; var a1 := base - 1.3 + 2.6 * (i + 1) / steps
		var w0 := sin(PI * float(i) / steps); var w1 := sin(PI * float(i + 1) / steps)
		var o0 := Vector3(sin(a0), 0, cos(a0)); var o1 := Vector3(sin(a1), 0, cos(a1))
		var p0 := o0 * radius; var p1 := o1 * radius
		var q0 := o0 * (radius - .55 * w0); var q1 := o1 * (radius - .55 * w1)
		for v in [q0, p0, p1, q0, p1, q1]: st.add_vertex(v)
	var m := MeshInstance3D.new(); m.mesh = st.commit()
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.albedo_color = Color(c.r * 2.2, c.g * 2.2, c.b * 2.2, .85)
	m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = center; m.add_to_group("fx_temp"); add_child(m)
	var tw := m.create_tween(); tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, .2)
	tw.tween_property(m, "rotation:y", -.35, .2)
	tw.chain().tween_callback(m.queue_free)
	for i in range(_count(10)):
		var a := base - 1.2 + 2.4 * randf()
		var p := center + Vector3(sin(a), 0, cos(a)) * radius * randf_range(.75, 1.0)
		glow.emit(p, Vector3(sin(a), .3, cos(a)) * randf_range(1, 2.5), randf_range(.15, .3), .05, c * 3.0, 0, 2, 0, 0)

# One segment of a blade swing trail: the quad between last frame's and this frame's hilt/tip, fading fast.
# real_time: fades on the wall clock (kill cam replay), so the trail clears even while time is nearly frozen.
func blade_quad(h0: Vector3, t0: Vector3, h1: Vector3, t1: Vector3, c: Color, real_time := false) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hot := Color(c.r * 1.8, c.g * 1.8, c.b * 1.8, .7); var clear := Color(c.r, c.g, c.b, 0.0)
	# tapered: transparent at the hilt, bright along the tip edge
	for pair in [[h0, clear], [t0, hot], [t1, hot], [h0, clear], [t1, hot], [h1, clear]]:
		st.set_color(pair[1]); st.add_vertex(pair[0])
	var m := MeshInstance3D.new(); m.mesh = st.commit()
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1); m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.add_to_group("fx_temp"); add_child(m)
	var tw := m.create_tween(); tw.set_ignore_time_scale(real_time); tw.tween_property(mat, "albedo_color:a", 0.0, .4 if real_time else .13); tw.tween_callback(m.queue_free)
	if randf() < .4: glow.emit(t1, (t1 - t0) * 8.0 + _rand_dir() * .4, .18, .04, c * 3.0, 0, 3, 0, 0)

func dust(p: Vector3) -> void:
	if _amount() < .4: return
	puff.emit(p + _rand_dir() * .05, Vector3(randf_range(-.3, .3), .35, randf_range(-.3, .3)), randf_range(.4, .6), .16, Color(.88, .89, .92, .55), 0, 2.0, 1.6, 0)

func ember(p: Vector3, c: Color) -> void:
	glow.emit(p, _rand_dir() * .5, randf_range(.12, .22), .05, c * 3.0, 0, 3, 0, 0)

func explosion(p: Vector3, radius: float, c: Color) -> void:
	var ground := Vector3(p.x, .05, p.z)
	# fireball: additive HDR puffs that swell and burn out from yellow-white to deep orange
	for i in range(_count(18)):
		var v := _rand_dir(); v.y = absf(v.y) * .8 + .2
		var hot := Color(1.25, .95, .35, 1) if i % 4 == 0 else (Color(1.15, .5, .08, 1) if i % 4 < 3 else Color(.85, .2, .04, 1))
		fire.emit(p + Vector3.UP * .4 + v * randf_range(.1, .5) * radius * .3, v * randf_range(1.5, 4.0) * radius * .35, randf_range(.22, .42), randf_range(.6, 1.0) * radius * .4, hot, -1.5, 3.0, 1.5, 0)
	fire.emit(p + Vector3.UP * .5, Vector3.ZERO, .09, radius * .4, Color(1.6, 1.3, .7, .95), 0, 0, .8, 0)
	# smoke column: dark puffs that rise and spread long after the fire
	for i in range(_count(14)):
		var v := _rand_dir(); v.y = absf(v.y) + .4
		puff.emit(p + Vector3.UP * .6 + v * .3, v * randf_range(.6, 1.8) + Vector3.UP * 1.0, randf_range(1.5, 2.5), randf_range(.3, .5) * radius * .35,
			Color(.16, .16, .18, .55) if i % 2 else Color(.34, .35, .38, .5), -.7, 1.0, 4.0, 0)
	# dust skirt along the floor
	for i in range(_count(16)):
		var a := TAU * i / 16.0
		var out := Vector3(cos(a), 0, sin(a))
		puff.emit(ground + out * .4, out * randf_range(4, 7) + Vector3.UP * .2, randf_range(.5, .8), .35, Color(.82, .83, .86, .55), 0, 4.0, 1.5, 0)
	_ring(p, c, radius * 1.2, .32)
	_ring(p, Color(1, .85, .55), radius * .7, .2)
	var light := OmniLight3D.new(); light.light_color = Color(1, .62, .3); light.light_energy = 9.0; light.omni_range = radius * 3.0
	light.position = p + Vector3.UP * 1.0; light.add_to_group("fx_temp"); add_child(light)
	var tw := light.create_tween(); tw.tween_property(light, "light_energy", 0.0, .35); tw.tween_callback(light.queue_free)
	for i in range(_count(30)):  # sparks
		var v := _rand_dir(); v.y = absf(v.y) + .3
		glow.emit(p + Vector3.UP * .3, v * randf_range(5, 11), randf_range(.3, .7), randf_range(.035, .07), Color(4, 2.2, .7), 12, .6, 0, 0)
	for i in range(_count(14)):  # chunks
		var v := _rand_dir(); v.y = absf(v.y) + .6
		solid.emit(p + Vector3.UP * .2, v * randf_range(3.5, 8), randf_range(1.2, 2.0), randf_range(.06, .13), Color("2b3640") if i % 2 else Color("8a929c"), 13, .2, 0, 12)
	_scorch(ground, radius)

func _scorch(p: Vector3, radius: float) -> void:
	var m := MeshInstance3D.new(); var disc := CylinderMesh.new(); disc.top_radius = radius * .55; disc.bottom_radius = radius * .55; disc.height = .01; disc.radial_segments = 20; m.mesh = disc
	var mat := StandardMaterial3D.new(); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = Color(.06, .06, .07, .55); mat.roughness = 1
	m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.position = p + Vector3.UP * (.02 + scorches.size() * .001)
	m.rotation.y = randf() * TAU; m.scale = Vector3(1, 1, randf_range(.8, 1.1)); m.add_to_group("fx_temp"); add_child(m)
	scorches.append(m)
	if scorches.size() > 14:
		var old: MeshInstance3D = scorches.pop_front()
		if is_instance_valid(old): old.queue_free()
	var tw := m.create_tween(); tw.tween_interval(4.0); tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(func(): scorches.erase(m); m.queue_free())

func exhaust(p: Vector3, back: Vector3) -> void:
	fire.emit(p, back * randf_range(1.5, 3) + _rand_dir() * .3, randf_range(.08, .14), randf_range(.14, .2), Color(1.3, .6, .12, .95), 0, 2, 1.0, 0)
	puff.emit(p + back * .15 + _rand_dir() * .06, back * .6 + Vector3.UP * .3 + _rand_dir() * .2, randf_range(.9, 1.4), .2, Color(.86, .87, .9, .65), -.15, 1.4, 2.4, 0)

# Growing orb at the railgun muzzle while it charges (one short-lived particle per frame).
func charge_orb(p: Vector3, amount: float, c: Color) -> void:
	fire.emit(p, Vector3.ZERO, .05, .06 + amount * .22, Color(c.r * 1.8, c.g * 1.8, c.b * 1.8, .85), 0, 0, 0, 0)
	if randf() < .5:
		var from := p + _rand_dir() * randf_range(.35, .6)
		glow.emit(from, (p - from) * 5.0, .12, .03, c * 3.0, 0, 0, 0, 0)

func rail_beam(a: Vector3, b: Vector3, c: Color, carrier: Node3D = null) -> void:
	var host: Node3D = carrier if is_instance_valid(carrier) else self
	var v := b - a
	if v.length() < .05: return
	var q := Quaternion(Vector3.UP, v.normalized())
	for layer in [[.05, Color(1, 1, 1), 4.0], [.16, c, 2.5]]:
		var m := MeshInstance3D.new(); var cyl := CylinderMesh.new()
		cyl.top_radius = layer[0]; cyl.bottom_radius = layer[0]; cyl.height = v.length(); cyl.radial_segments = 10; m.mesh = cyl
		var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = layer[1] * layer[2]; mat.albedo_color.a = .9 if layer[0] < .1 else .45
		m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_to_group("fx_temp"); host.add_child(m); m.global_position = (a + b) * .5; m.global_basis = Basis(q)
		var tw := m.create_tween(); tw.set_parallel(true)
		tw.tween_property(m, "scale", Vector3(.2, 1, .2), .35)
		tw.tween_property(mat, "albedo_color:a", 0.0, .35)
		tw.chain().tween_callback(m.queue_free)
	var steps := int(v.length() / 1.6)
	for i in range(steps):
		var p := a + v * (float(i) + .5) / steps
		var ring := MeshInstance3D.new(); var tor := TorusMesh.new(); tor.inner_radius = .14; tor.outer_radius = .2; tor.rings = 12; tor.ring_segments = 6; ring.mesh = tor
		var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = c * 2.0; mat.albedo_color.a = .8; ring.material_override = mat; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.add_to_group("fx_temp"); host.add_child(ring); ring.global_position = p; ring.global_basis = Basis(q)
		var tw := ring.create_tween(); tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3.ONE * 2.6, .4).set_delay(i * .012)
		tw.tween_property(mat, "albedo_color:a", 0.0, .4).set_delay(i * .012)
		tw.chain().tween_callback(ring.queue_free)
	for i in range(_count(int(v.length() * 1.5))):
		glow.emit(a + v * randf(), _rand_dir() * .8 + Vector3.UP * .4, randf_range(.3, .6), .045, c * 3.0, 0, 1.5, 0, 0)

func _flash_mesh(p: Vector3, c: Color, radius: float, duration: float) -> void:
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0; s.radial_segments = 12; s.rings = 6; m.mesh = s
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(c.r * 3, c.g * 3, c.b * 3, .95); m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p; m.scale = Vector3.ONE * radius * .4; m.add_to_group("fx_temp"); add_child(m)
	var tw := m.create_tween(); tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * radius, duration)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(m.queue_free)

func _ring(p: Vector3, c: Color, radius: float, duration: float) -> void:
	var m := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = .86; t.outer_radius = 1.0; t.rings = 32; t.ring_segments = 4; m.mesh = t
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(c.r * 2, c.g * 2, c.b * 2, .8); m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p + Vector3.UP * .06; m.scale = Vector3(.2, .05, .2); m.add_to_group("fx_temp"); add_child(m)
	var tw := m.create_tween(); tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(radius, .05, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(m.queue_free)

# ---------------------------------------------------------------- enemies
func number(p: Vector3, amount: float, c := Color.WHITE) -> void:
	if amount < .5: return
	var i := number_next; number_next = (number_next + 1) % numbers.size()
	var l := numbers[i]
	l.text = str(roundi(amount)); l.modulate = c; l.position = p + Vector3(randf_range(-.3, .3), 0, randf_range(-.2, .2))
	l.font_size = 40 if amount < 40 else 58
	l.visible = true; number_vel[i] = Vector3(randf_range(-.4, .4), 2.6, 0); number_life[i] = .75

# Breaks an enemy into voxels. mode: kinetic (shatter), explosive (blown apart) or energy (glowing disintegration).
func disintegrate(center: Vector3, scale: float, mode: String, dir: Vector3, c: Color) -> void:
	var body := [Color("2a2e35"), Color("1c2027"), Color("3b414b")]
	var count := _count(34 if mode != "energy" else 46)
	for i in range(count):
		var local := Vector3(randf_range(-.26, .26), randf_range(.05, 1.3), randf_range(-.2, .2)) * scale
		var p := center + local
		var s := randf_range(.07, .13) * scale
		match mode:
			"energy":
				if i % 3 == 0:
					solid.emit(p, dir * randf_range(.5, 1.5) + _rand_dir() * .6, randf_range(.6, 1.0), s * .8, body[i % 3], 6.0, .5, 0, 4)
				else:
					glow.emit(p, Vector3.UP * randf_range(.6, 1.8) + _rand_dir() * .5 + dir * .4, randf_range(.6, 1.2), s * .75, c * randf_range(1.8, 3.2), -.6, 1.4, 0, 3)
			"explosive":
				var out := (local.normalized() + Vector3.UP * .6 + dir * .5).normalized()
				solid.emit(p, out * randf_range(4, 8.5), randf_range(1.2, 2.0), s, body[i % 3], 12.0, .25, 0, 12)
				if i % 4 == 0: glow.emit(p, out * randf_range(3, 6), randf_range(.3, .6), s * .6, Color("ff8a3c") * 3.0, 9.8, .6, 0, 0)
			_:
				var v := dir * randf_range(1.2, 3.6) + _rand_dir() * 1.5 + Vector3.UP * randf_range(.8, 2.8)
				solid.emit(p, v, randf_range(1.2, 2.0), s, body[i % 3], 11.0, .3, 0, 9)
	for i in range(_count(3)):  # the ember eyes pop out as glowing chips
		glow.emit(center + Vector3(0, 1.0 * scale, 0), _rand_dir() * 2.0 + Vector3.UP * 2.0, randf_range(.35, .6), .06 * scale, Color("ff5a2c") * 3.0, 9.8, .5, 0, 0)
	if mode == "energy": _flash_mesh(center + Vector3.UP * .7 * scale, c, .8 * scale, .25)
	else: sparks(center + Vector3.UP * .7 * scale, Color("ffb35a"), 5, 4.0)
