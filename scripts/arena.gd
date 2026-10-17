extends Node3D

const LAYOUT_PATH := "res://assets/arena_layout.json"
const ARENA_MODELS := {"white":"res://assets/models/arena.glb","black":"res://assets/models/arena_black.glb","cryo":"res://assets/models/arena_cryo.glb",
 "toxic":"res://assets/models/arena_toxic.glb","core":"res://assets/models/arena_core.glb"}
# Lighting per dark environment (white keeps the defaults below): key light, sky, fog, glow and coloured work lights.
const MOODS := {
 "black":{"energy":1.25,"sun":Color("e8ecff"),"sky":[Color("2a1416"),Color("4a2226"),Color("140b0c"),Color("3a1c1f")],"bg":Color("0c0b0d"),"ambient":.75,
  "glow":[.9,.9,.08],"grade":[1.12,1.08],"fog":[Color("3a1418"),.004],"lamps":[Color("ff3040")],"lamp_energy":1.6},
 "cryo":{"energy":1.6,"sun":Color("e6f4ff"),"sky":[Color("8fb6d6"),Color("dbe9f2"),Color("9fb8c9"),Color("dbe9f2")],"bg":Color("c9dbe6"),"ambient":.65,
  "glow":[.6,1.1,.0],"grade":[.95,1.04],"fog":[Color("d6e8f2"),.006],"lamps":[Color("7fe0ff")],"lamp_energy":1.0},
 "toxic":{"energy":1.1,"sun":Color("f2ffe0"),"sky":[Color("1a2112"),Color("2c3a1c"),Color("0e120a"),Color("26321a")],"bg":Color("0d100a"),"ambient":.7,
  "glow":[.9,.9,.08],"grade":[1.1,1.08],"fog":[Color("2c4a14"),.006],"lamps":[Color("8cff3a")],"lamp_energy":1.5},
 "core":{"energy":1.0,"sun":Color("e8e0ff"),"sky":[Color("1a1028"),Color("2e1a45"),Color("0d0814"),Color("261540")],"bg":Color("0b0812"),"ambient":.7,
  "glow":[1.0,.85,.1],"grade":[1.12,1.1],"fog":[Color("2a1640"),.005],"lamps":[Color("a050ff"),Color("ff4fd8")],"lamp_energy":1.8},
}
var theme := "white"  # set by game.gd before the arena enters the tree
var obstacles: Array[Rect2] = []
var grid: AStarGrid2D
var sun: DirectionalLight3D
var world_env: WorldEnvironment

func _ready() -> void:
 _build()

func _v3(a: Array) -> Vector3:
 return Vector3(a[0],a[1],a[2])

func solid(label: String, pos: Vector3, size: Vector3, block_ground := true) -> void:
 var body := StaticBody3D.new()
 body.name = label
 body.position = pos
 body.collision_layer = 1
 var collision := CollisionShape3D.new()
 var cs := BoxShape3D.new()
 cs.size = size
 collision.shape = cs
 body.add_child(collision)
 add_child(body)
 if block_ground:
  obstacles.append(Rect2(Vector2(pos.x-size.x/2.0, pos.z-size.z/2.0), Vector2(size.x,size.z)))

