extends Node3D
class_name HealthPickup
## Dropped by robots: the green repair kit, or a power-up (Data.POWERUPS) shown as a coloured disc with its tag.

const Data = preload("res://scripts/data.gd")
var game: Node
var kind := "health"
var life := 18.0
var spin := 0.0
var bob: Node3D

func _ready() -> void:
	var p: Dictionary=Data.POWERUPS[kind]
	var c: Color=p.color
	bob=Node3D.new(); add_child(bob)
	var base:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=.34; mesh.bottom_radius=.34; mesh.height=.12; base.mesh=mesh
	var mat:=StandardMaterial3D.new(); mat.albedo_color=c.darkened(.35); mat.emission_enabled=true; mat.emission=c; mat.emission_energy_multiplier=1.4; base.material_override=mat; base.position.y=.13; bob.add_child(base)
	var sign:=Label3D.new(); sign.text=p.glyph; sign.font_size=70 if kind=="health" else 44; sign.pixel_size=.008; sign.position.y=.45; sign.modulate=c.lightened(.6)
	sign.outline_size=8; sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED; bob.add_child(sign)
	if kind!="health":  # power-ups glow and float so they read apart from the repair kit
		var light:=OmniLight3D.new(); light.light_color=c; light.light_energy=1.2; light.omni_range=2.0; light.position.y=.5; add_child(light)

func _process(delta: float) -> void:
	if game.state!="playing": return
	life-=delta; spin+=delta; bob.rotation.y=spin*1.6
	if kind!="health": bob.position.y=.12+sin(spin*3.0)*.08
	if life<3.0: visible=int(life*6.0)%2==0  # blinks before it expires
	if life<=0: queue_free(); return
	for h in game.heroes:
		if not is_instance_valid(h) or h.dead or h.downed: continue
		if h.global_position.distance_to(global_position)<1.0:
			h.apply_powerup(kind)
			game.flash(global_position+Vector3.UP,Data.POWERUPS[kind].color,.5); game.play_sfx("pickup"); queue_free(); return
