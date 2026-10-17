extends Node3D
class_name SectorProjectile
## Moving shots: enemy orbs, plasma orbs, rockets (smoke trail, explode on impact), lobbed grenades and robot
## mortar shells (lobbed, with a warning ring where they will land).

var game: Node
var source: SectorActor
var direction := Vector3.FORWARD
var speed := 12.0
var damage := 10.0
var life := 3.0
var radius := .23
var color := Color.WHITE
var cruise_y := -1.0 # height the shot settles to after leaving the muzzle (<0 keeps its height)
var kind := "enemy"  # enemy, plasma, rocket, grenade, shell
var landing := Vector3.ZERO  # shell: where it will come down (the warning ring sits there)
var radius_damage := 0.0
var knock := .8
var mesh_override: Mesh
var velocity := Vector3.ZERO
var fuse := -1.0
var bounces := 0
var trail_timer := 0.0
var visual: Node3D
var danger: MeshInstance3D
var danger_mat: StandardMaterial3D
var blink: OmniLight3D

func setup(g: Node, s: SectorActor, dir: Vector3, amount: float, c: Color, v: float) -> void:
 game=g; source=s; direction=dir.normalized(); damage=amount; color=c; speed=v

# Ballistic arc that lands on target after a fixed flight time.
func lob(from: Vector3, target: Vector3) -> void:
 var t:=clampf(from.distance_to(target)/11.0,.45,1.1)
 var g:=16.0
 velocity=Vector3((target.x-from.x)/t,(target.y+.15-from.y+.5*g*t*t)/t,(target.z-from.z)/t)
 life=4.0

func _ready() -> void:
 if mesh_override:
  var m:=MeshInstance3D.new(); m.mesh=mesh_override; m.scale=Vector3.ONE*(1.0 if kind=="rocket" else 1.25)  # rocket: same size as the loaded one
  m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  visual=Node3D.new(); visual.add_child(m); add_child(visual)
  if kind=="rocket": m.rotation.y=PI  # Blender front (-Y) imports facing +Z
 else:
  var mesh:=MeshInstance3D.new(); var ball:=SphereMesh.new()
  var r:=.17 if kind=="plasma" else radius
  ball.radius=r; ball.height=r*2; ball.radial_segments=12; ball.rings=6; mesh.mesh=ball
  var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color=Color(color.r*1.6,color.g*1.6,color.b*1.6) if kind=="plasma" else Color(color.r*3,color.g*3,color.b*3)
  mesh.material_override=mat; mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mesh)
  if kind=="plasma":
   var halo:=MeshInstance3D.new(); var hb:=SphereMesh.new(); hb.radius=.26; hb.height=.52; halo.mesh=hb
   var hm:=StandardMaterial3D.new(); hm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; hm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
   hm.albedo_color=Color(color.r,color.g,color.b,.28); halo.material_override=hm; halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(halo)
 if kind=="rocket" or kind=="plasma":
  var light:=OmniLight3D.new(); light.light_color=color; light.light_energy=1.4; light.omni_range=2.5; add_child(light)
 _face(direction if kind!="grenade" else velocity)
 if kind=="shell":
  danger=MeshInstance3D.new(); var ring:=TorusMesh.new(); ring.inner_radius=.9; ring.outer_radius=1.0; ring.rings=40; ring.ring_segments=3; danger.mesh=ring
  danger_mat=StandardMaterial3D.new(); danger_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; danger_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  danger_mat.albedo_color=Color(1.6,.25,.2,.5); danger.material_override=danger_mat; danger.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  danger.top_level=true; danger.scale=Vector3(radius_damage,.02,radius_damage); add_child(danger)
 if kind=="grenade":
  # blast-radius ring on the floor under the grenade, and a blinking fuse light
  danger=MeshInstance3D.new(); var t:=TorusMesh.new(); t.inner_radius=.93; t.outer_radius=1.0; t.rings=40; t.ring_segments=3; danger.mesh=t
  danger_mat=StandardMaterial3D.new(); danger_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; danger_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  danger_mat.albedo_color=Color(color.r*1.5,color.g*1.5,color.b*1.5,.0); danger.material_override=danger_mat; danger.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  danger.top_level=true; danger.scale=Vector3(radius_damage,.02,radius_damage); add_child(danger)
  blink=OmniLight3D.new(); blink.light_color=Color("ff4a3a"); blink.light_energy=0; blink.omni_range=2.2; add_child(blink)

