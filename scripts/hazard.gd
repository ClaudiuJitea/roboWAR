extends Node3D
class_name Hazard
## A glowing patch of floor that hurts fighters standing in it (the Forge Titan's molten pools).

var game: Node
var radius := 1.6
var life := 5.0
var dps := 14.0
var color := Color("ff6a1a")
var tick := 0.0
var disc_mat: StandardMaterial3D

func _ready() -> void:
	var disc:=MeshInstance3D.new(); var plate:=CylinderMesh.new(); plate.top_radius=radius; plate.bottom_radius=radius; plate.height=.02; plate.radial_segments=24
	disc.mesh=plate; disc_mat=StandardMaterial3D.new(); disc_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; disc_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.albedo_color=Color(color.r*2.2,color.g*2.2,color.b*2.2,.7); disc.material_override=disc_mat; disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y=.04; add_child(disc)
	var light:=OmniLight3D.new(); light.light_color=color; light.light_energy=1.5; light.omni_range=radius*2.2; light.position.y=.6; add_child(light)
	scale=Vector3(.2,1,.2)
	create_tween().tween_property(self,"scale",Vector3.ONE,.25)

func _physics_process(delta: float) -> void:
	if game.state!="playing": return
	life-=delta
	disc_mat.albedo_color.a=clampf(life/1.0,0,1)*(.55+.15*sin(Time.get_ticks_msec()*.012))
	if randf()<.4: game.fx.ember(global_position+Vector3(randf_range(-1,1),.1,randf_range(-1,1))*radius*.8,color)
	if life<=0: queue_free(); return
	tick-=delta
	if tick>0: return
	tick=.25
	for h in game.heroes:
		if is_instance_valid(h) and not h.dead and not h.downed and Vector2(h.global_position.x-global_position.x,h.global_position.z-global_position.z).length()<radius:
			game.hurt(h,dps*.25,null,global_position,"fire")