func _build() -> void:
 # campaign environments have their own wall layout; the Blender visuals are built from the same file
 var own: String="res://assets/arena_layout_%s.json" % theme
 var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(own if FileAccess.file_exists(own) else LAYOUT_PATH))
 solid("floor",_v3(layout.floor.pos),_v3(layout.floor.size),false)
 for entry in layout.perimeter: solid("perimeter_wall",_v3(entry[0]),_v3(entry[1]))
 for entry in layout.walls: solid("modular_wall",_v3(entry[0]),_v3(entry[1]))
 solid("cargo_body",_v3(layout.cargo.pos),_v3(layout.cargo.size))
 # Visual geometry is authored in Blender: source_art/blender/build_arena.py
 var path: String=ARENA_MODELS.get(theme,ARENA_MODELS.white)
 if not ResourceLoader.exists(path): path=ARENA_MODELS.white
 var visual: Node3D = load(path).instantiate()
 visual.name = "ArenaVisual"
 add_child(visual)
 var floor_mesh := visual.find_child("ArenaFloor",true,false) as GeometryInstance3D
 if floor_mesh: floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var light := DirectionalLight3D.new()
 # Low, raking sun from the far right throws long shadows toward the lower left.
 light.rotation_degrees = Vector3(-36,148,0)
 light.light_energy = 1.9
 light.light_color = Color("fff6ea")
 light.shadow_enabled = true
 light.shadow_blur = 1.0
 light.shadow_opacity = 1.0
 light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 light.directional_shadow_max_distance = 80
 add_child(light)
 sun=light
 world_env = WorldEnvironment.new()
 var env := Environment.new()
 var sky := Sky.new()
 var sky_mat := ProceduralSkyMaterial.new()
 sky_mat.sky_top_color = Color("6f8fc4")
 sky_mat.sky_horizon_color = Color("c9d6e6")
 sky_mat.ground_bottom_color = Color("8496ad")
 sky_mat.ground_horizon_color = Color("c9d6e6")
 sky.sky_material = sky_mat
 env.sky = sky
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("b8c4cf")
 # Blue sky fill gives the cool, readable shadows of the reference shots.
 env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 env.ambient_light_energy = .55
 env.ambient_light_sky_contribution = 1.0
 env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
 env.tonemap_mode = Environment.TONE_MAPPER_AGX
 env.tonemap_exposure = 1.0
 env.ssao_enabled = true
 env.ssao_radius = 1.4
 env.ssao_intensity = 1.6
 env.ssao_power = 1.4
 env.glow_enabled = true
 env.glow_intensity = .5
 env.glow_hdr_threshold = 1.2
 env.adjustment_enabled = true
 env.adjustment_saturation = 1.08
 env.adjustment_contrast = 1.04
 if MOODS.has(theme):
  var m: Dictionary=MOODS[theme]
  light.light_energy=m.energy; light.light_color=m.sun
  sky_mat.sky_top_color=m.sky[0]; sky_mat.sky_horizon_color=m.sky[1]
  sky_mat.ground_bottom_color=m.sky[2]; sky_mat.ground_horizon_color=m.sky[3]
  env.background_color=m.bg
  env.ambient_light_energy=m.ambient
  env.glow_intensity=m.glow[0]; env.glow_hdr_threshold=m.glow[1]; env.glow_bloom=m.glow[2]
  env.adjustment_saturation=m.grade[0]; env.adjustment_contrast=m.grade[1]
  env.fog_enabled=true; env.fog_light_color=m.fog[0]; env.fog_density=m.fog[1]
  # coloured work lights over the arena
  var k:=0
  for p in [Vector3(-14,5,-6),Vector3(14,5,-6),Vector3(-14,5,8),Vector3(14,5,8),Vector3(0,5,1)]:
   var omni:=OmniLight3D.new(); omni.position=p; omni.light_color=m.lamps[k%m.lamps.size()]; omni.light_energy=m.lamp_energy; omni.omni_range=11.0
   omni.shadow_enabled=false; add_child(omni); k+=1
 world_env.environment = env
 add_child(world_env)
 _make_grid()

func set_effects(level: float) -> void:
 if is_instance_valid(sun): sun.shadow_enabled = level >= .5
 if is_instance_valid(world_env):
  world_env.environment.ssao_enabled = level >= .75
  world_env.environment.glow_enabled = level >= .25

func _make_grid() -> void:
 grid=AStarGrid2D.new()
 grid.region=Rect2i(-22,-17,45,35)
 grid.cell_size=Vector2.ONE
 grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 grid.update()
 for x in range(-22,23):
  for z in range(-17,18):
   var p:=Vector3(x,0,z)
   if not valid_spawn(p): grid.set_point_solid(Vector2i(x,z))

func path_direction(from: Vector3, toward: Vector3) -> Vector3:
 if grid==null: return (toward-from).normalized()
 var a:=Vector2i(roundi(from.x),roundi(from.z))
 var b:=Vector2i(roundi(toward.x),roundi(toward.z))
 a.x=clampi(a.x,-22,22); a.y=clampi(a.y,-17,17)
 b.x=clampi(b.x,-22,22); b.y=clampi(b.y,-17,17)
 if grid.is_point_solid(a) or grid.is_point_solid(b): return (toward-from).normalized()
 var route:=grid.get_point_path(a,b)
 if route.size()<2: return (toward-from).normalized()
 var index:=1
 if route.size()>2 and Vector2(from.x,from.z).distance_to(route[1])<.45: index=2
 var dir:=Vector3(route[index].x-from.x,0,route[index].y-from.z)
 return dir.normalized()

func valid_spawn(p: Vector3) -> bool:
 if absf(p.x)>21.8 or absf(p.z)>16.8: return false
 for r in obstacles:
  if r.grow(.8).has_point(Vector2(p.x,p.z)): return false
 return true