func _face(dir: Vector3) -> void:
 if is_instance_valid(visual) and dir.length_squared()>.001:
  visual.look_at(global_position+dir if is_inside_tree() else position+dir,Vector3.UP if absf(dir.normalized().y)<.98 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
 if game.state!="playing": return
 life-=delta
 if life<=0: _finish(global_position,null); return
 trail_timer-=delta
 if kind=="grenade": _grenade(delta); return
 if kind=="shell": _shell(delta); return
 var start:=global_position; var finish:=start+direction*speed*delta
 if direction.y<0 and cruise_y>=0 and finish.y<=cruise_y:  # dived onto the aim point: level off at cruise height
  finish.y=cruise_y; direction=Vector3(direction.x,0,direction.z).normalized(); _face(direction)
 elif cruise_y>=0 and direction.y==0: finish.y=move_toward(start.y,cruise_y,delta*speed*.25)
 if trail_timer<=0:
  if kind=="rocket":
   trail_timer=.018; game.fx.exhaust(start-direction*.38,-direction)
  elif kind=="plasma":
   trail_timer=.03; game.fx.ember(start,color)
 var q:=PhysicsRayQueryParameters3D.create(start,finish,1|2|4)
 if is_instance_valid(source): q.exclude=[source.get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(q)
 if not hit.is_empty():
  var victim=hit.collider
  if victim is SectorActor and is_instance_valid(source) and victim.team==source.team:
   global_position=finish; return  # pass through allies
  _finish(hit.position,victim)
 else: global_position=finish

func _grenade(delta: float) -> void:
 if is_instance_valid(danger):
  danger.global_position=Vector3(global_position.x,.06,global_position.z)
  var pulse:=.35+.25*sin(Time.get_ticks_msec()*.025)
  danger_mat.albedo_color.a=pulse if fuse>=0 else .22
 if is_instance_valid(blink): blink.light_energy=3.0 if int(Time.get_ticks_msec()/90)%2==0 and fuse>=0 else (0.6 if fuse<0 else 0.0)
 if fuse>=0:
  fuse-=delta
  if fuse<=0: _finish(global_position,null)
  return
 velocity.y-=16.0*delta
 var start:=global_position; var finish:=start+velocity*delta
 if trail_timer<=0: trail_timer=.03; game.fx.trail(start,Color(.86,.88,.92,.6),.8); game.fx.ember(start,color)
 if is_instance_valid(visual): visual.rotate_x(delta*9.0)
 var q:=PhysicsRayQueryParameters3D.create(start,finish,1|2|4)
 if is_instance_valid(source): q.exclude=[source.get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(q)
 if hit.is_empty(): global_position=finish; return
 if hit.collider is SectorActor and is_instance_valid(source) and hit.collider.team!=source.team: _finish(hit.position,hit.collider); return
 # bounce off floor and walls, then settle and cook off
 global_position=hit.position+hit.normal*.12
 velocity=velocity.bounce(hit.normal)*.42
 bounces+=1
 game.fx.sparks(hit.position,color,3,2.0)
 if bounces>=2 or velocity.length()<2.5: velocity=Vector3.ZERO; fuse=.45; game.play_sfx("switch")

# Robot mortar shell: falls on its arc and bursts on the first thing it touches (floor, wall or fighter).
func _shell(delta: float) -> void:
 if is_instance_valid(danger):
  danger.global_position=Vector3(landing.x,.06,landing.z)
  danger_mat.albedo_color.a=.35+.3*sin(Time.get_ticks_msec()*.02)
 velocity.y-=16.0*delta
 var start:=global_position; var finish:=start+velocity*delta
 if trail_timer<=0: trail_timer=.03; game.fx.ember(start,color)
 var q:=PhysicsRayQueryParameters3D.create(start,finish,1|2)
 var hit:=get_world_3d().direct_space_state.intersect_ray(q)
 if hit.is_empty(): global_position=finish; return
 _finish(hit.position,hit.collider)

func _finish(pos: Vector3, victim) -> void:
 match kind:
  "shell":
   game.blast(pos,radius_damage,damage,source if is_instance_valid(source) else null,color,0)
  "rocket","grenade":
   game.explode(pos,radius_damage,damage,source,color,knock)
   if victim is SectorActor and is_instance_valid(source) and victim.team!=source.team: game.hurt(victim,damage*.35,source,pos-direction,"explosive",knock)
  "plasma":
   if victim is SectorActor and is_instance_valid(source) and victim.team!=source.team: game.hurt(victim,damage,source,pos-direction,"energy",knock)
   game.fx.sparks(pos,color,7,3.0)
   game.fx.muzzle(pos,-direction,color,1.0)
   for e in game.enemies.duplicate():
    if is_instance_valid(e) and e!=victim and not e.dead and e.global_position.distance_to(Vector3(pos.x,e.global_position.y,pos.z))<radius_damage:
     game.hurt(e,damage*.4,source,pos,"energy",.4)
  _:
   if victim is SectorActor and is_instance_valid(source) and victim.team!=source.team:
    game.hurt(victim,damage,source,source.global_position,"energy",.8)
   game.flash(pos,color,.24)
 queue_free()
